# Accountex Manufacturing - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the Manufacturing domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework.

## Work Order Management Commands and Events

### Work Order Lifecycle

#### CreateWorkOrder Command
**Purpose**: Creates a new work order for production planning and execution.

**Description**: Initiates production planning by creating work order including master item specification, quantity requirements, scheduling parameters, and resource coordination. Validates business rules and establishes foundation for production workflow.

**Parameters**:
- `work_order_id`: Unique work order identifier
- `work_order_number`: System-assigned or manual work order number
- `master_items`: List of items to manufacture with quantities
- `warehouse_id`: Production warehouse location
- `order_date`: Work order creation date
- `requested_date`: Required completion date
- `sales_order_reference`: Link to sales order if make-to-order
- `customer_reference`: Customer information if applicable
- `priority_level`: Production priority assignment

**Business Rules**:
- Master items must have valid BOM definitions
- Warehouse must be active and configured for manufacturing
- Requested dates must be achievable with lead times
- Manufacturing quantities must be positive
- Sales order reference must be valid if provided

---

#### ExplodeWorkOrder Command
**Purpose**: Explodes work order into detailed manufacturing jobs and component requirements.

**Description**: Breaks down work order into manufacturable jobs including BOM explosion, component calculation, resource allocation, and job hierarchy generation. Creates detailed production plan from high-level work order.

**Parameters**:
- `explosion_id`: Work order explosion identifier
- `work_order_id`: Work order to explode
- `explosion_scope`: Full or partial explosion scope
- `substitution_handling`: How to handle component substitutions
- `availability_checking`: Whether to validate component availability
- `resource_validation`: Whether to validate resource capacity

**Business Rules**:
- Work order must exist and not be already exploded
- All master items must have current BOM versions
- Component availability checking if configured
- Resource capacity validation if enabled
- Circular BOM references prevented

---

#### AmendWorkOrder Command
**Purpose**: Modifies existing work order with proper validation and audit trail.

**Description**: Updates work order information including master item changes, quantity adjustments, date modifications, and configuration updates while maintaining production integrity.

**Parameters**:
- `work_order_id`: Work order to amend
- `amendment_type`: Type of amendment (quantity, date, items)
- `master_item_changes`: Changes to master items and quantities
- `date_adjustments`: Updated requested or scheduled dates
- `configuration_updates`: Updated work order configuration
- `amendment_reason`: Justification for amendment
- `amended_by`: User making amendment

**Business Rules**:
- Cannot amend work orders with jobs in WIP
- Quantity increases require component availability validation
- Date changes must be achievable with current schedule
- Amendment authorization required for significant changes

---

#### VoidWorkOrder Command
**Purpose**: Voids work order with proper cleanup and compensation.

**Description**: Cancels work order and handles cleanup including inventory release, resource deallocation, cost reversal, and audit trail maintenance with appropriate compensation activities.

**Parameters**:
- `work_order_id`: Work order to void
- `void_reason`: Reason for voiding work order
- `void_scope`: Complete void or partial void to specific step
- `inventory_disposition`: How to handle allocated inventory
- `cost_handling`: How to handle accumulated costs
- `authorized_by`: User authorizing void

**Business Rules**:
- Cannot void work orders with completed jobs
- All WIP must be voided before work order void
- Inventory allocations must be released
- Cost reversals processed if applicable
- Void authorization required

---

#### PlaceWorkOrderOnHold Command
**Purpose**: Places work order on hold with reason tracking and impact analysis.

**Description**: Suspends work order processing including hold reason documentation, impact analysis, and coordination with affected processes while maintaining work order state.

**Parameters**:
- `work_order_id`: Work order to place on hold
- `hold_type`: Type of hold (material shortage, quality, customer request)
- `hold_reason`: Detailed reason for hold
- `expected_resolution`: Expected resolution timeframe
- `impact_analysis`: Analysis of hold impact on schedule
- `hold_authorized_by`: User authorizing hold

**Business Rules**:
- Hold reason must be valid and documented
- Impact analysis required for customer orders
- Hold authorization appropriate for hold type
- Scheduled resources may be released during hold

---

#### ReleaseWorkOrderFromHold Command
**Purpose**: Releases work order from hold status and resumes processing.

**Description**: Removes hold status and resumes production including hold resolution validation, resource reallocation, schedule updates, and process resumption coordination.

**Parameters**:
- `work_order_id`: Work order to release from hold
- `release_reason`: Reason for hold release
- `resolution_details`: How hold conditions were resolved
- `schedule_adjustments`: Updated schedule based on hold duration
- `resource_reallocation`: Resource reallocation requirements
- `released_by`: User authorizing release

**Business Rules**:
- Hold conditions must be resolved before release
- Resource availability must be revalidated
- Schedule adjustments may be required
- Release authorization appropriate for original hold type

---

### Work Order Events

#### WorkOrderCreated Event
**Purpose**: Records creation of new work order.

**Description**: Emitted when work order is successfully created. Contains work order details and triggers production planning and resource coordination activities.

**Data**:
- `work_order_id`: Created work order identifier
- `work_order_number`: Assigned work order number
- `master_items`: Items to be manufactured
- `total_quantity`: Total production quantity
- `warehouse_id`: Production warehouse
- `requested_completion`: Required completion date
- `created_by`: User creating work order
- `creation_timestamp`: Work order creation time

**Downstream Effects**:
- Triggers BOM explosion workflow if configured
- Initiates resource availability checking
- Updates production planning projections
- Creates work order tracking and monitoring

---

#### WorkOrderExploded Event
**Purpose**: Records completion of work order explosion into jobs.

**Description**: Emitted when work order explosion completes successfully. Contains explosion results and triggers job-level production planning and resource allocation.

**Data**:
- `explosion_id`: Explosion process identifier
- `work_order_id`: Exploded work order
- `jobs_created`: Manufacturing jobs generated
- `component_requirements`: Total component requirements
- `resource_requirements`: Resource capacity requirements
- `explosion_levels`: Depth of BOM explosion
- `exploded_at`: Explosion completion timestamp

**Downstream Effects**:
- Creates individual manufacturing jobs for tracking
- Triggers component allocation processes
- Initiates resource scheduling activities
- Updates production capacity planning

---

#### WorkOrderAmended Event
**Purpose**: Records amendments to existing work order.

**Description**: Emitted when work order is amended. Contains amendment details and triggers updates to related processes and schedules.

**Data**:
- `work_order_id`: Amended work order
- `amendment_type`: Type of amendment performed
- `changes`: Detailed change information
- `impact_analysis`: Impact on schedule and resources
- `amended_by`: User making amendment
- `amendment_timestamp`: When amendment occurred

**Downstream Effects**:
- Updates production schedules and resource allocations
- Triggers component requirement recalculation
- Updates job priorities and sequences
- Creates amendment audit trail

---

## Bill of Materials Commands and Events

### BOM Management

#### CreateBillOfMaterials Command
**Purpose**: Creates bill of materials for manufactured items.

**Description**: Establishes BOM structure including component relationships, resource requirements, production specifications, and version control setup for manufactured items.

**Parameters**:
- `bom_id`: Unique BOM identifier
- `parent_item_id`: Item being manufactured
- `bom_version`: BOM version number
- `components`: List of required components with quantities
- `resources`: Required machine and labor resources
- `production_instructions`: Manufacturing instructions
- `effective_date`: When BOM becomes active

**Business Rules**:
- Parent item must be manufacturable item type
- All component items must exist and be active
- Component quantities must be positive
- Resource requirements must be realistic
- Cannot create circular BOM references

---

#### UpdateBillOfMaterials Command
**Purpose**: Updates existing BOM with component or resource changes.

**Description**: Modifies BOM structure including component additions/removals, quantity changes, resource updates, and instruction modifications while maintaining BOM integrity and version control.

**Parameters**:
- `bom_id`: BOM to update
- `update_type`: Type of update (components, resources, instructions)
- `component_changes`: Component additions, removals, or modifications
- `resource_updates`: Resource requirement changes
- `instruction_updates`: Updated manufacturing instructions
- `effective_date`: When changes become effective
- `updated_by`: User making changes

**Business Rules**:
- Cannot update BOMs used in active work orders
- Component changes must maintain mathematical consistency
- Resource updates must be validated for capacity
- Effective dates must be future dates

---

#### ActivateBOMVersion Command
**Purpose**: Activates specific BOM version for production use.

**Description**: Makes BOM version active including version validation, dependency checking, and activation coordination while deactivating previous versions appropriately.

**Parameters**:
- `bom_id`: BOM version to activate
- `activation_date`: When BOM becomes active
- `deactivate_previous`: Whether to deactivate previous version
- `impact_analysis`: Impact on existing work orders
- `activated_by`: User authorizing activation

**Business Rules**:
- BOM version must be approved for activation
- Activation date must be appropriate for production planning
- Impact analysis required for version changes
- Only one version can be active per item

---

### BOM Events

#### BOMCreated Event
**Purpose**: Records creation of new bill of materials.

**Description**: Emitted when BOM is successfully created. Contains BOM structure and triggers validation and integration processes.

**Data**:
- `bom_id`: Created BOM identifier
- `parent_item_id`: Item for BOM
- `component_count`: Number of components defined
- `resource_count`: Number of resources required
- `bom_complexity`: Complexity metric for BOM
- `effective_date`: BOM effective date
- `created_by`: User creating BOM

**Downstream Effects**:
- Enables manufacturing planning for item
- Triggers cost rollup calculations
- Updates material requirements planning
- Creates BOM validation and monitoring

---

#### BOMUpdated Event
**Purpose**: Records updates to existing BOM structure.

**Description**: Emitted when BOM is modified. Contains update details and triggers recalculation of dependent processes and validations.

**Data**:
- `bom_id`: Updated BOM
- `update_type`: Type of update performed
- `changes`: Detailed change information
- `component_impact`: Impact on component requirements
- `resource_impact`: Impact on resource requirements
- `updated_by`: User making update

**Downstream Effects**:
- Triggers cost recalculation for item
- Updates existing work order validations
- Recalculates material requirements
- Updates BOM change audit trail

---

#### BOMVersionActivated Event
**Purpose**: Records activation of BOM version for production use.

**Description**: Emitted when BOM version is activated. Contains activation details and triggers production planning updates and version control processes.

**Data**:
- `bom_id`: Activated BOM version
- `parent_item_id`: Item for activated BOM
- `activation_date`: BOM activation date
- `previous_active_version`: Previously active version
- `production_impact`: Impact on production planning
- `activated_by`: User authorizing activation

**Downstream Effects**:
- Updates production planning for item
- Triggers work order validation updates
- Updates cost calculations with new BOM
- Creates version activation audit trail

---

## Production Execution Commands and Events

### Production Processing

#### StartProduction Command
**Purpose**: Initiates production execution for work order or job.

**Description**: Begins production execution including resource allocation, material reservation, production tracking setup, and coordination with production floor systems.

**Parameters**:
- `production_id`: Production execution identifier
- `work_order_id`: Work order being started
- `job_id`: Specific job if job-level start
- `operator_assignment`: Assigned production operator
- `machine_allocation`: Assigned production machines
- `shift_assignment`: Work shift for production
- `start_date`: Production start date

**Business Rules**:
- Work order must be released and ready for production
- Required resources must be available
- Material allocations must be confirmed
- Operator must be qualified for assigned operations

---

#### RecordProductionProgress Command
**Purpose**: Records production progress and operation completion.

**Description**: Captures production progress including operation completion, quantity produced, time consumed, quality checkpoints, and efficiency tracking for real-time production monitoring.

**Parameters**:
- `progress_id`: Production progress identifier
- `work_order_id`: Work order in progress
- `operation_id`: Completed operation
- `quantity_completed`: Quantity produced in operation
- `actual_time`: Actual time consumed
- `machine_time`: Machine time utilized
- `labor_time`: Labor time applied
- `quality_results`: Quality checkpoint results

**Business Rules**:
- Progress must be for active production
- Quantities cannot exceed planned amounts without authorization
- Time records must be reasonable and accurate
- Quality checkpoints must pass before proceeding

---

#### CompleteProduction Command
**Purpose**: Completes production execution with final processing.

**Description**: Finalizes production including completion validation, final cost calculation, variance analysis, inventory updating, and production documentation generation.

**Parameters**:
- `completion_id`: Production completion identifier
- `work_order_id`: Work order being completed
- `completion_type`: Full or partial completion
- `final_quantities`: Final production quantities
- `actual_costs`: Actual production costs incurred
- `quality_disposition`: Final quality status
- `completion_date`: Production completion date

**Business Rules**:
- All required operations must be completed
- Final quantities must be validated
- Quality requirements must be satisfied
- Cost variances must be within tolerance or approved

---

### Production Events

#### ProductionStarted Event
**Purpose**: Records initiation of production execution.

**Description**: Emitted when production execution begins. Contains production details and triggers production tracking, resource monitoring, and progress coordination.

**Data**:
- `production_id`: Production execution identifier
- `work_order_id`: Work order in production
- `assigned_resources`: Resources allocated to production
- `planned_duration`: Expected production time
- `operator_assignment`: Assigned production operator
- `machine_assignments`: Assigned production machines
- `started_at`: Production start timestamp

**Downstream Effects**:
- Activates production tracking and monitoring
- Begins resource utilization tracking
- Triggers progress reporting setup
- Creates production audit trail

---

#### ProductionProgressRecorded Event
**Purpose**: Records production progress and milestone completion.

**Description**: Emitted when production progress is recorded. Contains progress details and triggers performance monitoring, schedule updates, and quality validation.

**Data**:
- `progress_id`: Progress record identifier
- `work_order_id`: Work order with progress
- `operation_completed`: Completed operation details
- `quantity_produced`: Quantity completed in operation
- `efficiency_metrics`: Performance metrics for operation
- `quality_status`: Quality validation results
- `recorded_at`: Progress recording timestamp

**Downstream Effects**:
- Updates production schedule and completion estimates
- Triggers performance analysis and metrics
- Updates quality tracking and validation
- Creates production progress audit trail

---

#### ProductionCompleted Event
**Purpose**: Records completion of production execution.

**Description**: Emitted when production completes successfully. Contains completion details and triggers final processing, cost settlement, and inventory updates.

**Data**:
- `completion_id`: Production completion identifier
- `work_order_id`: Completed work order
- `final_quantities`: Final production quantities
- `total_costs`: Total production costs
- `cost_variances`: Production cost variances
- `quality_certification`: Final quality status
- `completed_at`: Production completion timestamp

**Downstream Effects**:
- Triggers finished goods processing
- Initiates cost variance analysis
- Updates inventory levels
- Creates production completion documentation

---

## Work-in-Process Commands and Events

### WIP Management

#### PostWorkInProcess Command
**Purpose**: Posts work-in-process for manufacturing jobs.

**Description**: Transfers materials and resources to work-in-process including cost accumulation, inventory consumption, resource application, and WIP tracking setup.

**Parameters**:
- `wip_posting_id`: WIP posting identifier
- `work_order_id`: Work order for WIP posting
- `job_scope`: Jobs included in WIP posting
- `material_consumption`: Materials being consumed
- `labor_application`: Labor being applied to WIP
- `machine_utilization`: Machine time being applied
- `posting_date`: Date for WIP posting

**Business Rules**:
- Work order must be exploded before WIP posting
- Material consumption cannot exceed allocations
- Resource applications must be validated
- WIP posting requires appropriate authorization

---

#### UpdateWIPProgress Command
**Purpose**: Updates work-in-process progress and status.

**Description**: Modifies WIP status including progress tracking, cost updates, resource consumption adjustments, and production milestone recording for accurate WIP management.

**Parameters**:
- `wip_update_id`: WIP update identifier
- `wip_id`: Work-in-process being updated
- `progress_percentage`: Production progress percentage
- `additional_costs`: Additional costs incurred
- `resource_adjustments`: Resource consumption adjustments
- `milestone_completion`: Production milestones achieved
- `updated_by`: User recording update

**Business Rules**:
- Progress updates must be reasonable and validated
- Cost adjustments require proper authorization
- Resource consumption must be accurate
- Milestones must be verified before recording

---

#### VoidWorkInProcess Command
**Purpose**: Voids WIP posting with proper reversal and cleanup.

**Description**: Cancels WIP posting including inventory restoration, resource deallocation, cost reversal, and audit trail maintenance with appropriate compensation processing.

**Parameters**:
- `wip_id`: Work-in-process to void
- `void_reason`: Reason for voiding WIP
- `reversal_method`: How to reverse WIP costs and consumption
- `inventory_restoration`: How to restore consumed materials
- `resource_deallocation`: How to handle applied resources
- `authorized_by`: User authorizing void

**Business Rules**:
- Cannot void WIP with finished goods posted
- All material consumption must be reversed
- Resource applications must be deallocated
- Void authorization required for WIP reversals

---

### WIP Events

#### WorkInProcessPosted Event
**Purpose**: Records posting of work-in-process for jobs.

**Description**: Emitted when WIP is posted successfully. Contains WIP details and triggers cost accumulation, inventory updates, and production tracking.

**Data**:
- `wip_posting_id`: WIP posting identifier
- `work_order_id`: Work order for WIP
- `jobs_in_wip`: Jobs moved to WIP status
- `material_costs`: Material costs applied to WIP
- `labor_costs`: Labor costs applied to WIP
- `machine_costs`: Machine costs applied to WIP
- `total_wip_value`: Total WIP value created
- `posted_at`: WIP posting timestamp

**Downstream Effects**:
- Updates WIP inventory balances
- Creates GL postings for WIP costs
- Triggers production cost tracking
- Updates work order status projections

---

#### WIPProgressUpdated Event
**Purpose**: Records updates to work-in-process progress.

**Description**: Emitted when WIP progress is updated. Contains progress details and triggers production monitoring and performance tracking activities.

**Data**:
- `wip_update_id`: WIP update identifier
- `wip_id`: Updated work-in-process
- `progress_metrics`: Production progress measurements
- `cost_accumulation`: Additional costs accumulated
- `efficiency_indicators`: Production efficiency metrics
- `milestone_achievements`: Completed production milestones
- `updated_at`: Progress update timestamp

**Downstream Effects**:
- Updates production progress tracking
- Triggers performance analysis and reporting
- Updates completion estimates
- Creates progress audit trail

---

## Resource Management Commands and Events

### Machine Management

#### CreateMachine Command
**Purpose**: Creates machine resource for manufacturing operations.

**Description**: Establishes machine resource including capacity definition, cost parameters, maintenance scheduling, and operational configuration for manufacturing resource planning.

**Parameters**:
- `machine_id`: Unique machine identifier
- `machine_code`: Machine identification code
- `machine_description`: Machine description and specifications
- `production_capacity`: Production rate and capacity
- `cost_parameters`: Setup, operation, and teardown costs
- `maintenance_schedule`: Preventive maintenance schedule
- `work_center_assignment`: Work center assignment

**Business Rules**:
- Machine code must be unique within system
- Production capacity must be realistic and measurable
- Cost parameters must be positive and reasonable
- Maintenance schedule must be realistic

---

#### ScheduleMaintenance Command
**Purpose**: Schedules machine maintenance with production coordination.

**Description**: Plans machine maintenance including maintenance window scheduling, production impact analysis, alternative resource planning, and maintenance coordination.

**Parameters**:
- `maintenance_id`: Maintenance schedule identifier
- `machine_id`: Machine requiring maintenance
- `maintenance_type`: Type of maintenance (preventive, corrective, overhaul)
- `scheduled_date`: When maintenance should occur
- `estimated_duration`: Expected maintenance time
- `production_impact`: Impact on production schedule
- `alternative_resources`: Alternative machines if available

**Business Rules**:
- Maintenance must be scheduled during appropriate windows
- Production impact must be minimized
- Alternative resources identified if possible
- Maintenance authorization required

---

#### RecordMachineTime Command
**Purpose**: Records machine time utilization for cost tracking.

**Description**: Captures machine time usage including operation time, setup time, downtime, and efficiency tracking for accurate cost allocation and performance monitoring.

**Parameters**:
- `time_record_id`: Machine time record identifier
- `machine_id`: Machine with time usage
- `work_order_id`: Work order using machine
- `operation_time`: Productive operation time
- `setup_time`: Setup time required
- `teardown_time`: Teardown time required
- `downtime`: Non-productive downtime
- `recorded_by`: User or system recording time

**Business Rules**:
- Time records must be accurate and reasonable
- Total time must reconcile with work shift
- Machine must be allocated to work order
- Time recording authorization required

---

### Machine Events

#### MachineCreated Event
**Purpose**: Records creation of machine resource.

**Description**: Emitted when machine resource is created. Contains machine details and triggers resource planning and capacity management setup.

**Data**:
- `machine_id`: Created machine identifier
- `machine_code`: Machine identification code
- `production_capacity`: Machine production capacity
- `cost_structure`: Machine cost parameters
- `work_center_id`: Assigned work center
- `created_by`: User creating machine

**Downstream Effects**:
- Adds machine to production capacity planning
- Enables machine scheduling and allocation
- Sets up maintenance tracking
- Creates machine performance monitoring

---

#### MaintenanceScheduled Event
**Purpose**: Records scheduling of machine maintenance.

**Description**: Emitted when machine maintenance is scheduled. Contains maintenance details and triggers production schedule adjustments and resource planning.

**Data**:
- `maintenance_id`: Maintenance schedule identifier
- `machine_id`: Machine for maintenance
- `maintenance_window`: Scheduled maintenance time
- `production_impact`: Impact on production schedule
- `alternative_arrangements`: Alternative resource plans
- `scheduled_by`: User scheduling maintenance

**Downstream Effects**:
- Adjusts production schedules for maintenance window
- Triggers alternative resource planning
- Updates machine availability projections
- Creates maintenance tracking and monitoring

---

#### MachineTimeRecorded Event
**Purpose**: Records machine time utilization and performance.

**Description**: Emitted when machine time is recorded. Contains time details and triggers cost allocation, performance analysis, and capacity utilization tracking.

**Data**:
- `time_record_id`: Machine time record
- `machine_id`: Machine with time usage
- `time_breakdown`: Breakdown of time usage
- `efficiency_metrics`: Machine efficiency measurements
- `cost_allocation`: Cost allocated to work orders
- `utilization_impact`: Impact on capacity utilization

**Downstream Effects**:
- Allocates machine costs to work orders
- Updates machine utilization metrics
- Triggers maintenance threshold monitoring
- Creates machine performance audit trail

---

## Cost Management Commands and Events

### Cost Processing

#### CalculateStandardCosts Command
**Purpose**: Calculates standard costs for manufactured items.

**Description**: Computes standard costs including material costs, labor costs, machine costs, and overhead allocation through multi-level BOM cost rollup for accurate standard costing.

**Parameters**:
- `cost_calculation_id`: Cost calculation identifier
- `item_scope`: Items included in cost calculation
- `calculation_method`: Method for cost rollup
- `cost_effective_date`: When costs become effective
- `overhead_basis`: Basis for overhead allocation
- `approval_required`: Whether cost approval needed

**Business Rules**:
- Standard costs must be calculated from current BOMs
- Overhead allocation methods must be consistent
- Cost effective dates must align with accounting periods
- Significant cost changes require approval

---

#### RecordActualCosts Command
**Purpose**: Records actual production costs for variance analysis.

**Description**: Captures actual production costs including material consumption costs, labor costs, machine costs, and overhead for comparison with standard costs and variance analysis.

**Parameters**:
- `actual_cost_id`: Actual cost record identifier
- `work_order_id`: Work order with actual costs
- `cost_components`: Breakdown of actual costs
- `material_costs`: Actual material costs incurred
- `labor_costs`: Actual labor costs applied
- `machine_costs`: Actual machine costs incurred
- `overhead_costs`: Actual overhead costs allocated

**Business Rules**:
- Actual costs must be supported by transactions
- Cost components must be complete and accurate
- Costs must be allocated to correct accounting periods
- Cost recording requires appropriate authorization

---

#### CalculateVariances Command
**Purpose**: Calculates production cost variances for analysis.

**Description**: Computes manufacturing cost variances including material variances, labor variances, overhead variances, and efficiency variances for performance analysis and corrective action.

**Parameters**:
- `variance_calculation_id`: Variance calculation identifier
- `work_order_id`: Work order for variance calculation
- `variance_scope`: Scope of variance analysis
- `standard_costs`: Standard costs for comparison
- `actual_costs`: Actual costs incurred
- `analysis_date`: Date of variance analysis

**Business Rules**:
- Variance calculations must be mathematically accurate
- Standard and actual costs must be from same period
- Significant variances require investigation
- Variance analysis must be complete and documented

---

### Cost Events

#### StandardCostsCalculated Event
**Purpose**: Records calculation of standard costs for items.

**Description**: Emitted when standard costs are calculated. Contains cost details and triggers cost update processes and variance monitoring setup.

**Data**:
- `cost_calculation_id`: Calculation identifier
- `items_calculated`: Items with new standard costs
- `cost_rollup_results`: Cost rollup calculation results
- `overhead_allocation`: Overhead allocation applied
- `effective_date`: Cost effective date
- `calculated_by`: User or system calculating costs

**Downstream Effects**:
- Updates standard cost master data
- Triggers cost variance monitoring setup
- Updates inventory valuation calculations
- Creates cost calculation audit trail

---

#### ActualCostsRecorded Event
**Purpose**: Records actual production costs for work orders.

**Description**: Emitted when actual costs are recorded. Contains cost details and triggers variance calculations and performance analysis.

**Data**:
- `actual_cost_id`: Actual cost record
- `work_order_id`: Work order with costs
- `cost_breakdown`: Detailed cost breakdown
- `total_actual_cost`: Total actual production cost
- `cost_drivers`: Primary drivers of costs
- `recorded_at`: Cost recording timestamp

**Downstream Effects**:
- Triggers variance calculation processes
- Updates work order cost tracking
- Enables performance analysis and reporting
- Creates actual cost audit trail

---

#### VariancesCalculated Event
**Purpose**: Records calculation of production cost variances.

**Description**: Emitted when cost variances are calculated. Contains variance details and triggers variance analysis, investigation, and corrective action processes.

**Data**:
- `variance_calculation_id`: Variance calculation identifier
- `work_order_id`: Work order with variances
- `variance_components`: Breakdown of variances by type
- `total_variance`: Net production variance
- `variance_causes`: Identified causes of variances
- `corrective_actions`: Recommended corrective actions
- `calculated_at`: Variance calculation timestamp

**Downstream Effects**:
- Triggers variance investigation processes
- Updates variance tracking and reporting
- Initiates corrective action workflows
- Creates variance analysis audit trail

---

## Quality Control Commands and Events

### Quality Management

#### CreateInspectionPlan Command
**Purpose**: Creates quality inspection plan for manufacturing operations.

**Description**: Establishes inspection requirements including test specifications, sampling plans, acceptance criteria, and inspection workflow for quality-controlled manufacturing.

**Parameters**:
- `inspection_plan_id`: Inspection plan identifier
- `item_id`: Item requiring inspection
- `inspection_type`: Type of inspection (incoming, in-process, final)
- `test_specifications`: Required tests and measurements
- `sampling_methodology`: Statistical sampling approach
- `acceptance_criteria`: Pass/fail criteria for tests
- `inspection_workflow`: Inspection process workflow

**Business Rules**:
- Inspection requirements must be based on item specifications
- Test specifications must be current and approved
- Sampling methodology must follow statistical standards
- Acceptance criteria must be measurable and objective

---

#### ScheduleInspection Command
**Purpose**: Schedules quality inspection for production operations.

**Description**: Plans inspection activities including inspector assignment, resource allocation, test scheduling, and coordination with production workflow for quality assurance.

**Parameters**:
- `inspection_schedule_id`: Inspection schedule identifier
- `inspection_plan_id`: Plan being scheduled
- `work_order_id`: Work order requiring inspection
- `scheduled_date`: When inspection should occur
- `inspector_assignment`: Assigned quality inspector
- `test_resources`: Resources needed for testing
- `inspection_priority`: Priority level for inspection

**Business Rules**:
- Inspector must be qualified for assigned tests
- Test resources must be available when needed
- Inspection timing must align with production workflow
- Priority levels must be appropriate for item criticality

---

#### RecordInspectionResults Command
**Purpose**: Records quality inspection results and disposition.

**Description**: Captures inspection results including test measurements, pass/fail determination, disposition decisions, and corrective action requirements for quality control.

**Parameters**:
- `inspection_result_id`: Inspection result identifier
- `inspection_id`: Inspection being recorded
- `test_measurements`: Actual test results and data
- `conformance_assessment`: Pass/fail evaluation
- `disposition_decision`: Accept, reject, or conditional acceptance
- `corrective_actions`: Required corrective actions
- `inspector_certification`: Inspector performing tests

**Business Rules**:
- Test results must be complete and accurate
- Conformance assessment must follow approved criteria
- Disposition must be appropriate for test results
- Corrective actions required for non-conformances

---

### Quality Events

#### InspectionPlanCreated Event
**Purpose**: Records creation of quality inspection plan.

**Description**: Emitted when inspection plan is created. Contains plan details and triggers inspection scheduling and quality workflow setup.

**Data**:
- `inspection_plan_id`: Created plan identifier
- `item_id`: Item for inspection plan
- `inspection_requirements`: Required inspections and tests
- `sampling_strategy`: Statistical sampling approach
- `workflow_definition`: Inspection process workflow
- `created_by`: User creating plan

**Downstream Effects**:
- Enables inspection scheduling for item
- Sets up quality workflow processes
- Triggers inspector training requirements
- Creates inspection plan audit trail

---

#### InspectionScheduled Event
**Purpose**: Records scheduling of quality inspection activities.

**Description**: Emitted when inspection is scheduled. Contains schedule details and triggers inspection preparation and resource coordination.

**Data**:
- `inspection_schedule_id`: Schedule identifier
- `inspection_plan_id`: Plan being scheduled
- `work_order_id`: Work order for inspection
- `inspection_timing`: When inspection scheduled
- `resource_allocation`: Resources allocated for inspection
- `scheduled_by`: User scheduling inspection

**Downstream Effects**:
- Allocates inspection resources and time
- Triggers inspection preparation activities
- Updates production schedule coordination
- Creates inspection schedule tracking

---

#### InspectionResultsRecorded Event
**Purpose**: Records quality inspection results and decisions.

**Description**: Emitted when inspection results are recorded. Contains results and triggers disposition processing, corrective actions, and quality status updates.

**Data**:
- `inspection_result_id`: Result record identifier
- `inspection_id`: Completed inspection
- `test_results`: Complete test data and measurements
- `conformance_status`: Overall conformance assessment
- `disposition`: Quality disposition decision
- `quality_impact`: Impact on production and quality metrics
- `recorded_at`: Result recording timestamp

**Downstream Effects**:
- Updates item quality status and availability
- Triggers corrective action workflows if needed
- Updates quality metrics and reporting
- Creates inspection result audit trail

---

## Master Data Commands and Events

### Master Data Management

#### CreateMasterData Command
**Purpose**: Creates manufacturing master data including items, resources, and configurations.

**Description**: Establishes master data for manufacturing including validation, relationship setup, configuration application, and integration coordination for manufacturing foundation data.

**Parameters**:
- `master_data_id`: Master data identifier
- `data_type`: Type of master data (item, machine, labor, BOM)
- `data_content`: Master data content and attributes
- `validation_rules`: Validation rules to apply
- `integration_requirements`: Integration setup requirements
- `approval_workflow`: Approval workflow if required

**Business Rules**:
- Master data must pass validation rules
- Relationships must be valid and consistent
- Integration requirements must be satisfied
- Approval workflow must be followed for critical data

---

#### UpdateMasterData Command
**Purpose**: Updates manufacturing master data with proper validation.

**Description**: Modifies master data including change validation, impact analysis, approval coordination, and integration updates while maintaining data integrity.

**Parameters**:
- `master_data_id`: Master data to update
- `update_type`: Type of update being performed
- `data_changes`: Specific changes to master data
- `impact_analysis`: Analysis of change impact
- `approval_requirements`: Approval needed for changes
- `effective_date`: When changes become effective

**Business Rules**:
- Changes must be validated for business impact
- Approval required for critical master data changes
- Effective dates must be appropriate for operations
- Change audit trail must be maintained

---

#### ValidateDataIntegrity Command
**Purpose**: Validates integrity of manufacturing master data.

**Description**: Performs comprehensive validation including consistency checking, relationship validation, business rule compliance, and integration validation for master data quality assurance.

**Parameters**:
- `validation_id`: Data validation identifier
- `validation_scope`: Scope of data validation
- `validation_rules`: Business rules to validate
- `relationship_checking`: Relationship consistency validation
- `integration_validation`: Integration point validation
- `correction_actions`: Automatic correction capabilities

**Business Rules**:
- Validation must be comprehensive and accurate
- Relationship consistency must be maintained
- Business rules must be enforced
- Integration points must be validated

---

### Master Data Events

#### MasterDataCreated Event
**Purpose**: Records creation of manufacturing master data.

**Description**: Emitted when master data is created. Contains data details and triggers validation, integration, and setup processes.

**Data**:
- `master_data_id`: Created data identifier
- `data_type`: Type of master data created
- `data_summary`: Summary of created data
- `validation_results`: Initial validation results
- `integration_status`: Integration setup status
- `created_by`: User creating data

**Downstream Effects**:
- Triggers integration setup processes
- Enables use of master data in operations
- Sets up monitoring and validation
- Creates master data audit trail

---

#### MasterDataUpdated Event
**Purpose**: Records updates to manufacturing master data.

**Description**: Emitted when master data is updated. Contains update details and triggers impact analysis, validation, and integration updates.

**Data**:
- `master_data_id`: Updated data identifier
- `update_details`: Specific changes made
- `impact_assessment`: Impact of changes
- `validation_results`: Validation of updated data
- `integration_updates`: Required integration updates
- `updated_by`: User making update

**Downstream Effects**:
- Updates dependent processes and calculations
- Triggers revalidation of affected data
- Updates integration points
- Creates update audit trail

---

## Summary

The Manufacturing domain contains **25 primary command types** and **20 primary event types** organized into:

**Work Order Management**: Work order creation, explosion, amendment, hold management with lifecycle events
**Bill of Materials**: BOM creation, updates, and version management commands with BOM lifecycle events
**Production Execution**: Production start, progress tracking, and completion commands with execution events
**Work-in-Process**: WIP posting, progress updates, and voiding commands with WIP lifecycle events
**Resource Management**: Machine and labor resource creation and management commands with resource events
**Cost Management**: Standard cost calculation, actual cost recording, and variance analysis commands with cost events
**Quality Control**: Inspection planning, scheduling, and result recording commands with quality events
**Master Data Management**: Master data creation, updates, and validation commands with data lifecycle events

Each command includes detailed parameters, business rules, and validation requirements, while events provide comprehensive data about system state changes and trigger appropriate downstream processing. The design supports complex manufacturing scenarios including multi-level BOMs, sophisticated costing methods, quality control processes, resource optimization, and seamless integration with other Accountex modules while maintaining complete traceability, regulatory compliance, and performance optimization capabilities.