# Accountex Manufacturing Module Business Logic - Part 2

## 4. Integration Points

### 4.1 Inventory Control Integration

#### Integration Logic

```elixir
defmodule Accountex.Manufacturing.InventoryIntegration do
  def handle_inventory_event(event) do
    case event do
      {:component_allocation, params} -> 
        reduce_available_quantity(params)
      
      {:wip_posting, params} -> 
        reduce_on_hand_quantity(params)
      
      {:job_completion, params} -> 
        increase_finished_goods_quantity(params)
      
      {:work_order_void, params} -> 
        reverse_inventory_transactions(params)
    end
  end
  
  defp reduce_available_quantity(%{item_id: item_id, quantity: qty}) do
    Accountex.Inventory.update_item(item_id, %{
      available_quantity: {:decrement, qty}
    })
  end
end
```

### 4.2 Sales Order Integration

#### Make-to-Order Logic

```elixir
defmodule Accountex.Manufacturing.SalesOrderIntegration do
  def create_work_order_from_sales_order(sales_order) do
    work_order_lines = 
      sales_order.line_items
      |> Enum.filter(fn item -> item.item.make_or_buy == :make end)
      |> Enum.map(fn line_item ->
        %{
          item_id: line_item.item_id,
          quantity: line_item.backorder_qty,
          request_date: line_item.required_date,
          sales_order_id: sales_order.id,
          sales_order_line_id: line_item.id
        }
      end)
    
    Accountex.Manufacturing.create_work_order(%{
      source: :sales_order,
      source_id: sales_order.id,
      lines: work_order_lines
    })
  end
end
```

### 4.3 Purchase Order Integration

#### Material Requirements Planning

```elixir
defmodule Accountex.Manufacturing.PurchaseIntegration do
  def generate_purchase_requirements(work_orders) do
    work_orders
    |> Enum.flat_map(&get_all_components/1)
    |> Enum.filter(fn component -> component.item.make_or_buy == :buy end)
    |> Enum.reduce(%{}, fn component, requirements ->
      net_requirement = calculate_net_requirement(component)
      
      if net_requirement > 0 do
        Map.update(requirements, component.item_id, net_requirement, &(&1 + net_requirement))
      else
        requirements
      end
    end)
    |> generate_purchase_orders()
  end
  
  defp calculate_net_requirement(component) do
    component.required_qty - component.available_qty
  end
end
```

### 4.4 General Ledger Integration

#### Journal Entry Generation

```elixir
defmodule Accountex.Manufacturing.GLIntegration do
  def post_manufacturing_transaction(transaction_type, params) do
    journal_entries = 
      case transaction_type do
        :wip_posting ->
          [
            %{account: :wip_inventory, debit: params.amount},
            %{account: :raw_materials_inventory, credit: params.amount}
          ]
        
        :labor_applied ->
          [
            %{account: :wip_inventory, debit: params.labor_amount},
            %{account: :labor_clearing, credit: params.labor_amount}
          ]
        
        :job_completion ->
          [
            %{account: :finished_goods_inventory, debit: params.finished_amount},
            %{account: :wip_inventory, credit: params.finished_amount}
          ]
        
        :variance_recognition ->
          variance_entries(params.variance)
      end
    
    Accountex.GeneralLedger.post_journal_entries(journal_entries)
  end
  
  defp variance_entries(variance) when variance > 0 do
    [
      %{account: :manufacturing_variance, debit: variance},
      %{account: :cost_of_goods_sold, credit: variance}
    ]
  end
  
  defp variance_entries(variance) do
    [
      %{account: :cost_of_goods_sold, debit: abs(variance)},
      %{account: :manufacturing_variance, credit: abs(variance)}
    ]
  end
end
```

### 4.5 Lot Control Integration

#### Lot Tracking Logic

```elixir
defmodule Accountex.Manufacturing.LotControl do
  defstruct [:component_lots, :finished_lot, :genealogy]
  
  def track_lot_usage(work_order) do
    component_lots = record_component_lots(work_order.components)
    finished_lot = generate_finished_lot(work_order)
    
    %__MODULE__{
      component_lots: component_lots,
      finished_lot: finished_lot,
      genealogy: build_genealogy_tree(component_lots, finished_lot)
    }
  end
  
  def build_genealogy_tree(component_lots, finished_lot) do
    %{
      lot_number: finished_lot.number,
      production_date: finished_lot.date,
      components: Enum.map(component_lots, fn lot ->
        %{
          lot_number: lot.number,
          item_id: lot.item_id,
          quantity_used: lot.quantity
        }
      end)
    }
  end
end
```

## 5. Business Rules and Validations

### 5.1 Manufacturing Quantity Calculations

#### Quantity Calculation Rules

```elixir
defmodule Accountex.Manufacturing.QuantityCalculator do
  def calculate_manufacturing_quantities(work_order, bom) do
    bom.components
    |> Enum.map(fn component ->
      gross_requirement = work_order.quantity * component.ratio
      scrap_factor = 1 + (component.scrap_percent / 100)
      net_requirement = Float.ceil(gross_requirement * scrap_factor)
      
      %{component | required_quantity: net_requirement}
    end)
  end
end
```

### 5.2 Component Availability Checking

#### Availability Validation

```elixir
defmodule Accountex.Manufacturing.AvailabilityValidator do
  def validate_component_availability(work_order, system_settings) do
    work_order.components
    |> Enum.reduce_while(:ok, fn component, :ok ->
      available_qty = calculate_available(component)
      
      cond do
        component.required_qty <= available_qty ->
          {:cont, :ok}
        
        system_settings.allow_overuse ->
          shortage = component.required_qty - available_qty
          {:cont, {:ok, :with_shortage, shortage}}
        
        true ->
          {:halt, {:error, {:insufficient_inventory, component.item_id}}}
      end
    end)
  end
  
  defp calculate_available(component) do
    component.on_hand - component.allocated + component.on_order
  end
end
```

### 5.3 Resource Capacity Planning

#### Capacity Validation

```elixir
defmodule Accountex.Manufacturing.CapacityValidator do
  def validate_resource_capacity(work_order) do
    with :ok <- validate_machine_capacity(work_order),
         :ok <- validate_labor_capacity(work_order) do
      :ok
    end
  end
  
  defp validate_machine_capacity(work_order) do
    work_order.machine_requirements
    |> Enum.reduce_while(:ok, fn {machine_id, required_hours}, :ok ->
      available_hours = get_available_capacity(
        machine_id,
        work_order.start_date,
        work_order.end_date
      )
      
      if required_hours <= available_hours do
        {:cont, :ok}
      else
        {:halt, {:error, {:insufficient_capacity, :machine, machine_id}}}
      end
    end)
  end
end
```

### 5.4 Cost Rollup Calculations

#### Cost Aggregation Logic

```elixir
defmodule Accountex.Manufacturing.CostRollup do
  def rollup_costs(item, level \\ 0) do
    case has_bom?(item) do
      false -> 
        %{material: 0, labor: 0, overhead: 0}
      
      true ->
        item.bill_of_materials
        |> Enum.reduce(%{material: 0, labor: 0, overhead: 0}, fn component, acc ->
          component_costs = 
            case component.type do
              :material ->
                %{material: component.quantity * component.unit_cost, labor: 0, overhead: 0}
              
              :labor ->
                %{material: 0, labor: component.hours * component.rate, overhead: 0}
              
              :machine ->
                %{material: 0, labor: 0, overhead: component.hours * component.rate}
            end
          
          sub_costs = 
            if is_assembly?(component) do
              rollup_costs(component, level + 1)
            else
              %{material: 0, labor: 0, overhead: 0}
            end
          
          %{
            material: acc.material + component_costs.material + sub_costs.material,
            labor: acc.labor + component_costs.labor + sub_costs.labor,
            overhead: acc.overhead + component_costs.overhead + sub_costs.overhead
          }
        end)
    end
  end
end
```

### 5.5 Production Scheduling Constraints

#### Scheduling Rules

```elixir
defmodule Accountex.Manufacturing.SchedulingConstraints do
  def validate_constraints(work_order) do
    with :ok <- validate_lead_time_constraint(work_order),
         :ok <- validate_resource_constraint(work_order),
         :ok <- validate_dependency_constraint(work_order),
         :ok <- validate_material_constraint(work_order) do
      :ok
    end
  end
  
  defp validate_lead_time_constraint(work_order) do
    finish_date = DateTime.add(work_order.start_date, work_order.manufacturing_lead_time, :day)
    
    if DateTime.compare(finish_date, work_order.required_date) == :lt do
      :ok
    else
      {:error, :lead_time_exceeds_requirement}
    end
  end
  
  defp validate_dependency_constraint(work_order) do
    # Child jobs must complete before parent jobs
    work_order.job_hierarchy
    |> validate_job_dependencies()
  end
end
```

## 6. Reporting and Analysis Requirements

### 6.1 Work Order Status Tracking

#### Status Report Generation

```elixir
defmodule Accountex.Manufacturing.Reports.WorkOrderStatus do
  def generate_report(filters) do
    work_orders = fetch_work_orders(filters)
    
    work_orders
    |> Enum.map(fn wo ->
      %{
        work_order_id: wo.id,
        item: wo.item.description,
        requested_qty: wo.requested_qty,
        in_process_qty: wo.in_process_qty,
        completed_qty: wo.completed_qty,
        status: wo.status,
        percent_complete: (wo.completed_qty / wo.requested_qty) * 100,
        days_in_process: Date.diff(Date.utc_today(), wo.start_date),
        estimated_completion: calculate_estimated_completion(wo)
      }
    end)
  end
  
  defp calculate_estimated_completion(work_order) do
    percent_remaining = (work_order.requested_qty - work_order.completed_qty) / work_order.requested_qty
    days_needed = work_order.standard_lead_time * percent_remaining
    Date.add(Date.utc_today(), trunc(days_needed))
  end
end
```

### 6.2 Material Requirements Planning

#### MRP Report Logic

```elixir
defmodule Accountex.Manufacturing.Reports.MRP do
  def generate_mrp_report(items, period) do
    items
    |> Enum.map(fn item ->
      gross_requirement = calculate_gross_requirements(item, period)
      scheduled_receipts = calculate_scheduled_receipts(item, period)
      projected_on_hand = item.current_on_hand + scheduled_receipts - gross_requirement
      
      net_requirement = 
        if projected_on_hand < item.safety_stock do
          item.safety_stock - projected_on_hand
        else
          0
        end
      
      planned_order = 
        if net_requirement > 0 do
          Float.ceil(net_requirement / item.order_quantity) * item.order_quantity
        else
          0
        end
      
      %{
        item_id: item.id,
        gross_requirement: gross_requirement,
        scheduled_receipts: scheduled_receipts,
        projected_on_hand: projected_on_hand,
        net_requirement: net_requirement,
        planned_order: planned_order
      }
    end)
  end
end
```

### 6.3 Resource Utilization Analysis

#### Utilization Metrics

```elixir
defmodule Accountex.Manufacturing.Reports.ResourceUtilization do
  def calculate_machine_utilization(machine, period) do
    allocated_hours = get_allocated_hours(machine, period)
    available_hours = get_available_hours(machine, period)
    standard_hours = get_standard_hours(machine, period)
    actual_hours = get_actual_hours(machine, period)
    
    %{
      machine_id: machine.id,
      utilization_rate: (allocated_hours / available_hours) * 100,
      efficiency: (standard_hours / actual_hours) * 100,
      downtime: calculate_downtime(machine, period)
    }
  end
  
  def calculate_labor_utilization(labor, period) do
    %{
      labor_id: labor.id,
      productive_hours: labor.direct_labor_hours / labor.total_hours,
      efficiency: labor.standard_hours / labor.actual_hours,
      overtime_percentage: (labor.overtime_hours / labor.total_hours) * 100
    }
  end
end
```

### 6.4 Production Variance Reporting

#### Variance Analysis

```elixir
defmodule Accountex.Manufacturing.Reports.Variance do
  def calculate_variances(work_order) do
    %{
      material: calculate_material_variance(work_order),
      labor: calculate_labor_variance(work_order),
      overhead: calculate_overhead_variance(work_order)
    }
  end
  
  defp calculate_material_variance(work_order) do
    price_variance = 
      (work_order.standard_price - work_order.actual_price) * work_order.actual_quantity
    
    quantity_variance = 
      (work_order.standard_quantity - work_order.actual_quantity) * work_order.standard_price
    
    %{
      price_variance: price_variance,
      quantity_variance: quantity_variance,
      total: price_variance + quantity_variance
    }
  end
  
  defp calculate_labor_variance(work_order) do
    rate_variance = 
      (work_order.standard_rate - work_order.actual_rate) * work_order.actual_hours
    
    efficiency_variance = 
      (work_order.standard_hours - work_order.actual_hours) * work_order.standard_rate
    
    %{
      rate_variance: rate_variance,
      efficiency_variance: efficiency_variance,
      total: rate_variance + efficiency_variance
    }
  end
end
```

### 6.5 WIP Tracking

#### WIP Analysis

```elixir
defmodule Accountex.Manufacturing.Reports.WIPTracking do
  def analyze_wip(date \\ Date.utc_today()) do
    wip_items = get_wip_items(date)
    
    %{
      total_value: calculate_total_wip_value(wip_items),
      aging: categorize_by_age(wip_items),
      turnover: calculate_wip_turnover(wip_items),
      days_in_wip: 365 / calculate_wip_turnover(wip_items)
    }
  end
  
  defp categorize_by_age(wip_items) do
    wip_items
    |> Enum.group_by(fn item ->
      days = Date.diff(Date.utc_today(), item.start_date)
      
      cond do
        days <= 30 -> :current
        days <= 60 -> :aged
        days <= 90 -> :old
        true -> :very_old
      end
    end)
    |> Enum.map(fn {category, items} ->
      {category, Enum.sum(Enum.map(items, & &1.value))}
    end)
    |> Map.new()
  end
end
```

### 6.6 Manufacturing Performance Metrics

#### KPI Calculations

```elixir
defmodule Accountex.Manufacturing.KPIs do
  def calculate_kpis(period) do
    %{
      first_pass_yield: calculate_first_pass_yield(period),
      oee: calculate_oee(period),
      manufacturing_cost_per_unit: calculate_cost_per_unit(period),
      on_time_delivery: calculate_on_time_delivery(period),
      scrap_rate: calculate_scrap_rate(period),
      inventory_turnover: calculate_inventory_turnover(period)
    }
  end
  
  def calculate_oee(period) do
    availability = calculate_availability(period)
    performance = calculate_performance(period)
    quality = calculate_quality(period)
    
    availability * performance * quality
  end
  
  defp calculate_availability(period) do
    run_time = get_run_time(period)
    planned_production_time = get_planned_production_time(period)
    run_time / planned_production_time
  end
  
  defp calculate_performance(period) do
    actual_output = get_actual_output(period)
    theoretical_output = get_theoretical_output(period)
    actual_output / theoretical_output
  end
  
  defp calculate_quality(period) do
    good_units = get_good_units(period)
    total_units = get_total_units(period)
    good_units / total_units
  end
end
```

## 7. System Configuration and Parameters

### 7.1 Global Manufacturing Settings

```elixir
defmodule Accountex.Manufacturing.Settings do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :allow_overuse_of_inventory, :boolean, default: false
    attribute :auto_explode_work_orders, :boolean, default: true
    attribute :auto_post_to_wip, :boolean, default: false
    attribute :default_cost_method, :atom do
      constraints one_of: [:standard, :average, :fifo, :lifo]
    end
    attribute :overhead_allocation_method, :atom do
      constraints one_of: [:percentage, :fixed_amount]
    end
    attribute :require_quality_approval, :boolean, default: false
    attribute :enable_multi_level_bom, :boolean, default: true
    attribute :max_bom_depth, :integer, default: 0  # 0 = unlimited
    attribute :default_manufacturing_lead_time_days, :integer, default: 7
    attribute :work_week_definition, :map  # days and hours
  end
end
```

### 7.2 Validation Parameters

```elixir
defmodule Accountex.Manufacturing.ValidationSettings do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :enforce_component_availability, :boolean, default: true
    attribute :validate_resource_capacity, :boolean, default: true
    attribute :require_approval_for_variance, :boolean, default: false
    attribute :variance_threshold_percent, :decimal, default: 10.0
    attribute :prevent_negative_inventory, :boolean, default: true
    attribute :require_serial_tracking, :boolean, default: false
    attribute :require_lot_tracking, :boolean, default: false
  end
end
```

## 8. Error Handling and Exception Management

### 8.1 Exception Types

```elixir
defmodule Accountex.Manufacturing.Exceptions do
  defmodule InsufficientInventoryError do
    defexception [:item_id, :required, :available, :message]
    
    def exception(opts) do
      %__MODULE__{
        item_id: opts[:item_id],
        required: opts[:required],
        available: opts[:available],
        message: "Insufficient inventory for item #{opts[:item_id]}: required #{opts[:required]}, available #{opts[:available]}"
      }
    end
  end
  
  defmodule ResourceCapacityError do
    defexception [:resource_id, :resource_type, :required_hours, :available_hours, :message]
  end
  
  defmodule CircularBOMError do
    defexception [:item_id, :path, :message]
    
    def exception(opts) do
      %__MODULE__{
        item_id: opts[:item_id],
        path: opts[:path],
        message: "Circular reference detected in BOM for item #{opts[:item_id]}: #{Enum.join(opts[:path], " -> ")}"
      }
    end
  end
  
  defmodule CostCalculationError do
    defexception [:item_id, :reason, :message]
  end
end
```

### 8.2 Transaction Rollback Logic

```elixir
defmodule Accountex.Manufacturing.TransactionRollback do
  def rollback_transaction(transaction) do
    case transaction.type do
      :work_order_explosion ->
        rollback_explosion(transaction)
      
      :wip_posting ->
        rollback_wip_posting(transaction)
      
      :job_completion ->
        rollback_job_completion(transaction)
      
      _ ->
        {:error, :unknown_transaction_type}
    end
  end
  
  defp rollback_explosion(transaction) do
    with :ok <- release_allocated_inventory(transaction.components),
         :ok <- delete_generated_jobs(transaction.jobs) do
      :ok
    end
  end
  
  defp rollback_wip_posting(transaction) do
    with :ok <- reverse_inventory_consumption(transaction.materials),
         :ok <- reverse_labor_application(transaction.labor),
         :ok <- reverse_gl_postings(transaction.journal_entries) do
      :ok
    end
  end
  
  defp rollback_job_completion(transaction) do
    with :ok <- reverse_inventory_increase(transaction.finished_goods),
         :ok <- restore_wip_balance(transaction.wip_reduction),
         :ok <- reverse_variance_postings(transaction.variances) do
      :ok
    end
  end
end
```

## 9. Audit and Compliance

### 9.1 Audit Trail Requirements

```elixir
defmodule Accountex.Manufacturing.AuditLog do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :transaction_id, :uuid
    attribute :transaction_type, :atom do
      constraints one_of: [:create, :update, :delete, :post]
    end
    attribute :entity_type, :atom do
      constraints one_of: [:work_order, :bom, :job, :component]
    end
    attribute :entity_id, :uuid
    attribute :user_id, :uuid
    attribute :timestamp, :utc_datetime_usec
    attribute :before_value, :map
    attribute :after_value, :map
    attribute :ip_address, :string
    attribute :reason_code, :string
  end
  
  calculations do
    calculate :changes, :map, fn record ->
      MapDiff.diff(record.before_value, record.after_value)
    end
  end
end
```

### 9.2 Compliance Controls

```elixir
defmodule Accountex.Manufacturing.ComplianceControls do
  def validate_lot_traceability(finished_lot) do
    # Complete genealogy from raw materials to finished goods
    genealogy = build_complete_genealogy(finished_lot)
    
    # Support for recalls and quality investigations
    affected_lots = trace_affected_lots(finished_lot)
    
    %{
      genealogy: genealogy,
      affected_lots: affected_lots,
      compliance_status: :compliant
    }
  end
  
  def validate_cost_accounting_compliance(work_order) do
    # GAAP-compliant inventory valuation
    # Proper WIP recognition and reporting
    %{
      valuation_method: work_order.cost_method,
      wip_recognition: :proper,
      gaap_compliant: true
    }
  end
  
  def enforce_quality_checkpoints(job) do
    required_checkpoints = get_required_checkpoints(job)
    completed_checkpoints = get_completed_checkpoints(job)
    
    MapSet.subset?(
      MapSet.new(required_checkpoints),
      MapSet.new(completed_checkpoints)
    )
  end
end
```

---

*This is Part 2 of 3. See [manufacturing_logic_part1.md](./manufacturing_logic_part1.md) for Core Processes and [manufacturing_logic_part3.md](./manufacturing_logic_part3.md) for Advanced Features.*