# Accountex Manufacturing - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the Manufacturing domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core Production Management Aggregates

### WorkOrder

**Purpose**: Central aggregate managing production requests and coordination of manufacturing activities.

**Description**: The WorkOrder aggregate serves as the primary entity for production management, handling work order creation, explosion into jobs, resource allocation, and lifecycle management. It coordinates multi-level manufacturing hierarchies and maintains complete production audit trails from creation through completion.

**Key Responsibilities**:
- Work order creation and lifecycle management
- Master item configuration and production planning
- Multi-level job hierarchy generation and management
- Resource allocation coordination (materials, machines, labor)
- Production scheduling and date management
- Hold status management and release processing

**State Structure**:
```elixir
defstruct [
  :work_order_id,
  :work_order_number,
  :order_date,
  :request_date,
  :warehouse_id,
  :sales_order_id, # Optional link to sales order
  :customer_id, # Optional customer reference
  :master_items, # List of items to manufacture
  :jobs, # Exploded job hierarchy
  :status, # :draft, :exploded, :in_process, :completed, :voided
  :on_hold,
  :explosion_status,
  :resource_allocations
]
```

**Key Commands**: `CreateWorkOrder`, `ExplodeWorkOrder`, `AmendWorkOrder`, `PlaceOnHold`, `ReleaseFromHold`, `VoidWorkOrder`

**Key Events**: `WorkOrderCreated`, `WorkOrderExploded`, `WorkOrderAmended`, `WorkOrderPlacedOnHold`, `WorkOrderReleased`, `WorkOrderVoided`

---

### BillOfMaterials

**Purpose**: Manages product structure definitions and component relationships for manufacturing.

**Description**: The BillOfMaterials aggregate defines the component structure for manufactured items including material requirements, resource needs, and production specifications. It handles version control, component substitutions, and multi-level BOM explosions with complete traceability.

**Key Responsibilities**:
- Product structure definition and component relationships
- Version control and change tracking for BOMs
- Component substitution logic and approval
- Resource requirement specification (materials, machines, labor)
- Multi-level BOM explosion coordination
- Production instruction and documentation management

**State Structure**:
```elixir
defstruct [
  :bom_id,
  :parent_item_id,
  :version_number,
  :revision,
  :status, # :draft, :pending_approval, :approved, :active, :inactive
  :effective_date,
  :expiration_date,
  :components, # List of required components
  :resources, # Required machine and labor resources
  :yield_percentage,
  :scrap_percentage,
  :production_instructions
]
```

**Key Commands**: `CreateBOM`, `UpdateBOM`, `AddComponent`, `RemoveComponent`, `ActivateVersion`, `CreateRevision`

**Key Events**: `BOMCreated`, `BOMUpdated`, `ComponentAdded`, `ComponentRemoved`, `VersionActivated`, `RevisionCreated`

---

### WorkOrderExplosion

**Purpose**: Manages the explosion process that breaks down work orders into manufacturable jobs.

**Description**: The WorkOrderExplosion aggregate orchestrates the complex process of exploding work orders into detailed manufacturing jobs including component calculation, resource allocation, job hierarchy generation, and availability checking with comprehensive validation and error handling.

**Key Responsibilities**:
- Work order explosion coordination and processing
- Component requirement calculation with scrap factors
- Multi-level job hierarchy generation
- Material availability validation and allocation
- Resource requirement calculation and validation
- Substitute item handling and approval

**State Structure**:
```elixir
defstruct [
  :explosion_id,
  :work_order_id,
  :explosion_date,
  :explosion_type, # :full, :partial, :selective
  :jobs, # Generated manufacturing jobs
  :component_allocations,
  :resource_requirements,
  :explosion_levels,
  :status, # :in_progress, :completed, :failed
  :validation_results
]
```

**Key Commands**: `ExplodeWorkOrder`, `ExplodePartialWorkOrder`, `ValidateExplosion`, `HandleSubstitution`

**Key Events**: `ExplosionStarted`, `JobCreated`, `ComponentAllocated`, `ExplosionCompleted`, `SubstituteUsed`

---

## Work-in-Process Management Aggregates

### WorkInProcess

**Purpose**: Manages items currently being manufactured with cost tracking and status management.

**Description**: The WorkInProcess aggregate handles items in active production including WIP posting, cost accumulation, progress tracking, and inventory management. It coordinates between raw materials consumption and finished goods production while maintaining accurate cost and quantity tracking.

**Key Responsibilities**:
- WIP posting and cost accumulation management
- Production progress tracking and status updates
- Material consumption coordination and validation
- Cost application and variance calculation
- Serial and lot number tracking through production
- Quality checkpoint coordination

**State Structure**:
```elixir
defstruct [
  :wip_id,
  :job_id,
  :work_order_id,
  :parent_item_id,
  :wip_start_date,
  :wip_quantity,
  :allocated_components,
  :consumed_materials,
  :labor_applied,
  :machine_time_used,
  :status, # :in_process, :completed, :voided, :on_hold
  :cost_accumulation
]
```

**Key Commands**: `PostWorkInProcess`, `ConsumeComponents`, `ApplyLaborCost`, `RecordMachineTime`, `VoidWIP`

**Key Events**: `WorkInProcessPosted`, `ComponentsConsumed`, `LaborApplied`, `MachineTimeRecorded`, `WIPVoided`

---

### FinishedGoods

**Purpose**: Manages completed manufacturing jobs with cost settlement and inventory integration.

**Description**: The FinishedGoods aggregate handles job completion including finished goods receipt, cost settlement, variance calculation, and inventory integration. It coordinates final product receipt with proper cost allocation and variance recognition.

**Key Responsibilities**:
- Job completion processing and validation
- Finished goods receipt and inventory integration
- Final cost calculation and variance analysis
- Serial and lot number assignment for finished products
- Quality release and inventory availability
- Cost settlement and GL posting coordination

**State Structure**:
```elixir
defstruct [
  :finished_job_id,
  :work_order_id,
  :job_id,
  :finished_item_id,
  :finish_date,
  :finished_quantity,
  :final_costs, # Material, labor, machine, overhead
  :cost_variances,
  :serial_numbers,
  :lot_numbers,
  :quality_status,
  :released_to_inventory,
  :status # :posted, :released, :voided
]
```

**Key Commands**: `PostFinishedJob`, `CalculateVariances`, `ReleaseToInventory`, `AssignSerialNumbers`, `VoidFinishedJob`

**Key Events**: `FinishedJobPosted`, `VariancesCalculated`, `ReleasedToInventory`, `SerialsAssigned`, `FinishedJobVoided`

---

## Resource Management Aggregates

### MachineResource

**Purpose**: Machine capacity management with availability tracking and maintenance coordination.

**Description**: The MachineResource aggregate manages manufacturing machines including capacity planning, availability tracking, maintenance scheduling, and cost allocation. It provides machine scheduling services and integrates with maintenance management for optimal machine utilization.

**Key Responsibilities**:
- Machine capacity calculation and availability tracking
- Production scheduling and resource allocation
- Maintenance scheduling and threshold monitoring
- Machine cost calculation and allocation to jobs
- Efficiency tracking and OEE calculation
- Downtime analysis and capacity optimization

**State Structure**:
```elixir
defstruct [
  :machine_id,
  :machine_code,
  :description,
  :production_rate_per_hour,
  :cost_per_hour,
  :availability_status, # :available, :busy, :maintenance, :down
  :current_utilization,
  :maintenance_schedule,
  :accumulated_hours,
  :efficiency_rating,
  :work_assignments # Current and scheduled work
]
```

**Key Commands**: `CreateMachine`, `UpdateMachineConfig`, `ScheduleMaintenance`, `RecordMachineTime`, `UpdateEfficiency`

**Key Events**: `MachineCreated`, `MachineConfigUpdated`, `MaintenanceScheduled`, `MachineTimeRecorded`, `EfficiencyUpdated`

---

### LaborResource

**Purpose**: Labor resource management with skill tracking and cost allocation.

**Description**: The LaborResource aggregate manages labor resources including skill tracking, capacity planning, cost calculation, and work assignment. It handles labor efficiency monitoring, overtime management, and integration with payroll systems.

**Key Responsibilities**:
- Labor resource definition and skill management
- Work assignment and capacity planning
- Labor cost calculation including overtime and burden
- Efficiency tracking and performance monitoring
- Skill certification and training coordination
- Labor scheduling and shift management

**State Structure**:
```elixir
defstruct [
  :labor_id,
  :employee_id,
  :skill_level,
  :certifications,
  :standard_rate,
  :overtime_rate,
  :efficiency_factor,
  :availability_status,
  :current_assignments,
  :work_center_assignments,
  :shift_schedule
]
```

**Key Commands**: `CreateLaborResource`, `UpdateSkills`, `AssignToWorkCenter`, `RecordLaborTime`, `UpdateEfficiency`

**Key Events**: `LaborResourceCreated`, `SkillsUpdated`, `AssignedToWorkCenter`, `LaborTimeRecorded`, `EfficiencyUpdated`

---

## Production Tracking Aggregates

### ProductionExecution

**Purpose**: Real-time production execution tracking with operation management and progress monitoring.

**Description**: The ProductionExecution aggregate tracks real-time production activities including operation execution, progress monitoring, quality checkpoints, and performance measurement. It coordinates production floor activities with planning and provides real-time visibility.

**Key Responsibilities**:
- Real-time production tracking and monitoring
- Operation execution coordination and validation
- Progress measurement and reporting
- Quality checkpoint enforcement
- Performance metric calculation
- Production floor integration and communication

**Key Commands**: `StartProduction`, `CompleteOperation`, `RecordProgress`, `HandleQualityCheckpoint`, `PauseProduction`

**Key Events**: `ProductionStarted`, `OperationCompleted`, `ProgressRecorded`, `QualityCheckpointPassed`, `ProductionPaused`

---

### MaterialReservation

**Purpose**: Material reservation and allocation management for production planning.

**Description**: The MaterialReservation aggregate manages material reservations for work orders including availability checking, allocation processing, shortage handling, and substitute management. It ensures materials are available when needed for production.

**Key Responsibilities**:
- Material requirement calculation and validation
- Inventory availability checking and reservation
- Allocation processing and shortage handling
- Substitute material identification and approval
- Lead time calculation for material procurement
- Material release and consumption coordination

**Key Commands**: `ReserveMaterials`, `AllocateComponents`, `HandleShortage`, `ProcessSubstitution`, `ReleaseMaterials`

**Key Events**: `MaterialsReserved`, `ComponentsAllocated`, `ShortageDetected`, `SubstitutionProcessed`, `MaterialsReleased`

---

## Cost Management Aggregates

### CostingEngine

**Purpose**: Manufacturing cost calculation and variance analysis with multiple costing methods.

**Description**: The CostingEngine aggregate manages sophisticated manufacturing cost calculations including standard costing, actual costing, variance analysis, and cost rollup through multi-level BOMs. It provides costing services and maintains cost audit trails.

**Key Responsibilities**:
- Multi-method cost calculation (standard, actual, average)
- Cost rollup through multi-level BOM structures
- Variance analysis and reporting (material, labor, overhead)
- Overhead allocation and calculation methods
- Cost settlement and GL posting coordination
- Cost audit trail and compliance tracking

**State Structure**:
```elixir
defstruct [
  :item_id,
  :costing_method, # :standard, :actual, :average
  :standard_costs, # Material, labor, machine, overhead
  :actual_costs,
  :cost_variances,
  :overhead_allocation_base,
  :cost_rollup_levels,
  :cost_history
]
```

**Key Commands**: `CalculateStandardCosts`, `RecordActualCosts`, `CalculateVariances`, `AllocateOverhead`, `SettleCosts`

**Key Events**: `StandardCostsCalculated`, `ActualCostsRecorded`, `VariancesCalculated`, `OverheadAllocated`, `CostsSettled`

---

### ProductionVariance

**Purpose**: Production variance tracking and analysis with corrective action coordination.

**Description**: The ProductionVariance aggregate manages variance tracking across all cost components including analysis, investigation, and corrective action coordination. It provides variance reporting and helps optimize production efficiency.

**Key Responsibilities**:
- Multi-component variance calculation and tracking
- Variance analysis and root cause investigation
- Corrective action recommendation and coordination
- Variance trend analysis and reporting
- Performance improvement opportunity identification
- Variance approval workflow for significant variances

**Key Commands**: `CalculateVariance`, `AnalyzeRootCause`, `RecommendCorrectiveAction`, `ApproveVariance`

**Key Events**: `VarianceCalculated`, `RootCauseAnalyzed`, `CorrectiveActionRecommended`, `VarianceApproved`

---

## Quality and Compliance Aggregates

### QualityControl

**Purpose**: Quality control process management with inspection workflows and compliance tracking.

**Description**: The QualityControl aggregate manages quality control processes including inspection planning, test execution, result evaluation, and compliance reporting. It integrates with production to enforce quality gates and maintain quality standards.

**Key Responsibilities**:
- Quality inspection planning and scheduling
- Test execution coordination and result recording
- Quality gate enforcement and compliance validation
- Non-conformance management and corrective actions
- Quality metrics calculation and reporting
- Regulatory compliance and audit support

**Key Commands**: `CreateInspectionPlan`, `ScheduleInspection`, `RecordTestResults`, `ProcessNonConformance`

**Key Events**: `InspectionPlanCreated`, `InspectionScheduled`, `TestResultsRecorded`, `NonConformanceProcessed`

---

### ComplianceManagement

**Purpose**: Regulatory compliance management with audit trail and traceability coordination.

**Description**: The ComplianceManagement aggregate ensures manufacturing operations meet regulatory requirements including lot traceability, audit trail maintenance, compliance reporting, and violation management. It supports various industry regulations and standards.

**Key Responsibilities**:
- Regulatory compliance monitoring and enforcement
- Lot and serial traceability management
- Audit trail maintenance for compliance
- Compliance reporting and documentation
- Violation detection and corrective action
- Regulatory change impact assessment

**Key Commands**: `ValidateCompliance`, `TrackLotGenealogy`, `GenerateComplianceReport`, `ProcessViolation`

**Key Events**: `ComplianceValidated`, `LotGenealogyTracked`, `ComplianceReportGenerated`, `ViolationProcessed`

---

## Planning and Scheduling Aggregates

### ProductionScheduler

**Purpose**: Production scheduling optimization with capacity planning and constraint management.

**Description**: The ProductionScheduler aggregate manages production scheduling including capacity planning, constraint management, resource optimization, and schedule maintenance. It balances demand requirements with resource availability for optimal production flow.

**Key Responsibilities**:
- Production schedule generation and optimization
- Capacity planning and constraint management
- Resource allocation and load balancing
- Schedule maintenance and adjustment
- Lead time calculation and management
- Production flow optimization

**Key Commands**: `CreateSchedule`, `OptimizeCapacity`, `AllocateResources`, `AdjustSchedule`, `ValidateConstraints`

**Key Events**: `ScheduleCreated`, `CapacityOptimized`, `ResourcesAllocated`, `ScheduleAdjusted`, `ConstraintsValidated`

---

### MaterialRequirementsPlanning

**Purpose**: Material requirements planning with demand forecasting and procurement coordination.

**Description**: The MaterialRequirementsPlanning aggregate manages MRP processing including demand calculation, supply planning, procurement coordination, and shortage management. It optimizes material availability for production requirements.

**Key Responsibilities**:
- Material requirement calculation from work orders
- Supply and demand planning coordination
- Procurement requirement generation
- Shortage identification and resolution
- Lead time planning and optimization
- Safety stock and reorder point management

**Key Commands**: `CalculateRequirements`, `PlanSupply`, `GenerateProcurement`, `HandleShortage`

**Key Events**: `RequirementsCalculated`, `SupplyPlanned`, `ProcurementGenerated`, `ShortageHandled`

---

## Configuration and Setup Aggregates

### ManufacturingConfiguration

**Purpose**: Manufacturing system configuration with parameter management and business rule setup.

**Description**: The ManufacturingConfiguration aggregate manages system-wide manufacturing configuration including processing options, costing methods, validation rules, and integration settings. It maintains configuration consistency and change audit trails.

**Key Responsibilities**:
- System-wide manufacturing parameter management
- Processing option configuration and validation
- Costing method setup and enforcement
- Business rule configuration and maintenance
- Integration parameter management
- Configuration change audit and approval

**Key Commands**: `UpdateConfiguration`, `SetCostingMethod`, `ConfigureValidation`, `EnableIntegration`

**Key Events**: `ConfigurationUpdated`, `CostingMethodSet`, `ValidationConfigured`, `IntegrationEnabled`

---

### WorkCenter

**Purpose**: Work center definition and capacity management with resource coordination.

**Description**: The WorkCenter aggregate manages production work centers including resource assignment, capacity definition, operational parameters, and performance tracking. It provides production organization and resource grouping capabilities.

**Key Responsibilities**:
- Work center definition and operational management
- Resource assignment and capacity planning
- Operational parameter configuration
- Performance tracking and optimization
- Calendar and shift management
- Cost center coordination

**Key Commands**: `CreateWorkCenter`, `AssignResources`, `UpdateCapacity`, `ConfigureCalendar`

**Key Events**: `WorkCenterCreated`, `ResourcesAssigned`, `CapacityUpdated`, `CalendarConfigured`

---

## Master Data Management Aggregates

### MasterDataManagement

**Purpose**: Manufacturing master data lifecycle management with approval workflows and version control.

**Description**: The MasterDataManagement aggregate coordinates master data maintenance including approval workflows, version control, change management, and data integrity validation. It ensures master data accuracy and consistency across manufacturing operations.

**Key Responsibilities**:
- Master data lifecycle management and validation
- Approval workflow coordination for data changes
- Version control and change tracking
- Data integrity validation and consistency checking
- Mass update operations and batch processing
- Master data audit trail maintenance

**Key Commands**: `RequestDataChange`, `ApproveDataChange`, `ValidateDataIntegrity`, `ExecuteMassUpdate`

**Key Events**: `DataChangeRequested`, `DataChangeApproved`, `DataIntegrityValidated`, `MassUpdateExecuted`

---

### InventoryTypeManagement

**Purpose**: Manufacturing-specific inventory type configuration with costing and tracking rules.

**Description**: The InventoryTypeManagement aggregate manages inventory types specific to manufacturing including costing method configuration, tracking requirements, and manufacturing behavior rules. It provides foundation for inventory management in manufacturing context.

**Key Responsibilities**:
- Manufacturing inventory type definition
- Costing method configuration and enforcement
- Lot and serial tracking requirement management
- Manufacturing behavior rule configuration
- GL account mapping for manufacturing transactions
- Type-specific validation rule management

**Key Commands**: `CreateInventoryType`, `ConfigureCostingMethod`, `SetTrackingRequirements`, `MapGLAccounts`

**Key Events**: `InventoryTypeCreated`, `CostingMethodConfigured`, `TrackingRequirementsSet`, `GLAccountsMapped`

---

## Performance and Analytics Aggregates

### ProductionAnalytics

**Purpose**: Production performance analysis with KPI calculation and trend identification.

**Description**: The ProductionAnalytics aggregate processes production data to generate performance analytics including efficiency metrics, quality indicators, cost analysis, and trend identification. It provides business intelligence for production optimization.

**Key Responsibilities**:
- Production performance metric calculation
- Efficiency analysis and OEE calculation
- Quality metric tracking and analysis
- Cost performance analysis and optimization
- Trend identification and forecasting
- Performance reporting and dashboard support

**Key Commands**: `CalculatePerformanceMetrics`, `AnalyzeEfficiency`, `GenerateKPIReport`, `IdentifyTrends`

**Key Events**: `PerformanceMetricsCalculated`, `EfficiencyAnalyzed`, `KPIReportGenerated`, `TrendsIdentified`

---

### CapacityAnalytics

**Purpose**: Capacity utilization analysis with optimization recommendations and planning support.

**Description**: The CapacityAnalytics aggregate analyzes capacity utilization across machines, labor, and work centers including bottleneck identification, optimization recommendations, and capacity planning support for strategic decision making.

**Key Responsibilities**:
- Capacity utilization measurement and analysis
- Bottleneck identification and impact analysis
- Optimization recommendation generation
- Capacity planning support and forecasting
- Resource efficiency analysis
- Strategic capacity decision support

**Key Commands**: `AnalyzeCapacityUtilization`, `IdentifyBottlenecks`, `RecommendOptimizations`, `ForecastCapacity`

**Key Events**: `CapacityUtilizationAnalyzed`, `BottlenecksIdentified`, `OptimizationsRecommended`, `CapacityForecasted`

---

## Integration and Communication Aggregates

### ManufacturingIntegration

**Purpose**: Integration coordination with other ERP modules and external systems.

**Description**: The ManufacturingIntegration aggregate manages integration between manufacturing and other modules including event coordination, data synchronization, API management, and integration error handling. It ensures data consistency across module boundaries.

**Key Responsibilities**:
- Inter-module integration coordination
- Event publishing and subscription management
- Data synchronization and consistency validation
- Integration error handling and recovery
- External system API management
- Integration audit trail and monitoring

**Key Commands**: `PublishManufacturingEvent`, `SyncWithModule`, `HandleIntegrationError`, `ValidateDataSync`

**Key Events**: `ManufacturingEventPublished`, `ModuleSyncCompleted`, `IntegrationErrorHandled`, `DataSyncValidated`

---

### LotTraceability

**Purpose**: Lot and serial number traceability with genealogy management and compliance support.

**Description**: The LotTraceability aggregate maintains complete lot and serial number traceability through the manufacturing process including genealogy tracking, forward and backward tracing, and compliance reporting for regulatory requirements.

**Key Responsibilities**:
- Lot and serial number genealogy maintenance
- Forward and backward traceability processing
- Component lot consumption tracking
- Finished lot generation and assignment
- Recall coordination and impact analysis
- Regulatory compliance and audit support

**Key Commands**: `TrackLotGenealogy`, `AssignFinishedLot`, `ProcessTraceabilityRequest`, `GenerateGenealogyReport`

**Key Events**: `LotGenealogyTracked`, `FinishedLotAssigned`, `TraceabilityRequestProcessed`, `GenealogyReportGenerated`

---

## Summary

The Manufacturing domain contains **15 primary aggregates** that collectively provide:

- **Production Management**: WorkOrder, WorkOrderExplosion for production planning and execution
- **Product Structure**: BillOfMaterials for product definition and component relationships
- **WIP Management**: WorkInProcess, FinishedGoods for production tracking and completion
- **Resource Management**: MachineResource, LaborResource for capacity and resource planning
- **Execution Tracking**: ProductionExecution, MaterialReservation for real-time production coordination
- **Cost Management**: CostingEngine, ProductionVariance for comprehensive cost tracking and analysis
- **Quality Operations**: QualityControl, ComplianceManagement for quality assurance and regulatory compliance
- **Planning Operations**: ProductionScheduler, MaterialRequirementsPlanning for production optimization
- **Configuration**: ManufacturingConfiguration, WorkCenter, InventoryTypeManagement for system setup
- **Analytics**: ProductionAnalytics, CapacityAnalytics for performance analysis and optimization
- **Integration**: ManufacturingIntegration, LotTraceability for external coordination and compliance
- **Master Data**: MasterDataManagement for data lifecycle and integrity

Each aggregate maintains strict consistency boundaries and communicates through well-defined events, ensuring data integrity while supporting complex manufacturing requirements including multi-level BOMs, sophisticated costing methods, quality control processes, capacity optimization, and seamless integration with other Accountex modules including Inventory Control, Sales Orders, Purchasing, and General Ledger. The design supports both discrete and process manufacturing scenarios with complete traceability, regulatory compliance, and performance optimization capabilities.