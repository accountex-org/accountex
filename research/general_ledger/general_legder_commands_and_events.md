# Accountex General Ledger - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the General Ledger domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework with strict double-entry bookkeeping principles.

## Chart of Accounts Management Commands and Events

### Account Management

#### CreateAccount Command
**Purpose**: Creates a new GL account in the chart of accounts.

**Description**: Establishes new general ledger account with proper validation including account code uniqueness, hierarchical positioning, and account type consistency. Validates account structure and initializes account for transaction processing.

**Parameters**:
- `account_id`: Unique account identifier
- `account_code`: Unique account code within chart
- `name`: Descriptive account name
- `account_type`: Account classification (asset, liability, equity, revenue, expense)
- `normal_balance`: Natural balance side (debit, credit)
- `parent_account_id`: Parent account for hierarchy
- `currency_code`: Account currency (default USD)
- `is_header_account`: Whether account accepts direct transactions
- `is_system_account`: Whether account is protected system account

**Business Rules**:
- Account code must be unique within chart of accounts
- Account type must align with hierarchical position
- Parent accounts cannot have direct transactions
- System accounts cannot be modified after setup
- Normal balance must align with account type

---

#### ModifyAccount Command
**Purpose**: Modifies existing GL account properties with validation.

**Description**: Updates existing account information with proper authorization and validation. Maintains account integrity while allowing necessary modifications with appropriate controls and audit trails.

**Parameters**:
- `account_id`: Account to modify
- `name`: Updated account name
- `description`: Updated description
- `status`: New account status
- `parent_account_id`: Updated parent account
- `modified_by`: User making modification
- `modification_reason`: Justification for change

**Business Rules**:
- Cannot change fundamental properties like account type or code
- No posted transactions can exist for accounts being deactivated
- Hierarchy changes must maintain logical consistency
- System accounts are protected from modification
- Authorization required for significant changes

---

#### DeactivateAccount Command
**Purpose**: Deactivates GL account with proper validation and cleanup.

**Description**: Safely deactivates account including validation of zero balance, no active transactions, and proper handling of child accounts. Maintains referential integrity and audit requirements.

**Parameters**:
- `account_id`: Account to deactivate
- `deactivation_reason`: Reason for deactivation
- `cascade_to_children`: Whether to deactivate child accounts
- `effective_date`: When deactivation becomes effective
- `authorized_by`: User authorizing deactivation

**Business Rules**:
- Account balance must be zero
- No unposted transactions can exist
- Child accounts must be handled appropriately
- Authorization required for deactivation
- System accounts cannot be deactivated

---

### Chart of Accounts Events

#### AccountCreated Event
**Purpose**: Records creation of new GL account.

**Description**: Emitted when GL account is successfully created. Contains complete account information and triggers initialization of account balances, projections, and integration notifications.

**Data**:
- `account_id`: Created account identifier
- `account_code`: Account code assigned
- `name`: Account name
- `account_type`: Account classification
- `normal_balance`: Balance side (debit/credit)
- `parent_account_id`: Parent account reference
- `currency_code`: Account currency
- `created_at`: Creation timestamp
- `created_by`: Creating user

**Downstream Effects**:
- Updates chart of accounts projection
- Initializes account balance records for all periods
- Notifies integrated modules of new account
- Creates account audit trail entry

---

#### AccountModified Event
**Purpose**: Records modifications to existing GL account.

**Description**: Emitted when account properties are successfully modified. Contains before/after values and triggers appropriate updates to projections and related systems.

**Data**:
- `account_id`: Modified account
- `changes`: Map of changed fields with old/new values
- `modified_by`: User making changes
- `modification_reason`: Reason for changes
- `modified_at`: Modification timestamp

**Downstream Effects**:
- Updates chart of accounts projections
- Notifies modules using the account
- Updates account hierarchy if changed
- Creates modification audit trail

---

#### AccountDeactivated Event
**Purpose**: Records account deactivation with effective date and reason.

**Description**: Emitted when account is successfully deactivated. Prevents future transactions and triggers cleanup activities while maintaining historical data integrity.

**Data**:
- `account_id`: Deactivated account
- `effective_date`: Deactivation effective date
- `deactivation_reason`: Reason for deactivation
- `cascade_to_children`: Whether children were also deactivated
- `deactivated_by`: Authorizing user

**Downstream Effects**:
- Prevents new transactions to account
- Updates account status projections
- Triggers account cleanup procedures
- Maintains historical transaction access

---

## Journal Entry Management Commands and Events

### Journal Entry Processing

#### CreateJournalEntry Command
**Purpose**: Creates new journal entry with double-entry validation.

**Description**: Creates journal entry ensuring double-entry bookkeeping principles including balance validation, account validation, and period checking. Supports manual, automatic, and recurring entry types.

**Parameters**:
- `journal_entry_id`: Unique entry identifier
- `journal_date`: Date of journal entry
- `posting_date`: Date for posting to periods
- `description`: Entry description
- `reference_number`: External reference
- `journal_type`: Type (manual, automatic, recurring, reversing)
- `source_module`: Originating module if automatic
- `source_document_id`: Source document reference
- `lines`: Array of journal entry lines with accounts and amounts
- `created_by`: User creating entry

**Business Rules**:
- Total debits must equal total credits
- Each line must reference valid, active account
- Posting dates must fall within open fiscal periods
- Unique transaction reference required for audit
- Minimum of two journal lines required

---

#### PostJournalEntry Command
**Purpose**: Posts draft journal entry to general ledger.

**Description**: Finalizes journal entry by posting to general ledger including final validation, balance updates, and immutability enforcement. Creates permanent financial record with audit trail.

**Parameters**:
- `journal_entry_id`: Entry to post
- `posting_user`: User authorizing posting
- `posting_timestamp`: When posting occurred
- `approval_reference`: Approval documentation if required
- `force_post`: Override certain validations if authorized

**Business Rules**:
- Final validation of account statuses and period locks
- Balance equation must be satisfied
- Posted entries become immutable
- Posting authority validation
- Period must still be open for posting

---

#### ReverseJournalEntry Command
**Purpose**: Creates reversing entry for posted journal entry.

**Description**: Creates exact opposite of posted journal entry for correction purposes including automatic line reversal, proper dating, and audit trail maintenance.

**Parameters**:
- `original_entry_id`: Entry to reverse
- `reversal_date`: Date for reversal entry
- `reversal_reason`: Reason for reversal
- `auto_post`: Whether to automatically post reversal
- `authorized_by`: User authorizing reversal

**Business Rules**:
- Original entry must be posted
- Reversal date must be in open period
- Authorization required for reversal
- Cannot reverse already reversed entries
- Creates exact opposite entry

---

#### CreateRecurringEntry Command
**Purpose**: Creates template for recurring journal entries.

**Description**: Establishes recurring journal entry template including schedule definition, account distributions, and automatic posting configuration. Enables automated journal entry generation.

**Parameters**:
- `template_id`: Recurring template identifier
- `template_name`: Descriptive template name
- `recurrence_pattern`: Frequency (daily, weekly, monthly, quarterly, yearly)
- `start_date`: When recurring entries begin
- `end_date`: When recurring entries end (if applicable)
- `auto_post`: Whether entries should auto-post
- `journal_lines`: Template for journal entry lines
- `notification_recipients`: Users to notify on generation

**Business Rules**:
- Template must have balanced journal lines
- All referenced accounts must be active
- Recurrence pattern must be valid
- Auto-post requires appropriate authorization
- Template validation for future date ranges

---

### Journal Entry Events

#### JournalEntryCreated Event
**Purpose**: Records creation of new journal entry.

**Description**: Emitted when journal entry is successfully created in draft state. Contains entry details and triggers validation and approval workflows.

**Data**:
- `journal_entry_id`: Created entry identifier
- `journal_date`: Entry date
- `posting_date`: Intended posting date
- `description`: Entry description
- `journal_type`: Entry type
- `total_amount`: Total entry amount
- `line_count`: Number of journal lines
- `created_by`: Creating user
- `source_module`: Source if automatic

**Downstream Effects**:
- Updates draft journal entry projections
- Triggers approval workflow if required
- Creates entry audit trail
- Validates accounts and amounts

---

#### JournalEntryPosted Event
**Purpose**: Records posting of journal entry to general ledger.

**Description**: Emitted when journal entry is successfully posted with permanent effect. Triggers account balance updates, transaction history updates, and integration notifications.

**Data**:
- `journal_entry_id`: Posted entry identifier
- `posting_date`: Actual posting date
- `journal_lines`: Complete journal entry lines
- `total_debits`: Total debit amounts
- `total_credits`: Total credit amounts
- `posted_by`: User posting entry
- `posted_at`: Posting timestamp
- `source_module`: Originating module
- `source_document_id`: Source document reference

**Downstream Effects**:
- Updates account balances for all affected accounts
- Updates transaction history projections
- Updates period totals and trial balance
- Publishes to system event bus for integration
- Triggers Jido agents for dependent workflows

---

#### JournalEntryReversed Event
**Purpose**: Records reversal of previously posted journal entry.

**Description**: Emitted when journal entry is successfully reversed. Contains reversal details and triggers balance corrections and audit trail updates.

**Data**:
- `original_entry_id`: Entry being reversed
- `reversal_entry_id`: New reversing entry
- `reversal_date`: Date of reversal
- `reversal_reason`: Reason for reversal
- `reversal_lines`: Reversing journal lines
- `authorized_by`: User authorizing reversal
- `auto_posted`: Whether reversal was automatically posted

**Downstream Effects**:
- Creates offsetting journal entry
- Updates account balances with reversal
- Updates audit trail and transaction history
- Notifies relevant stakeholders

---

#### AccountBalanceUpdated Event
**Purpose**: Records account balance changes from journal posting.

**Description**: Emitted when account balance changes due to journal entry posting. Provides detailed balance change information for real-time balance tracking and reconciliation.

**Data**:
- `account_id`: Account with balance change
- `previous_balance`: Balance before transaction
- `transaction_amount`: Amount of change
- `new_balance`: Balance after transaction
- `balance_type`: Whether debit or credit balance
- `journal_entry_id`: Source journal entry
- `period_id`: Fiscal period affected
- `updated_at`: Update timestamp

**Downstream Effects**:
- Updates real-time balance projections
- Triggers balance monitoring and alerts
- Updates trial balance calculations
- Enables real-time financial reporting

---

## Fiscal Period Management Commands and Events

### Period Operations

#### OpenFiscalPeriod Command
**Purpose**: Opens new fiscal period for transaction processing.

**Description**: Creates and opens new fiscal period including sequential validation, date range setup, and period initialization. Establishes period for transaction posting and reporting.

**Parameters**:
- `period_id`: Unique period identifier
- `period_number`: Sequential period number
- `fiscal_year`: Fiscal year for period
- `start_date`: Period start date
- `end_date`: Period end date
- `period_type`: Type (regular, adjustment, year_end)
- `opened_by`: User opening period

**Business Rules**:
- Periods must open in sequential order
- Prior periods must be properly closed or remain open per configuration
- Date ranges cannot overlap with existing periods
- Period-specific projections must be initialized
- Authorization required for period opening

---

#### CloseFiscalPeriod Command
**Purpose**: Closes fiscal period with validation and cleanup.

**Description**: Executes fiscal period closing including closing checklist validation, sub-ledger reconciliation, trial balance generation, and period lockdown. Ensures period integrity before closing.

**Parameters**:
- `period_id`: Period to close
- `closing_type`: Type of closing (soft_close, hard_close)
- `reconciliation_status`: Status of all reconciliation activities
- `adjustment_entries`: Final adjustment entries for period
- `closed_by`: User authorizing closure
- `closing_notes`: Special notes or conditions

**Business Rules**:
- Executes comprehensive closing checklist validations
- Sub-ledger reconciliation required and complete
- Trial balance must be balanced
- All transactions must be posted
- Authorization required for period closing

---

#### ReopenPeriod Command
**Purpose**: Reopens previously closed period for corrections.

**Description**: Reopens closed fiscal period for posting corrections or adjustments including validation of reopening authority, impact analysis, and proper controls.

**Parameters**:
- `period_id`: Period to reopen
- `reopen_reason`: Justification for reopening
- `reopened_by`: User authorizing reopening
- `reopen_scope`: Scope of reopening (full, restricted)
- `automatic_reclose`: Whether to automatically reclose after corrections

**Business Rules**:
- High-level authorization required for reopening
- Impact analysis on subsequent periods required
- Restricted scope may limit transaction types
- Audit trail for reopening activities
- May require reprocessing of subsequent periods

---

#### ExecuteYearEndClose Command
**Purpose**: Executes comprehensive year-end closing procedures.

**Description**: Performs year-end closing including income statement account closure, retained earnings calculation, tax provisions, and new year initialization.

**Parameters**:
- `fiscal_year`: Year being closed
- `closing_entries`: Income statement closing entries
- `retained_earnings_account_id`: Target for income closure
- `tax_provisions`: Tax provision adjustments
- `carry_forward_rules`: Rules for balance sheet account carryover
- `executed_by`: User executing year-end close

**Business Rules**:
- All periods in fiscal year must be closed
- Income statement accounts closed to retained earnings
- Balance sheet accounts carried forward to new year
- Tax provisions must be complete and accurate
- Comprehensive validation before execution

---

### Period Events

#### FiscalPeriodOpened Event
**Purpose**: Records opening of new fiscal period.

**Description**: Emitted when fiscal period is successfully opened for transaction processing. Establishes period context and enables transaction posting.

**Data**:
- `period_id`: Opened period identifier
- `period_number`: Sequential period number
- `fiscal_year`: Fiscal year
- `start_date`: Period start date
- `end_date`: Period end date
- `period_type`: Type of period
- `opened_by`: User opening period
- `opened_at`: Opening timestamp

**Downstream Effects**:
- Enables transaction posting to period
- Initializes period-specific projections
- Updates fiscal calendar status
- Creates period audit trail

---

#### PeriodClosed Event
**Purpose**: Records successful closure of fiscal period.

**Description**: Emitted when fiscal period is successfully closed with all validations passed. Contains period summary and triggers post-closing activities.

**Data**:
- `period_id`: Closed period identifier
- `fiscal_year`: Fiscal year
- `period_number`: Period number
- `closing_type`: Type of closure performed
- `trial_balance`: Period trial balance snapshot
- `closing_entries`: List of closing adjustment entries
- `closed_at`: Closure timestamp
- `closed_by`: User authorizing closure

**Downstream Effects**:
- Locks period against new transactions
- Creates period snapshot for reporting
- Triggers post-closing procedures
- Updates period status projections

---

#### YearEndCloseCompleted Event
**Purpose**: Records completion of year-end closing process.

**Description**: Emitted when year-end closing successfully completes with all income accounts closed and new year initialized. Marks major fiscal milestone.

**Data**:
- `fiscal_year`: Year that was closed
- `closing_entries_posted`: Income statement closing entries
- `retained_earnings_adjustment`: Amount transferred to retained earnings
- `new_year_initialized`: Whether new fiscal year was created
- `tax_provisions`: Final tax provision amounts
- `completed_at`: Completion timestamp

**Downstream Effects**:
- Completes fiscal year and begins new year
- Triggers annual financial statement preparation
- Updates multi-year financial projections
- Creates year-end audit trail and documentation

---

## Budget Management Commands and Events

### Budget Processing

#### CreateBudget Command
**Purpose**: Creates new budget for fiscal period with account allocations.

**Description**: Establishes budget including account-level budget amounts, approval workflows, and variance monitoring setup. Supports multiple budget types and scenarios.

**Parameters**:
- `budget_id`: Unique budget identifier
- `budget_type`: Type (operating, capital, cash_flow)
- `fiscal_year`: Budget fiscal year
- `budget_accounts`: Account-level budget amounts
- `approval_workflow`: Required approvals
- `variance_thresholds`: Monitoring thresholds
- `created_by`: User creating budget

**Business Rules**:
- Budget amounts must be reasonable and justified
- All budgeted accounts must exist and be active
- Budget approval workflow must be configured
- Variance thresholds within policy limits
- Budget authorization appropriate for amounts

---

#### ApproveBudget Command
**Purpose**: Approves budget for activation and monitoring.

**Description**: Authorizes budget for use including final validation, approval authority verification, and activation for variance monitoring and spending authorization.

**Parameters**:
- `budget_id`: Budget to approve
- `approved_by`: User providing approval
- `approval_level`: Authority level exercised
- `approval_conditions`: Any conditions or restrictions
- `variance_monitoring`: Monitoring configuration
- `effective_date`: When budget becomes active

**Business Rules**:
- Approval authority must be sufficient for budget amounts
- Budget validation must pass all checks
- Effective date must be appropriate for fiscal year
- Variance monitoring configuration required

---

#### RevisieBudget Command
**Purpose**: Revises existing budget with proper authorization and audit trail.

**Description**: Updates approved budget including revision justification, approval workflow, and impact analysis on spending authorizations and variance calculations.

**Parameters**:
- `budget_id`: Budget to revise
- `revision_reason`: Justification for revision
- `account_changes`: Specific account budget changes
- `revision_type`: Type of revision (increase, decrease, reallocation)
- `revised_by`: User requesting revision
- `approval_required`: Whether revision needs approval

**Business Rules**:
- Budget revisions require appropriate authorization
- Revision impact analysis required
- Significant revisions may require board approval
- Audit trail maintained for all revisions

---

#### MonitorBudgetVariance Command
**Purpose**: Monitors actual vs budget performance with automated alerting.

**Description**: Continuously monitors budget performance including variance calculation, threshold monitoring, and automated alerting for budget overruns or significant variances.

**Parameters**:
- `monitoring_id`: Monitoring process identifier
- `budget_id`: Budget being monitored
- `monitoring_period`: Period for variance calculation
- `variance_thresholds`: Alert thresholds
- `alert_recipients`: Users to notify of variances

**Business Rules**:
- Variance calculations must be accurate and timely
- Alert thresholds based on account and amount significance
- Notification requirements based on variance severity
- Real-time monitoring for critical accounts

---

### Budget Events

#### BudgetCreated Event
**Purpose**: Records creation of new budget.

**Description**: Emitted when budget is successfully created with account allocations. Contains budget structure and triggers approval workflow.

**Data**:
- `budget_id`: Created budget identifier
- `budget_type`: Type of budget
- `fiscal_year`: Budget year
- `total_budget_amount`: Total budget amount across all accounts
- `account_count`: Number of accounts with budget allocations
- `created_by`: User creating budget
- `approval_required`: Whether approval workflow triggered

**Downstream Effects**:
- Triggers budget approval workflow if required
- Initializes budget monitoring and variance tracking
- Updates budget projections and reporting
- Creates budget audit trail

---

#### BudgetApproved Event
**Purpose**: Records budget approval and activation.

**Description**: Emitted when budget receives final approval and becomes active for spending authorization and variance monitoring.

**Data**:
- `budget_id`: Approved budget
- `approved_by`: Final approver
- `approval_level`: Authority level used
- `approved_at`: Approval timestamp
- `effective_date`: When budget becomes active
- `variance_thresholds`: Configured monitoring thresholds

**Downstream Effects**:
- Activates budget for spending authorization
- Enables variance monitoring and alerting
- Updates budget status projections
- Triggers budget communication to stakeholders

---

#### BudgetVarianceDetected Event
**Purpose**: Records detection of significant budget variance.

**Description**: Emitted when actual spending varies significantly from budget requiring attention or action. Triggers investigation and potential corrective actions.

**Data**:
- `budget_id`: Budget with variance
- `account_id`: Account with variance
- `budgeted_amount`: Budgeted amount for period
- `actual_amount`: Actual amount for period
- `variance_amount`: Variance amount
- `variance_percentage`: Variance as percentage
- `threshold_exceeded`: Which threshold was exceeded

**Downstream Effects**:
- Triggers variance investigation workflow
- Updates budget performance reporting
- Notifies relevant stakeholders
- May trigger corrective action procedures

---

## Integration and Transfer Commands and Events

### Sub-Ledger Integration

#### ProcessSubLedgerTransaction Command
**Purpose**: Processes journal entry from subsidiary ledger module.

**Description**: Validates and processes journal entries received from subsidiary ledgers including AR, AP, inventory, and payroll modules. Ensures GL integrity while enabling automated posting.

**Parameters**:
- `transaction_id`: Source transaction identifier
- `source_module`: Originating module (AR, AP, inventory, etc.)
- `journal_lines`: Journal entry lines from source
- `posting_date`: Date for GL posting
- `auto_post`: Whether to automatically post to GL
- `reference_data`: Additional reference information

**Business Rules**:
- Source module must be authorized for GL posting
- Journal lines must be balanced
- All referenced accounts must exist and be active
- Posting date must be in open period
- Auto-posting authorization validation

---

#### ReconcileSubLedger Command
**Purpose**: Reconciles subsidiary ledger with general ledger balances.

**Description**: Performs reconciliation between subsidiary ledger totals and general ledger control account balances including variance identification and resolution procedures.

**Parameters**:
- `reconciliation_id`: Reconciliation process identifier
- `sub_ledger_module`: Module being reconciled
- `reconciliation_period`: Period for reconciliation
- `control_accounts`: GL control accounts to reconcile
- `tolerance_settings`: Acceptable variance tolerances

**Business Rules**:
- Reconciliation must be performed for each period
- Variances outside tolerance require investigation
- Control accounts must match subsidiary ledger design
- Reconciliation timing requirements

---

#### TransferToGL Command
**Purpose**: Transfers summarized transactions from modules to GL.

**Description**: Processes summary transfer of transactions from subsidiary modules to general ledger including summarization, validation, and posting coordination.

**Parameters**:
- `transfer_id`: Transfer process identifier
- `source_module`: Module transferring data
- `transfer_period`: Period being transferred
- `summary_method`: How transactions are summarized
- `transfer_accounts`: Target GL accounts
- `validation_rules`: Validation requirements

**Business Rules**:
- Transfer authorization from source module required
- Summary method must preserve accounting accuracy
- All transfer accounts must be valid and active
- Transfer period must be appropriate

---

### Integration Events

#### SubLedgerTransactionReceived Event
**Purpose**: Records receipt of transaction from subsidiary ledger.

**Description**: Emitted when transaction is received from subsidiary module for GL processing. Contains transaction details and triggers validation and posting workflows.

**Data**:
- `transaction_id`: Source transaction identifier
- `source_module`: Originating module
- `transaction_type`: Type of transaction
- `journal_lines`: Journal entry lines
- `posting_date`: Intended posting date
- `auto_post`: Auto-posting configuration
- `reference_data`: Supporting information
- `received_at`: Receipt timestamp

**Downstream Effects**:
- Triggers GL validation workflow
- Creates journal entry for posting if valid
- Updates integration monitoring
- Generates rejection notification if invalid

---

#### SubLedgerReconciled Event
**Purpose**: Records successful reconciliation with subsidiary ledger.

**Description**: Emitted when subsidiary ledger reconciliation completes successfully with all variances resolved. Confirms GL and subsidiary ledger consistency.

**Data**:
- `reconciliation_id`: Reconciliation process
- `sub_ledger_module`: Reconciled module
- `reconciliation_period`: Period reconciled
- `control_account_balances`: Final GL control account balances
- `sub_ledger_balances`: Subsidiary ledger totals
- `variances_resolved`: Any variances that were resolved
- `reconciled_at`: Reconciliation completion timestamp

**Downstream Effects**:
- Confirms GL and subsidiary ledger accuracy
- Updates reconciliation status projections
- Triggers period-end processing continuation
- Creates reconciliation audit documentation

---

#### ModuleTransferCompleted Event
**Purpose**: Records successful transfer from subsidiary module.

**Description**: Emitted when module transfer to GL completes successfully. Contains transfer summary and triggers GL posting and reconciliation activities.

**Data**:
- `transfer_id`: Transfer process identifier
- `source_module`: Module that transferred data
- `transfer_period`: Period transferred
- `transaction_count`: Number of transactions transferred
- `total_amount`: Total amount transferred
- `summary_entries`: Summary journal entries created
- `completed_at`: Transfer completion timestamp

**Downstream Effects**:
- Creates GL journal entries for posting
- Updates module integration status
- Triggers reconciliation procedures
- Updates transfer performance metrics

---

## Allocation and Distribution Commands and Events

### Allocation Processing

#### ConfigureAllocation Command
**Purpose**: Configures automatic allocation rules for cost/revenue distribution.

**Description**: Sets up allocation rules including allocation bases, distribution methods, and target accounts. Enables automated allocation processing for period-end and ongoing operations.

**Parameters**:
- `allocation_id`: Allocation configuration identifier
- `allocation_name`: Descriptive allocation name
- `source_accounts`: Accounts being allocated from
- `target_accounts`: Accounts receiving allocation
- `allocation_method`: Method for calculating allocation
- `allocation_base`: Statistical base for allocation (square footage, headcount, etc.)
- `allocation_schedule`: When allocations should be processed

**Business Rules**:
- Allocation methods must be mathematically sound
- Source and target accounts must be valid
- Allocation base must be measurable and current
- Total allocation percentages must equal 100%

---

#### ProcessAllocation Command
**Purpose**: Executes allocation calculation and journal entry creation.

**Description**: Performs allocation processing including calculation execution, journal entry generation, and posting coordination. Handles complex multi-step allocations with validation.

**Parameters**:
- `allocation_id`: Allocation to process
- `processing_period`: Period for allocation processing
- `allocation_amounts`: Amounts to allocate by source account
- `override_percentages`: Any percentage overrides for this processing
- `auto_post`: Whether to automatically post allocation entries

**Business Rules**:
- Allocation base data must be current and accurate
- Source accounts must have sufficient balances for allocation
- All allocation calculations must balance
- Authorization required for allocation overrides

---

#### ValidateAllocation Command
**Purpose**: Validates allocation configuration and calculations.

**Description**: Performs comprehensive validation of allocation setup and calculations including mathematical validation, account validation, and policy compliance checking.

**Parameters**:
- `allocation_id`: Allocation to validate
- `validation_scope`: Scope of validation (configuration, calculation, both)
- `validation_period`: Period for calculation validation
- `tolerance_settings`: Acceptable tolerance for validation

**Business Rules**:
- All referenced accounts must exist and be appropriate
- Allocation calculations must be mathematically correct
- Allocation policies must be followed
- Validation must be comprehensive and accurate

---

### Allocation Events

#### AllocationConfigured Event
**Purpose**: Records configuration of new allocation rules.

**Description**: Emitted when allocation configuration is established. Contains allocation rules and triggers validation and monitoring setup.

**Data**:
- `allocation_id`: Configuration identifier
- `allocation_name`: Allocation description
- `allocation_method`: Calculation method configured
- `source_accounts`: Accounts being allocated from
- `target_accounts`: Accounts receiving allocation
- `allocation_schedule`: Processing schedule
- `configured_by`: User configuring allocation

**Downstream Effects**:
- Enables allocation processing
- Sets up allocation monitoring and validation
- Updates allocation configuration projections
- Creates allocation audit trail

---

#### AllocationProcessed Event
**Purpose**: Records completion of allocation processing.

**Description**: Emitted when allocation processing completes successfully with journal entries created. Contains allocation results and triggers posting and reconciliation.

**Data**:
- `allocation_id`: Processed allocation
- `processing_period`: Period processed
- `allocation_entries`: Generated journal entries
- `total_allocated`: Total amount allocated
- `allocation_base_used`: Statistical base used for calculation
- `processed_at`: Processing completion timestamp

**Downstream Effects**:
- Creates journal entries for posting
- Updates allocation processing history
- Triggers allocation reconciliation
- Updates allocation performance metrics

---

## Multi-Currency and Consolidation Commands and Events

### Currency Management

#### UpdateExchangeRate Command
**Purpose**: Updates foreign exchange rates for multi-currency processing.

**Description**: Updates exchange rates for foreign currencies including rate validation, historical tracking, and impact analysis on existing transactions and balances.

**Parameters**:
- `currency_code`: Currency being updated
- `new_exchange_rate`: Updated exchange rate
- `rate_date`: Effective date for new rate
- `rate_source`: Source of exchange rate
- `rate_type`: Type of rate (daily, average, closing)
- `auto_revalue`: Whether to automatically revalue balances

**Business Rules**:
- Exchange rates must be from authorized sources
- Rate changes must be reasonable (within tolerance)
- Historical rates must be preserved
- Rate effective dates must be logical

---

#### ProcessCurrencyRevaluation Command
**Purpose**: Processes currency revaluation for foreign currency balances.

**Description**: Performs currency revaluation including unrealized gain/loss calculation, revaluation adjustment entries, and multi-currency balance updates.

**Parameters**:
- `revaluation_id`: Revaluation process identifier
- `currency_codes`: Currencies to revalue
- `revaluation_date`: Date for revaluation
- `revaluation_method`: Method for revaluation calculation
- `target_accounts`: Accounts to revalue
- `post_adjustments`: Whether to post revaluation entries

**Business Rules**:
- Revaluation methods must follow accounting standards
- Only foreign currency balances are revalued
- Revaluation adjustments properly classified
- Authorization required for revaluation processing

---

#### InitiateConsolidation Command
**Purpose**: Initiates multi-company consolidation process.

**Description**: Begins consolidation process including subsidiary data gathering, elimination entry preparation, and consolidated statement preparation.

**Parameters**:
- `consolidation_id`: Consolidation process identifier
- `parent_company_id`: Parent company for consolidation
- `subsidiary_companies`: List of subsidiaries to consolidate
- `consolidation_period`: Period being consolidated
- `elimination_rules`: Inter-company elimination rules
- `translation_methods`: Currency translation methods

**Business Rules**:
- All subsidiary periods must be closed
- Elimination rules must be complete and accurate
- Currency translation methods must be consistent
- Consolidation authorization required

---

### Multi-Currency Events

#### ExchangeRateUpdated Event
**Purpose**: Records update to foreign exchange rates.

**Description**: Emitted when exchange rate is updated with new rate information. Triggers revaluation procedures and balance updates for affected currencies.

**Data**:
- `currency_code`: Updated currency
- `previous_rate`: Prior exchange rate
- `new_rate`: Updated exchange rate
- `rate_date`: Effective date
- `rate_source`: Source of rate update
- `rate_variance`: Change from previous rate
- `updated_by`: User or system updating rate

**Downstream Effects**:
- Triggers currency revaluation if configured
- Updates multi-currency transaction processing
- Updates currency rate projections
- May trigger balance revaluation

---

#### CurrencyRevaluationCompleted Event
**Purpose**: Records completion of currency revaluation process.

**Description**: Emitted when currency revaluation completes with unrealized gains/losses calculated. Contains revaluation results and triggers appropriate GL postings.

**Data**:
- `revaluation_id`: Revaluation process
- `currency_codes`: Currencies that were revalued
- `revaluation_date`: Date of revaluation
- `total_gain_loss`: Net unrealized gain or loss
- `account_adjustments`: Account-level revaluation adjustments
- `gl_entries_created`: Journal entries for revaluation

**Downstream Effects**:
- Posts unrealized gain/loss entries to GL
- Updates multi-currency balance projections
- Updates foreign exchange reporting
- Creates revaluation audit documentation

---

#### ConsolidationCompleted Event
**Purpose**: Records completion of multi-company consolidation.

**Description**: Emitted when consolidation process completes with consolidated financial statements prepared. Contains consolidation results and summary information.

**Data**:
- `consolidation_id`: Consolidation process
- `parent_company_id`: Parent company
- `subsidiary_companies`: Consolidated subsidiaries
- `consolidation_period`: Period consolidated
- `elimination_entries`: Inter-company eliminations processed
- `consolidated_totals`: Final consolidated amounts
- `completed_at`: Consolidation completion timestamp

**Downstream Effects**:
- Creates consolidated financial statements
- Updates consolidation reporting projections
- Triggers consolidation audit procedures
- Enables regulatory reporting

---

## Reporting and Analytics Commands and Events

### Financial Reporting

#### GenerateTrialBalance Command
**Purpose**: Generates trial balance report for specified period.

**Description**: Creates trial balance including account balances, validation of balance equality, and report formatting. Supports various trial balance formats and comparative periods.

**Parameters**:
- `report_id`: Trial balance report identifier
- `period_id`: Period for trial balance
- `report_type`: Type of trial balance (detailed, summary, comparative)
- `account_filters`: Account selection criteria
- `format_options`: Report formatting preferences
- `comparative_periods`: Additional periods for comparison

**Business Rules**:
- Period must be available for reporting
- Account filters must be valid
- Trial balance must be mathematically balanced
- Report authorization appropriate for confidentiality level

---

#### GenerateFinancialStatements Command
**Purpose**: Generates standard financial statements (balance sheet, income statement, cash flow).

**Description**: Creates financial statements including balance sheet, income statement, statement of cash flows, and statement of equity with proper formatting and comparative information.

**Parameters**:
- `report_id`: Financial statement report identifier
- `reporting_period`: Primary reporting period
- `comparative_periods`: Periods for comparison
- `statement_types`: Which statements to generate
- `consolidation_level`: Individual company or consolidated
- `format_template`: Report format and layout

**Business Rules**:
- Reporting periods must be closed or current
- Comparative periods must be available
- Consolidation level authorization required
- Report format must meet standards

---

#### CalculateFinancialRatios Command
**Purpose**: Calculates financial ratios and performance metrics.

**Description**: Computes financial ratios including liquidity ratios, profitability ratios, efficiency ratios, and leverage ratios with trend analysis and benchmarking.

**Parameters**:
- `calculation_id`: Ratio calculation identifier
- `analysis_period`: Period for ratio calculation
- `ratio_types`: Specific ratios to calculate
- `comparative_periods`: Periods for trend analysis
- `benchmark_data`: Industry or peer benchmarks

**Business Rules**:
- Source data must be accurate and complete
- Ratio calculations must follow standard formulas
- Comparative analysis must use consistent periods
- Benchmarking data must be current and relevant

---

### Reporting Events

#### TrialBalanceGenerated Event
**Purpose**: Records generation of trial balance report.

**Description**: Emitted when trial balance is successfully generated with balanced totals. Contains trial balance summary and enables further financial statement preparation.

**Data**:
- `report_id`: Generated trial balance identifier
- `period_id`: Reporting period
- `total_debits`: Total debit balances
- `total_credits`: Total credit balances
- `account_count`: Number of accounts with balances
- `report_format`: Format used for report
- `generated_at`: Generation timestamp

**Downstream Effects**:
- Enables financial statement preparation
- Updates period-end reporting status
- Validates accounting equation balance
- Creates reporting audit trail

---

#### FinancialStatementsGenerated Event
**Purpose**: Records generation of financial statements.

**Description**: Emitted when financial statements are successfully generated with all components complete. Contains statement summary and enables distribution and analysis.

**Data**:
- `report_id`: Financial statement identifier
- `reporting_period`: Primary reporting period
- `statements_generated`: List of statements created
- `comparative_periods`: Comparison periods included
- `consolidation_level`: Individual or consolidated
- `statement_totals`: Key totals from statements

**Downstream Effects**:
- Enables statement distribution and publication
- Updates financial reporting projections
- Triggers ratio analysis and benchmarking
- Creates financial statement audit trail

---

#### FinancialRatiosCalculated Event
**Purpose**: Records calculation of financial ratios and metrics.

**Description**: Emitted when financial ratio analysis completes with calculated ratios and trend analysis. Contains ratio results and triggers performance analysis.

**Data**:
- `calculation_id`: Ratio calculation identifier
- `analysis_period`: Period analyzed
- `calculated_ratios`: All calculated ratios and values
- `trend_analysis`: Trend analysis results
- `benchmark_comparison`: Comparison to benchmarks
- `calculated_at`: Calculation completion timestamp

**Downstream Effects**:
- Updates financial performance projections
- Triggers performance analysis and insights
- Enables management reporting and dashboards
- Creates ratio analysis audit trail

---

## Error Handling and Recovery Commands and Events

### Error Management

#### HandleGLError Command
**Purpose**: Manages GL processing errors with appropriate recovery actions.

**Description**: Coordinates error handling including error classification, recovery action determination, compensation processing, and escalation management for GL operations.

**Parameters**:
- `error_id`: Error incident identifier
- `error_type`: Classification of error
- `affected_entities`: GL entities impacted by error
- `error_context`: Detailed error information
- `recovery_strategy`: Approach for error recovery
- `escalation_required`: Whether to escalate error

**Business Rules**:
- Error classification must be accurate
- Recovery strategy must preserve GL integrity
- Escalation based on error severity and financial impact
- All error handling must maintain audit trail

---

#### RecoverFromProcessingFailure Command
**Purpose**: Recovers from GL processing failures with validation.

**Description**: Executes recovery from processing failures including state restoration, transaction correction, balance validation, and process restart with appropriate safeguards.

**Parameters**:
- `recovery_id`: Recovery process identifier
- `failure_context`: Original failure information
- `recovery_actions`: Specific recovery steps
- `validation_requirements`: Validation needed for recovery
- `rollback_scope`: Scope of rollback if required

**Business Rules**:
- Recovery actions must restore consistent state
- All affected balances must be validated
- Recovery must maintain double-entry principles
- Authorization required for significant recovery actions

---

### Error Events

#### GLErrorOccurred Event
**Purpose**: Records occurrence of GL processing error.

**Description**: Emitted when GL error occurs requiring attention or recovery action. Contains error details and triggers appropriate response workflows.

**Data**:
- `error_id`: Error incident identifier
- `error_type`: Error classification
- `error_context`: Detailed error information
- `affected_accounts`: Accounts impacted by error
- `financial_impact`: Financial impact assessment
- `occurred_at`: Error occurrence timestamp

**Downstream Effects**:
- Triggers error handling workflow
- Updates system health monitoring
- Creates error tracking and escalation
- Notifies appropriate personnel based on severity

---

#### GLRecoveryCompleted Event
**Purpose**: Records successful completion of GL error recovery.

**Description**: Emitted when GL recovery completes successfully with system restored to consistent state. Validates recovery success and resumes normal processing.

**Data**:
- `recovery_id`: Recovery process identifier
- `original_error_id`: Error that was recovered from
- `recovery_actions`: Actions taken for recovery
- `validation_results`: Recovery validation results
- `balance_verification`: Confirmation of balance accuracy
- `completed_at`: Recovery completion timestamp

**Downstream Effects**:
- Resumes normal GL processing
- Updates error recovery metrics and procedures
- Completes error incident documentation
- Provides recovery lessons learned for process improvement

---

## Summary

The General Ledger domain contains **30 primary command types** and **25 primary event types** organized into:

**Chart Management**: Account creation, modification, and deactivation commands with account lifecycle events
**Journal Processing**: Journal entry creation, posting, and reversal commands with posting and balance update events
**Period Management**: Period opening, closing, and year-end commands with period lifecycle and closure events
**Budget Operations**: Budget creation, approval, revision, and monitoring commands with budget lifecycle events
**Integration Operations**: Sub-ledger transaction processing, reconciliation, and transfer commands with integration events
**Allocation Processing**: Allocation configuration, processing, and validation commands with allocation lifecycle events
**Multi-Currency Operations**: Exchange rate updates, revaluation, and consolidation commands with currency events
**Reporting Operations**: Trial balance, financial statement, and ratio calculation commands with reporting events
**Error Handling**: Error management and recovery commands with error occurrence and recovery events

Each command includes detailed parameters, business rules, and authorization requirements, while events provide comprehensive data about state changes and trigger appropriate downstream processing. The design supports sophisticated general ledger operations including multi-currency processing, consolidation, automated allocations, and intelligent error recovery while maintaining strict double-entry bookkeeping principles and comprehensive audit trails for regulatory compliance.