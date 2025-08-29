# Accountex Purchase Orders - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the Purchase Orders domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core Purchase Order Management Aggregates

### PurchaseOrder

**Purpose**: Primary aggregate managing the complete purchase order lifecycle from creation through fulfillment and closure.

**Description**: The PurchaseOrder aggregate serves as the central entity for procurement management, handling purchase order creation, vendor coordination, approval workflows, goods receipt coordination, and financial integration. It manages complex purchase order scenarios including standard orders, quotes, drop shipments, and multi-currency transactions while maintaining comprehensive audit trails throughout the procurement process.

**Key Responsibilities**:
- Purchase order creation and lifecycle management
- Vendor validation and credit limit enforcement
- Approval workflow coordination and authorization
- Multi-currency transaction handling and exchange rate management
- Line item management with pricing and discount calculations
- Receipt coordination and quantity tracking
- Integration with inventory, accounting, and vendor management

**State Structure**:
```elixir
defstruct [
  :purchase_order_id,
  :purchase_order_number,
  :vendor_id,
  :order_type, # :standard, :quote, :drop_ship, :blanket_release
  :status, # :draft, :pending_approval, :approved, :sent, :partially_received, :fully_received, :closed, :cancelled
  :order_date,
  :requested_delivery_date,
  :warehouse_code,
  :currency_code,
  :exchange_rate,
  :line_items,
  :financial_totals, # subtotal, taxes, freight, total amounts
  :approval_status,
  :receipt_status,
  :audit_trail
]
```

**Key Commands**: `CreatePurchaseOrder`, `ApprovePurchaseOrder`, `AmendPurchaseOrder`, `CancelPurchaseOrder`, `SubmitToVendor`, `ReceiveGoods`, `ClosePurchaseOrder`

**Key Events**: `PurchaseOrderCreated`, `PurchaseOrderApproved`, `PurchaseOrderAmended`, `PurchaseOrderCancelled`, `PurchaseOrderSubmitted`, `GoodsReceived`, `PurchaseOrderClosed`

---

### PurchaseOrderLineItem

**Purpose**: Individual line items within purchase orders including item specifications, quantities, pricing, and receipt tracking.

**Description**: The PurchaseOrderLineItem aggregate manages individual items within purchase orders including item validation, quantity management, pricing calculations, tax handling, and receipt tracking. It supports complex line item scenarios including vendor part numbers, specifications, multi-warehouse delivery, and partial receipt processing.

**Key Responsibilities**:
- Line item creation and validation
- Item specification and vendor part number management
- Quantity and pricing calculation
- Tax calculation and exemption handling
- Receipt quantity tracking and variance management
- GL account coding and distribution
- Integration with inventory and cost accounting

**Key Commands**: `AddLineItem`, `UpdateLineItemPricing`, `ModifyLineQuantity`, `SetLineSpecifications`, `ReceiveLineItem`, `CancelLineItem`

**Key Events**: `LineItemAdded`, `LineItemPricingUpdated`, `LineQuantityModified`, `LineSpecificationsSet`, `LineItemReceived`, `LineItemCancelled`

---

### BlanketPurchaseOrder

**Purpose**: Long-term purchase agreements allowing multiple order releases against pre-negotiated terms and pricing.

**Description**: The BlanketPurchaseOrder aggregate manages master purchase agreements that enable multiple order releases over time against locked pricing and terms. It handles quantity commitments, release tracking, expiration management, and pricing protection while coordinating with individual purchase orders created from releases.

**Key Responsibilities**:
- Blanket agreement creation and terms management
- Release quantity tracking and availability management
- Pricing protection and contract term enforcement
- Release authorization and validation
- Agreement expiration monitoring and renewal processing
- Performance tracking against commitments

**State Structure**:
```elixir
defstruct [
  :blanket_po_id,
  :blanket_po_number,
  :vendor_id,
  :agreement_start_date,
  :agreement_end_date,
  :total_commitment_amount,
  :total_commitment_quantity,
  :released_amount,
  :released_quantity,
  :remaining_commitment,
  :pricing_terms,
  :release_authorization_rules,
  :status, # :active, :expired, :fully_released, :cancelled
  :line_items,
  :release_history
]
```

**Key Commands**: `CreateBlanketPurchaseOrder`, `ReleaseBlanketPurchaseOrder`, `UpdateBlanketTerms`, `ExpireBlanketOrder`, `RenewBlanketOrder`

**Key Events**: `BlanketPurchaseOrderCreated`, `BlanketPurchaseOrderReleased`, `BlanketTermsUpdated`, `BlanketOrderExpired`, `BlanketOrderRenewed`

---

## Receipt and Fulfillment Aggregates

### ReceivedGoodsDocument

**Purpose**: Goods receipt management with quantity validation, quality control, and inventory integration.

**Description**: The ReceivedGoodsDocument aggregate handles the physical receipt of goods from vendors including receipt validation, quality inspection coordination, inventory updates, and financial accrual management. It supports partial receipts, over-receipt handling, and complex receipt scenarios with lot/serial tracking.

**Key Responsibilities**:
- Goods receipt processing and validation
- Quantity variance detection and tolerance checking
- Quality inspection coordination and hold processing
- Inventory quantity and cost updates
- Lot and serial number assignment and tracking
- Financial accrual creation and management
- Receipt cancellation and reversal processing

**State Structure**:
```elixir
defstruct [
  :receipt_id,
  :receipt_number,
  :purchase_order_id,
  :vendor_id,
  :receipt_date,
  :warehouse_code,
  :receipt_status, # :draft, :completed, :cancelled
  :received_line_items,
  :total_received_amount,
  :quality_status,
  :accrual_status,
  :cancellation_details
]
```

**Key Commands**: `ReceiveGoods`, `ValidateReceipt`, `InspectGoods`, `AccrueReceiptCosts`, `CancelReceipt`, `CompleteReceipt`

**Key Events**: `GoodsReceived`, `ReceiptValidated`, `GoodsInspected`, `ReceiptCostsAccrued`, `ReceiptCancelled`, `ReceiptCompleted`

---

### CancelledGoodsDocument

**Purpose**: Cancellation processing for previously received goods with inventory and financial impact management.

**Description**: The CancelledGoodsDocument aggregate manages the cancellation of goods receipts including validation of cancellation eligibility, inventory quantity reversal, cost adjustments, and financial accrual reversals. It maintains complete audit trails for cancelled receipts and coordinates with inventory and accounting systems.

**Key Responsibilities**:
- Receipt cancellation validation and processing
- Inventory quantity and cost reversal
- Financial accrual reversal and adjustment
- Audit trail maintenance for cancelled receipts
- Integration with inventory and accounting modules
- Cancellation reason tracking and reporting

**Key Commands**: `CancelGoodsReceipt`, `ValidateCancellation`, `ReverseInventoryImpact`, `ReverseAccruals`, `DocumentCancellation`

**Key Events**: `GoodsReceiptCancelled`, `CancellationValidated`, `InventoryImpactReversed`, `AccrualsReversed`, `CancellationDocumented`

---

## Vendor Management Aggregates

### Vendor

**Purpose**: Vendor master data management with performance tracking, compliance monitoring, and relationship coordination.

**Description**: The Vendor aggregate manages vendor master information including contact details, payment terms, banking information, compliance status, and performance metrics. It handles vendor onboarding, status management, performance evaluation, and integration with purchase order processing and payment systems.

**Key Responsibilities**:
- Vendor master data management and validation
- Payment terms and credit limit administration
- Performance tracking and scorecard generation
- Compliance monitoring and validation
- Banking information and payment method configuration
- Vendor classification and risk assessment

**Key Commands**: `CreateVendor`, `UpdateVendorInfo`, `SetPaymentTerms`, `UpdateCreditLimit`, `ClassifyVendor`, `SuspendVendor`, `EvaluatePerformance`

**Key Events**: `VendorCreated`, `VendorInfoUpdated`, `PaymentTermsSet`, `CreditLimitUpdated`, `VendorClassified`, `VendorSuspended`, `PerformanceEvaluated`

---

### VendorPerformance

**Purpose**: Comprehensive vendor performance analysis with metrics calculation and improvement coordination.

**Description**: The VendorPerformance aggregate continuously monitors and analyzes vendor performance across multiple dimensions including on-time delivery, quality metrics, pricing competitiveness, and service responsiveness. It generates performance scorecards, identifies improvement opportunities, and coordinates performance improvement initiatives.

**Key Responsibilities**:
- Performance metric calculation and tracking
- On-time delivery measurement and analysis
- Quality score compilation and trending
- Price competitiveness analysis
- Service level evaluation
- Performance improvement plan coordination

**Key Commands**: `CalculatePerformanceMetrics`, `GenerateVendorScorecard`, `IdentifyImprovementAreas`, `InitiatePerformanceReview`

**Key Events**: `PerformanceMetricsCalculated`, `VendorScorecardGenerated`, `ImprovementAreasIdentified`, `PerformanceReviewInitiated`

---

## Purchase Matching and Validation Aggregates

### ThreeWayMatch

**Purpose**: Purchase order, receipt, and invoice matching coordination with variance detection and resolution.

**Description**: The ThreeWayMatch aggregate orchestrates the three-way matching process between purchase orders, goods receipts, and vendor invoices. It validates document consistency, identifies variances, applies tolerance rules, and coordinates approval workflows for variance resolution ensuring financial accuracy and preventing unauthorized payments.

**Key Responsibilities**:
- Three-way document matching coordination
- Variance detection and tolerance checking
- Automatic approval for matches within tolerance
- Exception routing for out-of-tolerance variances
- Approval workflow coordination for variance resolution
- Match status tracking and reporting

**State Structure**:
```elixir
defstruct [
  :match_id,
  :purchase_order_id,
  :receipt_id,
  :invoice_id,
  :matching_status, # :pending, :matched, :variance_detected, :approved, :rejected
  :quantity_variance,
  :price_variance,
  :date_variance,
  :tolerance_settings,
  :approval_requirements,
  :resolution_status
]
```

**Key Commands**: `InitiateThreeWayMatch`, `ValidateDocumentMatch`, `ProcessVariance`, `ApproveVariance`, `RejectMatch`, `CompleteMatch`

**Key Events**: `ThreeWayMatchInitiated`, `DocumentMatchValidated`, `VarianceProcessed`, `VarianceApproved`, `MatchRejected`, `MatchCompleted`

---

### PurchaseOrderMatch

**Purpose**: Automated matching logic for purchase orders with configurable tolerance and exception handling.

**Description**: The PurchaseOrderMatch aggregate provides sophisticated matching services including amount-based and quantity-based matching with configurable tolerance levels. It automates routine matching while flagging exceptions for manual review and maintains complete matching audit trails.

**Key Responsibilities**:
- Automated document matching logic
- Tolerance configuration and application
- Exception identification and routing
- Match confidence scoring
- Matching rule configuration and maintenance
- Audit trail preservation for all matches

**Key Commands**: `ConfigureMatchingRules`, `ExecuteAutoMatch`, `ValidateMatchTolerance`, `ProcessMatchException`, `UpdateMatchingConfig`

**Key Events**: `MatchingRulesConfigured`, `AutoMatchExecuted`, `MatchToleranceValidated`, `MatchExceptionProcessed`, `MatchingConfigUpdated`

---

## Financial Management Aggregates

### LandedCostAccrual

**Purpose**: Landed cost calculation and allocation with comprehensive cost distribution management.

**Description**: The LandedCostAccrual aggregate manages the calculation and allocation of landed costs including freight, duties, insurance, and handling charges. It supports multiple allocation methods, handles complex cost distribution scenarios, and coordinates with inventory costing and financial accounting systems.

**Key Responsibilities**:
- Landed cost calculation and component management
- Cost allocation using multiple methods (weight, value, quantity)
- Freight and duty cost tracking
- Insurance and handling charge allocation
- Integration with inventory costing systems
- Financial accrual creation and reversal

**State Structure**:
```elixir
defstruct [
  :accrual_id,
  :receipt_id,
  :vendor_id,
  :total_landed_cost,
  :cost_components, # freight, duties, insurance, handling
  :allocation_method, # :by_weight, :by_value, :by_quantity, :manual
  :item_allocations,
  :accrual_status, # :calculated, :posted, :reversed
  :gl_postings
]
```

**Key Commands**: `CalculateLandedCost`, `AllocateCostComponents`, `PostLandedCostAccrual`, `ReverseLandedCostAccrual`, `UpdateCostAllocation`

**Key Events**: `LandedCostCalculated`, `CostComponentsAllocated`, `LandedCostAccrualPosted`, `LandedCostAccrualReversed`, `CostAllocationUpdated`

---

### PrepaymentManagement

**Purpose**: Purchase order prepayment handling with application coordination and refund processing.

**Description**: The PrepaymentManagement aggregate manages advance payments made to vendors including payment tracking, application to receipts, overpayment handling, and refund coordination. It supports various prepayment scenarios including deposits, progress payments, and full prepayments.

**Key Responsibilities**:
- Prepayment recording and tracking
- Payment application to goods receipts
- Overpayment identification and handling
- Refund processing coordination
- Prepayment balance monitoring
- Integration with accounts payable for payment processing

**Key Commands**: `RecordPrepayment`, `ApplyPrepaymentToReceipt`, `ProcessPrepaymentRefund`, `ReconcilePrepayments`

**Key Events**: `PrepaymentRecorded`, `PrepaymentAppliedToReceipt`, `PrepaymentRefundProcessed`, `PrepaymentsReconciled`

---

## Recurring and Automation Aggregates

### RecurringPurchaseOrder

**Purpose**: Template-based recurring purchase order generation with schedule management and automation.

**Description**: The RecurringPurchaseOrder aggregate manages automated recurring purchase order generation including template configuration, schedule management, automatic generation processing, and exception handling. It supports flexible scheduling patterns and handles seasonal variations and business calendar integration.

**Key Responsibilities**:
- Recurring template creation and configuration
- Schedule pattern management and calculation
- Automatic purchase order generation
- Template amendment and version control
- Generation exception handling and recovery
- Performance tracking and optimization

**State Structure**:
```elixir
defstruct [
  :recurring_po_id,
  :template_name,
  :vendor_id,
  :recurrence_pattern, # :daily, :weekly, :monthly, :quarterly, :annually
  :schedule_config,
  :next_generation_date,
  :template_line_items,
  :generation_history,
  :status, # :active, :suspended, :expired
  :exception_handling_rules
]
```

**Key Commands**: `CreateRecurringTemplate`, `GenerateRecurringPurchaseOrder`, `UpdateRecurringSchedule`, `SuspendRecurringOrder`, `ReactivateRecurringOrder`

**Key Events**: `RecurringTemplateCreated`, `RecurringPurchaseOrderGenerated`, `RecurringScheduleUpdated`, `RecurringOrderSuspended`, `RecurringOrderReactivated`

---

### ReorderPointMonitoring

**Purpose**: Automated reorder point monitoring with purchase requisition generation and economic order quantity optimization.

**Description**: The ReorderPointMonitoring aggregate continuously monitors inventory levels against reorder points and generates purchase requisitions when thresholds are reached. It optimizes order quantities using economic order quantity calculations and considers lead times, safety stock, and vendor constraints.

**Key Responsibilities**:
- Inventory level monitoring against reorder points
- Economic order quantity calculation and optimization
- Purchase requisition generation and vendor selection
- Lead time consideration and delivery scheduling
- Safety stock maintenance and adjustment
- Vendor performance integration for reorder decisions

**Key Commands**: `MonitorReorderPoints`, `GeneratePurchaseRequisition`, `CalculateEOQ`, `SelectOptimalVendor`, `OptimizeOrderQuantity`

**Key Events**: `ReorderPointReached`, `PurchaseRequisitionGenerated`, `EOQCalculated`, `OptimalVendorSelected`, `OrderQuantityOptimized`

---

## Quality and Compliance Aggregates

### QualityControl

**Purpose**: Quality inspection coordination for received goods with acceptance/rejection processing.

**Description**: The QualityControl aggregate manages quality control processes for received goods including inspection scheduling, test result recording, acceptance/rejection decisions, and nonconformance handling. It coordinates with receipt processing to ensure quality standards are met before inventory acceptance.

**Key Responsibilities**:
- Quality inspection scheduling and coordination
- Test result recording and evaluation
- Acceptance/rejection decision processing
- Nonconformance documentation and tracking
- Quality hold management and release processing
- Vendor quality performance tracking

**Key Commands**: `ScheduleInspection`, `RecordInspectionResults`, `AcceptGoods`, `RejectGoods`, `ProcessNonconformance`, `ReleaseQualityHold`

**Key Events**: `InspectionScheduled`, `InspectionResultsRecorded`, `GoodsAccepted`, `GoodsRejected`, `NonconformanceProcessed`, `QualityHoldReleased`

---

### ComplianceManagement

**Purpose**: Regulatory compliance monitoring with vendor validation and audit trail maintenance.

**Description**: The ComplianceManagement aggregate ensures purchase order operations meet regulatory requirements including vendor compliance validation, tax compliance checking, import/export regulation adherence, and audit trail maintenance for regulatory reporting.

**Key Responsibilities**:
- Vendor compliance validation and monitoring
- Tax compliance verification and reporting
- Import/export regulation compliance
- Regulatory audit trail maintenance
- Compliance violation detection and reporting
- Corrective action coordination

**Key Commands**: `ValidateVendorCompliance`, `CheckTaxCompliance`, `ValidateImportExport`, `GenerateComplianceReport`, `ProcessViolation`

**Key Events**: `VendorComplianceValidated`, `TaxComplianceChecked`, `ImportExportValidated`, `ComplianceReportGenerated`, `ViolationProcessed`

---

## Integration and Communication Aggregates

### InventoryIntegration

**Purpose**: Real-time integration with inventory management for quantity updates, cost calculations, and availability coordination.

**Description**: The InventoryIntegration aggregate manages seamless integration with inventory systems including real-time quantity updates, cost calculation coordination, availability checking, and reorder point monitoring. It ensures inventory accuracy and coordinates procurement with inventory planning.

**Key Responsibilities**:
- Real-time inventory quantity updates
- Cost calculation coordination and validation
- Availability checking and ATP calculations
- Reorder point monitoring and alerting
- Lot and serial number integration
- Inventory transaction audit trail maintenance

**Key Commands**: `UpdateInventoryQuantities`, `CalculateInventoryCosts`, `CheckAvailability`, `MonitorReorderPoints`, `IntegrateSerialLot`

**Key Events**: `InventoryQuantitiesUpdated`, `InventoryCostsCalculated`, `AvailabilityChecked`, `ReorderPointsMonitored`, `SerialLotIntegrated`

---

### APIntegration

**Purpose**: Accounts payable integration for invoice matching, payment coordination, and vendor management.

**Description**: The APIntegration aggregate manages integration with accounts payable systems including three-way matching coordination, payment processing integration, vendor information synchronization, and financial reporting coordination.

**Key Responsibilities**:
- Three-way matching data provision
- Payment processing coordination
- Vendor master data synchronization
- Invoice approval workflow integration
- Financial reporting data coordination
- Cash flow planning integration

**Key Commands**: `ProvideMatchingData`, `CoordinatePaymentProcessing`, `SyncVendorData`, `IntegrateInvoiceApproval`, `CoordinateFinancialReporting`

**Key Events**: `MatchingDataProvided`, `PaymentProcessingCoordinated`, `VendorDataSynced`, `InvoiceApprovalIntegrated`, `FinancialReportingCoordinated`

---

## Configuration and Setup Aggregates

### PurchaseOrderConfiguration

**Purpose**: Purchase order system configuration with parameter management and business rule setup.

**Description**: The PurchaseOrderConfiguration aggregate manages system-wide purchase order configuration including numbering schemes, approval matrices, tolerance settings, and integration parameters. It validates configuration changes and maintains configuration history for audit purposes.

**Key Responsibilities**:
- System parameter management and validation
- Approval workflow configuration
- Tolerance setting management
- Integration parameter configuration
- Business rule setup and maintenance
- Configuration change audit and tracking

**Key Commands**: `UpdatePOConfiguration`, `ConfigureApprovalMatrix`, `SetToleranceSettings`, `ConfigureIntegration`, `UpdateBusinessRules`

**Key Events**: `POConfigurationUpdated`, `ApprovalMatrixConfigured`, `ToleranceSettingsSet`, `IntegrationConfigured`, `BusinessRulesUpdated`

---

### NumberingConfiguration

**Purpose**: Purchase order and document numbering scheme management with sequence control.

**Description**: The NumberingConfiguration aggregate manages numbering schemes for purchase orders, receipts, and related documents including sequence generation, format configuration, and numbering validation. It ensures unique number generation and supports multiple numbering schemes for different document types.

**Key Responsibilities**:
- Document numbering scheme configuration
- Number sequence generation and tracking
- Numbering format validation and enforcement
- Multiple scheme support for different document types
- Number uniqueness validation
- Sequence reset and rollover management

**Key Commands**: `ConfigureNumberingScheme`, `GenerateNextNumber`, `ValidateNumberFormat`, `ResetNumberSequence`, `UpdateNumberingConfig`

**Key Events**: `NumberingSchemeConfigured`, `NextNumberGenerated`, `NumberFormatValidated`, `NumberSequenceReset`, `NumberingConfigUpdated`

---

## Analytics and Reporting Aggregates

### PurchaseAnalytics

**Purpose**: Purchase order analytics and reporting with spend analysis and performance metrics.

**Description**: The PurchaseAnalytics aggregate processes purchase order data to generate analytics including spend analysis, vendor performance metrics, cost trend analysis, and procurement insights. It provides business intelligence for purchasing decisions and strategic vendor management.

**Key Responsibilities**:
- Spend analysis and vendor ranking
- Cost trend identification and forecasting
- Purchase volume analysis and optimization
- Vendor performance benchmarking
- Contract compliance monitoring
- Procurement insight generation

**Key Commands**: `AnalyzePurchaseSpend`, `CalculateVendorMetrics`, `GenerateTrendAnalysis`, `BenchmarkVendorPerformance`, `GenerateProcurementInsights`

**Key Events**: `PurchaseSpendAnalyzed`, `VendorMetricsCalculated`, `TrendAnalysisGenerated`, `VendorPerformanceBenchmarked`, `ProcurementInsightsGenerated`

---

### ContractManagement

**Purpose**: Purchase contract and agreement management with terms tracking and compliance monitoring.

**Description**: The ContractManagement aggregate manages purchase contracts and agreements including contract terms, pricing agreements, volume commitments, and compliance tracking. It coordinates contract performance against actual purchases and manages contract renewal processes.

**Key Responsibilities**:
- Purchase contract creation and management
- Contract terms and pricing agreement tracking
- Volume commitment monitoring and compliance
- Contract performance analysis and reporting
- Contract renewal coordination
- Compliance violation detection and reporting

**Key Commands**: `CreatePurchaseContract`, `TrackContractPerformance`, `MonitorVolumeCommitments`, `ProcessContractRenewal`, `ValidateCompliance`

**Key Events**: `PurchaseContractCreated`, `ContractPerformanceTracked`, `VolumeCommitmentsMonitored`, `ContractRenewalProcessed`, `ComplianceValidated`

---

## Data Management and Import Aggregates

### BulkDataImport

**Purpose**: High-volume purchase order import processing with validation and error handling.

**Description**: The BulkDataImport aggregate manages bulk import operations for purchase orders, vendors, and related data including file validation, business rule checking, batch processing, and comprehensive error handling with rollback capabilities.

**Key Responsibilities**:
- Import file validation and parsing
- Business rule validation during import
- Batch processing coordination
- Error handling and invalid record management
- Import progress tracking and reporting
- Rollback and recovery processing

**State Structure**:
```elixir
defstruct [
  :import_id,
  :import_type, # :purchase_orders, :vendors, :receipts
  :file_info,
  :validation_results,
  :processing_status, # :validating, :processing, :completed, :failed
  :processed_count,
  :error_count,
  :import_results
]
```

**Key Commands**: `InitiateImport`, `ValidateImportFile`, `ProcessImportBatch`, `HandleImportError`, `CompleteImport`, `RollbackImport`

**Key Events**: `ImportInitiated`, `ImportFileValidated`, `ImportBatchProcessed`, `ImportErrorHandled`, `ImportCompleted`, `ImportRolledBack`

---

### DocumentManagement

**Purpose**: Purchase order document storage, retrieval, and lifecycle management with compliance support.

**Description**: The DocumentManagement aggregate manages purchase order document storage including purchase orders, receipts, vendor quotes, and supporting documentation. It handles document retention, version control, and compliance with document retention requirements.

**Key Responsibilities**:
- Document capture and storage
- Version control and document history
- Document retrieval and access control
- Retention policy enforcement
- Document distribution and workflow
- Compliance documentation maintenance

**Key Commands**: `StorePurchaseDocument`, `RetrieveDocument`, `VersionDocument`, `DistributeDocument`, `ArchiveDocument`, `EnforceRetention`

**Key Events**: `PurchaseDocumentStored`, `DocumentRetrieved`, `DocumentVersioned`, `DocumentDistributed`, `DocumentArchived`, `RetentionEnforced`

---

## Summary

The Purchase Orders domain contains **14 primary aggregates** that collectively provide:

- **Order Management**: PurchaseOrder, PurchaseOrderLineItem for comprehensive order processing and line item management
- **Agreement Management**: BlanketPurchaseOrder for long-term purchase agreements with release tracking
- **Receipt Processing**: ReceivedGoodsDocument, CancelledGoodsDocument for goods receipt and cancellation management
- **Vendor Operations**: Vendor, VendorPerformance for vendor lifecycle and performance tracking
- **Matching Operations**: ThreeWayMatch, PurchaseOrderMatch for document validation and variance resolution
- **Financial Operations**: LandedCostAccrual, PrepaymentManagement for cost allocation and advance payment handling
- **Automation**: RecurringPurchaseOrder, ReorderPointMonitoring for automated procurement processes
- **Quality Operations**: QualityControl, ComplianceManagement for quality assurance and regulatory compliance
- **Configuration**: PurchaseOrderConfiguration, NumberingConfiguration for system setup and parameter management
- **Analytics**: PurchaseAnalytics, ContractManagement for spend analysis and contract performance
- **Data Operations**: BulkDataImport, DocumentManagement for import processing and document lifecycle

Each aggregate maintains strict consistency boundaries and communicates through well-defined events, ensuring data integrity while supporting the complex business requirements of enterprise procurement operations. The design supports distributed processing, complete auditability, sophisticated vendor management, multi-currency transactions, quality control integration, and seamless integration with other Accountex modules including Inventory Control, Accounts Payable, Sales Orders, and General Ledger.