# Accountex Inventory Control - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the Inventory Control domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core Item Management Aggregates

### InventoryItem

**Purpose**: Core inventory item entity managing item master data, specifications, and lifecycle.

**Description**: The InventoryItem aggregate serves as the central entity for inventory management, handling item creation, specification management, costing methods, and status lifecycle. It manages complex item configurations including kit items, lot-controlled items, and serial-controlled items while maintaining comprehensive audit trails for all item changes.

**Key Responsibilities**:
- Item master data management and validation
- Specification configuration and version control
- Costing method definition and enforcement
- Kit component relationship management
- Status lifecycle management (active, inactive, discontinued)
- Multi-unit-of-measure support and conversions

**State Structure**:
```elixir
defstruct [
  :item_id,
  :sku,
  :description,
  :item_type, # :stock, :non_stock, :service, :kit
  :status, # :active, :inactive, :discontinued
  :costing_method, # :fifo, :lifo, :average, :specific, :standard
  :standard_cost,
  :reorder_point,
  :reorder_quantity,
  :safety_stock,
  :serial_controlled,
  :lot_controlled,
  :kit_components,
  :specifications
]
```

**Key Commands**: `CreateItem`, `UpdateItemSpecifications`, `ActivateItem`, `DeactivateItem`, `ConfigureKitComponents`

**Key Events**: `ItemCreated`, `ItemSpecificationsUpdated`, `ItemStatusChanged`, `KitComponentsConfigured`

---

### InventoryType

**Purpose**: Item type classification with default settings and behavior configuration.

**Description**: The InventoryType aggregate manages item type definitions that provide default settings and behavior for inventory items. It defines costing methods, lot control requirements, GL account mappings, and various flags that control item behavior across different modules.

**Key Responsibilities**:
- Item type definition and classification
- Default setting configuration for new items
- Costing method enforcement by type
- GL account mapping for inventory transactions
- Module behavior configuration
- Override permission management

**Key Commands**: `CreateInventoryType`, `UpdateTypeSettings`, `ConfigureGLAccounts`, `SetOverridePermissions`

**Key Events**: `InventoryTypeCreated`, `TypeSettingsUpdated`, `GLAccountsConfigured`, `OverridePermissionsSet`

---

## Warehouse and Location Management Aggregates

### Warehouse

**Purpose**: Physical warehouse location management with capacity and operational configuration.

**Description**: The Warehouse aggregate manages physical warehouse locations including address information, capacity constraints, operational settings, and GL account mappings. It handles warehouse configuration, bin management, and integration with warehouse management systems.

**Key Responsibilities**:
- Warehouse location definition and management
- Capacity constraint configuration and monitoring
- Operational setting management
- Bin structure and layout configuration
- GL account mapping for warehouse transactions
- Integration with external warehouse systems

**State Structure**:
```elixir
defstruct [
  :warehouse_id,
  :warehouse_code,
  :description,
  :address_details,
  :capacity_constraints,
  :bin_structure,
  :operational_settings,
  :gl_accounts,
  :status # :active, :inactive, :maintenance
]
```

**Key Commands**: `CreateWarehouse`, `UpdateWarehouseConfig`, `ConfigureBinStructure`, `SetCapacityLimits`

**Key Events**: `WarehouseCreated`, `WarehouseConfigUpdated`, `BinStructureConfigured`, `CapacityLimitsSet`

---

### WarehouseInventory

**Purpose**: Inventory balance management at the warehouse level with multi-location tracking.

**Description**: The WarehouseInventory aggregate manages inventory balances at the warehouse level including on-hand quantities, allocated amounts, cost tracking, and reorder point management. It supports complex scenarios including in-transit inventory, allocated stock, and safety stock management.

**Key Responsibilities**:
- Warehouse-level inventory balance maintenance
- On-hand quantity tracking and validation
- Allocation management and available-to-promise calculations
- Reorder point monitoring and purchase recommendations
- Cost layer management by costing method
- In-transit and allocated quantity tracking

**State Structure**:
```elixir
defstruct [
  :balance_id, # {item_id, warehouse_id}
  :quantity_on_hand,
  :quantity_allocated,
  :quantity_available,
  :quantity_in_transit,
  :cost_layers, # List of {date, quantity, unit_cost}
  :reorder_point,
  :safety_stock,
  :average_cost,
  :total_value
]
```

**Key Commands**: `UpdateWarehouseBalance`, `AllocateStock`, `ReleaseAllocation`, `RecalculateCosts`

**Key Events**: `WarehouseBalanceUpdated`, `StockAllocated`, `AllocationReleased`, `CostsRecalculated`

---

### BinInventory

**Purpose**: Bin-level inventory tracking with precise location management.

**Description**: The BinInventory aggregate manages inventory at the individual bin level providing precise location tracking, bin capacity management, and detailed movement history. It supports complex bin management scenarios including picking optimization and putaway strategies.

**Key Responsibilities**:
- Bin-level quantity tracking and management
- Bin capacity constraint enforcement
- Precise location management and optimization
- Movement history and audit trail maintenance
- Picking sequence optimization
- Putaway strategy implementation

**Key Commands**: `ReceiveIntoBin`, `IssueFromBin`, `MoveBetweenBins`, `AdjustBinQuantity`

**Key Events**: `StockReceivedIntoBin`, `StockIssuedFromBin`, `StockMovedBetweenBins`, `BinQuantityAdjusted`

---

## Movement and Transaction Aggregates

### InventoryTransfer

**Purpose**: Inter-warehouse and inter-bin transfer processing with tracking and validation.

**Description**: The InventoryTransfer aggregate manages inventory transfers between warehouses or bins including transfer authorization, in-transit tracking, receipt confirmation, and cost adjustments. It handles complex transfer scenarios including cross-company transfers and drop-ship arrangements.

**Key Responsibilities**:
- Transfer request creation and authorization
- In-transit tracking and status management
- Receipt confirmation and variance processing
- Cost adjustment and GL posting coordination
- Cross-company transfer management
- Transfer documentation and audit trails

**State Structure**:
```elixir
defstruct [
  :transfer_id,
  :item_id,
  :from_location_id,
  :to_location_id,
  :quantity,
  :transfer_cost,
  :status, # :draft, :submitted, :approved, :in_transit, :received, :completed
  :tracking_info,
  :variance_details,
  :approval_history
]
```

**Key Commands**: `InitiateTransfer`, `ApproveTransfer`, `ShipTransfer`, `ReceiveTransfer`, `CompleteTransfer`

**Key Events**: `TransferInitiated`, `TransferApproved`, `TransferShipped`, `TransferReceived`, `TransferCompleted`

---

### InventoryAdjustment

**Purpose**: Inventory quantity and value adjustments with reason tracking and approval management.

**Description**: The InventoryAdjustment aggregate manages inventory adjustments including quantity corrections, cost adjustments, write-offs, and physical count adjustments. It handles adjustment authorization, reason code validation, and GL posting coordination with comprehensive audit trails.

**Key Responsibilities**:
- Inventory adjustment processing and authorization
- Reason code validation and tracking
- Adjustment approval workflow management
- GL posting coordination and validation
- Adjustment audit trail maintenance
- Variance analysis and reporting

**State Structure**:
```elixir
defstruct [
  :adjustment_id,
  :item_id,
  :location_id,
  :adjustment_type, # :quantity, :cost, :writeoff, :revaluation
  :adjustment_quantity,
  :adjustment_value,
  :reason_code,
  :approval_status,
  :gl_posting_status,
  :audit_trail
]
```

**Key Commands**: `CreateAdjustment`, `ApproveAdjustment`, `PostAdjustmentToGL`, `ReverseAdjustment`

**Key Events**: `AdjustmentCreated`, `AdjustmentApproved`, `AdjustmentPostedToGL`, `AdjustmentReversed`

---

### InventoryTransaction

**Purpose**: Individual inventory transaction recording with complete audit trail and traceability.

**Description**: The InventoryTransaction aggregate records individual inventory movements including receipts, issues, transfers, and adjustments. It maintains complete transaction history, reference linking, and supports complex transaction scenarios including reversals and corrections.

**Key Responsibilities**:
- Individual transaction recording and validation
- Transaction reference and linking management
- Complete audit trail and traceability maintenance
- Transaction reversal and correction processing
- Cost calculation and GL integration
- Multi-module transaction coordination

**Key Commands**: `RecordTransaction`, `ReverseTransaction`, `CorrectTransaction`, `LinkTransactions`

**Key Events**: `TransactionRecorded`, `TransactionReversed`, `TransactionCorrected`, `TransactionsLinked`

---

## Physical Count and Cycle Count Aggregates

### PhysicalCount

**Purpose**: Physical inventory count processing with variance detection and adjustment coordination.

**Description**: The PhysicalCount aggregate manages physical inventory counts including count scheduling, execution coordination, variance detection, recount processing, and final adjustment posting. It supports various count types including full physical, cycle counts, and spot counts.

**Key Responsibilities**:
- Physical count planning and scheduling
- Count execution coordination and tracking
- Variance detection and tolerance checking
- Recount processing for variance resolution
- Final adjustment calculation and posting
- Count audit trail and compliance reporting

**State Structure**:
```elixir
defstruct [
  :count_id,
  :location_id,
  :count_type, # :full_physical, :cycle_count, :spot_count
  :count_status, # :scheduled, :active, :counted, :validated, :adjusted, :closed
  :expected_items,
  :counted_items,
  :variances,
  :tolerance_settings,
  :recount_history
]
```

**Key Commands**: `InitiatePhysicalCount`, `RecordCountedQuantity`, `ValidateCount`, `PostCountAdjustments`

**Key Events**: `PhysicalCountStarted`, `ItemCounted`, `CountVarianceDetected`, `CountCompleted`

---

### CycleCount

**Purpose**: Continuous cycle counting with ABC classification and count frequency management.

**Description**: The CycleCount aggregate manages ongoing cycle counting programs including ABC classification, count frequency scheduling, count assignment, and performance tracking. It optimizes counting efficiency while maintaining inventory accuracy.

**Key Responsibilities**:
- ABC classification management and maintenance
- Count frequency scheduling by classification
- Counter assignment and workload balancing
- Count performance tracking and optimization
- Accuracy improvement monitoring
- Count program analytics and reporting

**Key Commands**: `ScheduleCycleCount`, `AssignCounter`, `CompleteCycleCount`, `UpdateABCClassification`

**Key Events**: `CycleCountScheduled`, `CounterAssigned`, `CycleCountCompleted`, `ABCClassificationUpdated`

---

## Kit and Assembly Management Aggregates

### KitManagement

**Purpose**: Kit item configuration and component explosion with assembly coordination.

**Description**: The KitManagement aggregate handles kit item processing including component explosion, availability checking for all components, assembly coordination, and component substitution management. It supports both standard and configurable kits with complex component relationships.

**Key Responsibilities**:
- Kit component definition and explosion
- Component availability checking and validation
- Assembly process coordination and tracking
- Component substitution management
- Configurable kit option processing
- Kit cost calculation and rollup

**State Structure**:
```elixir
defstruct [
  :kit_item_id,
  :components, # List of {component_item_id, quantity, substitutable}
  :assembly_method, # :pick_to_order, :assemble_to_stock, :configure_to_order
  :component_availability,
  :assembly_instructions,
  :cost_rollup_method,
  :substitution_rules
]
```

**Key Commands**: `DefineKitComponents`, `ExplodeKitComponents`, `AssembleKit`, `ValidateSubstitution`

**Key Events**: `KitComponentsDefined`, `KitComponentsExploded`, `KitAssembled`, `SubstitutionValidated`

---

### KitAssembly

**Purpose**: Kit assembly process management with component consumption and finished goods receipt.

**Description**: The KitAssembly aggregate manages the physical assembly of kit items including component reservation, consumption tracking, assembly processing, and finished goods receipt. It handles assembly exceptions, component shortages, and quality control requirements.

**Key Responsibilities**:
- Assembly order creation and processing
- Component reservation and consumption
- Assembly process tracking and status management
- Quality control and inspection coordination
- Finished goods receipt and cost calculation
- Assembly exception handling and resolution

**Key Commands**: `CreateAssemblyOrder`, `ReserveComponents`, `ConsumeComponents`, `ReceiveAssembledKit`

**Key Events**: `AssemblyOrderCreated`, `ComponentsReserved`, `ComponentsConsumed`, `AssembledKitReceived`

---

## Lot and Serial Control Aggregates

### LotControl

**Purpose**: Lot and batch tracking with genealogy and traceability management.

**Description**: The LotControl aggregate manages lot and batch tracking including lot creation, genealogy maintenance, expiration management, and forward/backward traceability. It supports complex lot scenarios including lot splitting, merging, and quality hold management.

**Key Responsibilities**:
- Lot and batch creation and management
- Lot genealogy and traceability maintenance
- Expiration date tracking and management
- Quality hold and release processing
- Lot splitting and merging coordination
- Regulatory compliance and reporting

**State Structure**:
```elixir
defstruct [
  :lot_id,
  :lot_number,
  :item_id,
  :creation_date,
  :expiration_date,
  :parent_lots,
  :child_lots,
  :quality_status, # :released, :quarantine, :hold, :expired
  :test_results,
  :genealogy_chain,
  :quantity_balance
]
```

**Key Commands**: `CreateLot`, `UpdateLotStatus`, `SplitLot`, `MergeLots`, `HoldLot`, `ReleaseLot`

**Key Events**: `LotCreated`, `LotStatusUpdated`, `LotSplit`, `LotsMerged`, `LotHeld`, `LotReleased`

---

### SerialControl

**Purpose**: Serial number tracking with individual item lifecycle and service history.

**Description**: The SerialControl aggregate manages individual serial number tracking including serial assignment, lifecycle management, service history, and warranty tracking. It provides complete traceability for serialized items from manufacturing through disposal.

**Key Responsibilities**:
- Serial number assignment and validation
- Individual item lifecycle tracking
- Service history and maintenance record management
- Warranty tracking and claim processing
- Location tracking and movement history
- Regulatory compliance for serialized items

**State Structure**:
```elixir
defstruct [
  :serial_number,
  :item_id,
  :manufacturing_date,
  :warranty_expiration,
  :current_location,
  :service_history,
  :status, # :manufactured, :sold, :in_service, :retired
  :movement_history,
  :warranty_claims
]
```

**Key Commands**: `AssignSerialNumber`, `UpdateSerialStatus`, `RecordService`, `ProcessWarrantyClaim`

**Key Events**: `SerialNumberAssigned`, `SerialStatusUpdated`, `ServiceRecorded`, `WarrantyClaimProcessed`

---

## Costing and Valuation Aggregates

### CostingEngine

**Purpose**: Cost calculation and method management with layer tracking and valuation.

**Description**: The CostingEngine aggregate manages sophisticated costing calculations including FIFO/LIFO layer management, average cost calculations, standard cost maintenance, and cost variance analysis. It provides costing services to all inventory transactions and maintains audit trails for cost changes.

**Key Responsibilities**:
- Cost layer management for FIFO/LIFO methods
- Average cost calculation and maintenance
- Standard cost setting and variance analysis
- Cost method enforcement and validation
- Landed cost allocation and calculation
- Cost audit trail and compliance reporting

**State Structure**:
```elixir
defstruct [
  :item_id,
  :costing_method,
  :cost_layers, # List of {date, quantity, unit_cost, reference}
  :average_cost,
  :standard_cost,
  :cost_variances,
  :landed_cost_factors,
  :cost_history
]
```

**Key Commands**: `CalculateItemCost`, `UpdateStandardCost`, `ProcessCostVariance`, `AllocateLandedCosts`

**Key Events**: `ItemCostCalculated`, `StandardCostUpdated`, `CostVarianceProcessed`, `LandedCostsAllocated`

---

### InventoryValuation

**Purpose**: Inventory valuation calculation and reporting with multiple valuation methods.

**Description**: The InventoryValuation aggregate manages inventory valuation calculations for financial reporting including book value, market value, net realizable value, and lower-of-cost-or-market calculations. It supports multiple valuation methods and regulatory reporting requirements.

**Key Responsibilities**:
- Inventory valuation calculation by method
- Market value assessment and comparison
- Lower-of-cost-or-market analysis
- Obsolescence reserve calculation
- Valuation reporting and compliance
- Period-end valuation coordination

**Key Commands**: `CalculateInventoryValuation`, `AssessMarketValue`, `CalculateObsolescenceReserve`, `GenerateValuationReport`

**Key Events**: `InventoryValuationCalculated`, `MarketValueAssessed`, `ObsolescenceReserveCalculated`, `ValuationReportGenerated`

---

## Pricing Management Aggregates

### PricingEngine

**Purpose**: Complex pricing management with multi-level pricing and customer-specific pricing.

**Description**: The PricingEngine aggregate manages sophisticated pricing structures including base pricing, volume discounts, customer-specific pricing, promotional pricing, and contract pricing. It provides pricing calculation services and maintains pricing audit trails.

**Key Responsibilities**:
- Multi-level pricing structure management
- Volume discount configuration and calculation
- Customer-specific pricing maintenance
- Promotional pricing campaign management
- Contract pricing agreement processing
- Pricing audit trail and compliance tracking

**State Structure**:
```elixir
defstruct [
  :item_id,
  :base_price,
  :volume_tiers,
  :customer_pricing,
  :promotional_campaigns,
  :contract_agreements,
  :pricing_effective_dates,
  :margin_requirements
]
```

**Key Commands**: `SetBasePrice`, `ConfigureVolumeDiscounts`, `SetCustomerPrice`, `CreatePromotionalCampaign`

**Key Events**: `BasePriceSet`, `VolumeDiscountsConfigured`, `CustomerPriceSet`, `PromotionalCampaignCreated`

---

## Procurement Integration Aggregates

### PurchaseRequisition

**Purpose**: Purchase requisition generation based on reorder points and demand forecasting.

**Description**: The PurchaseRequisition aggregate manages automatic generation of purchase requisitions based on reorder points, demand forecasts, and inventory planning parameters. It optimizes purchasing decisions and maintains requisition audit trails.

**Key Responsibilities**:
- Automatic requisition generation based on reorder points
- Demand forecasting and planning integration
- Vendor selection and pricing optimization
- Requisition approval workflow coordination
- Purchase order conversion processing
- Procurement audit trail maintenance

**Key Commands**: `GenerateRequisition`, `OptimizeVendorSelection`, `ConvertToPurchaseOrder`, `CancelRequisition`

**Key Events**: `RequisitionGenerated`, `VendorSelectionOptimized`, `ConvertedToPurchaseOrder`, `RequisitionCancelled`

---

### LandedCost

**Purpose**: Landed cost calculation and allocation with freight and duty management.

**Description**: The LandedCost aggregate manages the calculation and allocation of landed costs including freight, duties, handling charges, and other cost factors that affect the total cost of inventory. It supports complex allocation methods and multi-currency scenarios.

**Key Responsibilities**:
- Landed cost component calculation and allocation
- Freight and duty cost management
- Multi-currency cost conversion
- Cost allocation method configuration
- Vendor cost tracking and analysis
- Landed cost audit trail maintenance

**Key Commands**: `CalculateLandedCost`, `AllocateCostComponents`, `UpdateFreightRates`, `ProcessDutyCalculation`

**Key Events**: `LandedCostCalculated`, `CostComponentsAllocated`, `FreightRatesUpdated`, `DutyCalculationProcessed`

---

## Quality and Compliance Aggregates

### QualityControl

**Purpose**: Quality control process management with inspection workflows and compliance tracking.

**Description**: The QualityControl aggregate manages quality control processes including inspection scheduling, test result recording, quality hold management, and compliance reporting. It integrates with lot control for quality-based lot management.

**Key Responsibilities**:
- Quality inspection scheduling and coordination
- Test result recording and validation
- Quality hold and release processing
- Non-conformance management and corrective actions
- Compliance reporting and audit trail maintenance
- Quality metrics tracking and improvement

**Key Commands**: `ScheduleInspection`, `RecordTestResults`, `IssueQualityHold`, `ReleaseFromHold`

**Key Events**: `InspectionScheduled`, `TestResultsRecorded`, `QualityHoldIssued`, `ReleasedFromHold`

---

### ComplianceManagement

**Purpose**: Regulatory compliance management with audit trail and reporting capabilities.

**Description**: The ComplianceManagement aggregate manages regulatory compliance requirements including FDA regulations, recall management, audit trail maintenance, and compliance reporting. It ensures inventory operations meet regulatory standards and maintains required documentation.

**Key Responsibilities**:
- Regulatory compliance monitoring and enforcement
- Recall process coordination and tracking
- Audit trail maintenance for compliance
- Regulatory reporting generation
- Documentation management and retention
- Compliance violation detection and resolution

**Key Commands**: `InitiateRecall`, `GenerateComplianceReport`, `ValidateCompliance`, `ProcessViolation`

**Key Events**: `RecallInitiated`, `ComplianceReportGenerated`, `ComplianceValidated`, `ViolationProcessed`

---

## Planning and Analytics Aggregates

### DemandForecasting

**Purpose**: Demand forecasting and inventory planning with statistical analysis and machine learning.

**Description**: The DemandForecasting aggregate manages demand forecasting including statistical analysis, seasonal pattern recognition, trend analysis, and machine learning-based predictions. It provides input for inventory planning and procurement decisions.

**Key Responsibilities**:
- Historical demand analysis and pattern recognition
- Statistical forecasting model application
- Seasonal adjustment and trend analysis
- Machine learning model training and prediction
- Forecast accuracy measurement and improvement
- Planning parameter optimization

**Key Commands**: `GenerateForecast`, `UpdateForecastModel`, `AnalyzeDemandPatterns`, `OptimizePlanningParameters`

**Key Events**: `ForecastGenerated`, `ForecastModelUpdated`, `DemandPatternsAnalyzed`, `PlanningParametersOptimized`

---

### InventoryPlanning

**Purpose**: Inventory planning optimization with reorder point calculation and safety stock management.

**Description**: The InventoryPlanning aggregate manages inventory planning including reorder point calculations, safety stock optimization, economic order quantity determination, and procurement timing optimization. It integrates with demand forecasting for intelligent planning decisions.

**Key Responsibilities**:
- Reorder point calculation and optimization
- Safety stock determination and management
- Economic order quantity calculation
- Procurement timing optimization
- Planning parameter maintenance
- Planning performance analysis

**Key Commands**: `CalculateReorderPoints`, `OptimizeSafetyStock`, `DetermineEOQ`, `UpdatePlanningParameters`

**Key Events**: `ReorderPointsCalculated`, `SafetyStockOptimized`, `EOQDetermined`, `PlanningParametersUpdated`

---

## Configuration and Setup Aggregates

### InventoryConfiguration

**Purpose**: Global inventory control configuration with parameter management and business rule setup.

**Description**: The InventoryConfiguration aggregate manages system-wide inventory control configuration including costing methods, numbering schemes, approval workflows, and integration settings. It validates configuration changes and maintains configuration history.

**Key Responsibilities**:
- Global inventory parameter management
- Costing method configuration and validation
- Numbering scheme setup and maintenance
- Approval workflow configuration
- Integration parameter management
- Configuration change audit and validation

**Key Commands**: `UpdateInventoryConfig`, `SetCostingMethods`, `ConfigureNumberingSchemes`, `SetupApprovalWorkflows`

**Key Events**: `InventoryConfigUpdated`, `CostingMethodsSet`, `NumberingSchemesConfigured`, `ApprovalWorkflowsSetup`

---

### WarehouseConfiguration

**Purpose**: Warehouse-specific configuration with operational parameters and layout management.

**Description**: The WarehouseConfiguration aggregate manages warehouse-specific configuration including bin layout, picking strategies, putaway rules, and operational parameters. It supports complex warehouse layouts and optimization strategies.

**Key Responsibilities**:
- Warehouse layout and bin configuration
- Picking strategy and optimization rules
- Putaway strategy and slotting optimization
- Operational parameter management
- Capacity planning and constraint management
- Performance optimization configuration

**Key Commands**: `ConfigureWarehouseLayout`, `SetPickingStrategy`, `OptimizePutawayRules`, `UpdateCapacityConstraints`

**Key Events**: `WarehouseLayoutConfigured`, `PickingStrategySet`, `PutawayRulesOptimized`, `CapacityConstraintsUpdated`

---

## Integration and Communication Aggregates

### InventoryIntegration

**Purpose**: Integration management with external systems including ERP modules and third-party systems.

**Description**: The InventoryIntegration aggregate manages integration with other ERP modules and external systems including data synchronization, event publishing, API management, and integration error handling. It ensures data consistency across system boundaries.

**Key Responsibilities**:
- ERP module integration and event coordination
- External system API management
- Data synchronization and consistency maintenance
- Integration error handling and recovery
- Event publishing and subscription management
- Integration audit trail and monitoring

**Key Commands**: `SyncWithModule`, `PublishInventoryEvent`, `HandleIntegrationError`, `ValidateDataConsistency`

**Key Events**: `ModuleSyncCompleted`, `InventoryEventPublished`, `IntegrationErrorHandled`, `DataConsistencyValidated`

---

## Summary

The Inventory Control domain contains **14 primary aggregates** that collectively provide:

- **Item Management**: InventoryItem, InventoryType for comprehensive item master data management
- **Location Management**: Warehouse, WarehouseInventory, BinInventory for multi-location inventory tracking
- **Movement Processing**: InventoryTransfer, InventoryAdjustment, InventoryTransaction for all inventory movements
- **Count Management**: PhysicalCount, CycleCount for physical inventory and cycle counting
- **Assembly Operations**: KitManagement, KitAssembly for kit and assembly processing
- **Costing Operations**: CostingEngine, InventoryValuation for sophisticated costing and valuation
- **Pricing Management**: PricingEngine for complex pricing structures
- **Procurement Support**: PurchaseRequisition, LandedCost for purchasing integration
- **Quality Operations**: QualityControl, ComplianceManagement for quality and regulatory compliance
- **Planning Operations**: DemandForecasting, InventoryPlanning for demand planning and optimization
- **Configuration**: InventoryConfiguration, WarehouseConfiguration for system setup and parameter management
- **Integration**: InventoryIntegration for external system coordination

Each aggregate maintains strict consistency boundaries and communicates through well-defined events, ensuring data integrity while supporting the complex business requirements of enterprise inventory management. The design supports distributed processing, complete auditability, multi-costing methods, lot/serial traceability, and seamless integration with other Accountex modules including Sales Orders, Purchase Orders, Manufacturing, and General Ledger.