# Accountex Accounts Receivable - Domain Aggregates

## Overview

This document provides a comprehensive list of all aggregates in the Accounts Receivable domain. Each aggregate represents a consistency boundary for related entities in the event-sourced system, following Domain-Driven Design principles with the Commanded event sourcing framework.

## Core Customer Management Aggregates

### CustomerAccount

**Purpose**: Manages customer profile, credit limits, payment terms, and overall account status.

**Description**: The CustomerAccount aggregate serves as the central entity for customer management, handling customer profile information, credit limit management, payment terms assignment, and account status tracking. It maintains customer relationships (parent-subsidiary), territory assignments, and integrates with all customer-related operations throughout the AR system.

**Key Responsibilities**:
- Customer profile management and validation
- Credit limit enforcement and monitoring
- Payment terms assignment and calculation
- Territory and salesperson assignment
- Customer classification and status management
- Parent-subsidiary account relationship management

**Key Commands**: `CreateCustomer`, `UpdateCustomerProfile`, `SetCreditLimit`, `AssignPaymentTerms`, `ArchiveCustomer`

**Key Events**: `CustomerCreated`, `CustomerProfileUpdated`, `CreditLimitSet`, `PaymentTermsAssigned`, `CustomerArchived`

---

### CustomerAddress

**Purpose**: Handles multiple billing and shipping addresses per customer with address validation.

**Description**: The CustomerAddress aggregate manages multiple addresses per customer including billing, shipping, and mailing addresses. It supports address validation, default address management, and integration with shipping and billing processes. The aggregate maintains address history for audit purposes.

**Key Responsibilities**:
- Multiple address management per customer
- Address validation and standardization
- Default billing and shipping address designation
- Address history tracking
- Integration with billing and shipping processes

**Key Commands**: `AddCustomerAddress`, `UpdateCustomerAddress`, `SetDefaultAddress`, `ValidateAddress`

**Key Events**: `CustomerAddressAdded`, `CustomerAddressUpdated`, `DefaultAddressSet`, `AddressValidated`

---

### CustomerActivity

**Purpose**: Tracks interactions and activities with customers for relationship management.

**Description**: The CustomerActivity aggregate captures all customer interactions including phone calls, emails, meetings, and other activities. It supports activity type configuration, status tracking, and provides comprehensive customer interaction history for sales and support teams.

**Key Responsibilities**:
- Customer interaction tracking and logging
- Activity type management and categorization
- Status and follow-up management
- Relationship history maintenance
- Integration with CRM functionality

**Key Commands**: `RecordCustomerActivity`, `UpdateActivityStatus`, `ScheduleFollowUp`

**Key Events**: `CustomerActivityRecorded`, `ActivityStatusUpdated`, `FollowUpScheduled`

---

## Invoice and Billing Aggregates

### Invoice

**Purpose**: Core billing document managing invoice lifecycle from creation to payment.

**Description**: The Invoice aggregate represents the central billing entity in the AR system. It manages the complete invoice lifecycle including creation, amendments, voiding, and payment tracking. The aggregate handles multi-currency invoices, tax calculations, freight charges, and maintains comprehensive audit trails for all invoice operations.

**Key Responsibilities**:
- Invoice creation and lifecycle management
- Multi-currency support and exchange rate handling
- Tax calculation and freight charge management
- Payment tracking and application
- Void and amendment processing with audit trails
- Integration with inventory and shipping systems

**State Structure**:
```elixir
defstruct [
  :invoice_id,
  :invoice_number,
  :customer_id,
  :invoice_date,
  :due_date,
  :amounts, # Map of all financial amounts
  :foreign_amounts, # Multi-currency amounts
  :line_items,
  :payment_applications,
  :status, # :open, :paid, :void, :past_due
  :audit_trail
]
```

**Key Commands**: `CreateInvoice`, `AmendInvoice`, `VoidInvoice`, `CopyInvoice`, `GenerateInvoiceFromShipment`

**Key Events**: `InvoiceCreated`, `InvoiceAmended`, `InvoiceVoided`, `InvoiceCopied`, `InvoiceGeneratedFromShipment`

---

### InvoiceLineItem

**Purpose**: Individual line items on invoices with pricing, discounting, and tax calculations.

**Description**: The InvoiceLineItem aggregate manages individual items on invoices including quantity, pricing, discounts, and specifications. It handles inventory allocation, revenue recognition, and supports complex pricing hierarchies with customer-specific pricing, promotional pricing, and volume discounts.

**Key Responsibilities**:
- Line item pricing and discount calculation
- Inventory allocation and tracking
- Revenue recognition and categorization
- Specification and configuration management
- Tax calculation per line item

**Key Commands**: `AddInvoiceLineItem`, `UpdateLineItemPricing`, `ApplyLineDiscount`, `SetItemSpecifications`

**Key Events**: `InvoiceLineItemAdded`, `LineItemPricingUpdated`, `LineDiscountApplied`, `ItemSpecificationsSet`

---

### RecurringInvoiceTemplate

**Purpose**: Templates for automated invoice generation with scheduling and lifecycle management.

**Description**: The RecurringInvoiceTemplate aggregate manages templates for automated recurring invoice generation. It handles scheduling patterns (weekly, monthly, quarterly, etc.), template amendments, suspension and reactivation, and maintains generation history for audit and billing purposes.

**Key Responsibilities**:
- Recurring invoice template configuration
- Scheduling pattern management (cycles and dates)
- Template amendment and version control
- Generation tracking and history
- Suspension and reactivation workflow

**State Structure**:
```elixir
defstruct [
  :template_id,
  :customer_id,
  :recurring_cycle, # :weekly, :monthly, :quarterly, etc.
  :next_generation_date,
  :end_date,
  :line_items,
  :generation_count,
  :status, # :active, :suspended, :completed
  :amendment_history
]
```

**Key Commands**: `CreateRecurringInvoiceTemplate`, `AmendTemplate`, `SuspendTemplate`, `ReactivateTemplate`, `GenerateRecurringInvoice`

**Key Events**: `RecurringInvoiceTemplateCreated`, `TemplateAmended`, `TemplateSuspended`, `TemplateReactivated`, `RecurringInvoiceGenerated`

---

## Payment Management Aggregates

### Payment

**Purpose**: Customer payment records with method tracking and application management.

**Description**: The Payment aggregate manages all customer payments including cash, checks, credit cards, and electronic payments. It handles payment validation, bank deposit assignment, void processing, and maintains complete payment history. The aggregate supports multi-currency payments and exchange rate calculations.

**Key Responsibilities**:
- Payment method processing and validation
- Bank deposit assignment and tracking
- Multi-currency payment handling
- Payment application coordination
- Void processing with audit trails

**State Structure**:
```elixir
defstruct [
  :payment_id,
  :receipt_number,
  :customer_id,
  :payment_date,
  :payment_method,
  :payment_amount,
  :foreign_amount, # For multi-currency
  :applied_amount,
  :unapplied_amount,
  :bank_deposit_id,
  :status, # :open, :applied, :deposited, :void
  :application_history
]
```

**Key Commands**: `ApplyPayment`, `VoidPayment`, `ProcessElectronicPayment`, `CreatePrepayment`

**Key Events**: `PaymentApplied`, `PaymentVoided`, `ElectronicPaymentProcessed`, `PrepaymentCreated`

---

### PaymentApplication

**Purpose**: Application of payments to specific invoices with discount and adjustment handling.

**Description**: The PaymentApplication aggregate manages the application of payments to specific invoices, handling partial payments, payment discounts, adjustments, and writeoffs. It maintains the relationship between payments and invoices while supporting complex application scenarios including overpayments and underpayments.

**Key Responsibilities**:
- Payment-to-invoice application management
- Discount calculation and application
- Adjustment and writeoff processing
- Multi-currency variance calculation
- Application void processing

**Key Commands**: `ApplyPaymentToInvoice`, `ApplyDiscount`, `ProcessAdjustment`, `VoidApplication`

**Key Events**: `PaymentAppliedToInvoice`, `DiscountApplied`, `AdjustmentProcessed`, `ApplicationVoided`

---

### OpenCredit

**Purpose**: Manages unapplied payment amounts and credit balances with refund processing.

**Description**: The OpenCredit aggregate handles unapplied customer payments and credit balances. It manages credit refund processing through various methods (check, cash, credit card), maintains credit history, and ensures proper accounting treatment of customer credit balances.

**Key Responsibilities**:
- Unapplied payment amount tracking
- Credit refund processing and authorization
- Multi-method refund support (check, cash, card)
- Credit balance history maintenance
- Integration with AP for refund checks

**Key Commands**: `RefundOpenCreditByCheck`, `RefundOpenCreditByCash`, `RefundOpenCreditByCard`, `ApplyOpenCredit`

**Key Events**: `OpenCreditRefunded`, `RefundCheckQueued`, `CashRefundProcessed`, `CardRefundProcessed`, `OpenCreditApplied`

---

## Returns and Adjustments Aggregates

### SalesReturn

**Purpose**: Manages product returns and credit generation with inventory restocking.

**Description**: The SalesReturn aggregate handles all aspects of product returns including return authorization, inventory restocking, credit generation, and item tracking for serialized/lot-controlled items. It supports returns with and without original invoices and maintains complete return audit trails.

**Key Responsibilities**:
- Return authorization and validation
- Inventory restocking coordination
- Credit note generation and application
- Serialized/lot item return tracking
- Return bin assignment and management

**Key Commands**: `CreateSalesReturnWithoutInvoice`, `CreateSalesReturnWithInvoice`, `AmendSalesReturn`, `VoidSalesReturn`

**Key Events**: `SalesReturnCreated`, `SalesReturnAmended`, `SalesReturnVoided`, `InventoryRestocked`, `OpenCreditGenerated`

---

### FinanceCharge

**Purpose**: Late payment charges with configurable calculation methods and customer eligibility.

**Description**: The FinanceCharge aggregate manages finance charges for past-due customer accounts. It supports multiple calculation methods (percentage or fixed amounts), minimum balance thresholds, compound interest calculations, and customer-specific eligibility rules. The aggregate integrates with statement generation and payment processing.

**Key Responsibilities**:
- Finance charge calculation and application
- Customer eligibility determination
- Minimum balance threshold enforcement
- Compound interest calculation
- Integration with statement processing

**Key Commands**: `ApplyFinanceChargeByInvoice`, `ApplyFinanceChargeByStatement`, `AdjustFinanceCharge`

**Key Events**: `FinanceChargeApplied`, `FinanceChargeAdjusted`

---

## Banking and Deposit Aggregates

### BankDeposit

**Purpose**: Groups receipts for bank deposit with verification and reconciliation tracking.

**Description**: The BankDeposit aggregate manages the grouping of customer receipts for bank deposit processing. It handles deposit registration (from deposit slip), recording (from system selection), verification workflows, and amendment processing. The aggregate ensures deposit balance verification and supports both manual and electronic deposit processing.

**Key Responsibilities**:
- Receipt grouping for deposit processing
- Deposit registration and recording coordination
- Balance verification and out-of-balance detection
- Amendment processing with proper authorization
- Electronic payment batch processing

**State Structure**:
```elixir
defstruct [
  :deposit_id,
  :bank_account_id,
  :deposit_date,
  :registered_amount, # From deposit slip
  :recorded_amount, # From system selection
  :deposit_items,
  :verification_status,
  :balance_status, # :balanced, :out_of_balance
  :reconciliation_status
]
```

**Key Commands**: `RecordBankDeposit`, `AmendBankDeposit`, `VoidBankDeposit`, `VerifyBankDeposit`

**Key Events**: `BankDepositRecorded`, `BankDepositAmended`, `BankDepositVoided`, `BankDepositVerified`

---

## Master Data Management Aggregates

### InventoryType

**Purpose**: Defines inventory item classifications with pricing, costing, and control settings.

**Description**: The InventoryType aggregate manages inventory item type definitions including cost methods (FIFO, LIFO, Average, Specific ID), lot control settings, kit configurations, and GL account mappings. It defines default settings that apply to all items of this type and supports complex inventory management scenarios.

**Key Responsibilities**:
- Cost method definition and enforcement
- Lot control and serial number management
- Kit item configuration and prebuild requirements
- GL account mapping for inventory transactions
- Permission settings for price and description overrides

**State Structure**:
```elixir
defstruct [
  :inventory_type_id,
  :code,
  :description,
  :cost_method, # :average, :fifo, :lifo, :specific_id
  :lot_control_settings,
  :kit_settings,
  :gl_accounts,
  :override_permissions,
  :amortization_settings
]
```

**Key Commands**: `CreateInventoryType`, `UpdateInventoryType`, `ConfigureLotControl`, `SetKitSettings`

**Key Events**: `InventoryTypeCreated`, `InventoryTypeUpdated`, `LotControlConfigured`, `KitSettingsSet`

---

### RevenueCode

**Purpose**: Revenue classification and GL account mapping for sales transactions.

**Description**: The RevenueCode aggregate manages revenue classification codes with associated GL account mappings for sales revenue, returns, discounts, and cost of goods sold. It ensures proper revenue recognition and supports financial reporting requirements for different revenue streams.

**Key Responsibilities**:
- Revenue classification and categorization
- GL account mapping for revenue transactions
- Sales returns and discount account management
- Cost of goods sold account assignment
- Revenue recognition rule enforcement

**Key Commands**: `CreateRevenueCode`, `UpdateRevenueCode`, `MapGLAccounts`

**Key Events**: `RevenueCodeCreated`, `RevenueCodeUpdated`, `GLAccountsMapped`

---

### TaxCode

**Purpose**: Sales tax configuration with multi-entity support and calculation rules.

**Description**: The TaxCode aggregate manages sales tax configuration supporting up to three tax entities per code. It handles tax rate calculations, rounding methods, taxable amount limits, and provides comprehensive tax calculation services for invoicing and reporting.

**Key Responsibilities**:
- Multi-entity tax configuration (up to 3 entities per code)
- Tax rate calculation and rounding rule management
- Taxable amount thresholds and limits
- GL account mapping for tax transactions
- Tax exemption and override handling

**State Structure**:
```elixir
defstruct [
  :tax_code_id,
  :code,
  :description,
  :tax_entities, # Up to 3 tax entities
  :calculation_rules,
  :rounding_settings,
  :amount_limits,
  :gl_accounts
]
```

**Key Commands**: `CreateTaxCode`, `UpdateTaxCode`, `ConfigureTaxEntities`, `SetCalculationRules`

**Key Events**: `TaxCodeCreated`, `TaxCodeUpdated`, `TaxEntitiesConfigured`, `CalculationRulesSet`

---

### PaymentTerm

**Purpose**: Payment terms definition with discount calculation and due date logic.

**Description**: The PaymentTerm aggregate manages payment terms including discount percentages, discount periods, net payment terms, and due date calculation methods. It supports complex date table configurations for seasonal payment terms and provides calculation services for invoice due dates and discounts.

**Key Responsibilities**:
- Payment terms configuration and validation
- Discount percentage and period management
- Due date calculation logic
- Date table configuration for seasonal terms
- Integration with invoice and payment processing

**Key Commands**: `CreatePaymentTerm`, `UpdatePaymentTerm`, `ConfigureDateTable`

**Key Events**: `PaymentTermCreated`, `PaymentTermUpdated`, `DateTableConfigured`

---

### Salesperson

**Purpose**: Sales team management with territory assignment and revenue tracking.

**Description**: The Salesperson aggregate manages sales team members including contact information, territory assignments, revenue code associations, and sales performance tracking. It supports commission calculations and provides sales analytics and reporting capabilities.

**Key Responsibilities**:
- Salesperson profile and contact management
- Territory and customer assignment
- Revenue tracking and commission calculation
- Sales performance analytics
- Integration with customer and invoice management

**Key Commands**: `CreateSalesperson`, `UpdateSalesperson`, `AssignTerritory`

**Key Events**: `SalespersonCreated`, `SalespersonUpdated`, `TerritoryAssigned`

---

## Banking and Financial Aggregates

### BankAccount

**Purpose**: Bank account management with deposit processing and reconciliation support.

**Description**: The BankAccount aggregate manages bank account information including routing details, check printing configuration, deposit numbering, and reconciliation tracking. It supports electronic payment configuration and integrates with deposit processing and bank reconciliation systems.

**Key Responsibilities**:
- Bank account configuration and maintenance
- Check printing setup and numbering
- Electronic payment configuration (ACH, wire)
- Deposit numbering and tracking
- Reconciliation status management

**State Structure**:
```elixir
defstruct [
  :bank_account_id,
  :bank_number,
  :account_number,
  :routing_info,
  :check_settings,
  :deposit_settings,
  :electronic_payment_config,
  :reconciliation_info,
  :current_balance
]
```

**Key Commands**: `CreateBankAccount`, `UpdateBankAccount`, `ConfigureCheckPrinting`, `ConfigureElectronicPayments`

**Key Events**: `BankAccountCreated`, `BankAccountUpdated`, `CheckPrintingConfigured`, `ElectronicPaymentsConfigured`

---

### FreightCode

**Purpose**: Freight charge configuration with weight-based and fixed amount pricing.

**Description**: The FreightCode aggregate manages freight charge configurations including minimum charges, weight-based pricing brackets, tax treatment, and GL account mapping. It provides freight calculation services for invoice processing and supports complex freight pricing scenarios.

**Key Responsibilities**:
- Freight charge configuration and calculation
- Weight-based pricing bracket management
- Tax treatment configuration
- GL account mapping for freight revenue
- Integration with invoice processing

**Key Commands**: `CreateFreightCode`, `UpdateFreightCode`, `ConfigureWeightBrackets`

**Key Events**: `FreightCodeCreated`, `FreightCodeUpdated`, `WeightBracketsConfigured`

---

## Currency and Tax Management Aggregates

### CurrencyCode

**Purpose**: Multi-currency support with exchange rate management and gain/loss calculations.

**Description**: The CurrencyCode aggregate manages foreign currency definitions including exchange rate management, conversion methods, and gain/loss calculation rules. It supports both home-to-foreign and foreign-to-home exchange methods and maintains historical exchange rate data.

**Key Responsibilities**:
- Currency definition and symbol management
- Exchange rate management and historical tracking
- Conversion method configuration
- Exchange gain/loss calculation
- GL account mapping for currency variances

**State Structure**:
```elixir
defstruct [
  :currency_code_id,
  :currency_code,
  :symbol,
  :description,
  :exchange_method, # :home_to_foreign, :foreign_to_home
  :current_rate,
  :rate_history,
  :gl_accounts
]
```

**Key Commands**: `CreateCurrencyCode`, `UpdateExchangeRate`, `ConfigureExchangeMethod`

**Key Events**: `CurrencyCodeCreated`, `ExchangeRateUpdated`, `ExchangeMethodConfigured`

---

### TaxEntity

**Purpose**: Individual tax authority configuration with rates, limits, and calculation rules.

**Description**: The TaxEntity aggregate represents individual tax authorities with specific tax rates, calculation methods, taxable amount limits, and rounding rules. Multiple tax entities can be combined into tax codes to support complex tax scenarios with multiple jurisdictions.

**Key Responsibilities**:
- Tax authority rate management
- Calculation method and rounding rule configuration
- Taxable amount limits and thresholds
- GL account mapping for tax transactions
- Integration with multi-jurisdiction tax codes

**Key Commands**: `CreateTaxEntity`, `UpdateTaxRate`, `SetCalculationRules`, `ConfigureRounding`

**Key Events**: `TaxEntityCreated`, `TaxRateUpdated`, `CalculationRulesSet`, `RoundingConfigured`

---

## Period-End and Closing Aggregates

### AccountingPeriod

**Purpose**: Manages accounting period lifecycle and state transitions for AR operations.

**Description**: The AccountingPeriod aggregate manages the lifecycle of accounting periods specific to AR operations including opening, soft closing, hard closing, and reopening processes. It coordinates with system-wide period management while maintaining AR-specific closing requirements and validations.

**Key Responsibilities**:
- AR-specific period state management
- Period opening and closing validation
- Transaction cutoff enforcement
- Period-end process coordination
- Integration with system-wide period management

**Key Commands**: `OpenARPeriod`, `InitiatePeriodClose`, `SoftClosePeriod`, `HardClosePeriod`, `ReopenPeriod`

**Key Events**: `ARPeriodOpened`, `PeriodCloseInitiated`, `PeriodSoftClosed`, `PeriodHardClosed`, `PeriodReopened`

---

### ARClosingProcess

**Purpose**: Orchestrates the complete AR period-end closing workflow with validation and checkpoints.

**Description**: The ARClosingProcess aggregate manages the comprehensive period-end closing process including transaction validation, aging calculations, GL synchronization, and multi-currency revaluation. It maintains closing checklists, validation results, and provides rollback capabilities for failed closings.

**Key Responsibilities**:
- Period-end closing workflow orchestration
- Transaction validation and completeness checking
- Aging calculation coordination
- GL synchronization and balance reconciliation
- Multi-currency revaluation processing

**State Structure**:
```elixir
defstruct [
  :closing_process_id,
  :period_id,
  :closing_date,
  :validation_results,
  :aging_results,
  :gl_sync_status,
  :revaluation_results,
  :status, # :initiated, :validating, :calculating, :posting, :completed, :failed
  :checklist_items
]
```

**Key Commands**: `InitiatePeriodClose`, `ValidateTransactions`, `PerformAgingCalculation`, `InitiateGLSync`, `PerformRevaluation`

**Key Events**: `PeriodCloseInitiated`, `TransactionValidationCompleted`, `AgingCalculationCompleted`, `GLSyncCompleted`, `RevaluationCompleted`

---

### CurrencyRevaluation

**Purpose**: Multi-currency revaluation processing with gain/loss calculation and GL posting.

**Description**: The CurrencyRevaluation aggregate manages foreign currency revaluation processes including unrealized gain/loss calculations, GL posting for currency adjustments, and historical revaluation tracking. It supports both automatic and manual revaluation triggers.

**Key Responsibilities**:
- Currency revaluation calculation and processing
- Unrealized gain/loss determination
- GL posting for currency adjustments
- Historical revaluation tracking
- Integration with period-end closing

**Key Commands**: `InitiateCurrencyRevaluation`, `CalculateRevaluationGains`, `PostRevaluationAdjustments`

**Key Events**: `CurrencyRevaluationInitiated`, `RevaluationGainsCalculated`, `RevaluationAdjustmentsPosted`

---

## Configuration and Setup Aggregates

### ARConfiguration

**Purpose**: Global AR configuration management with parameter validation and change tracking.

**Description**: The ARConfiguration aggregate manages system-wide AR configuration including processing rules, default settings, integration parameters, and business logic configuration. It maintains configuration history and validates configuration changes for business impact.

**Key Responsibilities**:
- Global AR parameter management
- Default setting configuration
- Business rule configuration
- Integration parameter management
- Configuration change validation and history

**Key Commands**: `UpdateARConfiguration`, `SetDefaultSettings`, `ConfigureBusinessRules`, `UpdateIntegrationParameters`

**Key Events**: `ARConfigurationUpdated`, `DefaultSettingsSet`, `BusinessRulesConfigured`, `IntegrationParametersUpdated`

---

### AgingConfiguration

**Purpose**: Aging bucket definition and calculation rule management.

**Description**: The AgingConfiguration aggregate manages aging bucket definitions with non-overlapping day ranges, calculation methods, and aging report configuration. It ensures aging bucket consistency and provides aging calculation services throughout the AR system.

**Key Responsibilities**:
- Aging bucket definition and validation
- Calculation method configuration
- Non-overlapping range enforcement
- Aging report parameter management
- Historical aging configuration tracking

**Key Commands**: `DefineAgingBuckets`, `UpdateAgingCalculation`, `ConfigureAgingReports`

**Key Events**: `AgingBucketsDefined`, `AgingCalculationUpdated`, `AgingReportsConfigured`

---

## Import and Integration Aggregates

### InvoiceImport

**Purpose**: Bulk invoice import processing with validation and error handling.

**Description**: The InvoiceImport aggregate manages bulk invoice import operations including file validation, structure mapping, business rule validation, and batch processing. It maintains import history, error tracking, and provides comprehensive import status reporting.

**Key Responsibilities**:
- Import file structure validation
- Field mapping and data transformation
- Business rule validation during import
- Batch processing and progress tracking
- Error handling and invalid record management

**State Structure**:
```elixir
defstruct [
  :import_id,
  :file_path,
  :structure_id,
  :import_status, # :validating, :importing, :completed, :failed
  :total_invoices,
  :processed_count,
  :error_count,
  :validation_errors,
  :processing_results
]
```

**Key Commands**: `StartInvoiceImport`, `ValidateImportFile`, `ProcessImportBatch`, `CompleteInvoiceImport`

**Key Events**: `InvoiceImportStarted`, `ImportFileValidated`, `ImportBatchProcessed`, `InvoiceImportCompleted`

---

### GLIntegration

**Purpose**: Integration state and synchronization management with General Ledger module.

**Description**: The GLIntegration aggregate manages the integration between AR and GL modules including balance synchronization, journal entry generation, posting validation, and reconciliation processes. It maintains integration state and provides rollback capabilities for failed synchronizations.

**Key Responsibilities**:
- AR-GL balance synchronization
- Journal entry generation and validation
- Posting process coordination
- Integration state management
- Reconciliation and error handling

**Key Commands**: `InitiateGLSync`, `PostGLJournals`, `ReconcileBalances`, `ValidateGLPosting`

**Key Events**: `GLSyncInitiated`, `GLJournalsPosted`, `BalancesReconciled`, `GLPostingValidated`

---

### BalanceReconciliation

**Purpose**: Handles reconciliation between AR and GL modules with discrepancy resolution.

**Description**: The BalanceReconciliation aggregate manages reconciliation processes between AR subsidiary ledgers and GL control accounts. It identifies discrepancies, tracks resolution efforts, and maintains reconciliation history for audit and compliance purposes.

**Key Responsibilities**:
- AR-GL balance comparison and validation
- Discrepancy identification and tracking
- Reconciliation workflow management
- Resolution process coordination
- Audit trail maintenance for reconciliations

**Key Commands**: `InitiateReconciliation`, `IdentifyDiscrepancies`, `ResolveDiscrepancy`, `CompleteReconciliation`

**Key Events**: `ReconciliationInitiated`, `DiscrepanciesIdentified`, `DiscrepancyResolved`, `ReconciliationCompleted`

---

## Summary

The Accounts Receivable domain contains **18 primary aggregates** that collectively provide:

- **Customer Management**: CustomerAccount, CustomerAddress, CustomerActivity for comprehensive customer lifecycle
- **Billing Operations**: Invoice, InvoiceLineItem, RecurringInvoiceTemplate for complete billing functionality
- **Payment Processing**: Payment, PaymentApplication, OpenCredit for payment lifecycle management
- **Returns and Adjustments**: SalesReturn, FinanceCharge for return processing and late charge management
- **Banking Operations**: BankDeposit, BankAccount for deposit processing and bank management
- **Master Data**: InventoryType, RevenueCode, TaxCode, PaymentTerm, Salesperson, FreightCode for foundational data management
- **Currency Support**: CurrencyCode, TaxEntity for multi-currency and tax management
- **Period Operations**: AccountingPeriod, ARClosingProcess, CurrencyRevaluation for period-end processing
- **Configuration**: ARConfiguration, AgingConfiguration for system setup and parameter management
- **Integration**: InvoiceImport, GLIntegration, BalanceReconciliation for data import and module integration

Each aggregate maintains strict consistency boundaries and communicates through well-defined events, ensuring data integrity while supporting the complex business requirements of enterprise accounts receivable operations. The design supports distributed processing, complete auditability, and seamless integration with other Accountex modules.