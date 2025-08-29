# Accountex Manufacturing Module Business Logic - Part 1

## 1. Core Manufacturing Processes and Workflows

### 1.1 Work Order Creation and Management

#### Work Order Initialization Logic

**Creation Methods**: System supports three primary creation pathways:
- Manual creation with full parameter control
- Copy from existing work order with automatic field population  
- Generation from open sales orders with quantity and specification inheritance

#### Work Order Creation Business Rules

**BR-MI-023:** Each work order can contain unlimited master items with independent production parameters
**BR-MI-024:** System automatically pulls backorder quantities from sales orders as default manufacturing quantities
**BR-MI-025:** Work orders can be placed on hold status pending component availability

#### Work Order Structure

**BR-MI-026:** Each master item explodes into unlimited job levels with parent-child relationships
**BR-MI-027:** Components assigned sequential step numbers matching actual production flow
**BR-MI-028:** Support for multiple start dates and request dates per work order line item
**BR-MI-029:** Automatic allocation of raw materials and subassemblies upon work order explosion

#### Work Order State Management

**Work Order State Transitions:** Created → Exploded → WIP Posted → In Process → Finished → Closed

**BR-MI-030:** Work orders can be voided entirely or up to specific step numbers
**BR-MI-031:** Component lists modifiable after explosion
**BR-MI-032:** Real-time status monitoring through multiple report types

### 1.2 Bill of Materials (BOM) Handling

#### BOM Structure and Logic

- **Component Relationships**: Define ratio of component items required to produce one parent item unit
- **Resource Integration**: Machine and labor resources applied through BOM assignments
- **Version Control**: Multiple BOM versions maintained with change tracking and rollback capability
- **Production Rates**: Customizable labor and machine production rates per BOM

#### Component Management Rules

**BR-MI-011:** BOM components support inventory items, machine resources, labor resources, and non-stock items
**BR-MI-012:** Multiple substitute items definable for each component
**BR-MI-013:** Components assigned to specific manufacturing steps for sequencing
**BR-MI-014:** Manufacturing instructions stored with each BOM

#### BOM Maintenance Logic

**BR-MI-015:** BOMs updatable without affecting existing work orders
**BR-MI-016:** Components and entire BOMs copyable within or across companies
**BR-MI-017:** Simultaneous replacement of specific components across multiple BOMs
**BR-MI-018:** Separate BOMs for each item specification combination

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

**BR-MI-019:** Can explode entire work orders or specific line items
**BR-MI-020:** Explosion controllable to specific step numbers
**BR-MI-021:** Automatic generation of material requirement projections
**BR-MI-022:** System determines make vs. buy decisions for subassemblies

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

**BR-MI-007:** Costs propagate through all component levels
**BR-MI-008:** Cumulative lead times calculated across levels
**BR-MI-009:** Machine and labor scheduled considering all levels
**BR-MI-010:** Choose to manufacture or use existing inventory at each level

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

**BR-MI-001:** Parent items cannot complete until child components finish
**BR-MI-002:** WIP posting required before marking in-process
**BR-MI-003:** Quality hold prevents automatic closure

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

**BR-MI-004:** Inventory levels adjusted immediately upon consumption
**BR-MI-005:** Track waste and remnants during production
**BR-MI-006:** Maintain lot genealogy through production

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

---

*This is Part 1 of 3. Continue with [manufacturing_logic_part2.md](./manufacturing_logic_part2.md) for Integration Points and Business Rules, and [manufacturing_logic_part3.md](./manufacturing_logic_part3.md) for Advanced Features and Configuration.*