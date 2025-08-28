# Accountex Manufacturing Module Business Logic

## 1. Core Manufacturing Processes and Workflows

### 1.1 Work Order Creation and Management

#### Work Order Initialization Logic

- **Creation Methods**: System supports three primary creation pathways:
  - Manual creation with full parameter control
  - Copy from existing work order with automatic field population
  - Generation from open sales orders with quantity and specification inheritance
- **Master Item Configuration**: Each work order can contain unlimited master items with independent production parameters
- **Backorder Integration**: System automatically pulls backorder quantities from sales orders as default manufacturing quantities
- **Hold Management**: Work orders can be placed on hold status pending component availability

#### Work Order Structure

- **Multi-Level Job Hierarchy**: Each master item explodes into unlimited job levels with parent-child relationships
- **Step-Based Manufacturing**: Components assigned sequential step numbers matching actual production flow
- **Production Scheduling**: Support for multiple start dates and request dates per work order line item
- **Resource Allocation**: Automatic allocation of raw materials and subassemblies upon work order explosion

#### Work Order State Management

Work orders maintain the following state transitions:

- **Created** → **Exploded** → **WIP Posted** → **In Process** → **Finished** → **Closed**
- **Void States**: Can be voided entirely or up to specific step numbers
- **Amendment Capability**: Component lists modifiable after explosion
- **Status Tracking**: Real-time status monitoring through multiple report types

### 1.2 Bill of Materials (BOM) Handling

#### BOM Structure and Logic

- **Component Relationships**: Define ratio of component items required to produce one parent item unit
- **Resource Integration**: Machine and labor resources applied through BOM assignments
- **Version Control**: Multiple BOM versions maintained with change tracking and rollback capability
- **Production Rates**: Customizable labor and machine production rates per BOM

#### Component Management Rules

- **Component Types Supported**:
  - Inventory items (raw materials, subassemblies)
  - Machine resources with cost and time tracking
  - Labor resources with skill and rate management
  - Non-stock items for services and intangibles
- **Substitution Logic**: Multiple substitute items definable for each component
- **Step Assignment**: Components assigned to specific manufacturing steps for sequencing
- **Manufacturing Instructions**: Unlimited notes and instructions stored with each BOM

#### BOM Maintenance Logic

- **Dynamic Updates**: BOMs updatable without affecting existing work orders
- **Copy Functionality**: Components and entire BOMs copyable within or across companies
- **Batch Replacement**: Simultaneous replacement of specific components across multiple BOMs
- **Specification Integration**: Separate BOMs for each item specification combination

### 1.3 Work Order Explosion Process

#### Explosion Mechanics

- **Timing Options**:
  - Automatic explosion during work order creation
  - Deferred explosion for faster data entry
- **Multi-Level Processing**: System recursively explodes through unlimited levels
- **Job Hierarchy Generation**: Creates parent-child relationships for all components

#### Explosion Calculation Logic

```elixir
defmodule Accountex.Manufacturing.Explosion do
  def explode_work_order(work_order, master_item) do
    with {:ok, component_quantities} <- calculate_components(master_item, work_order.production_qty),
         {:ok, available} <- check_inventory_availability(component_quantities),
         {:ok, resources} <- calculate_resource_requirements(master_item, work_order.production_qty),
         {:ok, lead_times} <- calculate_lead_times(component_quantities),
         {:ok, job_hierarchy} <- generate_job_hierarchy(component_quantities, work_order) do
      {:ok, %{
        components: component_quantities,
        available_inventory: available,
        resource_requirements: resources,
        lead_time: lead_times,
        job_hierarchy: job_hierarchy
      }}
    end
  end

  defp calculate_components(item, production_qty) do
    item.bill_of_materials
    |> Enum.map(fn component ->
      %{
        item_id: component.item_id,
        required_qty: production_qty * component.ratio,
        step_number: component.step_number
      }
    end)
    |> then(&{:ok, &1})
  end
end
```

#### Explosion Control Features

- **Selective Explosion**: Can explode entire work orders or specific line items
- **Step-Level Control**: Explosion controllable to specific step numbers
- **Material Requirements Planning**: Automatic generation of material requirement projections
- **Subassembly Optimization**: System determines make vs. buy decisions for subassemblies

### 1.4 Work-in-Process (WIP) Posting

#### WIP Posting Logic

- **Posting Options**:
  - Automatic posting upon work order save
  - Manual posting for control
  - Step-by-step posting for gradual processing
  - Job-specific posting without affecting other jobs
- **Cost Application Methods**:
  - Actual cost: Apply actual material, labor, and machine costs
  - Standard cost: Apply predetermined standard costs
  - Hybrid: Actual costs for components, standard for finished items

#### WIP Accounting Rules

```elixir
defmodule Accountex.Manufacturing.WIP do
  def calculate_wip_value(work_order, cost_method) do
    materials = calculate_material_cost(work_order.components, cost_method)
    labor = calculate_labor_cost(work_order.labor_hours, work_order.labor_rate)
    machine = calculate_machine_cost(work_order.machine_hours, work_order.machine_rate)
    overhead = calculate_overhead(materials + labor + machine, work_order.overhead_method)
    
    %{
      materials: materials,
      labor: labor,
      machine: machine,
      overhead: overhead,
      total: materials + labor + machine + overhead
    }
  end
end
```

#### WIP State Management

- **Status Tracking**: Each work order maintains WIP status by component
- **Completion Estimates**: Calculate estimated completion based on historical data
- **Voiding Capability**: WIP voidable entirely or up to specific step numbers
- **General Ledger Integration**: Automatic journal entry generation for WIP transactions

### 1.5 Finished Job Posting

#### Job Completion Processing Logic

- **Completion Options**:
  - Complete entire work order with all subsidiary jobs
  - Selective job completion while others remain in process
  - Step-level completion with remaining components in WIP
  - Quality hold option before inventory release

#### Finished Goods Integration

```elixir
defmodule Accountex.Manufacturing.JobCompletion do
  def complete_job(job, options \\ []) do
    with :ok <- validate_prerequisites(job, options),
         {:ok, variance} <- calculate_cost_variance(job),
         {:ok, _} <- transfer_costs_to_finished_goods(job),
         {:ok, updated_inventory} <- update_inventory_levels(job),
         {:ok, serial_numbers} <- assign_serial_numbers(job, options[:require_serial]),
         {:ok, documentation} <- generate_completion_documents(job) do
      {:ok, %{
        job: job,
        variance: variance,
        inventory: updated_inventory,
        serial_numbers: serial_numbers,
        documentation: documentation
      }}
    end
  end
  
  defp validate_prerequisites(job, options) do
    unless options[:force_complete] do
      prerequisite_jobs_complete?(job)
    else
      :ok
    end
  end
end
```

#### Production Variance Analysis

- **Variance Tracking Components**:
  - Material variance = (Standard Qty × Standard Price) - (Actual Qty × Actual Price)
  - Labor variance = (Standard Hours × Standard Rate) - (Actual Hours × Actual Rate)
  - Overhead variance = Applied Overhead - Actual Overhead
- **Efficiency Metrics**: Track actual vs. expected performance

### 1.6 Multi-Level Manufacturing Components

#### Hierarchical Structure Management

- **Level Processing**: System maintains unlimited parent-child levels
- **Modular BOMs**: Subassemblies managed as independent reusable modules
- **Assembly Hierarchy**: Clear level designation for tracking
- **Dependency Management**: Cross-level dependencies tracked and validated

#### Nested BOM Processing Logic

```elixir
defmodule Accountex.Manufacturing.BOM do
  def explode_component(item, level, quantity) do
    case has_bom?(item) do
      false -> {:ok, []}
      true ->
        item.bill_of_materials
        |> Enum.flat_map(fn component ->
          required_qty = quantity * component.ratio
          
          with {:ok, _} <- allocate_inventory(component, required_qty),
               child_components <- if component.is_assembly do
                 {:ok, children} = explode_component(component, level + 1, required_qty)
                 children
               else
                 []
               end do
            [%{
              item: component,
              level: level,
              quantity: required_qty,
              children: child_components
            }]
          end
        end)
        |> then(&{:ok, &1})
    end
  end
end
```

#### Complex Product Management

- **Multi-Level Costing**: Costs propagate through all component levels
- **Lead Time Cascading**: Cumulative lead times calculated across levels
- **Resource Scheduling**: Machine and labor scheduled considering all levels
- **Selective Manufacturing**: Choose to manufacture or use existing inventory at each level

## 2. Master Data Management

### 2.1 Machine Records

#### Machine Record Structure

```elixir
defmodule Accountex.Manufacturing.Machine do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :machine_id, :string, allow_nil?: false
    attribute :description, :string
    attribute :production_rate, :decimal
    attribute :cost_per_hour, :decimal
    attribute :work_shifts, {:array, :string}
    attribute :setup_time, :integer
    attribute :teardown_time, :integer
    attribute :maintenance_schedule_hours, :integer
    attribute :current_utilization, :decimal
    attribute :availability_status, :atom do
      constraints one_of: [:available, :busy, :maintenance]
    end
  end
end
```

#### Machine Resource Logic

```elixir
defmodule Accountex.Manufacturing.MachineCapacity do
  def calculate_available_capacity(machine, shift_hours, efficiency_rate) do
    allocated_hours = get_allocated_hours(machine)
    (shift_hours - allocated_hours) * efficiency_rate
  end
  
  def calculate_machine_cost(machine, setup_time, production_time, teardown_time) do
    total_time = setup_time + production_time + teardown_time
    total_time * machine.cost_per_hour
  end
  
  def validate_availability(machine, requested_time) do
    available_capacity = calculate_available_capacity(machine, 8.0, 0.85)
    
    if requested_time <= available_capacity do
      :ok
    else
      {:error, :insufficient_capacity}
    end
  end
end
```

### 2.2 Labor Records

#### Labor Record Structure

```elixir
defmodule Accountex.Manufacturing.Labor do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :labor_id, :string, allow_nil?: false
    attribute :description, :string
    attribute :skill_level, :string
    attribute :standard_rate, :decimal
    attribute :overtime_rate, :decimal
    attribute :work_shifts, {:array, :string}
    attribute :current_allocation_hours, :decimal
    attribute :skills, {:array, :string}
    attribute :efficiency_factor, :decimal
  end
end
```

#### Labor Cost Application

```elixir
defmodule Accountex.Manufacturing.LaborCost do
  def calculate_labor_cost(labor, hours_worked, is_overtime) do
    rate = if is_overtime, do: labor.overtime_rate, else: labor.standard_rate
    hours_worked * rate * labor.efficiency_factor
  end
  
  def apply_overhead(labor_cost, overhead_method) do
    case overhead_method do
      {:percentage, percent} -> labor_cost * (1 + percent / 100)
      {:fixed_amount, amount} -> labor_cost + amount
    end
  end
  
  def validate_skill_requirements(labor, required_skills) do
    MapSet.subset?(
      MapSet.new(required_skills),
      MapSet.new(labor.skills)
    )
  end
end
```

### 2.3 Inventory Items with Manufacturing Capabilities

#### Manufacturing-Specific Fields

```elixir
defmodule Accountex.Manufacturing.Item do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :item_id, :string, allow_nil?: false
    attribute :description, :string
    attribute :item_type, :atom do
      constraints one_of: [:raw, :assembly, :finished, :non_stock]
    end
    attribute :manufacturing_lead_time_days, :integer
    attribute :safety_stock, :decimal
    attribute :reorder_point, :decimal
    attribute :reorder_quantity, :decimal
    attribute :cost_method, :atom do
      constraints one_of: [:standard, :average, :fifo, :lifo]
    end
    attribute :make_or_buy, :atom do
      constraints one_of: [:make, :buy, :either]
    end
    attribute :specifications, :map
    attribute :lot_controlled, :boolean, default: false
    attribute :serial_controlled, :boolean, default: false
  end

  relationships do
    has_many :bill_of_materials, Accountex.Manufacturing.BOMComponent
    has_many :substitute_items, Accountex.Manufacturing.SubstituteItem
  end
end
```

#### Manufacturing Item Validation Rules

```elixir
defmodule Accountex.Manufacturing.ItemValidation do
  def validate_item_type_consistency(item, bom_requirements) do
    case {item.item_type, bom_requirements} do
      {:raw, %{can_have_bom: true}} -> {:error, :raw_materials_cannot_have_bom}
      {:finished, %{must_be_component: true}} -> {:error, :finished_goods_cannot_be_component}
      _ -> :ok
    end
  end
  
  def validate_specification_match(item, required_specs) do
    required_specs
    |> Enum.all?(fn {key, value} ->
      Map.get(item.specifications, key) == value
    end)
    |> case do
      true -> :ok
      false -> {:error, :specification_mismatch}
    end
  end
end
```

### 2.4 Inventory Types for Manufacturing

#### Type-Specific Processing Rules

```elixir
defmodule Accountex.Manufacturing.ItemTypeProcessor do
  def process_by_type(item, operation) do
    case item.item_type do
      :raw -> process_raw_material(item, operation)
      :assembly -> process_subassembly(item, operation)
      :finished -> process_finished_good(item, operation)
      :non_stock -> process_non_stock(item, operation)
      _ -> {:error, :unknown_item_type}
    end
  end
  
  defp process_raw_material(item, :allocate) do
    # Vendor management with lead time tracking
    # Automatic allocation to work orders
    # Purchase order integration for replenishment
  end
  
  defp process_subassembly(item, :make_or_buy_decision) do
    cond do
      item.on_hand >= item.required_qty -> {:decision, :use_existing}
      item.make_or_buy == :make -> {:decision, :manufacture}
      item.make_or_buy == :buy -> {:decision, :purchase}
      true -> optimize_make_vs_buy(item)
    end
  end
end
```

### 2.5 System Remarks and Notes

#### Notes Management Structure

```elixir
defmodule Accountex.Manufacturing.SystemRemark do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :entity_type, :atom do
      constraints one_of: [:machine, :labor, :item, :work_order, :bom]
    end
    attribute :entity_id, :uuid
    attribute :note_type, :atom do
      constraints one_of: [:instruction, :warning, :information]
    end
    attribute :language, :string, default: "en"
    attribute :text, :text
    attribute :attachments, {:array, :string}
    attribute :propagate_to_documents, :boolean, default: false
    attribute :print_on_reports, :boolean, default: true
  end
end
```

## 3. Transaction Flows and State Management

### 3.1 Work Order Lifecycle States

#### State Transition Logic

```elixir
defmodule Accountex.Manufacturing.WorkOrderStateMachine do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  state_machine do
    initial_states [:created]
    default_initial_state :created

    transitions do
      transition :explode, from: :created, to: :exploded
      transition :post_wip, from: :exploded, to: :wip_posted
      transition :start_production, from: :wip_posted, to: :in_process
      transition :finish, from: :in_process, to: :finished
      transition :close, from: :finished, to: :closed
      transition :void, from: :*, to: :voided
    end
  end

  changes do
    change transition_state(:explode) do
      before_change fn changeset, _ ->
        validate_explosion_requirements(changeset)
      end
    end
    
    change transition_state(:finish) do
      before_change fn changeset, _ ->
        validate_all_jobs_complete(changeset)
      end
    end
  end
end
```

#### State Validation Rules

- Parent items cannot complete until child components finish
- WIP posting required before marking in-process
- Quality hold prevents automatic closure

### 3.2 Component Allocation and Consumption

#### Allocation Logic

```elixir
defmodule Accountex.Manufacturing.ComponentAllocation do
  def allocate_components(work_order) do
    work_order.components
    |> Enum.reduce_while({:ok, []}, fn component, {:ok, allocations} ->
      with {:ok, available_qty} <- get_available_inventory(component.item_id),
           required_qty <- calculate_requirement(component, work_order.quantity),
           {:ok, allocated} <- perform_allocation(component, required_qty, available_qty) do
        {:cont, {:ok, [allocated | allocations]}}
      else
        {:error, :insufficient_inventory} = error when not work_order.allow_overuse ->
          {:halt, error}
        {:error, :insufficient_inventory} ->
          allocated = %{component | allocated_qty: available_qty, shortage: required_qty - available_qty}
          {:cont, {:ok, [allocated | allocations]}}
      end
    end)
  end
  
  defp perform_allocation(component, required_qty, available_qty) do
    allocated = min(required_qty, available_qty)
    
    with :ok <- update_inventory_allocation(component.item_id, allocated) do
      {:ok, %{component | allocated_qty: allocated}}
    end
  end
end
```

#### Consumption Tracking

- **Real-time Updates**: Inventory levels adjusted immediately upon consumption
- **Scrap Recording**: Track waste and remnants during production
- **Lot Tracking**: Maintain lot genealogy through production

### 3.3 Resource Scheduling

#### Scheduling Algorithm

```elixir
defmodule Accountex.Manufacturing.ResourceScheduler do
  def schedule_resources(work_order) do
    work_order.jobs
    |> Enum.reduce({:ok, []}, fn job, {:ok, scheduled_jobs} ->
      with {:ok, machine_slot} <- find_machine_slot(job),
           {:ok, labor_slot} <- find_labor_slot(job),
           {:ok, scheduled_job} <- schedule_job(job, machine_slot, labor_slot) do
        {:ok, [scheduled_job | scheduled_jobs]}
      end
    end)
  end
  
  defp schedule_job(job, machine_slot, labor_slot) do
    scheduled_start = max(machine_slot.start, labor_slot.start)
    duration = max(machine_slot.duration, labor_slot.duration)
    
    job
    |> Map.put(:scheduled_start, scheduled_start)
    |> Map.put(:scheduled_end, DateTime.add(scheduled_start, duration, :minute))
    |> reserve_resources()
  end
  
  defp reserve_resources(job) do
    with :ok <- reserve_machine(job.machine_id, job.scheduled_start, job.scheduled_end),
         :ok <- reserve_labor(job.labor_id, job.scheduled_start, job.scheduled_end) do
      {:ok, job}
    end
  end
end
```

### 3.4 Cost Tracking and Variance

#### Cost Flow Logic

```elixir
defmodule Accountex.Manufacturing.CostFlow do
  defstruct [
    :material_cost,
    :labor_cost,
    :machine_cost,
    :overhead_cost,
    :total_cost
  ]
  
  def calculate_costs(work_order) do
    %__MODULE__{
      material_cost: sum_material_costs(work_order.components),
      labor_cost: sum_labor_costs(work_order.labor_entries),
      machine_cost: sum_machine_costs(work_order.machine_entries),
      overhead_cost: apply_overhead(work_order)
    }
    |> calculate_total()
  end
  
  def calculate_variance(standard_costs, actual_costs) do
    %{
      material: standard_costs.material_cost - actual_costs.material_cost,
      labor: standard_costs.labor_cost - actual_costs.labor_cost,
      overhead: standard_costs.overhead_cost - actual_costs.overhead_cost,
      total: standard_costs.total_cost - actual_costs.total_cost
    }
  end
  
  defp calculate_total(%__MODULE__{} = costs) do
    total = costs.material_cost + costs.labor_cost + costs.machine_cost + costs.overhead_cost
    %{costs | total_cost: total}
  end
end
```

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

This comprehensive business logic document defines the core functionality and rules for the Accountex Manufacturing Module using Elixir and Ash framework patterns, providing a complete blueprint for implementation without any UI/UX considerations. The logic focuses on robust manufacturing control, flexible configuration, comprehensive reporting, and seamless integration with other Accountex modules.

# Manufacturing Application Business Logic

## Overview

The Manufacturing application manages the complete production lifecycle from work order creation through finished goods posting. It integrates with Inventory, Sales, and General Ledger applications to provide comprehensive production management capabilities.

## Core Aggregates

### 1. WorkOrder Aggregate

Represents a production request for one or more master items.

#### Commands

##### CreateWorkOrder

- **Input**:
  - work_order_number (optional if auto-generated)
  - order_date
  - request_date
  - warehouse_id
  - sales_order_id (optional)
  - customer_id (optional)
  - system_remark_id (optional)
  - remarks (optional)
  - on_hold (boolean)
  - explode_on_creation (boolean)
  - allow_multiple_request_dates (boolean)
  - master_items (list of items with quantities and request dates)

- **Validations**:
  - Warehouse must exist and be active
  - Sales order must exist if provided
  - Customer must exist if provided
  - Master items must have valid BOM records
  - Request dates must be future or current dates
  - Manufacturing quantities must be positive

- **Events Emitted**:
  - WorkOrderCreated
  - MasterItemAddedToWorkOrder (for each master item)
  - WorkOrderPlacedOnHold (if on_hold = true)

##### AmendWorkOrder

- **Input**:
  - work_order_id
  - updates (fields to update)
  - master_items_to_add (optional)
  - master_items_to_remove (optional)

- **Validations**:
  - Work order must exist and not be voided
  - Cannot amend if all jobs are posted to WIP
  - Cannot change manufacturing quantities for items in WIP
  - Cannot remove master items that are in process or finished

- **Events Emitted**:
  - WorkOrderAmended
  - MasterItemAddedToWorkOrder (for additions)
  - MasterItemRemovedFromWorkOrder (for removals)

##### VoidWorkOrder

- **Input**:
  - work_order_id
  - reason

- **Validations**:
  - Work order must exist
  - No items can be in WIP or finished status
  - Must void all WIP and finished jobs first

- **Events Emitted**:
  - WorkOrderVoided

##### PlaceWorkOrderOnHold

- **Input**:
  - work_order_id
  - reason

- **Validations**:
  - Work order must exist and not be voided
  - Work order must not already be on hold

- **Events Emitted**:
  - WorkOrderPlacedOnHold

##### ReleaseWorkOrderFromHold

- **Input**:
  - work_order_id

- **Validations**:
  - Work order must exist and be on hold

- **Events Emitted**:
  - WorkOrderReleasedFromHold

#### State

```elixir
%WorkOrder{
  id: UUID,
  work_order_number: String,
  order_date: Date,
  request_date: Date,
  warehouse_id: UUID,
  sales_order_id: UUID | nil,
  customer_id: UUID | nil,
  system_remark_id: UUID | nil,
  remarks: String,
  on_hold: boolean,
  exploded: boolean,
  allow_multiple_request_dates: boolean,
  master_items: [%MasterItem{}],
  jobs: [%Job{}],
  status: :draft | :exploded | :in_process | :completed | :voided
}
```

### 2. BillOfMaterials Aggregate

Manages the component structure for manufactured items.

#### Commands

##### CreateBillOfMaterials

- **Input**:
  - parent_item_id
  - components (list of component items with types and quantities)
  - instructions (optional)

- **Validations**:
  - Parent item must exist and be a manufactured item
  - Component items must exist
  - Quantities must be positive
  - Cannot create circular dependencies

- **Events Emitted**:
  - BillOfMaterialsCreated
  - ComponentAddedToBOM (for each component)

##### UpdateBillOfMaterials

- **Input**:
  - bom_id
  - components_to_add
  - components_to_update
  - components_to_remove
  - instructions (optional)

- **Validations**:
  - BOM must exist
  - Cannot update if used in active work orders
  - Must maintain valid component structure

- **Events Emitted**:
  - BillOfMaterialsUpdated
  - ComponentAddedToBOM
  - ComponentUpdatedInBOM
  - ComponentRemovedFromBOM

#### State

```elixir
%BillOfMaterials{
  id: UUID,
  parent_item_id: UUID,
  components: [%Component{}],
  instructions: String,
  active: boolean,
  revision_number: Integer
}

%Component{
  id: UUID,
  type: :inventory | :labor | :machine,
  component_id: UUID,
  quantity: Decimal | nil,
  time_required: Duration | nil,
  setup_time: Duration | nil,
  teardown_time: Duration | nil,
  work_shift_id: UUID | nil
}
```

### 3. WorkOrderExplosion Aggregate

Manages the explosion process that breaks down work orders into manufacturable jobs.

#### Commands

##### ExplodeWorkOrder

- **Input**:
  - work_order_id
  - explosion_options (substitute handling, subassembly options)

- **Validations**:
  - Work order must exist and not be exploded
  - All master items must have valid BOMs
  - Check inventory availability if configured
  - Check machine availability if configured
  - Validate substitute items if needed

- **Events Emitted**:
  - WorkOrderExplosionStarted
  - JobCreated (for each manufacturing job)
  - ComponentAllocated (for each component allocation)
  - SubstituteItemUsed (if substitutes applied)
  - WorkOrderExplosionCompleted

##### ExplodePartialWorkOrder

- **Input**:
  - work_order_id
  - master_item_ids (specific items to explode)

- **Validations**:
  - Work order must exist
  - Specified master items must not already be exploded
  - Same validation as full explosion for selected items

- **Events Emitted**:
  - PartialExplosionStarted
  - JobCreated
  - ComponentAllocated
  - PartialExplosionCompleted

#### State

```elixir
%WorkOrderExplosion{
  id: UUID,
  work_order_id: UUID,
  explosion_date: DateTime,
  jobs: [%Job{}],
  allocations: [%ComponentAllocation{}],
  explosion_levels: Integer,
  status: :in_progress | :completed | :failed
}

%Job{
  id: UUID,
  job_number: String,
  work_order_id: UUID,
  parent_item_id: UUID,
  level: Integer,
  manufacturing_quantity: Decimal,
  components: [%AllocatedComponent{}],
  status: :pending | :in_process | :finished | :voided
}
```

### 4. WorkInProcess Aggregate

Manages items currently being manufactured.

#### Commands

##### PostWorkInProcess

- **Input**:
  - posting_method (:entire_work_order | :by_work_order | :by_job)
  - work_order_id
  - job_id (if by_job)
  - master_item_id (if by_work_order)
  - start_date
  - post_date
  - wip_quantity
  - bin_id
  - component_allocations (bin and quantity overrides)

- **Validations**:
  - Work order must be exploded
  - Job must exist and not be in process
  - WIP quantity cannot exceed backorder quantity
  - Components must have sufficient availability
  - Check for serialized/lot-controlled items
  - Validate machine time availability

- **Events Emitted**:
  - WorkInProcessPosted
  - InventoryAllocated (for each component)
  - MachineTimeScheduled
  - LaborTimeScheduled
  - SerialNumbersAllocated (if applicable)
  - LotNumbersAllocated (if applicable)

##### VoidWorkInProcess

- **Input**:
  - wip_id
  - reason

- **Validations**:
  - WIP record must exist
  - No finished goods posted against this WIP
  - Must handle reversal of allocations

- **Events Emitted**:
  - WorkInProcessVoided
  - InventoryDeallocated
  - MachineTimeCancelled
  - LaborTimeCancelled

#### State

```elixir
%WorkInProcess{
  id: UUID,
  job_id: UUID,
  work_order_id: UUID,
  parent_item_id: UUID,
  start_date: Date,
  post_date: Date,
  wip_quantity: Decimal,
  bin_id: UUID,
  warehouse_id: UUID,
  allocated_components: [%AllocatedComponent{}],
  status: :in_process | :finished | :voided
}

%AllocatedComponent{
  component_type: :inventory | :labor | :machine,
  component_id: UUID,
  allocated_quantity: Decimal | nil,
  allocated_time: Duration | nil,
  bin_id: UUID | nil,
  serial_numbers: [String],
  lot_numbers: [String]
}
```

### 5. FinishedGoods Aggregate

Manages completed manufacturing jobs.

#### Commands

##### PostFinishedJob

- **Input**:
  - posting_method (:entire_work_order | :by_work_order | :by_job)
  - work_order_id
  - job_id (if by_job)
  - master_item_id (if by_work_order)
  - finish_date
  - post_date
  - finished_quantity
  - bin_id
  - overhead_cost (optional)
  - actual_component_usage (optional overrides)
  - release_to_inventory (boolean)

- **Validations**:
  - WIP must exist if WIP required
  - Finished quantity cannot exceed WIP quantity (if WIP required)
  - Components must be available for non-WIP postings
  - Validate serialized/lot-controlled items
  - Check for complete job closure

- **Events Emitted**:
  - FinishedJobPosted
  - InventoryIncreased (for finished items)
  - InventoryConsumed (for components)
  - WIPCompleted
  - WorkOrderCompleted (if all jobs finished)
  - OverheadCostApplied (if applicable)

##### VoidFinishedJob

- **Input**:
  - finished_job_id
  - reason

- **Validations**:
  - Finished job must exist
  - Finished items must still be in inventory
  - Must handle cost reversals

- **Events Emitted**:
  - FinishedJobVoided
  - InventoryReversed
  - CostReversed

#### State

```elixir
%FinishedGoods{
  id: UUID,
  job_id: UUID,
  work_order_id: UUID,
  parent_item_id: UUID,
  finish_date: Date,
  post_date: Date,
  finished_quantity: Decimal,
  bin_id: UUID,
  warehouse_id: UUID,
  overhead_cost: Decimal,
  total_cost: Decimal,
  component_costs: [%ComponentCost{}],
  released_to_inventory: boolean,
  status: :posted | :voided
}
```

## Business Rules

### Work Order Rules

1. **Work Order Number Generation**
   - Can be system-generated or manually entered
   - Must be unique within the system
   - Format configurable in module setup

2. **Master Item Requirements**
   - Must have active BOM before adding to work order
   - Cannot add inactive items
   - Serialized/lot-controlled items require special handling

3. **Hold Status Rules**
   - Work orders on hold cannot be posted to WIP
   - Can still be amended while on hold
   - Must release hold before processing

### Explosion Rules

1. **Component Availability**
   - Check on-hand quantities if configured
   - Allow overuse if configured
   - Handle substitute items when shortages occur

2. **Explosion Levels**
   - Support up to 999 levels of subassemblies
   - Each level represents parent-component relationship
   - Master item is always level 1

3. **Resource Allocation**
   - Inventory items reduce on-hand, increase allocated
   - Machine time checks time before overhaul
   - Labor time checks resource availability

### Work-In-Process Rules

1. **Posting Requirements**
   - Must explode before posting to WIP
   - Cannot post more than manufacturing quantity
   - Serialized items require serial number selection

2. **Partial Processing**
   - Can post partial quantities to WIP
   - Can process by entire order, by item, or by job
   - Once started by job, must continue by job

3. **Component Usage**
   - Can override allocated quantities
   - Must handle setup and teardown times
   - Work shift assignments affect scheduling

### Finished Goods Rules

1. **Completion Requirements**
   - WIP posting required if configured
   - Cannot finish more than WIP quantity (if required)
   - Must handle remaining WIP cancellation

2. **Inventory Release**
   - Optional immediate release to inventory
   - Released items cannot be modified
   - Unreleased allows additional posting

3. **Cost Calculation**
   - Component costs accumulated
   - Overhead calculation methods configurable
   - Total cost includes materials, labor, machine, overhead

## Integration Points

### Inventory Integration

1. **Component Availability**
   - Query current on-hand quantities
   - Check bin-level availability
   - Handle serial/lot number assignments

2. **Inventory Updates**
   - Reduce component quantities
   - Increase finished goods quantities
   - Update allocated quantities

3. **Events to Publish**
   - ComponentsAllocatedForManufacturing
   - FinishedGoodsProduced
   - ComponentsConsumedInProduction

### Sales Order Integration

1. **Work Order Creation**
   - Can create from sales order
   - Link maintains traceability
   - Updates sales order fulfillment status

2. **Events to Subscribe**
   - SalesOrderCreated (for auto work order creation)
   - SalesOrderItemShipped (for completion tracking)

3. **Events to Publish**
   - ManufacturingStartedForSalesOrder
   - ManufacturingCompletedForSalesOrder

### General Ledger Integration

1. **Cost Posting**
   - WIP account postings
   - Finished goods account postings
   - Cost of goods sold calculations

2. **Events to Publish**
   - WorkInProcessCostPosted
   - FinishedGoodsCostPosted
   - ManufacturingVarianceCalculated

### Machine Maintenance Integration

1. **Machine Availability**
   - Check time before overhaul
   - Track machine usage hours
   - Schedule maintenance windows

2. **Events to Subscribe**
   - MachineMaintenanceScheduled
   - MachineStatusChanged

3. **Events to Publish**
   - MachineTimeConsumed
   - MaintenanceThresholdApproaching

## Configuration Requirements

### Module Setup Parameters

1. **Work Order Configuration**
   - Auto-generate work order numbers
   - Allow creation from sales orders
   - Multiple request date handling
   - Default explosion behavior

2. **Inventory Configuration**
   - Check on-hand quantities
   - Allow inventory overuse
   - Use available subassembly quantities
   - Substitute item handling

3. **Processing Configuration**
   - Require WIP for finished jobs
   - Prompt for WIP posting
   - Overhead cost calculation method
   - Machine time validation

4. **Printing Configuration**
   - Work order formats
   - Routing slip options
   - Production slip settings

## Workflow Sequences

### Standard Manufacturing Flow

1. **Create Work Order**
   - Add master items with quantities
   - Set request dates
   - Optional link to sales order

2. **Explode Work Order**
   - Generate jobs for all levels
   - Allocate components
   - Handle substitutions if needed

3. **Post Work-In-Process**
   - Select posting method
   - Allocate specific bins
   - Handle serial/lot numbers

4. **Post Finished Job**
   - Record actual quantities
   - Apply overhead costs
   - Release to inventory

### Partial Processing Flow

1. **Selective Explosion**
   - Choose specific master items
   - Generate jobs for selection only

2. **Job-Level Processing**
   - Post individual jobs to WIP
   - Complete jobs independently
   - Maintain job sequence integrity

### Amendment Flow

1. **Amend Work Order**
   - Add/remove master items
   - Change quantities (if not in WIP)
   - Update dates and remarks

2. **Re-explode if Needed**
   - New items require explosion
   - Maintain existing job numbers

## Error Handling

### Validation Failures

1. **Insufficient Inventory**
   - Option to use substitutes
   - Option to overuse
   - Option to place on hold

2. **Resource Conflicts**
   - Machine unavailability
   - Labor conflicts
   - Time constraint violations

3. **Recovery Procedures**
   - Void and restart transactions
   - Partial completion options
   - Hold for resolution

## Audit and Tracking

### Transaction History

1. **Work Order Changes**
   - Creation and amendments
   - Status changes
   - User and timestamp tracking

2. **Production Tracking**
   - WIP posting history
   - Completion records
   - Cost accumulation trail

3. **Component Usage**
   - Planned vs actual usage
   - Variance tracking
   - Efficiency metrics

## Performance Considerations

1. **Explosion Optimization**
   - Cache BOM structures
   - Batch component checks
   - Parallel job generation

2. **Inventory Updates**
   - Batch allocation updates
   - Optimistic locking for quantities
   - Queue for GL postings

3. **Query Optimization**
   - Index on work order status
   - Composite index on job hierarchy
   - Materialized views for cost rollups
