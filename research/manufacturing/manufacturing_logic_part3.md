# Accountex Manufacturing Module Business Logic - Part 3

## Advanced Features and Configuration

### Quality Control Integration

```elixir
defmodule Accountex.Manufacturing.QualityControl do
  defstruct [:inspection_id, :work_order_id, :operation_id, :status, :results]

  def create_inspection_request(work_order_operation) do
    with {:ok, inspection_plan} <- get_inspection_plan(work_order_operation),
         {:ok, sampling_plan} <- determine_sampling_plan(work_order_operation.quantity) do
      
      %QualityInspectionRequest{
        work_order_id: work_order_operation.work_order_id,
        operation_id: work_order_operation.id,
        inspection_plan_id: inspection_plan.id,
        sample_size: sampling_plan.sample_size,
        acceptance_criteria: sampling_plan.acceptance_criteria,
        required_tests: inspection_plan.test_specifications,
        status: :pending
      }
    end
  end

  def process_inspection_results(inspection_id, test_results) do
    with {:ok, inspection} <- get_inspection(inspection_id),
         {:ok, evaluation} <- evaluate_results(test_results, inspection.acceptance_criteria) do
      
      case evaluation.disposition do
        :accept ->
          emit_event(%QualityInspectionPassed{
            inspection_id: inspection_id,
            work_order_id: inspection.work_order_id
          })
        
        :reject ->
          emit_event(%QualityInspectionFailed{
            inspection_id: inspection_id,
            work_order_id: inspection.work_order_id,
            defect_details: evaluation.defects
          })
        
        :conditional ->
          emit_event(%QualityInspectionConditional{
            inspection_id: inspection_id,
            work_order_id: inspection.work_order_id,
            conditions: evaluation.conditions
          })
      end
    end
  end
end
```

### Capacity Planning and Scheduling

```elixir
defmodule Accountex.Manufacturing.CapacityPlanning do
  def calculate_available_capacity(work_center_id, date_range) do
    with {:ok, work_center} <- get_work_center(work_center_id),
         {:ok, machines} <- get_work_center_machines(work_center_id),
         {:ok, calendar} <- get_production_calendar(work_center_id, date_range) do
      
      total_capacity = Enum.reduce(machines, 0, fn machine, acc ->
        machine_capacity = calculate_machine_capacity(machine, calendar)
        acc + machine_capacity
      end)
      
      allocated_capacity = get_allocated_capacity(work_center_id, date_range)
      
      %{
        total_capacity_hours: total_capacity,
        allocated_capacity_hours: allocated_capacity,
        available_capacity_hours: total_capacity - allocated_capacity,
        utilization_percentage: (allocated_capacity / total_capacity) * 100,
        work_center_id: work_center_id,
        date_range: date_range
      }
    end
  end

  def schedule_work_order(work_order, scheduling_method \\ :forward) do
    case scheduling_method do
      :forward -> forward_schedule(work_order)
      :backward -> backward_schedule(work_order)
      :finite -> finite_capacity_schedule(work_order)
      :infinite -> infinite_capacity_schedule(work_order)
    end
  end

  defp finite_capacity_schedule(work_order) do
    with {:ok, operations} <- get_bom_operations(work_order.bom_id),
         {:ok, resource_calendar} <- get_resource_availability() do
      
      scheduled_operations = Enum.reduce(operations, [], fn operation, acc ->
        earliest_start = calculate_earliest_start(operation, acc)
        
        scheduled_slot = find_available_capacity_slot(
          operation.work_center_id,
          operation.required_capacity,
          earliest_start
        )
        
        [scheduled_slot | acc]
      end)
      
      {:ok, Enum.reverse(scheduled_operations)}
    end
  end
end
```

### Performance Metrics and KPIs

```elixir
defmodule Accountex.Manufacturing.Metrics do
  def calculate_manufacturing_kpis(date_range) do
    %{
      oee: calculate_overall_oee(date_range),
      throughput: calculate_throughput(date_range),
      cycle_time: calculate_average_cycle_time(date_range),
      yield: calculate_production_yield(date_range),
      on_time_delivery: calculate_otd_rate(date_range),
      inventory_turns: calculate_inventory_turnover(date_range),
      labor_efficiency: calculate_labor_efficiency(date_range),
      cost_variance: calculate_cost_variance(date_range),
      quality_metrics: calculate_quality_metrics(date_range),
      capacity_utilization: calculate_capacity_utilization(date_range)
    }
  end

  def calculate_throughput(date_range) do
    with {:ok, completed_orders} <- get_completed_work_orders(date_range) do
      total_output = Enum.reduce(completed_orders, 0, fn order, acc ->
        acc + order.completed_quantity
      end)
      
      days_in_range = Date.diff(date_range.end_date, date_range.start_date) + 1
      
      %{
        total_units_produced: total_output,
        average_daily_throughput: total_output / days_in_range,
        orders_completed: length(completed_orders)
      }
    end
  end
end
```

### Error Handling and Recovery

```elixir
defmodule Accountex.Manufacturing.ErrorHandling do
  def handle_production_failure(work_order_id, failure_reason) do
    with {:ok, work_order} <- get_work_order(work_order_id) do
      case failure_reason do
        :machine_breakdown ->
          handle_machine_failure(work_order)
        
        :material_shortage ->
          handle_material_shortage(work_order)
        
        :quality_failure ->
          handle_quality_failure(work_order)
        
        :operator_error ->
          handle_operator_error(work_order)
        
        _ ->
          handle_generic_failure(work_order, failure_reason)
      end
    end
  end

  defp handle_machine_failure(work_order) do
    # Stop production
    pause_work_order(work_order.id)
    
    # Find alternative machine
    case find_alternative_machine(work_order) do
      {:ok, alt_machine} ->
        reschedule_to_machine(work_order, alt_machine)
      
      :no_alternative ->
        create_maintenance_request(work_order.machine_id)
        notify_production_delay(work_order)
    end
  end

  defp handle_material_shortage(work_order) do
    # Check for substitutes
    case find_substitute_materials(work_order) do
      {:ok, substitutes} ->
        approve_substitutes(work_order, substitutes)
      
      :no_substitutes ->
        create_urgent_purchase_order(work_order)
        reschedule_work_order(work_order)
    end
  end
end
```

### Configuration and Settings

```elixir
defmodule Accountex.Manufacturing.Config do
  @moduledoc """
  Manufacturing module configuration settings
  """

  def default_settings do
    %{
      # Capacity Planning
      scheduling_method: :finite_capacity,
      planning_horizon_days: 90,
      capacity_buffer_percentage: 15,
      
      # Inventory Management
      allow_negative_inventory: false,
      default_cost_method: :average,
      auto_reserve_materials: true,
      
      # Production Control
      require_quality_inspection: true,
      auto_complete_operations: false,
      track_scrap_separately: true,
      
      # Costing
      overhead_allocation_method: :machine_hours,
      standard_cost_update_frequency: :quarterly,
      variance_threshold_percentage: 5,
      
      # Work Order Management
      work_order_number_pattern: "WO-{YYYY}-{00000}",
      auto_release_approved_orders: true,
      max_operations_per_order: 50,
      
      # Performance Tracking
      oee_calculation_interval: :daily,
      efficiency_baseline_percentage: 85,
      quality_target_percentage: 98
    }
  end
end
```

### Master Data Management Workflows

```elixir
defmodule Manufacturing.MasterData.Workflows.Approval do
  use Commanded.ProcessManagers.ProcessManager,
    name: "MasterDataApproval",
    router: Manufacturing.Router
    
  defstruct [
    :change_request_id,
    :entity_type,
    :entity_id,
    :status,
    :approvals_required,
    :approvals_received,
    :rejection_reason
  ]
  
  def handle(%__MODULE__{status: :pending} = state, %ChangeRequested{} = event) do
    approvers = determine_approvers(event.entity_type, event.change_type)
    
    Enum.map(approvers, fn approver ->
      %RequestApproval{
        request_id: state.change_request_id,
        approver_id: approver.id,
        entity_type: event.entity_type,
        entity_id: event.entity_id,
        changes: event.changes
      }
    end)
  end
  
  def handle(%__MODULE__{} = state, %ApprovalGranted{} = event) do
    state = %{state | approvals_received: state.approvals_received + 1}
    
    if state.approvals_received >= state.approvals_required do
      %ApplyMasterDataChange{
        entity_type: state.entity_type,
        entity_id: state.entity_id,
        approved_by: event.approver_id,
        approval_date: DateTime.utc_now()
      }
    else
      [] # Wait for more approvals
    end
  end
end
```

### Period End Closing Procedures

```elixir
defmodule Manufacturing.PeriodEnd.ClosingEngine do
  def execute_period_close(period) do
    steps = [
      {:validate_production_orders, &validate_all_orders_processed/1},
      {:calculate_wip_valuation, &calculate_wip_values/1},
      {:post_cost_variances, &post_variance_entries/1},
      {:reconcile_inventory, &reconcile_perpetual_to_gl/1},
      {:lock_transactions, &lock_period_transactions/1},
      {:archive_data, &archive_period_data/1}
    ]
    
    execute_steps_sequentially(steps, period)
  end
  
  defp validate_all_orders_processed(period) do
    incomplete = get_incomplete_orders(period)
    
    if Enum.empty?(incomplete) do
      :ok
    else
      {:error, "Incomplete orders exist", incomplete}
    end
  end
  
  defp calculate_wip_values(period) do
    jobs = get_active_jobs(period)
    
    wip_summary = Enum.map(jobs, fn job ->
      %{
        job_id: job.id,
        material_cost: calculate_material_wip(job),
        labor_cost: calculate_labor_wip(job),
        overhead_cost: calculate_overhead_wip(job),
        total: calculate_total_wip(job)
      }
    end)
    
    {:ok, wip_summary}
  end
end
```

### Data Purging and Archival

```elixir
defmodule Manufacturing.PeriodEnd.DataArchival do
  @retention_years 7
  
  def archive_old_data(current_period) do
    cutoff_date = calculate_cutoff_date(@retention_years)
    
    archival_tasks = [
      archive_completed_jobs(cutoff_date),
      archive_transaction_history(cutoff_date),
      archive_cost_calculations(cutoff_date),
      compress_audit_logs(cutoff_date)
    ]
    
    execute_archival_tasks(archival_tasks)
  end
  
  defp archive_completed_jobs(cutoff_date) do
    jobs = get_completed_jobs_before(cutoff_date)
    
    Enum.each(jobs, fn job ->
      archive_record = %ArchivedJob{
        original_id: job.id,
        data: compress(job),
        archived_at: DateTime.utc_now(),
        retrieval_key: generate_retrieval_key(job)
      }
      
      save_to_archive(archive_record)
      mark_as_archived(job.id)
    end)
  end
end
```

### Manufacturing Module Setup Parameters

```elixir
defmodule Manufacturing.Setup.Configuration do
  embedded_schema do
    # Core settings
    field :enable_multi_level_bom, :boolean, default: true
    field :enable_phantom_assemblies, :boolean, default: true
    field :enable_configure_to_order, :boolean, default: false
    field :enable_repetitive_manufacturing, :boolean, default: false
    
    # Numbering sequences
    embeds_one :numbering, NumberingConfig do
      field :job_order_prefix, :string
      field :job_order_sequence, :integer, default: 100000
      field :bom_number_format, :string, default: "BOM-{YYYY}-{#####}"
      field :work_order_format, :string, default: "WO-{PLANT}-{######}"
      field :reset_frequency, :atom, default: :never # :annual, :monthly, :never
    end
    
    # Costing configuration
    embeds_one :costing, CostingConfig do
      field :default_method, :atom, default: :standard
      field :variance_calculation, :atom, default: :period_end
      field :overhead_basis, :atom, default: :labor_hours
      field :activity_based_costing, :boolean, default: false
    end
    
    # Capacity planning
    embeds_one :capacity, CapacityConfig do
      field :scheduling_method, :atom, default: :infinite
      field :consider_material_availability, :boolean, default: true
      field :buffer_percentage, :decimal, default: 10.0
      field :shift_calendar_id, :uuid
    end
    
    # Integration parameters
    embeds_one :integration, IntegrationConfig do
      field :real_time_gl_posting, :boolean, default: true
      field :auto_create_purchase_requisitions, :boolean, default: true
      field :quality_inspection_required, :boolean, default: false
      field :mes_integration_enabled, :boolean, default: false
    end
  end
end
```

### Validation Rules

```elixir
defmodule Manufacturing.Setup.Validators do
  def validate_configuration(config) do
    validations = [
      validate_numbering_sequences(config.numbering),
      validate_costing_consistency(config.costing),
      validate_capacity_settings(config.capacity),
      validate_integration_dependencies(config.integration)
    ]
    
    aggregate_results(validations)
  end
  
  defp validate_costing_consistency(costing) do
    if costing.activity_based_costing && costing.overhead_basis != :activities do
      {:error, "ABC requires activity-based overhead allocation"}
    else
      :ok
    end
  end
  
  defp validate_integration_dependencies(integration) do
    if integration.mes_integration_enabled && !integration.real_time_gl_posting do
      {:warning, "MES integration works best with real-time GL posting"}
    else
      :ok
    end
  end
end
```

### Dynamic Parameter Updates

```elixir
defmodule Manufacturing.Setup.ParameterManager do
  def update_parameter(path, value) do
    with :ok <- validate_parameter_change(path, value),
         :ok <- check_dependent_parameters(path),
         {:ok, config} <- load_current_config() do
      
      updated = put_in(config, path, value)
      
      event = %ConfigurationChanged{
        parameter_path: path,
        old_value: get_in(config, path),
        new_value: value,
        changed_by: current_user(),
        changed_at: DateTime.utc_now()
      }
      
      {:ok, updated, event}
    end
  end
  
  def apply_configuration_template(template_name) do
    template = load_template(template_name)
    
    Enum.map(template.parameters, fn {path, value} ->
      update_parameter(path, value)
    end)
  end
end
```

## Event Sourcing Considerations

### Event Store Integration

```elixir
defmodule Manufacturing.Events.Store do
  def append_events(stream_id, events, expected_version) do
    Commanded.EventStore.append_to_stream(
      stream_id,
      expected_version,
      events,
      metadata: %{
        causation_id: UUID.uuid4(),
        correlation_id: get_correlation_id(),
        user_id: get_current_user_id()
      }
    )
  end
end
```

### Projection Handlers

```elixir
defmodule Manufacturing.Projections.InventoryProjection do
  use Commanded.Projections.Ecto
  
  project %InventoryAdjusted{} = event do
    update_inventory_balance(event.item_id, event.quantity_change)
    update_adjustment_history(event)
  end
  
  project %JobCompleted{} = event do
    increase_finished_goods(event.item_id, event.quantity)
    decrease_wip_value(event.job_id)
  end
end
```

## Integration Architecture

### Module Boundaries

- **Inventory Management**: Handles all inventory-related aggregates and events
- **BOM Management**: Manages bill of materials and product structures
- **WIP Management**: Controls work-in-process operations and job lifecycle
- **Financial Integration**: Manages GL postings and cost accounting
- **Period Operations**: Handles closing procedures and archival

### Cross-Module Communication

- Events published through domain event bus
- Read models shared via query interfaces
- Saga orchestrators for complex workflows
- Process managers for long-running operations

## Error Handling and Recovery

### Compensation Strategies

```elixir
defmodule Manufacturing.Sagas.JobCompletionSaga do
  def handle_failure(error, state) do
    case error do
      {:inventory_posting_failed, reason} ->
        compensate_inventory_transactions(state)
      
      {:cost_calculation_error, details} ->
        revert_to_manual_costing(state, details)
      
      {:quality_checkpoint_failed, checkpoint} ->
        route_to_quality_review(state, checkpoint)
      
      _ ->
        escalate_to_supervisor(state, error)
    end
  end
  
  defp compensate_inventory_transactions(state) do
    # Reverse any completed inventory transactions
    # Restore previous inventory levels
    # Notify relevant stakeholders
  end
end
```

### Data Consistency Validation

```elixir
defmodule Manufacturing.DataConsistency do
  def validate_system_consistency do
    %{
      inventory_balance: validate_inventory_balances(),
      cost_layer_integrity: validate_cost_layers(),
      bom_circular_references: check_bom_references(),
      work_order_completeness: validate_work_orders(),
      gl_posting_accuracy: validate_gl_postings()
    }
  end
  
  def repair_data_inconsistencies(validation_results) do
    validation_results
    |> Enum.filter(fn {_check, result} -> result != :ok end)
    |> Enum.map(fn {check, errors} ->
      attempt_automatic_repair(check, errors)
    end)
  end
end
```

## Performance Optimization

```elixir
defmodule Manufacturing.Performance do
  # Caching frequently accessed master data
  def cache_active_boms do
    Manufacturing.Resources.BOM
    |> Ash.Query.for_read(:active)
    |> Ash.Query.load([:components])
    |> Ash.read!()
    |> Enum.each(fn bom ->
      key = "bom:#{bom.item_id}:active"
      Cachex.put(:manufacturing_cache, key, bom, ttl: :timer.hours(1))
    end)
  end
  
  # Batch processing for high-volume operations
  def batch_complete_work_orders(work_order_ids) do
    work_order_ids
    |> Enum.chunk_every(100)
    |> Task.async_stream(fn batch ->
      process_completion_batch(batch)
    end, max_concurrency: 10)
    |> Enum.to_list()
  end
end
```

## Testing Scenarios

```elixir
defmodule Accountex.Manufacturing.TestScenarios do
  describe "work order lifecycle" do
    test "complete work order flow from creation to completion" do
      # Create work order
      {:ok, work_order} = create_test_work_order()
      assert work_order.status == :draft
      
      # Submit and approve
      {:ok, work_order} = submit_work_order(work_order.id)
      assert work_order.status == :submitted
      
      {:ok, work_order} = approve_work_order(work_order.id)
      assert work_order.status == :approved
      
      # Check material availability
      {:ok, availability} = check_material_availability(work_order.id)
      assert availability.all_materials_available == true
      
      # Release and start production
      {:ok, work_order} = release_work_order(work_order.id)
      assert work_order.status == :released
      
      {:ok, work_order} = start_production(work_order.id, %{
        operator_id: "test-operator",
        machine_id: "test-machine"
      })
      assert work_order.status == :in_progress
      
      # Complete operations
      complete_all_operations(work_order.id)
      
      # Quality inspection
      {:ok, inspection} = create_quality_inspection(work_order.id)
      {:ok, _} = pass_quality_inspection(inspection.id)
      
      # Complete work order
      {:ok, work_order} = complete_work_order(work_order.id)
      assert work_order.status == :completed
      
      # Verify inventory updates
      {:ok, item_stock} = get_item_stock(work_order.item_id)
      assert item_stock.quantity == work_order.quantity
    end
  end

  describe "material requirements planning" do
    test "correctly calculates net requirements with safety stock" do
      item_id = "test-item-001"
      gross_requirement = Decimal.new(100)
      
      # Setup test data
      set_current_stock(item_id, 30)
      set_safety_stock(item_id, 10)
      set_allocated_stock(item_id, 5)
      
      {:ok, requirements} = calculate_net_requirements(
        item_id,
        gross_requirement,
        Date.utc_today()
      )
      
      assert requirements.net_requirement == Decimal.new(85)
      # 100 (gross) - 30 (current) + 5 (allocated) + 10 (safety) = 85
    end
  end
end
```

## Monitoring and Alerts

```elixir
defmodule Accountex.Manufacturing.Monitoring do
  def setup_manufacturing_alerts do
    [
      %Alert{
        name: "machine_maintenance_due",
        condition: fn machine ->
          machine.accumulated_hours_since_overhaul >= machine.time_between_overhauls_hours * 0.9
        end,
        action: :notify_maintenance_team,
        severity: :warning
      },
      %Alert{
        name: "material_shortage",
        condition: fn item ->
          item.current_stock < item.reorder_point
        end,
        action: :create_purchase_requisition,
        severity: :high
      },
      %Alert{
        name: "work_order_delayed",
        condition: fn work_order ->
          DateTime.compare(DateTime.utc_now(), work_order.planned_completion_date) == :gt &&
          work_order.status != :completed
        end,
        action: :notify_production_manager,
        severity: :high
      },
      %Alert{
        name: "quality_failure_rate_high",
        condition: fn metrics ->
          metrics.quality_failure_rate > 0.05
        end,
        action: :trigger_quality_review,
        severity: :critical
      }
    ]
  end
end
```

## Summary

The Accountex Manufacturing module provides a comprehensive, event-sourced solution for managing all aspects of manufacturing operations. Built on Ash Framework and Commanded, it ensures complete traceability, real-time visibility, and seamless integration with other Accountex modules. The system supports complex manufacturing scenarios including multi-level BOMs, sophisticated costing methods, quality control integration, and advanced scheduling while maintaining flexibility for customization and scalability.

Key features include:

- **Work Order Management**: Complete lifecycle from creation to completion
- **Bill of Materials**: Multi-level BOMs with version control and approval workflows
- **Resource Management**: Machine and labor capacity planning and utilization
- **Cost Accounting**: Multiple costing methods with variance analysis
- **Quality Integration**: Quality checkpoints and inspection workflows
- **Performance Metrics**: Comprehensive KPIs including OEE, efficiency, and throughput
- **Integration**: Seamless connectivity with Inventory, Sales, Purchasing, and GL modules
- **Configuration**: Flexible parameter management and template-based setup

---

*This completes Part 3 of 3. See [manufacturing_logic_part1.md](./manufacturing_logic_part1.md) for Core Processes and [manufacturing_logic_part2.md](./manufacturing_logic_part2.md) for Integration Points.*