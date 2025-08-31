# Bank Reconciliation Business Logic

## Overview

The Bank Reconciliation application manages cash flow tracking, bank transaction recording, and reconciliation processes. It integrates with Accounts Receivable, Accounts Payable, and Payroll modules to ensure all transactions affecting bank balances are available for reconciliation. The system maintains real-time cash position visibility and enables transfer of bank transaction journal entries to the General Ledger.

## Core Entities

### Bank Account

- **Attributes**:
  - Bank account number
  - Account description
  - Currency code
  - GL account ID for posting
  - Next deposit number
  - Next check number (handwritten and computer-generated)
  - Account status (active/inactive)
  - Balance tracking fields
  - System-generated deposit/check number settings

### Transaction Code

- **Attributes**:
  - Code identifier
  - Description
  - Transaction type (Receipt/Disbursement/Transfer)
  - Require deposit/check number flag
  - GL distribution accounts and percentages
  - Active status

### Bank Transaction

- **Base Attributes**:
  - Transaction number (system-generated)
  - Bank account reference
  - Transaction code
  - Transaction date
  - Amount (in bank currency)
  - Description
  - Reference number
  - Transfer to GL flag
  - Verification/cancellation status
  - Verification/cancellation date
  
- **Subtypes**:
  - **Deposit**: Includes deposit number, deposit date
  - **Other Receipt**: Receipt date, no deposit number required
  - **Check**: Check number, check date, payee name, payee reference/memo
  - **Other Disbursement**: Disbursement date, no check number required
  - **Bank Transfer**: From/to bank accounts, transfer date

### GL Distribution

- **Attributes**:
  - Transaction reference
  - GL account ID
  - Distribution amount
  - Line item description
  - Distribution percentage

### Recurring Transaction Template

- **Attributes**:
  - Template code
  - Transaction type
  - Frequency settings
  - Base transaction details
  - Active status
  - Last generation date

## Commands and Events

### Bank Account Management

#### CreateBankAccount

- **Input**: Bank details, GL account, currency, number settings
- **Validations**:
  - Unique bank account code
  - Valid GL account ID
  - Valid currency code
- **Events**: BankAccountCreated

#### UpdateBankAccount

- **Input**: Account updates
- **Validations**:
  - Cannot change bank code
  - Check number sequence validation
- **Events**: BankAccountUpdated

### Transaction Recording

#### RecordDeposit

- **Input**: Bank account, transaction code, deposit details, GL distributions
- **Validations**:
  - Transaction code must be Receipt type with deposit requirement
  - Deposit number uniqueness (if not system-generated)
  - GL distribution must balance to deposit amount
  - Currency exchange rate validation for foreign currency
- **Events**: DepositRecorded
- **Side Effects**:
  - Update next deposit number if manually changed
  - Create GL journal entries if transfer flag set

#### RecordOtherReceipt

- **Input**: Bank account, transaction code, receipt details, GL distributions
- **Validations**:
  - Transaction code must be Receipt type without deposit requirement
  - GL distribution balance validation
- **Events**: OtherReceiptRecorded

#### RecordCheck

- **Input**: Bank account, check details, payee info, GL distributions
- **Validations**:
  - Transaction code must be Disbursement type with check requirement
  - Check number sequence validation
  - GL distribution balance validation
- **Events**: CheckRecorded
- **Side Effects**: Update next check number if manually changed

#### RecordOtherDisbursement

- **Input**: Bank account, disbursement details, GL distributions
- **Validations**:
  - Transaction code must be Disbursement type without check requirement
  - GL distribution balance validation
- **Events**: OtherDisbursementRecorded

#### RecordBankTransfer

- **Input**: From bank, to bank, amount, date
- **Validations**:
  - Different bank accounts required
  - Sufficient balance in source account
  - Currency conversion validation if different currencies
- **Events**: BankTransferRecorded

### Transaction Amendment

#### AmendTransaction

- **Input**: Transaction ID, updated fields
- **Validations**:
  - Transaction not verified/cancelled
  - Transaction not posted to GL
  - Maintain GL distribution balance
- **Events**: TransactionAmended

#### VoidTransaction

- **Input**: Transaction ID
- **Validations**:
  - Transaction exists
  - Not already voided
  - Not posted to GL if cancelled
- **Events**: TransactionVoided

### Bank Reconciliation

#### VerifyDeposit

- **Input**: Deposit transaction ID, verification date
- **Validations**:
  - Transaction exists and is deposit type
  - Not already verified
- **Events**: DepositVerified

#### CancelCheck

- **Input**: Check transaction ID, cancellation date
- **Validations**:
  - Transaction exists and is check type
  - Not already cancelled
- **Events**: CheckCancelled

#### ReconcileBankStatement

- **Input**: Bank account, statement date, statement balance, transaction selections
- **Validations**:
  - All selected transactions belong to bank account
  - Reconciliation balance matches statement
- **Events**: BankStatementReconciled

### Recurring Transactions

#### CreateRecurringTemplate

- **Input**: Template details, frequency, transaction pattern
- **Validations**:
  - Valid transaction pattern
  - Frequency settings validation
- **Events**: RecurringTemplateCreated

#### GenerateRecurringTransaction

- **Input**: Template ID, generation date
- **Validations**:
  - Template active
  - Generation date follows frequency rules
- **Events**: RecurringTransactionGenerated
- **Side Effects**: Create actual transaction based on template

### Import Operations

#### ImportBankTransactions

- **Input**: Bank account, import file, mapping configuration
- **Validations**:
  - File format validation
  - Duplicate transaction detection
  - Amount and date validation
- **Events**: BankTransactionsImported
- **Side Effects**: Create transactions based on import

## Business Rules

### Transaction Recording Rules

1. **Deposit Number Sequencing**:
   - System-generated or manual based on bank account settings
   - Automatic increment for next transaction
   - Warning on out-of-sequence numbers

2. **Check Number Management**:
   - Separate sequences for handwritten and computer checks
   - Option to use same starting number for both types
   - Validation against duplicate check numbers

3. **GL Distribution Requirements**:
   - Total distributions must equal transaction amount
   - At least one distribution line required
   - Bank account GL automatically debited/credited

4. **Currency Handling**:
   - Transactions recorded in bank account currency
   - Automatic conversion to home currency for GL posting
   - Exchange rate from currency code or manual override

### Reconciliation Rules

1. **Status Progression**:
   - Deposits: Unverified → Verified
   - Checks: Outstanding → Cancelled
   - Other transactions follow similar patterns

2. **Amendment Restrictions**:
   - Cannot amend verified/cancelled transactions
   - Cannot amend after GL posting
   - Must unverify/uncancel before amendment

3. **Reconciliation Balance**:
   - Book balance + deposits - checks = Bank statement balance
   - Adjustments for outstanding items
   - Service charges and interest handling

### Period-End Rules

1. **Posting Restrictions**:
   - Cannot post to restricted periods
   - Verification required before posting (configurable)
   - Batch posting of multiple periods

2. **GL Transfer**:
   - Only transactions marked for transfer
   - Consolidation by GL account and period
   - Audit trail maintenance

## Integration Points

### With General Ledger

- **Journal Entry Creation**: All bank transactions create GL entries
- **Account Validation**: GL account existence and status
- **Period Restrictions**: Respect GL posting period settings
- **Balance Updates**: Real-time GL balance impacts

### With Accounts Payable

- **Check Integration**: AP checks appear in bank reconciliation
- **Vendor Payment Tracking**: Link checks to AP invoices
- **Payment Batch Processing**: Bulk check recording from AP

### With Accounts Receivable

- **Deposit Integration**: AR receipts create bank deposits
- **Customer Receipt Tracking**: Link deposits to AR invoices
- **Batch Deposit Processing**: Consolidated customer deposits

### With Payroll

- **Payroll Check Integration**: Payroll checks in reconciliation
- **Direct Deposit Processing**: ACH transaction handling
- **Tax Payment Tracking**: Tax disbursements recording

## Workflows

### Daily Cash Management Workflow

1. **Morning Balance Review**:
   - Check overnight transactions
   - Review pending deposits
   - Identify outstanding checks

2. **Transaction Recording**:
   - Record manual deposits
   - Enter handwritten checks
   - Process bank charges/interest

3. **Import Processing**:
   - Download bank transactions
   - Map to transaction codes
   - Review and approve imports

### Monthly Reconciliation Workflow

1. **Pre-Reconciliation**:
   - Ensure all transactions recorded
   - Review outstanding items from prior month
   - Identify timing differences

2. **Statement Reconciliation**:
   - Mark cleared deposits
   - Cancel presented checks
   - Record bank adjustments

3. **Discrepancy Resolution**:
   - Investigate unmatched items
   - Create adjustment entries
   - Document reconciliation differences

4. **Post-Reconciliation**:
   - Generate reconciliation reports
   - Transfer to General Ledger
   - Archive bank statements

### Period-End Closing Workflow

1. **Transaction Verification**:
   - Review unverified deposits
   - Confirm outstanding checks
   - Validate GL distributions

2. **GL Transfer Preparation**:
   - Mark transactions for transfer
   - Review posting dates
   - Validate account mappings

3. **Transfer Execution**:
   - Create GL journal entries
   - Update transaction status
   - Generate transfer reports

## Validation Rules

### Transaction Validations

- Amount must be greater than zero
- Transaction date within allowed periods
- Required fields based on transaction type
- GL account must exist and be active
- Currency code must be valid
- Exchange rate must be positive

### Bank Account Validations

- Unique bank account code
- Valid GL account assignment
- Currency code exists
- Check/deposit number format rules
- Cannot delete with existing transactions

### Reconciliation Validations

- Statement date after last reconciliation
- All reconciling items must belong to same bank
- Reconciled balance must match statement
- Cannot reconcile future-dated transactions

## Reporting Requirements

### Operational Reports

- **Deposit Reports**: Unverified and verified deposits
- **Check Reports**: Outstanding and cancelled checks
- **Transaction Listings**: By date, type, or status
- **Bank Transfer Reports**: Transfer activity between accounts

### Reconciliation Reports

- **Bank Reconciliation Report**: Full reconciliation with adjustments
- **Unreconciled Transaction Listing**: Outstanding items detail
- **Bank Statement Report**: Simulated bank statement

### Analysis Reports

- **Cash Position Report**: Current balances across all banks
- **Cash Flow Analysis**: Inflows and outflows by period
- **Transaction Code Analysis**: Usage by transaction code

## Security and Audit

### Access Controls

- Bank account level permissions
- Transaction type restrictions
- Amendment/void permissions
- Reconciliation authority levels

### Audit Trail

- All transaction changes logged
- User and timestamp tracking
- Reason codes for amendments/voids
- Reconciliation history preservation

## Performance Considerations

### Transaction Volume

- Support high-volume daily transactions
- Efficient bulk import processing
- Optimized reconciliation algorithms

### Data Retention

- Configurable retention periods
- Archive old reconciliations
- Purge completed transactions option

## Error Handling

### Common Error Scenarios

- Duplicate check/deposit numbers
- Insufficient GL distribution
- Invalid period posting attempts
- Currency conversion failures
- Import format mismatches

### Recovery Procedures

- Transaction reversal capabilities
- Batch error handling for imports
- Reconciliation rollback option
- GL posting reversal process

# Bank Reconciliation Business Logic

## Overview

The Bank Reconciliation application provides comprehensive functionality for managing bank accounts, recording financial transactions, reconciling bank statements, and maintaining accurate cash position records. This document outlines the business logic requirements for implementing these capabilities within the Accountex modular architecture.

## Core Domain Entities

### Bank Account

- **Purpose**: Represents a financial institution account used for business transactions
- **Key Attributes**:
  - Bank account number (unique identifier)
  - Bank name and routing number
  - Account type (checking, savings, other)
  - Currency code
  - GL account association
  - Current balance information
  - Check numbering sequences (computer and handwritten)
  - Deposit numbering sequence
  - Previous statement date and balance
  - Unreconciled amount tracking

### Transaction

- **Purpose**: Represents any financial movement affecting a bank account
- **Types**:
  - Deposit
  - Other Receipt
  - Check
  - Other Disbursement
  - Bank Transfer (source and target)
  - Electronic Payment
- **Key Attributes**:
  - Transaction number (unique per type and bank)
  - Transaction code (categorization)
  - Date and amount
  - Description and reference
  - Verification/cancellation status
  - GL distribution details
  - Source module identifier

### Transaction Code

- **Purpose**: Categorizes and defines default behavior for transactions
- **Key Attributes**:
  - Code and description
  - Transaction type (receipt, disbursement, transfer)
  - Default GL account distributions
  - Status (active/inactive)
  - Check/deposit number requirement flag

### Bank Statement

- **Purpose**: Represents a periodic statement from the financial institution
- **Key Attributes**:
  - Statement period (start and end dates)
  - Beginning and ending balances
  - Total deposits/receipts (count and amount)
  - Total checks/disbursements (count and amount)
  - Reconciliation status

### Recurring Transaction Template

- **Purpose**: Defines templates for automatically generating repetitive transactions
- **Key Attributes**:
  - Template identifier
  - Transaction type and details
  - Recurrence pattern (weekly, monthly, quarterly, etc.)
  - Next occurrence date
  - End date or number of cycles
  - Status (active/inactive)

## Business Rules and Validations

### Bank Account Management

1. **Account Setup Rules**:
   - Currency code is immutable once set
   - GL account ID is mandatory
   - Bank routing number must be valid format (9 characters for US)
   - Account number must be unique within the system

2. **Check Numbering Rules**:
   - Check numbers must be sequential within type (computer/handwritten)
   - Cannot reuse check numbers for the same bank account
   - Next check number must be greater than highest used (unless starting new sequence)
   - Computer and handwritten checks can share or have separate sequences

3. **Deposit Numbering Rules**:
   - System can auto-generate sequential deposit numbers
   - Manual deposit numbers must be unique per bank account
   - Next deposit number must exceed highest used (unless new sequence)

4. **Balance Validation**:
   - Previous statement balance becomes beginning balance for current period
   - Unreconciled amount must equal sum of all unverified/uncancelled transactions

### Transaction Recording

1. **Deposit/Receipt Rules**:
   - Must have valid bank account
   - Must have transaction date and positive amount
   - Must have transaction code of receipt type
   - Deposit number required if configured for bank account
   - Cannot modify verified deposits

2. **Check/Disbursement Rules**:
   - Amount cannot exceed maximum allowed for bank account
   - Check number required for check transactions
   - Cannot void verified/cancelled checks
   - Must have transaction code of disbursement type
   - Cannot modify cancelled disbursements

3. **Bank Transfer Rules**:
   - Source and target banks must be different
   - Must have transfer type transaction code
   - Transfer and received amounts must balance when converted to home currency
   - Both sides of transfer must be verified/unverified together

4. **Multi-Currency Rules**:
   - Exchange rates required for foreign currency transactions
   - Home currency equivalent must be calculated for GL posting
   - Currency conversion must maintain accounting balance

### Bank Reconciliation

1. **Reconciliation Process Rules**:
   - Statement ending balance must equal calculated ending balance
   - Calculated balance = Previous balance + Verified deposits - Cancelled checks
   - Count verification optional (if enabled, counts must also match)
   - Cannot modify reconciled transactions from finalized periods

2. **Transaction Verification Rules**:
   - Deposits/receipts marked as verified when cleared
   - Checks/disbursements marked as cancelled when cleared
   - Transfers must be verified on both source and target sides
   - Verification date defaults to current date but can be modified

3. **Period Finalization Rules**:
   - Once finalized, reconciliation cannot be modified
   - Finalized ending balance becomes next period's beginning balance
   - All verified/cancelled items locked from changes
   - Warning required if out of balance before finalization

### Recurring Transactions

1. **Template Rules**:
   - Must have valid transaction code matching template type
   - Cannot use transaction codes requiring check/deposit numbers
   - Next recurring date must be >= current date
   - End date must be >= next recurring date

2. **Generation Rules**:
   - Only generate from active templates
   - Generate only for cycles within specified date range
   - Update next recurring date after generation
   - Respect end date and cycle count limits

3. **Special Date Handling**:
   - Last day of month option maintains month-end dates
   - Skip invalid dates (e.g., February 30)
   - Adjust for weekends/holidays if configured

## Commands and Events

### Bank Account Commands

```elixir
# Commands
CreateBankAccount
UpdateBankAccount
UpdateCheckSequence
UpdateDepositSequence
CloseBankAccount

# Events
BankAccountCreated
BankAccountUpdated
CheckSequenceUpdated
DepositSequenceUpdated
BankAccountClosed
```

### Transaction Commands

```elixir
# Deposit/Receipt Commands
RecordDeposit
RecordOtherReceipt
AmendDeposit
VoidDeposit
VerifyDeposit

# Check/Disbursement Commands
RecordCheck
RecordOtherDisbursement
AmendCheck
VoidCheck
CancelCheck

# Transfer Commands
RecordBankTransfer
AmendBankTransfer
VoidBankTransfer
VerifyBankTransfer

# Events
DepositRecorded
CheckRecorded
TransferRecorded
TransactionAmended
TransactionVoided
TransactionVerified
TransactionCancelled
```

### Reconciliation Commands

```elixir
# Commands
StartReconciliation
UpdateReconciliationInfo
MarkTransactionsReconciled
UnmarkTransactionsReconciled
FinalizeReconciliation
SaveReconciliationProgress

# Events
ReconciliationStarted
ReconciliationInfoUpdated
TransactionsMarkedReconciled
TransactionsUnmarkedReconciled
ReconciliationFinalized
ReconciliationProgressSaved
```

### Recurring Transaction Commands

```elixir
# Commands
CreateRecurringTemplate
UpdateRecurringTemplate
ActivateRecurringTemplate
DeactivateRecurringTemplate
GenerateRecurringTransactions
VoidRecurringTemplate

# Events
RecurringTemplateCreated
RecurringTemplateUpdated
RecurringTemplateActivated
RecurringTemplateDeactivated
RecurringTransactionsGenerated
RecurringTemplateVoided
```

## Workflows and Processes

### Deposit Recording Workflow

1. **Validation Phase**:
   - Validate bank account exists and is active
   - Validate transaction code is receipt type
   - Generate or validate deposit number
   - Validate amount is positive
   - Check GL account distributions balance

2. **Recording Phase**:
   - Create deposit transaction record
   - Update bank account running balance
   - Generate GL journal entries
   - Emit DepositRecorded event

3. **Post-Processing**:
   - Update deposit sequence if auto-generated
   - Notify dependent modules (GL, AR if applicable)

### Check Recording Workflow

1. **Validation Phase**:
   - Validate bank account and check number
   - Ensure check number not already used
   - Validate amount within limits
   - Validate transaction code is disbursement type

2. **Recording Phase**:
   - Create check transaction record
   - Update bank account balance
   - Generate GL journal entries
   - Emit CheckRecorded event

3. **Post-Processing**:
   - Update check number sequence
   - Notify dependent modules (GL, AP if applicable)

### Bank Transfer Workflow

1. **Validation Phase**:
   - Validate both bank accounts exist
   - Ensure source has sufficient funds
   - Calculate currency conversions if needed
   - Validate transfer amounts balance

2. **Recording Phase**:
   - Create transfer out transaction for source
   - Create transfer in transaction for target
   - Update both bank account balances
   - Generate GL journal entries
   - Emit TransferRecorded event

3. **Post-Processing**:
   - Link transfer transactions
   - Update currency exchange tracking if applicable

### Reconciliation Workflow

1. **Initialization Phase**:
   - Load bank account and previous reconciliation
   - Set statement date range and balances
   - Load all unreconciled transactions

2. **Matching Phase**:
   - Mark deposits as verified
   - Mark checks as cancelled
   - Track running totals and variances
   - Allow bulk selection by criteria

3. **Validation Phase**:
   - Calculate ending balance variance
   - Verify count matches if required
   - Display outstanding items
   - Warn if out of balance

4. **Finalization Phase**:
   - Lock all reconciled transactions
   - Update bank account statement info
   - Generate reconciliation report
   - Emit ReconciliationFinalized event

### Recurring Transaction Generation

1. **Selection Phase**:
   - Filter templates by date range and bank
   - Check template active status
   - Verify within cycle dates

2. **Generation Phase**:
   - For each qualifying template:
     - Create transaction from template
     - Apply template GL distributions
     - Update next recurring date
     - Decrement cycle count if applicable

3. **Completion Phase**:
   - Report generation summary
   - Deactivate expired templates
   - Emit RecurringTransactionsGenerated events

### Import Process Workflow

1. **Configuration Phase**:
   - Define import file format and mappings
   - Set up converter codes for data transformation
   - Configure column definitions and data types

2. **Validation Phase**:
   - Parse import file
   - Validate data types and formats
   - Check for duplicate transactions
   - Apply converter code transformations

3. **Import Phase**:
   - Create transaction records
   - Skip duplicates
   - Track errors and warnings
   - Generate import summary

4. **Review Phase**:
   - Display imported transactions for review
   - Allow corrections before saving
   - Option to rollback entire import

## Integration Points

### General Ledger Integration

- **Journal Entry Generation**:
  - All transactions generate GL journal entries
  - Respect GL account distributions
  - Handle multi-currency conversions
  - Support summary or detail posting

- **Period Management**:
  - Respect GL period restrictions
  - Validate posting dates within open periods
  - Support future period posting if allowed

- **Account Validation**:
  - Validate GL account IDs exist
  - Check account active status
  - Verify account allows bank posting

### Accounts Payable Integration

- **Check Processing**:
  - Receive check records from AP
  - Update check sequences
  - Process electronic payments
  - Handle positive pay files

- **Vendor Payment Tracking**:
  - Link checks to vendor payments
  - Track payment methods
  - Support payment consolidation

### Accounts Receivable Integration

- **Deposit Processing**:
  - Receive deposit records from AR
  - Link deposits to customer receipts
  - Track deposit methods
  - Support batch deposits

### Payroll Integration

- **Payroll Check Processing**:
  - Receive payroll checks
  - Handle direct deposits
  - Process payroll tax payments
  - Track employee payments

## Reporting Requirements

### Operational Reports

1. **Transaction Reports**:
   - Outstanding checks/deposits
   - Verified/cancelled transactions
   - Transaction listings by date/type
   - Bank transfer reports

2. **Reconciliation Reports**:
   - Current reconciliation status
   - Historical reconciliations
   - Unreconciled items listing
   - Reconciliation variance analysis

3. **Recurring Transaction Reports**:
   - Active templates listing
   - Generation schedule forecast
   - Template execution history

### Management Reports

1. **Cash Position Reports**:
   - Daily cash position
   - Cash flow forecast
   - Bank account balances
   - Currency exposure analysis

2. **Audit Reports**:
   - Transaction audit trail
   - Reconciliation history
   - User activity logs
   - Exception reports

### Compliance Reports

1. **Positive Pay Files**:
   - Generate bank-specific formats
   - Track file transmission
   - Exception reporting

2. **Bank Statement Analysis**:
   - Statement comparison reports
   - Variance analysis
   - Trend analysis

## Security and Compliance

### Access Control

1. **Function-Level Security**:
   - Restrict transaction recording by type
   - Control reconciliation functions
   - Limit report access
   - Manage configuration changes

2. **Data-Level Security**:
   - Bank account access restrictions
   - Amount limits by user role
   - Transaction type restrictions
   - Period closure enforcement

### Audit Trail

1. **Transaction Audit**:
   - Track all changes to transactions
   - Record user, date, time of changes
   - Maintain before/after values
   - Support regulatory compliance

2. **Reconciliation Audit**:
   - Log all reconciliation activities
   - Track verification/cancellation actions
   - Document out-of-balance resolutions
   - Maintain reconciliation history

### Compliance Features

1. **Segregation of Duties**:
   - Separate recording and approval functions
   - Independent reconciliation process
   - Dual control for sensitive operations

2. **Internal Controls**:
   - Enforce sequential numbering
   - Prevent duplicate transactions
   - Require appropriate authorizations
   - Validate transaction limits

## Performance Considerations

### Data Management

1. **Transaction Volume**:
   - Support high transaction volumes
   - Efficient search and filtering
   - Optimized reconciliation matching
   - Batch processing capabilities

2. **Historical Data**:
   - Archive old reconciliations
   - Maintain summary data
   - Support data purging policies
   - Optimize query performance

### Processing Efficiency

1. **Bulk Operations**:
   - Batch transaction import
   - Mass verification/cancellation
   - Bulk recurring generation
   - Efficient report generation

2. **Real-Time Updates**:
   - Immediate balance updates
   - Live reconciliation totals
   - Current cash position
   - Dynamic variance calculation

## Error Handling and Recovery

### Transaction Errors

1. **Validation Errors**:
   - Clear error messages
   - Field-level validation
   - Business rule explanations
   - Suggested corrections

2. **Processing Errors**:
   - Transaction rollback capability
   - Partial save options
   - Error logging and reporting
   - Recovery procedures

### Reconciliation Errors

1. **Out-of-Balance Handling**:
   - Identify variance sources
   - Provide reconciliation aids
   - Support adjusting entries
   - Document resolutions

2. **Data Integrity**:
   - Detect data inconsistencies
   - Provide repair utilities
   - Maintain backup data
   - Support data restoration

## Future Enhancements

### Automation Features

1. **Bank Feed Integration**:
   - Direct bank connections
   - Automatic transaction import
   - Smart matching algorithms
   - Exception handling

2. **AI-Powered Reconciliation**:
   - Machine learning for matching
   - Anomaly detection
   - Predictive categorization
   - Automated corrections

### Advanced Analytics

1. **Cash Flow Optimization**:
   - Predictive cash forecasting
   - Optimal transfer timing
   - Interest optimization
   - Currency hedging support

2. **Risk Management**:
   - Fraud detection
   - Unusual transaction alerts
   - Compliance monitoring
   - Risk scoring

This business logic specification provides the foundation for implementing a comprehensive Bank Reconciliation application within the Accountex modular architecture, ensuring robust financial transaction management and accurate cash position tracking.

# Bank Reconciliation Business Logic

## Overview

The Bank Reconciliation application manages the recording, tracking, and reconciliation of bank transactions within the Accountex system. It provides functionality for managing deposits, disbursements, transfers, and the reconciliation process between company records and bank statements.

## Core Aggregates

### BankAccount

Represents a bank account maintained by the company.

**Attributes:**

- `bank_id` - Unique identifier for the bank account
- `bank_name` - Name of the bank
- `account_number` - Bank account number
- `routing_number` - Bank routing number
- `account_type` - Type of account (checking, savings, other)
- `currency_code` - Currency for the account
- `current_balance` - Current balance per company records
- `statement_balance` - Last reconciled bank statement balance
- `unreconciled_amount` - Difference between current and statement balance
- `gl_account_id` - Associated General Ledger account
- `check_format` - Format for computer-generated checks
- `next_check_number` - Next available check number
- `next_deposit_number` - Next available deposit number
- `use_system_generated_deposits` - Whether to auto-generate deposit numbers
- `status` - Active/Inactive status

**ACH Configuration:**

- `ach_directory` - Storage location for ACH files
- `ach_file_prefix` - Prefix for ACH filenames
- `ach_next_batch` - Next batch sequence number
- `ach_immediate_origin` - Company identification number
- `ach_immediate_destination` - Bank branch ABA number
- `ach_service_class_code` - Service class for ACH files

**Positive Pay Configuration:**

- `positive_pay_format` - Bank's document format
- `positive_pay_directory` - Storage location for positive pay files
- `positive_pay_file_prefix` - Prefix for positive pay filenames
- `positive_pay_next_batch` - Next batch sequence number

### BankTransaction

Represents individual bank transactions (deposits, checks, transfers).

**Attributes:**

- `transaction_id` - Unique identifier
- `bank_id` - Associated bank account
- `transaction_type` - Receipt, Disbursement, or Transfer
- `transaction_code` - Classification code
- `transaction_date` - Date of transaction
- `reference_number` - Check/deposit number
- `payee` - Recipient (for disbursements)
- `payer` - Source (for receipts)
- `amount` - Transaction amount
- `memo` - Description/memo
- `cleared_status` - Uncleared, Cleared, Reconciled, Void
- `cleared_date` - Date cleared by bank
- `gl_distribution` - GL account distribution
- `transfer_to_gl` - Flag for GL transfer

### BankStatement

Represents a bank statement for reconciliation.

**Attributes:**

- `statement_id` - Unique identifier
- `bank_id` - Associated bank account
- `statement_date` - Statement date
- `beginning_balance` - Opening balance
- `ending_balance` - Closing balance
- `total_deposits` - Total deposits on statement
- `total_checks` - Total checks on statement
- `deposit_count` - Number of deposits
- `check_count` - Number of checks
- `reconciliation_status` - In Progress, Completed, Cancelled

### TransactionCode

Defines transaction classifications and default GL distributions.

**Attributes:**

- `code` - Unique transaction code
- `description` - Description of the transaction type
- `transaction_type` - Receipt, Disbursement, or Transfer
- `require_reference_number` - Whether check/deposit number is required
- `default_gl_accounts` - Default GL account distributions
- `distribution_percentages` - Percentage split for GL distribution
- `status` - Active/Inactive

### RecurringTransaction

Template for recurring bank transactions.

**Attributes:**

- `template_id` - Unique identifier
- `template_name` - Name of the template
- `transaction_type` - Receipt, Disbursement, or Transfer
- `bank_id` - Associated bank account
- `transaction_code` - Classification code
- `payee` - Default payee
- `amount` - Default amount
- `memo` - Default description
- `gl_distribution` - GL account distribution
- `frequency` - Daily, Weekly, Monthly, etc.
- `next_occurrence` - Next scheduled date
- `end_date` - Optional end date
- `status` - Active/Inactive

## Commands

### Bank Account Management

#### CreateBankAccount

Creates a new bank account record.

**Input:**

- Bank account details
- GL account association
- Check/deposit configuration
- ACH settings (optional)
- Positive pay settings (optional)

**Validations:**

- Unique bank account ID
- Valid GL account exists
- Valid currency code
- Routing number format

**Events:**

- `BankAccountCreated`

#### UpdateBankAccount

Updates bank account information.

**Input:**

- Bank account ID
- Updated fields

**Validations:**

- Bank account exists
- Cannot change bank ID if transactions exist
- Valid GL account if changed

**Events:**

- `BankAccountUpdated`

#### DeactivateBankAccount

Marks a bank account as inactive.

**Input:**

- Bank account ID

**Validations:**

- Bank account exists
- No unreconciled transactions
- Current balance is zero

**Events:**

- `BankAccountDeactivated`

### Recording Transactions

#### RecordDeposit

Records a deposit or other receipt transaction.

**Input:**

- Bank account ID
- Transaction date
- Deposit amount
- Deposit number (optional)
- Transaction code
- Payer information
- GL distribution
- Memo

**Validations:**

- Valid bank account
- Valid transaction code for receipts
- Deposit number required if configured
- GL accounts exist and are active
- Distribution percentages total 100%

**Events:**

- `DepositRecorded`
- `BankBalanceIncreased`

#### RecordCheck

Records a check or other disbursement.

**Input:**

- Bank account ID
- Transaction date
- Check amount
- Check number (optional)
- Transaction code
- Payee information
- GL distribution
- Memo

**Validations:**

- Valid bank account
- Valid transaction code for disbursements
- Check number required if configured
- Sufficient bank balance
- GL accounts exist and are active

**Events:**

- `CheckRecorded`
- `BankBalanceDecreased`

#### RecordBankTransfer

Records a transfer between bank accounts.

**Input:**

- From bank account ID
- To bank account ID
- Transfer date
- Transfer amount
- Transaction code
- Reference number
- Memo

**Validations:**

- Both bank accounts exist and active
- Valid transaction code for transfers
- Sufficient balance in source account
- Accounts can be in different currencies

**Events:**

- `BankTransferRecorded`
- `BankBalanceDecreased` (from account)
- `BankBalanceIncreased` (to account)

#### VoidTransaction

Voids a previously recorded transaction.

**Input:**

- Transaction ID
- Void date
- Void reason

**Validations:**

- Transaction exists
- Transaction not already void
- Transaction not reconciled
- Void date >= transaction date

**Events:**

- `TransactionVoided`
- `BankBalanceAdjusted`

### Bank Reconciliation

#### StartReconciliation

Begins a new bank reconciliation process.

**Input:**

- Bank account ID
- Statement date
- Ending balance
- Total deposits
- Total checks
- Deposit count (optional)
- Check count (optional)

**Validations:**

- Valid bank account
- No reconciliation in progress
- Statement date >= last reconciliation date

**Events:**

- `ReconciliationStarted`

#### MarkTransactionCleared

Marks a transaction as cleared during reconciliation.

**Input:**

- Transaction ID
- Cleared date
- Statement reference (optional)

**Validations:**

- Transaction exists
- Transaction not void
- Part of active reconciliation
- Cleared date >= transaction date

**Events:**

- `TransactionCleared`

#### MarkTransactionUncleared

Removes cleared status from a transaction.

**Input:**

- Transaction ID

**Validations:**

- Transaction exists
- Transaction currently cleared
- Part of active reconciliation
- Not previously reconciled

**Events:**

- `TransactionUncleared`

#### AddAdjustment

Adds an adjustment entry during reconciliation.

**Input:**

- Bank account ID
- Adjustment type (bank fee, interest, etc.)
- Amount
- Date
- GL account
- Description

**Validations:**

- Active reconciliation exists
- Valid GL account
- Date within statement period

**Events:**

- `ReconciliationAdjustmentAdded`

#### CompleteReconciliation

Finalizes the bank reconciliation.

**Input:**

- Bank account ID
- Reconciliation notes (optional)

**Validations:**

- Active reconciliation exists
- Statement balance matches adjusted book balance
- All required items cleared
- Record counts match if configured

**Events:**

- `ReconciliationCompleted`
- `TransactionsReconciled`
- `StatementBalanceUpdated`

#### CancelReconciliation

Cancels an in-progress reconciliation.

**Input:**

- Bank account ID
- Cancellation reason

**Validations:**

- Active reconciliation exists

**Events:**

- `ReconciliationCancelled`
- `ClearedTransactionsReverted`

### Recurring Transactions

#### CreateRecurringTemplate

Creates a recurring transaction template.

**Input:**

- Template details
- Transaction type and code
- Default values
- Frequency settings
- GL distribution

**Validations:**

- Valid bank account
- Valid transaction code
- GL accounts exist
- Valid frequency pattern

**Events:**

- `RecurringTemplateCreated`

#### GenerateRecurringTransaction

Generates transactions from recurring templates.

**Input:**

- Template ID
- Generation date
- Override values (optional)

**Validations:**

- Template exists and active
- Generation date >= next occurrence
- Bank account active

**Events:**

- `RecurringTransactionGenerated`
- Corresponding transaction events

#### UpdateRecurringTemplate

Updates a recurring template.

**Input:**

- Template ID
- Updated fields

**Validations:**

- Template exists
- Valid updated values

**Events:**

- `RecurringTemplateUpdated`

### Period Operations

#### ClosePeriod

Closes the current accounting period for bank reconciliation.

**Input:**

- Period end date
- GL batch number (optional)
- Purge settings

**Validations:**

- All bank accounts reconciled
- No unposted transactions
- GL transfer allowed

**Events:**

- `PeriodClosed`
- `TransactionsTransferredToGL`
- `HistoricalTransactionsPurged`

#### TransferToGeneralLedger

Transfers bank transactions to the General Ledger.

**Input:**

- Date range
- Bank account filter (optional)
- Batch number (optional)

**Validations:**

- Transactions marked for GL transfer
- GL module available
- Valid GL accounts

**Events:**

- `TransactionsTransferredToGL`

## Business Rules

### Transaction Recording Rules

1. **Check Numbering**
   - System can auto-generate check numbers sequentially
   - Manual check numbers must be unique per bank account
   - Handwritten checks can be recorded with manual numbers

2. **Deposit Numbering**
   - System can auto-generate deposit numbers if configured
   - Manual deposit numbers must be unique per bank account

3. **GL Distribution**
   - Total distribution must equal 100%
   - All GL accounts must be active
   - Transfer transactions don't require GL distribution

4. **Multi-Currency**
   - Transactions recorded in bank account currency
   - Exchange gains/losses calculated for foreign currency accounts
   - Transfers between different currencies calculate exchange differences

### Reconciliation Rules

1. **Balance Matching**
   - Adjusted book balance must equal statement ending balance
   - Difference = Ending Balance - (Beginning Balance + Cleared Deposits - Cleared Checks ± Adjustments)

2. **Transaction Clearing**
   - Only unreconciled transactions can be cleared
   - Cleared date must be >= transaction date
   - Void transactions cannot be cleared

3. **Record Count Validation**
   - If configured, deposit count must match statement
   - If configured, check count must match statement

4. **Outstanding Items**
   - Uncleared transactions remain outstanding
   - Outstanding items carry forward to next reconciliation

### Period-End Rules

1. **Closing Prerequisites**
   - All bank accounts must be reconciled
   - No transactions with future dates
   - GL transfer must be allowed

2. **Purging Rules**
   - Only reconciled transactions before purge date
   - Maintains audit trail in history
   - Cannot purge current period transactions

3. **GL Transfer Rules**
   - Transactions must be marked for GL transfer
   - Creates journal entries with proper debits/credits
   - Maintains reference between bank transaction and GL entry

## Integration Points

### General Ledger Integration

- Posts journal entries for bank transactions
- Updates GL account balances
- Maintains audit trail between modules

### Accounts Payable Integration

- Receives payment information for vendor checks
- Updates vendor payment records
- Processes computer-generated checks

### Accounts Receivable Integration

- Receives deposit information from customer payments
- Updates customer payment records
- Processes deposit slips

### Payroll Integration

- Receives payroll check information
- Processes direct deposit files
- Updates employee payment records

### Currency Management

- Retrieves exchange rates
- Calculates foreign currency conversions
- Posts exchange gains/losses

## Workflow Processes

### Standard Reconciliation Workflow

1. **Preparation Phase**
   - Receive bank statement
   - Print outstanding items report
   - Review unreconciled transactions

2. **Reconciliation Phase**
   - Enter statement information
   - Mark cleared transactions
   - Add adjustments (fees, interest)
   - Investigate discrepancies

3. **Completion Phase**
   - Verify balanced
   - Complete reconciliation
   - Print reconciliation report
   - Update GL if configured

### Check Processing Workflow

1. **Check Creation**
   - Record check information
   - Assign check number
   - Distribute to GL accounts

2. **Check Printing** (if computer check)
   - Generate check batch
   - Print checks
   - Update check numbers

3. **Check Clearing**
   - Mark as cleared during reconciliation
   - Update cleared date
   - Reconcile with bank statement

### ACH Processing Workflow

1. **File Generation**
   - Compile electronic payments
   - Generate ACH file format
   - Apply bank specifications

2. **File Transmission**
   - Transmit to bank
   - Receive confirmation
   - Update transmission log

3. **Settlement**
   - Monitor bank account
   - Reconcile ACH transactions
   - Handle returns/corrections

## Events

### Bank Account Events

- `BankAccountCreated`
- `BankAccountUpdated`
- `BankAccountDeactivated`
- `BankAccountReactivated`

### Transaction Events

- `DepositRecorded`
- `CheckRecorded`
- `BankTransferRecorded`
- `TransactionVoided`
- `TransactionModified`
- `BankBalanceIncreased`
- `BankBalanceDecreased`
- `BankBalanceAdjusted`

### Reconciliation Events

- `ReconciliationStarted`
- `TransactionCleared`
- `TransactionUncleared`
- `ReconciliationAdjustmentAdded`
- `ReconciliationCompleted`
- `ReconciliationCancelled`
- `TransactionsReconciled`
- `StatementBalanceUpdated`
- `ClearedTransactionsReverted`

### Recurring Events

- `RecurringTemplateCreated`
- `RecurringTemplateUpdated`
- `RecurringTemplateDeactivated`
- `RecurringTransactionGenerated`

### Period Events

- `PeriodClosed`
- `TransactionsTransferredToGL`
- `HistoricalTransactionsPurged`

## Error Handling

### Validation Errors

- Invalid bank account
- Insufficient funds
- Invalid GL accounts
- Distribution percentage mismatch
- Duplicate reference numbers
- Invalid date ranges

### Reconciliation Errors

- Out of balance
- Record count mismatch
- Missing required clearances
- Invalid adjustments

### Integration Errors

- GL module unavailable
- Currency conversion failure
- ACH file generation error
- External system communication failure

## Audit and Compliance

### Audit Trail Requirements

- All transactions timestamped
- User identification on all actions
- Reason codes for voids and adjustments
- Before/after values for modifications
- Reconciliation history maintained

### Compliance Features

- Positive pay file generation
- ACH format compliance
- Check fraud prevention
- Bank statement retention
- Segregation of duties support

## Performance Considerations

### Transaction Volume

- Support high-volume transaction entry
- Batch processing capabilities
- Efficient clearing during reconciliation

### Reconciliation Performance

- Quick transaction matching
- Optimized balance calculations
- Efficient outstanding item queries

### Reporting Performance

- Cached balance calculations
- Indexed transaction searches
- Optimized period-end processinng

# Bank Reconciliation Business Logic

## Overview

The Bank Reconciliation module manages the recording, tracking, and reconciliation of all bank-related transactions within the Accountex system. It provides comprehensive functionality for managing deposits, disbursements, transfers, and the reconciliation process between company records and bank statements.

## Core Domain Entities

### BankAccount

Represents a bank account maintained by the company.

**Attributes:**

- `bank_id` - Unique identifier for the bank account
- `bank_name` - Name of the bank account
- `account_type` - Type of account (checking, savings, other)
- `account_number` - Bank account number
- `routing_number` - Bank routing number
- `gl_account_id` - Associated General Ledger account
- `currency_code` - Currency denomination of the account
- `check_format` - Format for computer-generated checks
- `next_check_number` - Next available check number for computer checks
- `next_deposit_number` - Next available deposit number
- `use_system_generated_deposit_number` - Boolean flag for auto-numbering
- `current_balance` - Current calculated balance in the system
- `previous_statement_balance` - Balance from last reconciled statement
- `ending_statement_balance` - Balance from current statement being reconciled
- `last_reconciliation_date` - Date of last completed reconciliation
- `status` - Active/Inactive status

**Business Rules:**

- Bank account ID must be unique across the system
- GL Account ID must exist and be valid
- Currency code must exist in the system
- Cannot delete bank account with current activities
- All checks must use same starting check number within an account
- Deposit numbers must be sequential if system-generated

### TransactionCode

Defines categorization for bank transactions.

**Attributes:**

- `transaction_code` - Unique code identifier (max 10 characters)
- `transaction_type` - Receipt, Disbursement, or Transfer
- `description` - Description of the transaction type
- `require_document_number` - Whether check/deposit number is required
- `status` - Active/Inactive
- `reference_accounts` - List of GL accounts with distribution percentages

**Business Rules:**

- Transaction code must be unique
- Total distribution percentage must equal 100%
- Cannot delete if used in existing transactions
- Transfer type codes cannot have reference accounts
- Receipt/Disbursement codes requiring document numbers can only be used in corresponding functions

### BankDeposit

Represents deposits and other receipts into bank accounts.

**Attributes:**

- `deposit_id` - Unique identifier
- `bank_id` - Bank account receiving the deposit
- `deposit_number` - Deposit slip/reference number
- `deposit_date` - Date of deposit
- `transaction_code` - Classification code
- `amount` - Total deposit amount
- `memo` - Description/notes
- `gl_distributions` - List of GL account distributions
- `reconciliation_status` - Unreconciled/Cleared/Verified
- `statement_date` - Bank statement date when cleared
- `transfer_to_gl` - Flag for GL posting

**Business Rules:**

- Deposit date cannot be in a closed period
- Amount must be greater than zero
- GL distributions must balance to deposit amount
- Cannot modify after reconciliation verified
- Deposit number required if transaction code requires it

### BankDisbursement

Represents checks and other disbursements from bank accounts.

**Attributes:**

- `disbursement_id` - Unique identifier
- `bank_id` - Bank account for disbursement
- `check_number` - Check/reference number
- `disbursement_date` - Date of disbursement
- `transaction_code` - Classification code
- `payee` - Recipient of payment
- `amount` - Disbursement amount
- `memo` - Description/notes
- `gl_distributions` - List of GL account distributions
- `reconciliation_status` - Unreconciled/Cleared/Verified/Voided
- `void_date` - Date check was voided (if applicable)
- `statement_date` - Bank statement date when cleared
- `transfer_to_gl` - Flag for GL posting

**Business Rules:**

- Cannot use check number already used in same bank account
- Amount must be greater than zero
- GL distributions must balance to disbursement amount
- Cannot modify after reconciliation verified
- Check number required if transaction code requires it
- Voided checks cannot be modified or deleted

### BankTransfer

Represents transfers between bank accounts.

**Attributes:**

- `transfer_id` - Unique identifier
- `from_bank_id` - Source bank account
- `to_bank_id` - Destination bank account
- `transfer_date` - Date of transfer
- `amount` - Transfer amount
- `from_transaction_code` - Transaction code for source account
- `to_transaction_code` - Transaction code for destination account
- `memo` - Description/notes
- `from_reconciliation_status` - Status in source account
- `to_reconciliation_status` - Status in destination account
- `transfer_to_gl` - Flag for GL posting

**Business Rules:**

- Cannot transfer between same account
- Both bank accounts must be active
- Amount must be greater than zero
- Transfer date cannot be in closed period
- Both sides must be reconciled together

### BankStatement

Represents a bank statement for reconciliation.

**Attributes:**

- `statement_id` - Unique identifier
- `bank_id` - Associated bank account
- `statement_date` - Statement ending date
- `beginning_balance` - Opening balance per bank
- `ending_balance` - Closing balance per bank
- `total_deposits` - Total deposits per bank
- `total_disbursements` - Total disbursements per bank
- `deposit_count` - Number of deposits
- `disbursement_count` - Number of disbursements
- `adjustments` - List of reconciliation adjustments
- `reconciliation_status` - In Progress/Completed
- `reconciled_by` - User who completed reconciliation
- `reconciliation_date` - Date reconciliation completed

**Business Rules:**

- Beginning balance must match previous statement ending balance
- Statement date must be after previous statement date
- Cannot have multiple open reconciliations for same account
- Must balance before completion

### ReconciliationAdjustment

Represents adjustments made during reconciliation.

**Attributes:**

- `adjustment_id` - Unique identifier
- `statement_id` - Associated bank statement
- `adjustment_type` - Service Charge, Interest, NSF, Other
- `amount` - Adjustment amount
- `gl_account_id` - GL account for posting
- `description` - Description of adjustment

**Business Rules:**

- Must have valid GL account
- Amount can be positive or negative
- Created only during reconciliation process

## Commands and Events

### Bank Account Management

**Commands:**

- `CreateBankAccount` - Creates new bank account
- `UpdateBankAccount` - Updates bank account details
- `DeactivateBankAccount` - Marks account as inactive
- `UpdateBankBalance` - Updates current balance

**Events:**

- `BankAccountCreated` - Bank account created
- `BankAccountUpdated` - Bank account details updated
- `BankAccountDeactivated` - Bank account marked inactive
- `BankBalanceUpdated` - Balance updated

### Transaction Recording

**Commands:**

- `RecordDeposit` - Records a deposit/receipt
- `RecordDisbursement` - Records a check/disbursement
- `RecordTransfer` - Records a bank transfer
- `VoidDisbursement` - Voids a check
- `UpdateTransaction` - Updates transaction details
- `DeleteTransaction` - Removes unreconciled transaction

**Events:**

- `DepositRecorded` - Deposit transaction created
- `DisbursementRecorded` - Disbursement transaction created
- `TransferRecorded` - Transfer transaction created
- `DisbursementVoided` - Check marked as void
- `TransactionUpdated` - Transaction details modified
- `TransactionDeleted` - Transaction removed

### Bank Reconciliation

**Commands:**

- `StartReconciliation` - Begins reconciliation process
- `MarkTransactionCleared` - Marks transaction as cleared
- `UnmarkTransactionCleared` - Removes cleared status
- `AddReconciliationAdjustment` - Adds adjustment entry
- `CompleteReconciliation` - Finalizes reconciliation
- `CancelReconciliation` - Cancels in-progress reconciliation

**Events:**

- `ReconciliationStarted` - Reconciliation process begun
- `TransactionCleared` - Transaction matched to statement
- `TransactionUncleared` - Cleared status removed
- `AdjustmentAdded` - Reconciliation adjustment created
- `ReconciliationCompleted` - Reconciliation finalized
- `ReconciliationCancelled` - Reconciliation abandoned

### Period Processing

**Commands:**

- `ClosePeriod` - Closes accounting period
- `TransferToGeneralLedger` - Posts transactions to GL
- `PurgeTransactions` - Removes old reconciled transactions

**Events:**

- `PeriodClosed` - Accounting period closed
- `TransactionsTransferredToGL` - Journal entries posted
- `TransactionsPurged` - Old transactions removed

## Business Workflows

### Deposit Recording Workflow

1. **Initiate Deposit**
   - Validate bank account exists and is active
   - Validate deposit date not in closed period
   - Generate deposit number if system-generated

2. **Apply Transaction Code**
   - Verify transaction code is active
   - Verify transaction code type is Receipt
   - Apply deposit number requirement rules

3. **Distribute to GL Accounts**
   - Default GL accounts from transaction code
   - Allow override of accounts and percentages
   - Validate total distribution equals 100%

4. **Calculate Balances**
   - Update bank account current balance
   - Mark for GL transfer if configured

5. **Save Transaction**
   - Generate DepositRecorded event
   - Update audit trail

### Disbursement Recording Workflow

1. **Initiate Disbursement**
   - Validate bank account exists and is active
   - Validate check number not already used
   - Validate disbursement date not in closed period

2. **Apply Transaction Code**
   - Verify transaction code is active
   - Verify transaction code type is Disbursement
   - Apply check number requirement rules

3. **Distribute to GL Accounts**
   - Default GL accounts from transaction code
   - Allow override of accounts and percentages
   - Validate total distribution equals 100%

4. **Calculate Balances**
   - Update bank account current balance
   - Mark for GL transfer if configured

5. **Save Transaction**
   - Generate DisbursementRecorded event
   - Update audit trail

### Bank Transfer Workflow

1. **Initiate Transfer**
   - Validate both bank accounts exist and are active
   - Validate accounts are different
   - Validate transfer date not in closed period

2. **Apply Transaction Codes**
   - Apply withdrawal code to source account
   - Apply deposit code to destination account
   - Both must be Transfer type

3. **Process Transfer**
   - Decrease source account balance
   - Increase destination account balance
   - Create linked transactions in both accounts

4. **Save Transactions**
   - Generate TransferRecorded event
   - Update audit trails for both accounts

### Bank Reconciliation Workflow

1. **Initialize Reconciliation**
   - Verify no other reconciliation in progress
   - Load previous statement balance
   - Enter current statement details

2. **Load Transactions**
   - Retrieve all unreconciled deposits
   - Retrieve all unreconciled disbursements
   - Retrieve all unreconciled transfers
   - Include transactions up to statement date

3. **Match Transactions**
   - Mark deposits that appear on statement
   - Mark disbursements that cleared bank
   - Handle outstanding items

4. **Process Adjustments**
   - Add service charges
   - Add interest earned
   - Add NSF or other adjustments
   - Create GL distributions for adjustments

5. **Balance Reconciliation**
   - Calculate adjusted bank balance
   - Calculate adjusted book balance
   - Verify balances match

6. **Complete Reconciliation**
   - Mark cleared transactions as verified
   - Update statement balances
   - Generate ReconciliationCompleted event
   - Create adjustment transactions if needed

### Check Voiding Workflow

1. **Identify Check**
   - Locate disbursement by check number
   - Verify check not already voided
   - Verify check not reconciled

2. **Process Void**
   - Mark disbursement as voided
   - Reverse GL distributions
   - Update bank balance

3. **Update Records**
   - Generate DisbursementVoided event
   - Maintain audit trail of void

### Period-End Closing Workflow

1. **Validate Prerequisites**
   - Ensure all reconciliations complete
   - Verify no unbalanced transactions
   - Check GL transfer settings

2. **Transfer to General Ledger**
   - Collect all transactions marked for transfer
   - Group by GL account
   - Create journal entries
   - Post to GL if configured

3. **Purge Old Transactions**
   - Identify transactions before purge date
   - Verify transactions are reconciled
   - Remove from active files
   - Archive if configured

4. **Advance Period**
   - Update current period
   - Reset period counters
   - Generate PeriodClosed event

## Integration Points

### General Ledger Integration

- Post journal entries for all bank transactions
- Update GL account balances
- Respect GL period closings
- Handle multi-currency postings

### Accounts Payable Integration

- Import AP computer checks
- Share vendor payment information
- Prevent duplicate check numbers
- Handle AP payment voids

### Payroll Integration

- Import payroll checks
- Track employee payments
- Handle direct deposits
- Process payroll voids

### Currency Management

- Support multi-currency accounts
- Calculate exchange gains/losses
- Handle currency conversions
- Update exchange rates

## Validation Rules

### Transaction Validation

- Dates must be within open periods
- Amounts must be positive
- GL distributions must balance
- Document numbers must be unique within account
- Transaction codes must be active

### Reconciliation Validation

- Statement date must be after previous statement
- Beginning balance must match previous ending
- All adjustments must have GL accounts
- Reconciliation must balance before completion
- Cannot have overlapping reconciliations

### Balance Validation

- Running balances must be maintained
- Reconciled balance must match statement
- GL postings must balance
- Currency conversions must balance

## Reporting Requirements

### Transaction Reports

- Deposit listing by date range
- Check register by date range
- Transfer listing
- Outstanding items report
- Void check report

### Reconciliation Reports

- Bank reconciliation statement
- Reconciliation history
- Adjustment detail report
- Outstanding check aging

### GL Integration Reports

- GL transfer report
- Journal entry preview
- Posting audit trail
- Period-end summary

## Security and Audit

### Access Control

- Bank account level security
- Transaction type permissions
- Reconciliation approval rights
- Void authorization
- Period closing rights

### Audit Trail

- All transactions logged with user/timestamp
- Modification history maintained
- Void reasons tracked
- Reconciliation approvals recorded
- Balance change history

## Multi-Currency Considerations

### Exchange Rate Management

- Current rates by currency
- Historical rate tracking
- Rate change audit trail

### Foreign Currency Transactionns

- Convert at transaction date
- Calculate realized gains/losses
- Track unrealized gains/losses
- Handle settlement differences

### Reconciliation in Foreign Currency

- Statement in foreign currency
- Convert for GL posting
- Track exchange differences
- Adjust for rate changes

## Recurring Transaction Support

### Template Management

- Create recurring templates
- Set frequency and schedule
- Define expiration rules
- Track generation history

### Automatic Generation

- Process on schedule
- Apply current dates
- Increment document numbers
- Handle skipped periods

## Data Retention

### Active Transaction Retention

- Keep unreconciled indefinitely
- Keep current period transactions
- Maintain based on business rules

### Historical Data

- Archive reconciled transactions
- Compress old statements
- Maintain audit requirements
- Support historical reporting
