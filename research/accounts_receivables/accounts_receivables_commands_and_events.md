# Accountex Accounts Receivable - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the Accounts Receivable domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework.

## Customer Management Commands and Events

### Customer Lifecycle Management

#### CreateCustomer Command
**Purpose**: Creates a new customer account in the AR system.

**Description**: Establishes new customer account including profile information, credit settings, and initial configuration. Validates customer data and sets up customer for transaction processing with appropriate defaults and business rules.

**Parameters**:
- `customer_id`: Unique customer identifier
- `customer_number`: System-assigned customer number
- `company_name`: Customer business name
- `contact_information`: Primary contact details
- `billing_address`: Primary billing address
- `shipping_address`: Primary shipping address
- `credit_limit_amount`: Initial credit limit
- `payment_terms`: Default payment terms
- `tax_settings`: Tax configuration and exemptions

**Business Rules**:
- Customer number must be unique within system
- Company name required for business customers
- Credit limit must be non-negative
- Payment terms must be valid and active
- Tax settings must comply with jurisdiction rules

---

#### UpdateCustomerProfile Command
**Purpose**: Updates customer profile information and settings.

**Description**: Modifies customer information including contact details, addresses, credit limits, and configuration settings. Maintains customer data integrity while allowing necessary business changes with proper audit trails.

**Parameters**:
- `customer_id`: Customer to update
- `profile_updates`: Map of fields to update
- `address_changes`: Updated address information
- `credit_adjustments`: Credit limit modifications
- `updated_by`: User making changes
- `update_reason`: Justification for changes

**Business Rules**:
- Cannot reduce credit limit below current outstanding balance
- Address changes require validation for tax jurisdiction impact
- Significant credit limit increases require approval
- Profile updates maintain historical versions

---

#### SetCreditLimit Command
**Purpose**: Sets or modifies customer credit limit with authorization.

**Description**: Establishes or changes customer credit limits including permanent limits, temporary increases, and credit hold management. Integrates with credit evaluation and approval processes.

**Parameters**:
- `customer_id`: Customer for credit limit change
- `new_credit_limit`: Updated credit limit amount
- `temporary_increase`: Temporary credit increase if applicable
- `temporary_valid_until`: Expiration for temporary increase
- `credit_evaluation`: Supporting credit analysis
- `authorized_by`: User with authority for credit decisions

**Business Rules**:
- Credit limit increases above threshold require approval
- Temporary increases must have expiration dates
- Cannot set credit limit below current outstanding balance
- Credit evaluation required for significant increases

---

#### ArchiveCustomer Command
**Purpose**: Archives inactive customer account with proper cleanup.

**Description**: Safely archives customer account including data preservation, relationship cleanup, and audit trail maintenance. Ensures regulatory compliance while removing customer from active operations.

**Parameters**:
- `customer_id`: Customer to archive
- `archive_reason`: Reason for archiving
- `final_balance_disposition`: How to handle remaining balances
- `data_retention_period`: How long to maintain archived data
- `authorized_by`: User authorizing archive

**Business Rules**:
- Customer must have zero outstanding balance
- All open transactions must be resolved
- Archive retention must meet regulatory requirements
- Authorization required for customer archiving

---

### Customer Events

#### CustomerCreated Event
**Purpose**: Records creation of new customer account.

**Description**: Emitted when customer account is successfully created. Contains customer details and triggers initialization of customer-related processes and projections.

**Data**:
- `customer_id`: Created customer identifier
- `customer_number`: Assigned customer number
- `company_name`: Customer business name
- `initial_credit_limit`: Starting credit limit
- `payment_terms`: Default payment terms assigned
- `salesperson_assigned`: Assigned sales representative
- `created_by`: User creating customer
- `created_at`: Creation timestamp

**Downstream Effects**:
- Initializes customer projections and balances
- Sets up credit monitoring and limits
- Triggers welcome communication workflow
- Creates customer audit trail

---

#### CustomerProfileUpdated Event
**Purpose**: Records changes to customer profile information.

**Description**: Emitted when customer profile is updated with change details. Provides audit trail and triggers updates to related projections and integrations.

**Data**:
- `customer_id`: Updated customer
- `changes`: Map of changed fields with before/after values
- `address_updates`: Address change details
- `tax_impact`: Tax jurisdiction changes if applicable
- `updated_by`: User making changes
- `updated_at`: Update timestamp

**Downstream Effects**:
- Updates customer projections and views
- Triggers tax jurisdiction recalculation if needed
- Updates customer communication preferences
- Maintains change audit trail

---

#### CreditLimitSet Event
**Purpose**: Records credit limit establishment or modification.

**Description**: Emitted when customer credit limit is set or changed. Contains credit details and triggers credit monitoring and approval workflow updates.

**Data**:
- `customer_id`: Customer with credit change
- `previous_limit`: Former credit limit
- `new_limit`: Updated credit limit
- `temporary_increase`: Temporary increase details if applicable
- `credit_evaluation`: Supporting analysis
- `authorized_by`: Approving authority
- `effective_date`: When change becomes effective

**Downstream Effects**:
- Updates credit monitoring and alerts
- Triggers credit availability calculations
- Updates customer risk assessments
- Enables order processing within new limits

---

## Invoice Management Commands and Events

### Invoice Processing

#### CreateInvoice Command
**Purpose**: Creates new customer invoice with comprehensive validation.

**Description**: Generates customer invoice including line items, tax calculations, freight charges, and payment terms. Validates customer credit, inventory availability, and business rules before creation.

**Parameters**:
- `invoice_id`: Unique invoice identifier
- `customer_id`: Customer being invoiced
- `invoice_number`: Invoice number (auto-generated or manual)
- `invoice_date`: Invoice creation date
- `due_date`: Payment due date
- `line_items`: List of products/services being invoiced
- `tax_settings`: Tax calculation parameters
- `freight_charges`: Shipping and handling charges
- `payment_terms`: Payment terms for this invoice

**Business Rules**:
- Customer must be active and not on credit hold
- Invoice number must be unique
- Line items must reference valid products/services
- Tax calculations must be accurate for jurisdiction
- Total amounts must balance correctly

---

#### AmendInvoice Command
**Purpose**: Modifies existing invoice with proper validation and audit.

**Description**: Updates invoice information including line item changes, amount adjustments, and term modifications. Maintains invoice integrity while allowing necessary corrections with comprehensive audit trails.

**Parameters**:
- `invoice_id`: Invoice to amend
- `amendment_type`: Type of amendment (correction, addition, adjustment)
- `line_item_changes`: Changes to invoice line items
- `amount_adjustments`: Financial adjustments
- `amendment_reason`: Justification for amendment
- `amended_by`: User making amendment

**Business Rules**:
- Cannot amend invoices with payments applied
- Amendment must maintain mathematical accuracy
- Significant amendments require approval
- Amendment history maintained for audit

---

#### VoidInvoice Command
**Purpose**: Voids invoice with proper cleanup and compensation.

**Description**: Cancels invoice and handles all related cleanup including inventory restoration, credit limit adjustment, and reversal of any applied amounts. Maintains complete audit trail of void transaction.

**Parameters**:
- `invoice_id`: Invoice to void
- `void_reason`: Reason for voiding invoice
- `void_date`: Effective date of void
- `compensation_required`: Whether compensation transactions needed
- `authorized_by`: User authorizing void

**Business Rules**:
- Cannot void invoices with partial payments unless handled
- Void requires appropriate authorization
- Inventory adjustments processed if applicable
- Customer credit limit restored

---

#### GenerateRecurringInvoice Command
**Purpose**: Generates invoice from recurring template with validation.

**Description**: Creates invoice based on recurring template including template validation, pricing updates, customer verification, and automated processing options.

**Parameters**:
- `template_id`: Source recurring template
- `generation_date`: Date for invoice generation
- `customer_validation`: Current customer status check
- `pricing_updates`: Whether to apply current pricing
- `auto_process`: Whether to auto-approve and process

**Business Rules**:
- Template must be active and within date range
- Customer must still be active and in good standing
- Pricing updates require appropriate authorization
- Auto-processing based on customer and amount thresholds

---

### Invoice Events

#### InvoiceCreated Event
**Purpose**: Records creation of new customer invoice.

**Description**: Emitted when invoice is successfully created. Contains complete invoice information and triggers downstream processing including credit impact, inventory updates, and aging calculations.

**Data**:
- `invoice_id`: Created invoice identifier
- `customer_id`: Customer being invoiced
- `invoice_number`: Generated invoice number
- `invoice_total`: Total invoice amount
- `due_date`: Payment due date
- `tax_amount`: Total tax amount
- `line_item_count`: Number of line items
- `created_by`: User creating invoice

**Downstream Effects**:
- Updates customer aging and balance projections
- Impacts customer credit availability
- Triggers inventory allocation if applicable
- Creates receivable in GL integration

---

#### InvoiceAmended Event
**Purpose**: Records invoice amendments with change details.

**Description**: Emitted when invoice is amended with complete change tracking. Provides audit trail and triggers updates to related calculations and projections.

**Data**:
- `invoice_id`: Amended invoice
- `amendment_type`: Type of amendment
- `changes`: Detailed change information
- `amount_impact`: Financial impact of changes
- `tax_recalculation`: Updated tax amounts
- `amended_by`: User making amendment
- `amendment_date`: When amendment occurred

**Downstream Effects**:
- Updates customer balance and aging projections
- Recalculates tax liabilities if changed
- Updates inventory allocations if line items changed
- Maintains amendment audit trail

---

#### InvoiceVoided Event
**Purpose**: Records invoice void with compensation details.

**Description**: Emitted when invoice is voided. Contains void details and triggers all necessary cleanup and compensation activities.

**Data**:
- `invoice_id`: Voided invoice
- `void_reason`: Reason for void
- `original_amount`: Amount of voided invoice
- `compensation_transactions`: Related cleanup transactions
- `inventory_restoration`: Inventory adjustments made
- `credit_restoration`: Credit limit adjustments
- `authorized_by`: User authorizing void

**Downstream Effects**:
- Reverses customer balance and aging impact
- Restores customer credit availability
- Processes inventory compensation if needed
- Creates void audit trail and notifications

---

## Payment Management Commands and Events

### Payment Processing

#### ApplyPayment Command
**Purpose**: Applies customer payment to specific invoices with proper allocation.

**Description**: Processes customer payment including payment validation, invoice selection, discount calculations, and allocation across multiple invoices. Handles overpayments and creates open credits as needed.

**Parameters**:
- `payment_id`: Unique payment identifier
- `customer_id`: Customer making payment
- `payment_amount`: Total payment amount
- `payment_method`: Method of payment (cash, check, card, etc.)
- `payment_date`: Date payment received
- `invoice_allocations`: Specific invoice applications
- `discount_taken`: Early payment discounts applied
- `reference_number`: Payment reference or check number

**Business Rules**:
- Payment amount must be positive
- Customer must exist and not be archived
- Invoice allocations cannot exceed payment amount
- Discounts must be within eligible timeframe
- Payment method must be valid for customer

---

#### ProcessElectronicPayment Command
**Purpose**: Processes electronic payments including ACH and wire transfers.

**Description**: Handles electronic payment processing including validation of banking information, payment authorization, processing coordination, and confirmation tracking.

**Parameters**:
- `payment_id`: Electronic payment identifier
- `customer_id`: Customer making payment
- `bank_account_info`: Customer banking details
- `payment_amount`: Amount being transferred
- `transfer_type`: ACH, wire, or other electronic method
- `authorization_code`: Payment authorization reference
- `processing_date`: When payment processing initiated

**Business Rules**:
- Bank account information must be validated
- Electronic payment authorization required
- Transfer type must match customer setup
- Processing limits and security checks applied

---

#### VoidPayment Command
**Purpose**: Voids payment with proper reversal and cleanup.

**Description**: Cancels payment and reverses all applications including invoice balance restoration, open credit adjustments, and audit trail maintenance.

**Parameters**:
- `payment_id`: Payment to void
- `void_reason`: Reason for voiding payment
- `void_date`: Effective date of void
- `reversal_method`: How to handle applied amounts
- `authorized_by`: User authorizing void

**Business Rules**:
- Cannot void payments after certain time periods
- Void authorization required based on amount
- All applications must be reversed
- Customer balances restored to pre-payment state

---

#### ApplyOpenCredit Command
**Purpose**: Applies existing open credit to customer invoices.

**Description**: Uses unapplied customer credits to pay invoices including credit validation, invoice selection, allocation processing, and balance updates.

**Parameters**:
- `credit_application_id`: Credit application identifier
- `customer_id`: Customer with open credit
- `available_credit`: Amount of credit available
- `invoice_applications`: Invoices to apply credit against
- `application_date`: Date of credit application
- `applied_by`: User processing application

**Business Rules**:
- Customer must have available open credit
- Applied amount cannot exceed available credit
- Invoice applications must be for same customer
- Application maintains credit audit trail

---

### Payment Events

#### PaymentApplied Event
**Purpose**: Records successful payment application to invoices.

**Description**: Emitted when payment is successfully applied to customer invoices. Contains application details and triggers balance updates and reconciliation activities.

**Data**:
- `payment_id`: Applied payment
- `customer_id`: Customer making payment
- `total_amount_applied`: Total amount applied to invoices
- `invoice_applications`: Detailed applications by invoice
- `discounts_taken`: Early payment discounts applied
- `open_credit_created`: Any overpayment credit created
- `applied_by`: User processing payment
- `application_date`: When payment was applied

**Downstream Effects**:
- Updates customer balance and aging projections
- Updates invoice payment status
- Creates open credit if overpayment exists
- Triggers bank deposit processing

---

#### ElectronicPaymentProcessed Event
**Purpose**: Records processing of electronic payment transaction.

**Description**: Emitted when electronic payment processing completes. Contains processing details and triggers confirmation tracking and reconciliation procedures.

**Data**:
- `payment_id`: Electronic payment processed
- `customer_id`: Customer making payment
- `transaction_reference`: Bank processing reference
- `processing_status`: Status from bank processing
- `confirmation_expected`: Expected confirmation timing
- `fees_charged`: Any processing fees
- `processed_at`: Processing completion timestamp

**Downstream Effects**:
- Updates payment status projections
- Triggers confirmation monitoring
- Updates electronic payment reconciliation
- Creates processing audit trail

---

#### OpenCreditApplied Event
**Purpose**: Records application of open credit to customer invoices.

**Description**: Emitted when open credit is successfully applied to invoices. Contains application details and triggers balance and credit updates.

**Data**:
- `credit_application_id`: Credit application transaction
- `customer_id`: Customer receiving credit application
- `credit_amount_applied`: Total credit applied
- `invoice_applications`: Detailed applications by invoice
- `remaining_credit`: Remaining open credit after application
- `application_date`: Date of credit application
- `applied_by`: User processing application

**Downstream Effects**:
- Updates customer balance and aging
- Updates invoice payment status
- Adjusts customer open credit balance
- Triggers credit utilization tracking

---

## Recurring Invoice Commands and Events

### Recurring Invoice Management

#### CreateRecurringInvoiceTemplate Command
**Purpose**: Creates template for automated recurring invoice generation.

**Description**: Establishes recurring invoice template including schedule definition, line items, pricing configuration, and automated processing rules. Enables scheduled invoice generation for subscription-based billing.

**Parameters**:
- `template_id`: Unique template identifier
- `customer_id`: Customer for recurring invoices
- `template_name`: Descriptive template name
- `recurring_cycle`: Frequency (weekly, monthly, quarterly, etc.)
- `start_date`: When recurring billing begins
- `end_date`: When recurring billing ends (if applicable)
- `line_items`: Template line items with products/services
- `pricing_configuration`: Fixed vs. current pricing rules
- `auto_processing`: Automatic invoice processing settings

**Business Rules**:
- Customer must be active and approved for recurring billing
- Recurring cycle must be valid business cycle
- Line items must reference valid products/services
- Pricing configuration must be consistent
- Auto-processing authorization appropriate for amounts

---

#### GenerateRecurringInvoice Command
**Purpose**: Generates individual invoice from recurring template.

**Description**: Creates actual invoice from template including template validation, pricing application, customer verification, and processing coordination based on template configuration.

**Parameters**:
- `generation_id`: Generation transaction identifier
- `template_id`: Source template for generation
- `generation_date`: Date for invoice generation
- `customer_validation`: Current customer status
- `pricing_application`: How to apply current vs. template pricing
- `auto_process_settings`: Automatic processing configuration

**Business Rules**:
- Template must be active and within valid date range
- Generation date must align with template schedule
- Customer must still meet recurring billing criteria
- Pricing changes require appropriate authorization

---

#### AmendRecurringTemplate Command
**Purpose**: Modifies recurring invoice template with impact analysis.

**Description**: Updates recurring template including line item changes, schedule modifications, and pricing adjustments. Analyzes impact on future generations and maintains template version control.

**Parameters**:
- `template_id`: Template to amend
- `amendment_type`: Type of amendment (schedule, pricing, items)
- `schedule_changes`: Updated recurring schedule
- `line_item_changes`: Changes to template line items
- `pricing_updates`: Pricing rule modifications
- `effective_date`: When changes become effective
- `amended_by`: User making amendments

**Business Rules**:
- Cannot change template retroactively for generated invoices
- Schedule changes must maintain business logic
- Pricing updates require appropriate authorization
- Amendment impact analysis required

---

#### SuspendRecurringTemplate Command
**Purpose**: Suspends recurring template processing temporarily or permanently.

**Description**: Stops automatic invoice generation including suspension period definition, pending invoice handling, and resumption criteria establishment.

**Parameters**:
- `template_id`: Template to suspend
- `suspension_type`: Temporary or permanent suspension
- `suspension_reason`: Reason for suspension
- `suspension_start_date`: When suspension begins
- `suspension_end_date`: When suspension ends (if temporary)
- `pending_invoice_handling`: How to handle already generated invoices
- `suspended_by`: User authorizing suspension

**Business Rules**:
- Suspension authorization based on customer relationship
- Temporary suspensions require end dates
- Pending invoice handling requires customer approval
- Suspension audit trail maintained

---

### Recurring Invoice Events

#### RecurringTemplateCreated Event
**Purpose**: Records creation of recurring invoice template.

**Description**: Emitted when recurring template is established. Contains template configuration and triggers scheduling and monitoring setup.

**Data**:
- `template_id`: Created template identifier
- `customer_id`: Customer for recurring invoices
- `recurring_cycle`: Configured schedule frequency
- `total_template_value`: Total value of template line items
- `auto_processing_enabled`: Whether automatic processing configured
- `next_generation_date`: Next scheduled generation
- `created_by`: User creating template

**Downstream Effects**:
- Enables automatic invoice generation scheduling
- Sets up template monitoring and tracking
- Updates customer recurring billing status
- Creates template audit trail

---

#### RecurringInvoiceGenerated Event
**Purpose**: Records automatic generation of invoice from template.

**Description**: Emitted when invoice is automatically generated from template. Contains generation details and triggers invoice processing workflow.

**Data**:
- `generation_id`: Generation transaction identifier
- `template_id`: Source template
- `generated_invoice_id`: Created invoice
- `generation_date`: When invoice was generated
- `template_cycle_number`: Cycle number for this generation
- `pricing_applied`: Pricing method used
- `next_generation_date`: Next scheduled generation

**Downstream Effects**:
- Creates new invoice for standard processing
- Updates template generation history and counters
- Triggers automatic processing if configured
- Schedules next generation occurrence

---

#### RecurringTemplateSuspended Event
**Purpose**: Records suspension of recurring template processing.

**Description**: Emitted when recurring template is suspended. Contains suspension details and triggers processing halt and notification activities.

**Data**:
- `template_id`: Suspended template
- `suspension_type`: Temporary or permanent
- `suspension_reason`: Reason for suspension
- `suspension_period`: Start and end dates
- `pending_invoices_affected`: Count of pending invoices
- `suspended_by`: User authorizing suspension

**Downstream Effects**:
- Halts automatic invoice generation
- Updates template status and availability
- Triggers customer notification if required
- Creates suspension audit trail

---

## Bank Deposit Commands and Events

### Deposit Processing

#### RecordBankDeposit Command
**Purpose**: Records bank deposit including payment grouping and validation.

**Description**: Creates bank deposit by grouping customer payments including deposit validation, payment selection, total verification, and deposit documentation preparation.

**Parameters**:
- `deposit_id`: Unique deposit identifier
- `bank_account_id`: Target bank account for deposit
- `deposit_date`: Date of deposit
- `payment_selections`: Payments included in deposit
- `deposit_total`: Total amount being deposited
- `deposit_reference`: Bank deposit reference number
- `deposit_slip_info`: Physical deposit slip details

**Business Rules**:
- All payments must be from same bank account
- Deposit total must equal sum of selected payments
- Payments cannot already be in another deposit
- Deposit date must be reasonable

---

#### AmendBankDeposit Command
**Purpose**: Modifies bank deposit with validation and balance checking.

**Description**: Updates bank deposit including payment additions/removals, amount adjustments, and balance verification. Maintains deposit integrity and audit requirements.

**Parameters**:
- `deposit_id`: Deposit to amend
- `payments_to_add`: Additional payments for deposit
- `payments_to_remove`: Payments to remove from deposit
- `amount_adjustments`: Any amount corrections
- `amendment_reason`: Justification for amendment
- `amended_by`: User making amendment

**Business Rules**:
- Cannot amend verified or reconciled deposits
- Amendment must maintain deposit balance
- Payment additions/removals must be valid
- Amendment authorization required

---

#### VerifyBankDeposit Command
**Purpose**: Verifies bank deposit against bank confirmation.

**Description**: Confirms bank deposit processing including bank confirmation matching, balance verification, and discrepancy resolution. Completes deposit lifecycle and enables reconciliation.

**Parameters**:
- `deposit_id`: Deposit to verify
- `bank_confirmation`: Bank confirmation details
- `verification_date`: Date of verification
- `amount_confirmed`: Amount confirmed by bank
- `discrepancies`: Any differences found
- `verified_by`: User performing verification

**Business Rules**:
- Deposit must be recorded before verification
- Bank confirmation required for verification
- Discrepancies must be resolved before verification
- Verification authorization required

---

#### VoidBankDeposit Command
**Purpose**: Voids bank deposit with payment release and cleanup.

**Description**: Cancels bank deposit and releases all included payments including payment status restoration, balance adjustments, and audit trail maintenance.

**Parameters**:
- `deposit_id`: Deposit to void
- `void_reason`: Reason for voiding deposit
- `payment_disposition`: How to handle released payments
- `void_date`: Effective date of void
- `authorized_by`: User authorizing void

**Business Rules**:
- Cannot void verified or reconciled deposits
- All payments must be released back to undeposited status
- Void authorization required
- Audit trail maintained for void transaction

---

### Deposit Events

#### BankDepositRecorded Event
**Purpose**: Records creation of bank deposit with payment grouping.

**Description**: Emitted when bank deposit is created with grouped payments. Contains deposit details and triggers verification and reconciliation processes.

**Data**:
- `deposit_id`: Created deposit identifier
- `bank_account_id`: Target bank account
- `deposit_date`: Date of deposit
- `payment_count`: Number of payments in deposit
- `deposit_total`: Total amount deposited
- `payment_methods`: Summary of payment methods included
- `recorded_by`: User recording deposit

**Downstream Effects**:
- Groups payments for bank processing
- Triggers deposit verification workflow
- Updates bank account projections
- Creates deposit tracking and audit

---

#### BankDepositVerified Event
**Purpose**: Records successful deposit verification against bank confirmation.

**Description**: Emitted when deposit verification completes successfully. Contains verification details and enables final reconciliation processing.

**Data**:
- `deposit_id`: Verified deposit
- `verification_date`: Date of verification
- `bank_confirmation_reference`: Bank confirmation details
- `verified_amount`: Amount confirmed by bank
- `verification_status`: Final verification status
- `verified_by`: User completing verification

**Downstream Effects**:
- Completes deposit processing lifecycle
- Enables bank reconciliation processing
- Updates deposit status projections
- Creates verification audit documentation

---

## Credit Management Commands and Events

### Credit Processing

#### ProcessCreditHold Command
**Purpose**: Places customer on credit hold with proper validation and notification.

**Description**: Implements credit hold including hold validation, impact analysis, existing order handling, and stakeholder notification. Prevents further credit transactions while preserving existing commitments.

**Parameters**:
- `customer_id`: Customer to place on hold
- `hold_type`: Type of credit hold (soft, hard, temporary)
- `hold_reason`: Reason for credit hold
- `effective_date`: When hold becomes effective
- `existing_order_handling`: How to handle pending orders
- `hold_review_date`: When to review hold status
- `authorized_by`: User authorizing hold

**Business Rules**:
- Hold authorization required based on customer balance
- Impact analysis required for existing orders
- Customer notification required for holds
- Hold review dates must be established

---

#### ReleaseCreditHold Command
**Purpose**: Releases customer from credit hold with validation.

**Description**: Removes credit hold including hold resolution validation, credit re-evaluation, order release coordination, and status restoration.

**Parameters**:
- `customer_id`: Customer to release from hold
- `release_reason`: Reason for hold release
- `credit_reevaluation`: Updated credit assessment
- `new_credit_terms`: Any new credit terms or limits
- `order_release_instructions`: How to handle held orders
- `released_by`: User authorizing release

**Business Rules**:
- Hold conditions must be resolved before release
- Credit reevaluation may be required
- Release authorization appropriate for original hold reason
- Order processing resumption coordination

---

#### ProcessCreditAdjustment Command
**Purpose**: Processes credit adjustments including write-offs and allowances.

**Description**: Handles credit adjustments including bad debt write-offs, customer allowances, and billing corrections with proper authorization and GL integration.

**Parameters**:
- `adjustment_id`: Credit adjustment identifier
- `customer_id`: Customer for adjustment
- `adjustment_type`: Type (write-off, allowance, correction)
- `adjustment_amount`: Amount of adjustment
- `adjustment_reason`: Detailed justification
- `gl_account_mapping`: GL accounts for posting
- `authorized_by`: User authorizing adjustment

**Business Rules**:
- Adjustment authorization required based on amount
- Write-offs require documentation and approval
- GL account mappings must be valid
- Adjustment audit trail maintained

---

### Credit Events

#### CreditHoldPlaced Event
**Purpose**: Records placement of customer on credit hold.

**Description**: Emitted when customer is placed on credit hold. Contains hold details and triggers order processing restrictions and notifications.

**Data**:
- `customer_id`: Customer placed on hold
- `hold_type`: Type of credit hold implemented
- `hold_reason`: Reason for hold placement
- `effective_date`: When hold became effective
- `orders_affected`: Impact on existing orders
- `review_date`: Scheduled hold review date
- `authorized_by`: User authorizing hold

**Downstream Effects**:
- Restricts new order processing for customer
- Triggers customer and sales team notification
- Updates customer status projections
- Creates hold tracking and monitoring

---

#### CreditHoldReleased Event
**Purpose**: Records release of customer from credit hold.

**Description**: Emitted when credit hold is released. Contains release details and triggers order processing restoration and status updates.

**Data**:
- `customer_id`: Customer released from hold
- `release_date`: Date of hold release
- `release_reason`: Reason for release
- `credit_terms_updated`: Any new credit terms
- `orders_released`: Orders released for processing
- `released_by`: User authorizing release

**Downstream Effects**:
- Restores normal order processing for customer
- Triggers held order evaluation and processing
- Updates customer status and credit projections
- Creates release audit trail and notifications

---

## Finance Charge Commands and Events

### Finance Charge Processing

#### ApplyFinanceChargeByInvoice Command
**Purpose**: Applies finance charges to individual past-due invoices.

**Description**: Calculates and applies finance charges to specific invoices including charge calculation, eligibility validation, charge invoice creation, and customer notification.

**Parameters**:
- `charge_id`: Finance charge identifier
- `invoice_id`: Invoice receiving finance charge
- `customer_id`: Customer being charged
- `charge_calculation_method`: How charge was calculated
- `charge_amount`: Finance charge amount
- `charge_date`: Date charge applied
- `minimum_balance_met`: Whether minimum balance threshold met

**Business Rules**:
- Invoice must be past due beyond grace period
- Customer must be eligible for finance charges
- Charge calculation must follow configured method
- Minimum balance thresholds must be met

---

#### ApplyFinanceChargeByStatement Command
**Purpose**: Applies finance charges based on customer statement balance.

**Description**: Calculates finance charges based on total customer balance including statement-level calculation, charge allocation, and comprehensive charge documentation.

**Parameters**:
- `charge_id`: Finance charge identifier
- `customer_id`: Customer being charged
- `statement_balance`: Balance subject to finance charges
- `charge_rate`: Finance charge rate applied
- `charge_period`: Period for which charges calculated
- `compound_interest`: Whether compound interest applied
- `charge_allocation`: How charges allocated across invoices

**Business Rules**:
- Statement balance must exceed minimum threshold
- Charge rates must be within regulatory limits
- Compound interest rules must be followed
- Charge allocation must be mathematically accurate

---

### Finance Charge Events

#### FinanceChargeApplied Event
**Purpose**: Records application of finance charges to customer account.

**Description**: Emitted when finance charges are applied to customer. Contains charge details and triggers balance updates and customer notification.

**Data**:
- `charge_id`: Finance charge transaction
- `customer_id`: Customer charged
- `charge_amount`: Total finance charge applied
- `invoices_charged`: Invoices receiving charges
- `charge_method`: Calculation method used
- `charge_date`: Date charges applied
- `compound_interest_applied`: Compound interest details

**Downstream Effects**:
- Updates customer balance and aging
- Creates finance charge invoice or adjustment
- Triggers customer notification of charges
- Updates finance charge reporting and analytics

---

#### FinanceChargeAdjusted Event
**Purpose**: Records adjustment to previously applied finance charges.

**Description**: Emitted when finance charges are adjusted or reversed. Contains adjustment details and triggers appropriate balance corrections and notifications.

**Data**:
- `adjustment_id`: Charge adjustment identifier
- `original_charge_id`: Original finance charge being adjusted
- `customer_id`: Customer receiving adjustment
- `adjustment_amount`: Amount of adjustment
- `adjustment_reason`: Reason for adjustment
- `adjusted_by`: User making adjustment

**Downstream Effects**:
- Updates customer balance with adjustment
- Creates credit memo or balance adjustment
- Updates finance charge analytics
- Triggers customer notification of adjustment

---

## Multi-Currency Commands and Events

### Currency Management

#### UpdateExchangeRate Command
**Purpose**: Updates foreign exchange rates with validation and impact analysis.

**Description**: Updates exchange rates for foreign currencies including rate validation, historical tracking, impact analysis on open transactions, and revaluation triggering.

**Parameters**:
- `currency_code_id`: Currency being updated
- `new_exchange_rate`: Updated exchange rate
- `rate_effective_date`: When new rate becomes effective
- `rate_source`: Source of exchange rate information
- `auto_revalue_balances`: Whether to trigger automatic revaluation
- `impact_analysis`: Analysis of rate change impact

**Business Rules**:
- Exchange rates must be from authorized sources
- Rate changes must be reasonable (within variance tolerance)
- Rate effective dates must be logical and current
- Historical rates preserved for audit and revaluation

---

#### InitiateCurrencyRevaluation Command
**Purpose**: Initiates comprehensive currency revaluation process.

**Description**: Begins currency revaluation including scope definition, balance identification, revaluation calculation, and posting coordination for unrealized gains and losses.

**Parameters**:
- `revaluation_id`: Revaluation process identifier
- `revaluation_date`: Date for revaluation calculation
- `currency_scope`: Currencies included in revaluation
- `customer_scope`: Customers included in revaluation
- `revaluation_method`: Calculation method for gains/losses
- `auto_post_adjustments`: Whether to automatically post results
- `initiated_by`: User initiating revaluation

**Business Rules**:
- Revaluation dates must be end-of-period dates
- Currency scope must include valid foreign currencies
- Revaluation methods must follow accounting standards
- Auto-posting authorization required

---

#### CalculateRevaluationGains Command
**Purpose**: Calculates unrealized foreign exchange gains and losses.

**Description**: Performs detailed calculation of foreign exchange gains/losses including balance analysis, rate application, gain/loss determination, and GL posting preparation.

**Parameters**:
- `calculation_id`: Calculation process identifier
- `revaluation_id`: Parent revaluation process
- `customer_balances`: Customer balances to revalue
- `exchange_rates`: Current exchange rates to apply
- `calculation_method`: Method for gain/loss calculation
- `gl_posting_accounts`: GL accounts for posting adjustments

**Business Rules**:
- Customer balances must be in foreign currencies
- Exchange rates must be current and authorized
- Calculation methods must comply with accounting standards
- GL posting accounts must be valid and active

---

### Currency Events

#### ExchangeRateUpdated Event
**Purpose**: Records update to foreign exchange rates.

**Description**: Emitted when exchange rate is updated. Contains rate change details and triggers revaluation procedures and transaction processing updates.

**Data**:
- `currency_code_id`: Updated currency
- `previous_rate`: Former exchange rate
- `new_rate`: Updated exchange rate
- `rate_variance`: Percentage change from previous rate
- `effective_date`: When new rate becomes effective
- `rate_source`: Source of rate update
- `updated_by`: User or system updating rate

**Downstream Effects**:
- Triggers automatic revaluation if configured
- Updates multi-currency transaction processing
- Impacts open transaction valuations
- Creates rate change audit trail

---

#### CurrencyRevaluationCompleted Event
**Purpose**: Records completion of currency revaluation process.

**Description**: Emitted when currency revaluation completes with calculated gains/losses. Contains revaluation results and triggers GL posting and reporting activities.

**Data**:
- `revaluation_id`: Completed revaluation process
- `revaluation_date`: Date of revaluation
- `currencies_processed`: Currencies included in revaluation
- `total_gain_loss`: Net unrealized gain or loss
- `customer_adjustments`: Customer-level adjustments
- `gl_entries_generated`: Journal entries for posting
- `completed_by`: User or system completing revaluation

**Downstream Effects**:
- Posts unrealized gain/loss entries to GL
- Updates customer foreign currency balances
- Updates foreign exchange reporting
- Creates revaluation audit documentation

---

## Period-End Processing Commands and Events

### Period Closing

#### InitiatePeriodClose Command
**Purpose**: Initiates AR period-end closing process with validation.

**Description**: Begins period-end closing including closing validation, process coordination, and checkpoint establishment. Ensures all AR transactions properly processed before closing.

**Parameters**:
- `period_id`: Period being closed
- `closing_date`: Effective date of closure
- `closing_type`: Type of closing (soft, hard, preliminary)
- `validation_requirements`: Required validations before closing
- `integration_coordination`: Coordination with other modules
- `initiated_by`: User initiating closure

**Business Rules**:
- All transactions must be posted and validated
- Aging calculations must be current
- Bank reconciliations must be complete
- GL integration must be synchronized

---

#### ValidateTransactions Command
**Purpose**: Validates all AR transactions for period completeness.

**Description**: Performs comprehensive transaction validation including completeness checking, balance verification, integration validation, and exception identification.

**Parameters**:
- `period_id`: Period for validation
- `validation_scope`: Scope of validation (full, incremental, exception-only)
- `validation_rules`: Specific business rules to apply
- `exception_tolerance`: Acceptable exception thresholds
- `validation_date`: Date validation performed

**Business Rules**:
- All transactions must have complete data
- Customer balances must reconcile to transaction detail
- Payment applications must balance correctly
- Integration with GL must be complete

---

#### PerformAgingCalculation Command
**Purpose**: Calculates customer aging for period-end reporting.

**Description**: Performs comprehensive aging calculation including bucket assignment, balance categorization, and aging report preparation for period-end analysis.

**Parameters**:
- `calculation_id`: Aging calculation identifier
- `period_id`: Period for aging calculation
- `aging_date`: Date for aging calculation
- `aging_buckets`: Aging bucket definitions
- `customer_scope`: Customers included in calculation
- `currency_handling`: Multi-currency aging approach

**Business Rules**:
- Aging date must be end of period
- Aging buckets must be complete and non-overlapping
- Multi-currency aging must use consistent rate methodology
- Aging calculations must be mathematically accurate

---

### Period-End Events

#### PeriodCloseInitiated Event
**Purpose**: Records initiation of AR period-end closing.

**Description**: Emitted when period-end closing begins. Contains closing details and triggers comprehensive closing workflow coordination.

**Data**:
- `period_id`: Period being closed
- `closing_date`: Effective closure date
- `closing_type`: Type of closure being performed
- `validation_requirements`: Required validation steps
- `estimated_completion`: Expected completion timeframe
- `initiated_by`: User initiating closure

**Downstream Effects**:
- Triggers comprehensive validation workflow
- Restricts new transaction processing for period
- Initiates aging and reconciliation procedures
- Creates closing progress tracking

---

#### TransactionValidationCompleted Event
**Purpose**: Records completion of transaction validation process.

**Description**: Emitted when transaction validation completes. Contains validation results and enables continuation of closing process or exception handling.

**Data**:
- `period_id`: Period validated
- `validation_results`: Detailed validation outcomes
- `transactions_validated`: Count of validated transactions
- `exceptions_found`: Any validation exceptions
- `validation_summary`: Summary of validation process
- `validated_at`: Validation completion timestamp

**Downstream Effects**:
- Enables period closing continuation if successful
- Triggers exception resolution if issues found
- Updates period closing progress tracking
- Creates validation audit documentation

---

## Summary

The Accounts Receivable domain contains **30 primary command types** and **25 primary event types** organized into:

**Customer Management**: Customer creation, updates, credit limit management, and archival commands with lifecycle events
**Invoice Processing**: Invoice creation, amendment, voiding, and recurring invoice commands with billing lifecycle events
**Payment Management**: Payment application, electronic payment processing, and void commands with payment status events
**Bank Deposit Operations**: Deposit recording, verification, and amendment commands with deposit lifecycle events
**Credit Management**: Credit hold, release, and adjustment commands with credit status events
**Finance Charge Processing**: Finance charge application and adjustment commands with charge lifecycle events
**Recurring Invoice Operations**: Template creation, generation, and management commands with recurring billing events
**Multi-Currency Operations**: Exchange rate updates and revaluation commands with currency management events
**Period-End Processing**: Period closing, validation, and reconciliation commands with closing lifecycle events

Each command includes detailed parameters, business rules, and validation requirements, while events provide comprehensive data about system state changes and trigger appropriate downstream processing. The design supports complex AR business processes including multi-currency operations, recurring billing, sophisticated payment processing, automated finance charges, and comprehensive period-end procedures while maintaining data integrity, audit compliance, and seamless integration with other Accountex modules.