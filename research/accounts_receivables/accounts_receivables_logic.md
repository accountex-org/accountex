# Accountex Accounts Receivables Business Logic Design

## Overview

The Accounts Receivables (AR) application is a pluggable module in the Accountex system that manages customer billing, collections, and credit management. It operates as an event-sourced application using Commanded and AshCommanded, communicating with other modules through events.

## Core Domain Concepts

### 1. Customer Account Management

#### Aggregates
- **CustomerAccount**: Manages customer profile, credit limits, and payment terms
- **CustomerAddress**: Handles multiple billing/shipping addresses per customer
- **CustomerActivity**: Tracks interactions and activities with customers

#### Commands
- `CreateCustomer`
- `UpdateCustomerProfile`
- `SetCreditLimit`
- `AssignPaymentTerms`
- `AddCustomerAddress`
- `RecordCustomerActivity`
- `ArchiveCustomer`

#### Events
- `CustomerCreated`
- `CustomerProfileUpdated`
- `CreditLimitSet`
- `PaymentTermsAssigned`
- `CustomerAddressAdded`
- `CustomerActivityRecorded`
- `CustomerArchived`

#### Business Rules
- Credit limit validation against outstanding balances and open orders
- Customer classification for pricing and discount tiers
- Territory and salesperson assignment rules
- Parent-subsidiary account relationships

### 2. Invoice Management

#### Aggregates
- **Invoice**: Core billing document
- **InvoiceLineItem**: Individual items on invoices
- **RecurringInvoiceTemplate**: Templates for automated invoice generation

#### Commands
- `CreateInvoice`
- `AmendInvoice`
- `VoidInvoice`
- `CopyInvoice`
- `GenerateInvoiceFromShipment`
- `CreateRecurringInvoiceTemplate`
- `GenerateRecurringInvoice`

#### Events
- `InvoiceCreated`
- `InvoiceAmended`
- `InvoiceVoided`
- `InvoiceCopied`
- `InvoiceGeneratedFromShipment`
- `RecurringInvoiceTemplateCreated`
- `RecurringInvoiceGenerated`

#### Business Rules
- Invoice numbering (system-generated or manual)
- Tax calculation based on shipping address
- Freight charge calculation by weight or fixed amount
- Discount application hierarchy
- Multi-warehouse support
- Inventory allocation and depletion
- Serialized/lot-controlled item tracking

### 3. Sales Returns Processing

#### Aggregates
- **SalesReturn**: Manages product returns and credit generation

#### Commands
- `CreateSalesReturnWithoutInvoice`
- `CreateSalesReturnWithInvoice`
- `AmendSalesReturn`
- `VoidSalesReturn`

#### Events
- `SalesReturnCreated`
- `SalesReturnAmended`
- `SalesReturnVoided`
- `InventoryRestocked`
- `OpenCreditGenerated`

#### Business Rules
- Return authorization validation
- Serialized/lot/kit item return tracking
- Inventory restocking rules
- Credit note generation
- Return bin assignment

### 4. Payment Processing

#### Aggregates
- **Payment**: Customer payment records
- **PaymentApplication**: Application of payments to invoices
- **OpenCredit**: Unapplied payment amounts

#### Commands
- `ApplyPayment`
- `ApplyOpenCredit`
- `PostPrepayment`
- `PostNonCustomerPayment`
- `VoidPayment`
- `VoidAppliedCredit`
- `ProcessElectronicPayment`

#### Events
- `PaymentApplied`
- `OpenCreditApplied`
- `PrepaymentPosted`
- `NonCustomerPaymentPosted`
- `PaymentVoided`
- `AppliedCreditVoided`
- `ElectronicPaymentProcessed`

#### Business Rules
- Payment method validation (cash, check, credit card, electronic)
- Auto-application logic based on invoice age
- Prompt payment discount calculation
- Payment to finance charge priority
- Multi-currency exchange rate handling
- Average payment days calculation

### 5. Finance Charges
n
#### Aggregates
- **FinanceCharge**: Late payment charges

#### Commands
- `ApplyFinanceChargeByInvoice`
- `ApplyFinanceChargeByStatement`
- `AdjustFinanceCharge`

#### Events
- `FinanceChargeApplied`
- `FinanceChargeAdjusted`

#### Business Rules
- Charge calculation methods (percentage or fixed)
- Minimum balance thresholds
- Charge period restrictions
- Compound interest on outstanding charges
- Customer and pay code eligibility

### 6. Credit Management

#### Aggregates
- **OpenCreditRefund**: Refund processing for credit balances

#### Commands
- `RefundOpenCreditByCheck`
- `RefundOpenCreditByCash`
- `RefundOpenCreditByCard`

#### Events
- `OpenCreditRefunded`
- `RefundCheckQueued`
- `CashRefundProcessed`
- `CardRefundProcessed`

#### Business Rules
- Refund authorization
- AP integration for check refunds
- Negative receipt generation

### 7. Bank Deposit Management

#### Aggregates
- **BankDeposit**: Groups receipts for deposit

#### Commands
- `RecordBankDeposit`
- `AmendBankDeposit`
- `VoidBankDeposit`
- `VerifyBankDeposit`

#### Events
- `BankDepositRecorded`
- `BankDepositAmended`
- `BankDepositVoided`
- `BankDepositVerified`

#### Business Rules
- Receipt grouping by bank and date
- Deposit slip generation
- Bank reconciliation markers

## Integration Points

### With Sales Order Module
- **Inbound Events**:
  - `ShipmentCompleted` → Trigger invoice generation
  - `SalesOrderCreated` → Update customer open orders
  - `SalesOrderCancelled` → Adjust credit availability

- **Outbound Events**:
  - `InvoiceGenerated` → Update SO fulfillment status
  - `CreditLimitExceeded` → Notify SO for order holds

### With Inventory Control Module
- **Inbound Events**:
  - `InventoryAvailable` → Enable invoice line items
  - `ItemPriceUpdated` → Reflect in pending invoices

- **Outbound Events**:
  - `InventoryConsumed` → Decrease on-hand quantities
  - `InventoryRestocked` → Process returns
  - `SerialNumbersAllocated` → Track serialized items

### With General Ledger Module
- **Outbound Events**:
  - `RevenueRecognized` → Post sales entries
  - `ReceivableCreated` → Update AR balance
  - `BadDebtWrittenOff` → Adjust expense accounts
  - `DiscountGranted` → Post discount entries
  - `TaxCollected` → Update tax liability

### With Accounts Payable Module
- **Outbound Events**:
  - `RefundCheckRequested` → Create AP invoice for refund

### With Bank Reconciliation Module
- **Outbound Events**:
  - `DepositRecorded` → Update bank balance
  - `ElectronicPaymentProcessed` → Record ACH transactions

## Process Workflows

### Invoice Creation Workflow
1. Validate customer credit status
2. Check inventory availability
3. Calculate pricing based on hierarchy:
   - Customer-specific pricing
   - Price code pricing
   - Special/promotional pricing
   - Standard pricing
4. Apply discounts
5. Calculate taxes
6. Generate invoice number
7. Emit `InvoiceCreated` event
8. Update customer balances
9. Decrease inventory

### Payment Application Workflow
1. Validate payment method
2. Record receipt
3. Apply to invoices (oldest first or by selection)
4. Calculate and apply discounts
5. Generate open credit if overpayment
6. Update customer aging
7. Emit payment events

### Finance Charge Workflow
1. Identify eligible past-due accounts
2. Calculate charges based on configuration
3. Create charge invoices or adjust existing
4. Update customer balances
5. Emit charge events

### Electronic Payment Workflow
1. Generate prenote files
2. Await bank confirmation
3. Activate customer for electronic payments
4. Process payment batches
5. Generate NACHA files
6. Record transactions

## Multi-Currency Support

### Exchange Rate Management
- Real-time rate updates
- Transaction-specific rate overrides
- Gain/loss calculation on payment
- Revaluation processing

### Currency-Specific Rules
- Bank account currency matching
- Customer currency preferences
- Multi-currency price lists
- Foreign currency statements

## Data Validation Rules

### Invoice Validation
- Customer exists and is active
- Invoice date within open periods
- Payment terms are valid
- Tax codes are applicable
- Inventory availability for stock items
- Serial/lot numbers are unique

### Payment Validation
- Payment amount is positive
- Bank account matches currency
- Credit card is not expired
- Check number format is valid
- Receipt date is valid

### Credit Management
- Credit limit enforcement
- Past-due balance restrictions
- Order hold triggers
- Collection status flags

## Period-End Processing

### Commands
- `CloseAccountingPeriod`
- `TransferToGeneralLedger`
- `PerformCurrencyRevaluation`
- `ArchiveHistoricalData`

### Events
- `PeriodClosed`
- `DataTransferredToGL`
- `CurrencyRevaluationCompleted`
- `HistoricalDataArchived`

### Business Rules
- Prevent posting to closed periods
- Ensure all transactions are posted
- Validate GL account mappings
- Generate period-end reports

## Reporting Requirements

### Operational Reports
- Invoice listings and summaries
- Payment/cash receipts journals
- Customer aging analysis
- Open credit reports
- Sales analysis by customer/item/salesperson

### Financial Reports
- AR status and balances
- Revenue recognition
- Tax liability
- Currency gain/loss
- Bad debt analysis

### Customer Communications
- Statements (balance forward/open item)
- Collection letters
- Payment receipts
- Credit memos

## Security and Audit

### Access Control
- Function-level permissions
- Customer-level restrictions
- Amount thresholds
- Void/amendment authorization

### Audit Trail
- All events are immutable
- User tracking on all commands
- Timestamp preservation
- Amendment history
- Void reason tracking

## Performance Considerations

### Event Stream Optimization
- Aggregate snapshotting for high-volume customers
- Event projection caching
- Batch processing for bulk operations

### Query Optimization
- Read model projections for reporting
- Indexed search capabilities
- Pagination for large datasets

## Error Handling

### Command Failures
- Validation error responses
- Compensation events for rollback
- Retry logic for transient failures

### Integration Failures
- Event replay capabilities
- Dead letter queue for failed events
- Circuit breaker for external services

## Configuration Management

### System Parameters
- Invoice numbering schemes
- Tax calculation methods
- Finance charge settings
- Aging bucket definitions
- Default GL account mappings

### Customer-Specific Settings
- Payment terms
- Credit limits
- Pricing tiers
- Tax exemptions
- Statement preferences

## Migration Support

### Beginning Balance Import
- Customer balance posting
- Historical invoice import
- Open credit migration
- Aging preservation

### Data Import/Export
- CSV/JSON format support
- Field mapping configuration
- Validation and error reporting
- Batch processing capabilities



