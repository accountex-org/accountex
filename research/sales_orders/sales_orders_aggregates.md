# Accountex Sales Orders - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the Sales Orders domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core Order Management Aggregates

### Order

**Purpose**: Primary aggregate representing a customer purchase request managing the complete order lifecycle.

**Description**: The Order aggregate serves as the central entity for sales order management, handling order creation, approval workflows, inventory allocation, fulfillment coordination, and billing integration. It manages order state transitions from draft through completion while maintaining comprehensive audit trails and supporting various order types (standard, blanket releases, recurring).

**Key Responsibilities**:
- Order creation and lifecycle management
- Customer credit validation and hold processing
- Pricing calculation and discount application
- Inventory allocation coordination
- Approval workflow management
- Fulfillment process coordination
- Multi-currency support and exchange rate handling

**State Structure**:
```elixir
defstruct [
  :order_id,
  :order_number,
  :customer_id,
  :order_type, # :standard, :blanket, :recurring, :drop_ship
  :status, # :draft, :pending, :approved, :pick_released, :shipped, :invoiced, :closed, :cancelled
  :currency_code,
  :exchange_rate,
  :payment_terms,
  :ship_to_address,
  :bill_to_address,
  :line_items,
  :total_amount,
  :credit_status,
  :fulfillment_status
]
```

**Key Commands**: `CreateOrder`, `ApproveOrder`, `AllocateInventory`, `ShipOrder`, `CancelOrder`

**Key Events**: `OrderCreated`, `OrderApproved`, `InventoryAllocated`, `OrderShipped`, `OrderInvoiced`, `OrderCancelled`

---

### OrderLine

**Purpose**: Individual products or services within an order including quantity, pricing, and fulfillment details.

**Description**: The OrderLine aggregate manages individual line items within sales orders including item specifications, quantity management, pricing calculations, inventory allocation, and fulfillment tracking. It supports kit items, configurable products, and complex pricing scenarios with multiple discount types.

**Key Responsibilities**:
- Line item pricing and discount calculation
- Kit component explosion and management
- Inventory allocation and availability tracking
- Specification and configuration management
- Tax calculation per line item
- Fulfillment status tracking

**Key Commands**: `AddOrderLine`, `UpdateLineItemPricing`, `AllocateLineInventory`, `ShipLineItem`, `CancelLineItem`

**Key Events**: `OrderLineAdded`, `LineItemPricingUpdated`, `LineInventoryAllocated`, `LineItemShipped`, `LineItemCancelled`

---

## Quote Management Aggregates

### Quote

**Purpose**: Pre-order document with proposed pricing and terms requiring customer acceptance.

**Description**: The Quote aggregate manages sales quotations including pricing proposals, terms negotiation, approval workflows, and conversion to orders. It handles quote versioning, expiration management, and maintains quote history for customer relationship management.

**Key Responsibilities**:
- Quote creation and pricing proposal management
- Terms negotiation and approval workflow
- Quote versioning and revision tracking
- Expiration management and renewal processing
- Quote-to-order conversion coordination
- Customer acceptance tracking

**State Structure**:
```elixir
defstruct [
  :quote_id,
  :quote_number,
  :customer_id,
  :status, # :draft, :pending_approval, :approved, :presented, :accepted, :rejected, :expired
  :revision_number,
  :quote_date,
  :expiration_date,
  :proposed_terms,
  :pricing_details,
  :approval_status,
  :conversion_status
]
```

**Key Commands**: `CreateQuote`, `ReviseQuote`, `ApproveQuote`, `PresentQuote`, `ConvertToOrder`

**Key Events**: `QuoteCreated`, `QuoteRevised`, `QuoteApproved`, `QuotePresented`, `QuoteAccepted`, `QuoteConverted`

---

### QuoteApproval

**Purpose**: Manages quote approval routing and processing with escalation and delegation support.

**Description**: The QuoteApproval aggregate orchestrates quote approval processes based on approval matrices, delegation rules, and escalation policies. It handles complex approval scenarios including pricing approvals, discount authorizations, and credit term approvals.

**Key Responsibilities**:
- Quote approval routing and workflow management
- Pricing approval validation and authorization
- Discount approval processing
- Credit term approval coordination
- Escalation management for approval timeouts
- Delegation authority validation

**State Structure**:
```elixir
defstruct [
  :quote_id,
  :approval_workflow_id,
  :required_approvals, # Map of approval types to required approvers
  :received_approvals,
  :approval_status,
  :escalation_history,
  :pricing_approvals, # Special handling for pricing overrides
  :credit_approvals
]
```

**Key Commands**: `InitiateQuoteApproval`, `SubmitApproval`, `EscalateQuoteApproval`, `DelegateApproval`

**Key Events**: `QuoteApprovalInitiated`, `QuoteApprovalSubmitted`, `QuoteApprovalEscalated`, `QuoteApprovalDelegated`

---

## Fulfillment and Shipping Aggregates

### Shipment

**Purpose**: Manages physical shipment processing from warehouse release through delivery confirmation.

**Description**: The Shipment aggregate handles the physical fulfillment of orders including picking coordination, packing optimization, carrier integration, tracking management, and delivery confirmation. It supports partial shipments, over-shipments, and complex shipping scenarios with multiple warehouses.

**Key Responsibilities**:
- Warehouse release and picking coordination
- Packing optimization and cartonization
- Carrier selection and rate calculation
- Tracking number assignment and monitoring
- Delivery confirmation processing
- Partial shipment and backorder management

**State Structure**:
```elixir
defstruct [
  :shipment_id,
  :order_id,
  :status, # :pending, :picking, :packing, :shipped, :delivered
  :warehouse_id,
  :shipment_lines,
  :tracking_info,
  :carrier_details,
  :actual_vs_planned_quantities,
  :delivery_confirmation
]
```

**Key Commands**: `CreateShipment`, `CompletePicking`, `ConfirmShipment`, `UpdateTrackingInfo`, `ConfirmDelivery`

**Key Events**: `ShipmentCreated`, `PickingCompleted`, `ShipmentConfirmed`, `TrackingInfoUpdated`, `DeliveryConfirmed`

---

### ShipmentAcceptance

**Purpose**: Customer acceptance processing for shipped items with quality validation and returns handling.

**Description**: The ShipmentAcceptance aggregate manages customer acceptance of shipped items including acceptance confirmation, quality validation, returns processing, and acceptance documentation. It handles acceptance tracking for compliance and warranty purposes.

**Key Responsibilities**:
- Customer acceptance confirmation processing
- Quality validation and inspection results
- Returns processing and authorization
- Acceptance documentation and audit trails
- Warranty and compliance tracking

**Key Commands**: `ProcessAcceptance`, `ConfirmQuality`, `InitiateReturn`, `DocumentAcceptance`

**Key Events**: `AcceptanceProcessed`, `QualityConfirmed`, `ReturnInitiated`, `AcceptanceDocumented`

---

## Advanced Order Types Aggregates

### BlanketOrder

**Purpose**: Master agreement for multiple order releases with pricing and terms locked for a period.

**Description**: The BlanketOrder aggregate manages master purchase agreements that allow customers to release orders against pre-negotiated terms and pricing. It handles quantity commitments, release scheduling, pricing protection, and agreement lifecycle management.

**Key Responsibilities**:
- Blanket agreement creation and terms management
- Release order generation and tracking
- Quantity commitment monitoring
- Pricing protection and escalation clauses
- Agreement renewal and amendment processing
- Release authorization and validation

**State Structure**:
```elixir
defstruct [
  :blanket_order_id,
  :customer_id,
  :agreement_number,
  :start_date,
  :end_date,
  :total_commitment,
  :released_amount,
  :pricing_terms,
  :release_schedule,
  :status # :active, :suspended, :expired, :completed
]
```

**Key Commands**: `CreateBlanketOrder`, `ReleaseAgainstBlanket`, `AmendBlanketTerms`, `RenewBlanketOrder`

**Key Events**: `BlanketOrderCreated`, `OrderReleasedFromBlanket`, `BlanketTermsAmended`, `BlanketOrderRenewed`

---

### RecurringOrder

**Purpose**: Automated order generation based on predefined schedules and customer requirements.

**Description**: The RecurringOrder aggregate manages automated recurring order generation including schedule management, order template maintenance, automatic generation processing, and customer notification. It supports flexible scheduling patterns and handles generation exceptions.

**Key Responsibilities**:
- Recurring order template management
- Schedule configuration and pattern management
- Automatic order generation processing
- Template amendment and version control
- Generation exception handling
- Customer notification coordination

**State Structure**:
```elixir
defstruct [
  :recurring_order_id,
  :customer_id,
  :template_details,
  :schedule_pattern, # :weekly, :monthly, :quarterly, etc.
  :next_generation_date,
  :end_date,
  :generation_history,
  :status, # :active, :suspended, :completed
  :amendment_history
]
```

**Key Commands**: `CreateRecurringOrder`, `GenerateRecurringOrder`, `SuspendRecurring`, `ModifySchedule`

**Key Events**: `RecurringOrderCreated`, `RecurringOrderGenerated`, `RecurringSuspended`, `ScheduleModified`

---

## Billing and Financial Aggregates

### AdvancedBilling

**Purpose**: Manages advanced billing scenarios including milestone billing, progress billing, and contract billing.

**Description**: The AdvancedBilling aggregate handles complex billing scenarios beyond standard shipment-based billing including milestone billing for projects, progress billing based on completion percentages, and contract-based billing with revenue recognition. It integrates with accounting for proper revenue recognition.

**Key Responsibilities**:
- Milestone billing configuration and processing
- Progress billing calculation and validation
- Contract billing schedule management
- Revenue recognition coordination
- Billing document generation
- Payment tracking and application

**State Structure**:
```elixir
defstruct [
  :advance_bill_id,
  :order_id,
  :billing_type, # :milestone, :progress, :contract
  :billing_schedule,
  :completed_milestones,
  :billed_amount,
  :revenue_recognized,
  :status # :active, :completed, :suspended
]
```

**Key Commands**: `CreateAdvancedBilling`, `ProcessMilestone`, `CalculateProgress`, `GenerateBill`

**Key Events**: `AdvancedBillingCreated`, `MilestoneProcessed`, `ProgressCalculated`, `BillGenerated`

---

## Cancellation and Returns Aggregates

### OrderCancellation

**Purpose**: Manages order cancellation processing with impact analysis and compensation handling.

**Description**: The OrderCancellation aggregate handles order cancellation requests including cancellation authorization, impact analysis on inventory and fulfillment, compensation processing, and cancellation audit trails. It supports partial cancellations and handles complex cancellation scenarios.

**Key Responsibilities**:
- Cancellation request processing and authorization
- Impact analysis on inventory, fulfillment, and billing
- Compensation calculation and processing
- Partial cancellation handling
- Restocking coordination
- Customer notification and documentation

**State Structure**:
```elixir
defstruct [
  :order_id,
  :cancellation_id,
  :cancellation_reason,
  :cancelled_items,
  :impact_analysis,
  :compensation_required,
  :status, # :requested, :approved, :processing, :completed
  :restocking_status
]
```

**Key Commands**: `RequestCancellation`, `ApproveCancellation`, `ProcessCancellation`, `CompleteCompensation`

**Key Events**: `CancellationRequested`, `CancellationApproved`, `CancellationProcessed`, `CompensationCompleted`

---

## Import and Integration Aggregates

### ImportBatch

**Purpose**: Manages bulk order import operations with validation and error handling.

**Description**: The ImportBatch aggregate handles bulk import of sales orders from external systems including file validation, data transformation, business rule validation, and batch processing. It maintains import history, error tracking, and provides comprehensive import status reporting.

**Key Responsibilities**:
- Import file validation and parsing
- Data transformation and business rule validation
- Batch processing coordination
- Error handling and invalid record management
- Import progress tracking and reporting
- Rollback and recovery processing

**State Structure**:
```elixir
defstruct [
  :batch_id,
  :import_type, # :orders, :quotes, :blanket_orders
  :file_info,
  :validation_results,
  :processing_status, # :validating, :processing, :completed, :failed
  :processed_count,
  :error_count,
  :import_results
]
```

**Key Commands**: `InitiateImport`, `ValidateImportFile`, `ProcessImportBatch`, `CompleteImport`, `RollbackImport`

**Key Events**: `ImportInitiated`, `ImportFileValidated`, `ImportBatchProcessed`, `ImportCompleted`, `ImportRolledBack`

---

## Master Data Management Aggregates

### Salesperson

**Purpose**: Sales team management with territory assignment and commission tracking.

**Description**: The Salesperson aggregate manages sales team member information including territory assignments, commission structures, performance tracking, and customer relationship management. It supports commission calculations and provides sales analytics and reporting capabilities.

**Key Responsibilities**:
- Salesperson profile and territory management
- Commission structure configuration and calculation
- Performance tracking and analytics
- Customer assignment and relationship management
- Quota management and tracking
- Sales reporting and analysis

**State Structure**:
```elixir
defstruct [
  :salesperson_id,
  :employee_id,
  :territory_assignments,
  :commission_structure,
  :performance_metrics,
  :customer_assignments,
  :quota_targets,
  :status # :active, :inactive, :on_leave
]
```

**Key Commands**: `CreateSalesperson`, `AssignTerritory`, `UpdateCommissionStructure`, `SetQuotas`

**Key Events**: `SalespersonCreated`, `TerritoryAssigned`, `CommissionStructureUpdated`, `QuotasSet`

---

### CustomerProductCatalog

**Purpose**: Customer-specific product catalogs with pricing and availability management.

**Description**: The CustomerProductCatalog aggregate manages customer-specific product catalogs including approved products, customer-specific pricing, product restrictions, and ordering preferences. It supports complex B2B scenarios with negotiated pricing and restricted product access.

**Key Responsibilities**:
- Customer-specific product catalog management
- Negotiated pricing maintenance
- Product access restriction enforcement
- Ordering preference configuration
- Catalog versioning and updates
- Integration with master product catalog

**Key Commands**: `CreateCustomerCatalog`, `UpdateCustomerPricing`, `RestrictProducts`, `UpdatePreferences`

**Key Events**: `CustomerCatalogCreated`, `CustomerPricingUpdated`, `ProductsRestricted`, `PreferencesUpdated`

---

### PricingRuleEngine

**Purpose**: Complex pricing rule management with hierarchy and calculation logic.

**Description**: The PricingRuleEngine aggregate manages sophisticated pricing rules including customer-specific pricing, volume discounts, promotional pricing, and complex pricing hierarchies. It provides pricing calculation services and maintains pricing audit trails for compliance purposes.

**Key Responsibilities**:
- Pricing rule configuration and hierarchy management
- Volume discount calculation and tier management
- Promotional pricing campaign management
- Customer-specific pricing maintenance
- Pricing calculation service provision
- Pricing audit trail and compliance tracking

**State Structure**:
```elixir
defstruct [
  :pricing_rule_id,
  :rule_hierarchy,
  :volume_tiers,
  :promotional_campaigns,
  :customer_pricing_agreements,
  :effective_dates,
  :calculation_logic,
  :audit_trail
]
```

**Key Commands**: `CreatePricingRule`, `UpdateVolumeDiscounts`, `ConfigurePromotions`, `SetCustomerPricing`

**Key Events**: `PricingRuleCreated`, `VolumeDiscountsUpdated`, `PromotionsConfigured`, `CustomerPricingSet`

---

## Payment and Credit Management Aggregates

### PaymentProcessor

**Purpose**: Order payment processing with method validation and authorization.

**Description**: The PaymentProcessor aggregate manages order payment processing including payment method validation, authorization processing, payment confirmation, and refund handling. It supports multiple payment methods and integrates with external payment gateways for secure payment processing.

**Key Responsibilities**:
- Payment method validation and processing
- Authorization and capture coordination
- Payment confirmation and settlement
- Refund and chargeback processing
- Fraud detection and prevention
- Payment audit trail maintenance

**State Structure**:
```elixir
defstruct [
  :payment_id,
  :order_id,
  :payment_method,
  :authorization_details,
  :payment_status, # :pending, :authorized, :captured, :settled, :failed, :refunded
  :transaction_reference,
  :gateway_response,
  :fraud_check_results
]
```

**Key Commands**: `ProcessPayment`, `AuthorizePayment`, `CapturePayment`, `ProcessRefund`

**Key Events**: `PaymentProcessed`, `PaymentAuthorized`, `PaymentCaptured`, `RefundProcessed`

---

### CreditManagement

**Purpose**: Customer credit evaluation and limit management with hold processing.

**Description**: The CreditManagement aggregate manages customer credit limits, credit holds, payment term validation, and credit risk assessment. It provides real-time credit checking services and maintains credit history for risk management purposes.

**Key Responsibilities**:
- Credit limit management and monitoring
- Real-time credit checking and validation
- Credit hold processing and release authorization
- Payment term validation and enforcement
- Credit risk assessment and scoring
- Credit history maintenance and reporting

**Key Commands**: `SetCreditLimit`, `ProcessCreditHold`, `ReleaseCreditHold`, `UpdateCreditTerms`

**Key Events**: `CreditLimitSet`, `CreditHoldProcessed`, `CreditHoldReleased`, `CreditTermsUpdated`

---

## Inventory Integration Aggregates

### InventoryAllocation

**Purpose**: Inventory reservation and allocation management with multi-warehouse support.

**Description**: The InventoryAllocation aggregate manages inventory allocation for sales orders including ATP calculations, multi-warehouse allocation, backorder processing, and allocation optimization. It coordinates with inventory management for real-time availability and supports complex allocation scenarios.

**Key Responsibilities**:
- Available-to-Promise (ATP) calculation
- Multi-warehouse allocation optimization
- Soft and hard reservation management
- Backorder processing and notification
- Allocation expiration and cleanup
- Substitution processing and approval

**State Structure**:
```elixir
defstruct [
  :allocation_id,
  :order_id,
  :allocated_items, # Map of line items to warehouse allocations
  :allocation_type, # :soft_reservation, :hard_allocation
  :allocation_expiry,
  :backorder_items,
  :substitutions,
  :allocation_status
]
```

**Key Commands**: `AllocateInventory`, `ConfirmAllocation`, `ProcessBackorder`, `HandleSubstitution`

**Key Events**: `InventoryAllocated`, `AllocationConfirmed`, `BackorderProcessed`, `SubstitutionHandled`

---

### KitManagement

**Purpose**: Kit item configuration and component explosion with build coordination.

**Description**: The KitManagement aggregate handles kit item processing including component explosion, availability checking for all components, kit building coordination, and component substitution management. It supports both standard and configurable kits with complex component relationships.

**Key Responsibilities**:
- Kit component explosion and validation
- Component availability checking
- Kit build coordination and scheduling
- Component substitution management
- Configurable kit option processing
- Kit inventory tracking and management

**Key Commands**: `ExplodeKitComponents`, `BuildKit`, `ValidateComponents`, `ProcessSubstitution`

**Key Events**: `KitComponentsExploded`, `KitBuilt`, `ComponentsValidated`, `SubstitutionProcessed`

---

## Configuration and Setup Aggregates

### SalesConfiguration

**Purpose**: Sales order system configuration with parameter management and business rule setup.

**Description**: The SalesConfiguration aggregate manages sales order system configuration including order numbering schemes, approval matrices, pricing rules, tax settings, and integration parameters. It validates configuration changes and maintains configuration history.

**Key Responsibilities**:
- Order numbering scheme configuration
- Approval matrix setup and maintenance
- Tax calculation rule configuration
- Integration parameter management
- Business rule configuration
- System parameter validation

**Key Commands**: `ConfigureOrderNumbering`, `SetupApprovalMatrix`, `ConfigureTaxRules`, `UpdateIntegrationSettings`

**Key Events**: `OrderNumberingConfigured`, `ApprovalMatrixSetup`, `TaxRulesConfigured`, `IntegrationSettingsUpdated`

---

### TerritoryManagement

**Purpose**: Sales territory definition and assignment with hierarchy management.

**Description**: The TerritoryManagement aggregate manages sales territory definitions including geographic boundaries, customer assignments, salesperson allocations, and territory performance tracking. It supports hierarchical territory structures and territory rebalancing.

**Key Responsibilities**:
- Territory boundary definition and management
- Customer territory assignment
- Salesperson territory allocation
- Territory hierarchy management
- Performance tracking by territory
- Territory rebalancing coordination

**Key Commands**: `DefineTerritory`, `AssignCustomers`, `AllocateSalesperson`, `RebalanceTerritories`

**Key Events**: `TerritoryDefined`, `CustomersAssigned`, `SalespersonAllocated`, `TerritoriesRebalanced`

---

## Analytics and Reporting Aggregates

### SalesAnalytics

**Purpose**: Sales performance analysis and reporting with trend identification and forecasting.

**Description**: The SalesAnalytics aggregate processes sales data to generate performance analytics including sales trends, customer analysis, product performance, and sales forecasting. It provides business intelligence for sales management and strategic planning.

**Key Responsibilities**:
- Sales performance calculation and analysis
- Customer behavior analysis and segmentation
- Product performance tracking and optimization
- Sales forecasting and trend analysis
- Territory and salesperson performance metrics
- Business intelligence report generation

**Key Commands**: `CalculateSalesMetrics`, `AnalyzeCustomerBehavior`, `GenerateForecast`, `CreateAnalyticsReport`

**Key Events**: `SalesMetricsCalculated`, `CustomerBehaviorAnalyzed`, `ForecastGenerated`, `AnalyticsReportCreated`

---

### OrderFulfillmentAnalytics

**Purpose**: Fulfillment performance analysis with cycle time tracking and optimization recommendations.

**Description**: The OrderFulfillmentAnalytics aggregate analyzes order fulfillment performance including cycle times, fulfillment accuracy, shipping performance, and customer satisfaction metrics. It provides operational insights for process optimization and performance improvement.

**Key Responsibilities**:
- Order cycle time analysis and tracking
- Fulfillment accuracy measurement
- Shipping performance monitoring
- Customer satisfaction tracking
- Process optimization recommendations
- Operational performance reporting

**Key Commands**: `AnalyzeFulfillmentPerformance`, `TrackCycleTimes`, `MeasureAccuracy`, `GenerateOptimizationReport`

**Key Events**: `FulfillmentPerformanceAnalyzed`, `CycleTimesTracked`, `AccuracyMeasured`, `OptimizationReportGenerated`

---

## Integration and Communication Aggregates

### CustomerIntegration

**Purpose**: Integration with customer systems for order automation and status communication.

**Description**: The CustomerIntegration aggregate manages integration with customer systems including EDI processing, API integrations, automated order import, and status synchronization. It handles communication protocols and maintains integration audit trails.

**Key Responsibilities**:
- EDI transaction processing and validation
- Customer system API integration
- Automated order import and processing
- Status synchronization and notification
- Integration error handling and recovery
- Communication audit trail maintenance

**Key Commands**: `ProcessEDIOrder`, `SyncOrderStatus`, `HandleIntegrationError`, `ValidateCustomerData`

**Key Events**: `EDIOrderProcessed`, `OrderStatusSynced`, `IntegrationErrorHandled`, `CustomerDataValidated`

---

### WarehouseIntegration

**Purpose**: Integration with warehouse management systems for fulfillment coordination.

**Description**: The WarehouseIntegration aggregate manages integration with warehouse management systems including pick list generation, shipment coordination, inventory updates, and fulfillment status synchronization. It handles multiple warehouse coordination and cross-docking scenarios.

**Key Responsibilities**:
- WMS integration and communication
- Pick list generation and transmission
- Shipment coordination and tracking
- Inventory status synchronization
- Cross-dock processing coordination
- Fulfillment exception handling

**Key Commands**: `GeneratePickList`, `CoordinateShipment`, `SyncInventoryStatus`, `ProcessCrossDock`

**Key Events**: `PickListGenerated`, `ShipmentCoordinated`, `InventoryStatusSynced`, `CrossDockProcessed`

---

## Summary

The Sales Orders domain contains **16 primary aggregates** that collectively provide:

- **Order Management**: Order, OrderLine for core order processing and line item management
- **Quote Management**: Quote, QuoteApproval for quotation and approval processing
- **Fulfillment**: Shipment, ShipmentAcceptance, InventoryAllocation, KitManagement for complete fulfillment operations
- **Advanced Orders**: BlanketOrder, RecurringOrder for complex order types
- **Billing**: AdvancedBilling for sophisticated billing scenarios
- **Cancellations**: OrderCancellation for cancellation processing
- **Import**: ImportBatch for bulk data operations
- **Master Data**: Salesperson, CustomerProductCatalog, PricingRuleEngine for foundational data management
- **Financial**: PaymentProcessor, CreditManagement for payment and credit operations
- **Configuration**: SalesConfiguration, TerritoryManagement for system setup
- **Analytics**: SalesAnalytics, OrderFulfillmentAnalytics for performance analysis
- **Integration**: CustomerIntegration, WarehouseIntegration for external system coordination

Each aggregate maintains strict consistency boundaries and communicates through well-defined events, ensuring data integrity while supporting the complex business requirements of enterprise sales order management. The design supports distributed processing, complete auditability, and seamless integration with other Accountex modules including Accounts Receivable, Inventory Management, General Ledger, and Warehouse Management.