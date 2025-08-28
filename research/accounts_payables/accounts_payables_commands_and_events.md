# Accountex Accounts Payable - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the Accounts Payable domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework.

## Invoice Management Commands and Events

### Invoice Receipt and Processing

#### CreateInvoice Command
**Purpose**: Creates a new purchase invoice in the system.

**Description**: Initiates invoice processing by capturing invoice data from vendor including amounts, dates, and GL distributions. Validates basic business rules and creates invoice in draft state for further processing.

**Parameters**:
- `invoice_id`: Unique identifier for the invoice
- `vendor_id`: Vendor providing the invoice
- `invoice_number`: Vendor's invoice number
- `invoice_date`: Date on vendor invoice
- `due_date`: Payment due date
- `amount`: Invoice total amount
- `tax_amount`: Tax component
- `gl_distributions`: Account coding information

**Business Rules**:
- Vendor must be active and approved
- Invoice number must be unique per vendor
- Invoice date cannot be future-dated
- Amount must be positive
- GL distributions must sum to invoice total

---

#### ValidateInvoice Command
**Purpose**: Validates invoice against business rules and matching requirements.

**Description**: Performs comprehensive validation including three-way matching (when applicable), duplicate detection, tax calculation verification, and approval requirement determination. Routes invoice based on validation results.

**Parameters**:
- `invoice_id`: Invoice to validate
- `validation_rules`: Specific rules to apply
- `tolerance_settings`: Matching tolerance configuration

**Business Rules**:
- Three-way matching required for PO-based invoices
- Duplicate detection across vendor invoices
- Tax calculation accuracy validation
- GL account existence verification

---

#### ApproveInvoice Command
**Purpose**: Approves an invoice for payment processing.

**Description**: Records approval decision and advances invoice through approval workflow. May trigger automatic payment scheduling based on system configuration and vendor terms.

**Parameters**:
- `invoice_id`: Invoice to approve
- `approver_id`: User providing approval
- `approval_level`: Level of authority
- `approval_notes`: Comments or justification

**Business Rules**:
- Approver must have sufficient authority level
- Invoice must be in pending approval state
- Cannot approve own invoices (segregation of duties)

---

#### RejectInvoice Command
**Purpose**: Rejects an invoice and returns to originator.

**Description**: Records rejection decision with reason codes and triggers notification workflow. Handles compensation activities including encumbrance reversal and vendor notification.

**Parameters**:
- `invoice_id`: Invoice to reject
- `rejection_reason`: Coded reason for rejection
- `rejected_by`: User making rejection
- `return_to_vendor`: Flag for vendor notification

**Business Rules**:
- Rejection reason must be provided
- Cannot reject paid invoices
- Triggers compensation workflow

---

#### CancelInvoice Command
**Purpose**: Cancels an invoice before processing completion.

**Description**: Voids an invoice and reverses any associated transactions or allocations. Triggers cleanup activities including GL reversal and vendor notification.

**Parameters**:
- `invoice_id`: Invoice to cancel
- `cancellation_reason`: Reason for cancellation
- `authorized_by`: User with cancellation authority
- `effective_date`: When cancellation takes effect

**Business Rules**:
- Authorization required based on invoice amount
- Cannot cancel processed payments
- Triggers automatic reversal entries

---

### Invoice Events

#### InvoiceReceived Event
**Purpose**: Records the receipt of a new invoice in the system.

**Description**: Emitted when an invoice is successfully created and entered into the system. Contains all invoice details and triggers downstream processing workflows.

**Data**:
- `invoice_id`: Unique invoice identifier
- `vendor_id`: Source vendor
- `invoice_number`: Vendor invoice number
- `amount`: Invoice amount
- `due_date`: Payment due date
- `received_at`: System timestamp

**Downstream Effects**:
- Updates vendor transaction history
- Triggers validation workflow
- Updates AP aging projections
- Notifies approval workflow if required

---

#### InvoiceValidated Event
**Purpose**: Records completion of invoice validation process.

**Description**: Emitted when invoice validation completes, including results of business rule checks, three-way matching, and duplicate detection. Routes invoice to next processing stage.

**Data**:
- `invoice_id`: Validated invoice
- `validation_results`: Pass/fail status for each rule
- `matching_status`: Three-way matching results
- `approval_required`: Whether approval needed
- `validated_at`: Validation completion timestamp

**Downstream Effects**:
- Routes to approval workflow if required
- Updates invoice status projections
- Triggers payment scheduling if auto-approved

---

#### InvoiceApproved Event
**Purpose**: Records invoice approval and authorization for payment.

**Description**: Emitted when invoice receives all required approvals and is authorized for payment. Triggers payment scheduling and updates various projections.

**Data**:
- `invoice_id`: Approved invoice
- `approved_by`: Final approver
- `approval_level`: Authority level used
- `approved_at`: Approval timestamp
- `payment_scheduling`: Automatic scheduling instructions

**Downstream Effects**:
- Enables payment scheduling
- Updates AP aging and cash flow projections
- Triggers budget encumbrance if configured

---

## Payment Management Commands and Events

### Payment Processing

#### SchedulePayment Command
**Purpose**: Schedules invoice for payment in upcoming payment run.

**Description**: Adds approved invoices to payment queue with payment method selection, date calculation, and batch assignment. Considers early payment discounts and cash flow optimization.

**Parameters**:
- `payment_id`: Unique payment identifier
- `invoice_ids`: List of invoices to pay
- `payment_method`: Method (check, ACH, wire, virtual card)
- `payment_date`: Scheduled payment date
- `take_discount`: Whether to take early payment discount

**Business Rules**:
- All invoices must be approved
- Payment date must consider method lead times
- Early payment discount eligibility validation
- Cash availability confirmation

---

#### ExecutePayment Command
**Purpose**: Executes payment through selected payment method.

**Description**: Processes payment including bank file generation, payment transmission, and status tracking. Handles various payment methods with appropriate security and audit controls.

**Parameters**:
- `payment_id`: Payment to execute
- `bank_account_id`: Source bank account
- `execution_method`: Specific execution approach
- `dual_approval`: Second authorization if required

**Business Rules**:
- Dual approval required for high-value payments
- Bank account validation and prenote confirmation
- OFAC screening completion required
- Payment limits validation

---

#### CancelPayment Command
**Purpose**: Cancels a scheduled payment before execution.

**Description**: Removes payment from processing queue and updates invoice status. Handles payment cancellation with appropriate audit trail and notification.

**Parameters**:
- `payment_id`: Payment to cancel
- `cancellation_reason`: Coded reason
- `cancelled_by`: User requesting cancellation
- `notify_vendor`: Whether to notify vendor

**Business Rules**:
- Cannot cancel executed payments
- Cancellation authority validation
- Invoice status restoration to approved

---

#### ReversePayment Command
**Purpose**: Reverses a completed payment (recall or stop payment).

**Description**: Initiates payment reversal including bank notification, GL reversal entries, and vendor communication. Handles complex reversal scenarios with proper compensation.

**Parameters**:
- `payment_id`: Payment to reverse
- `reversal_type`: Stop payment, recall, or correction
- `reversal_reason`: Detailed explanation
- `authorized_by`: High-level authorization

**Business Rules**:
- High-level authorization required
- Cannot reverse payments older than cutoff period
- Triggers automatic GL reversal entries
- Vendor notification required

---

### Payment Events

#### PaymentScheduled Event
**Purpose**: Records payment scheduling and queue assignment.

**Description**: Emitted when invoices are scheduled for payment with method selection and timing. Updates cash flow projections and payment run status.

**Data**:
- `payment_id`: Scheduled payment identifier
- `invoice_ids`: List of invoices included
- `payment_method`: Selected payment method
- `payment_date`: Scheduled execution date
- `total_amount`: Payment amount

**Downstream Effects**:
- Updates cash flow forecasting
- Updates payment run status
- Triggers bank account validation if needed

---

#### PaymentExecuted Event
**Purpose**: Records successful payment execution and transmission.

**Description**: Emitted when payment is successfully transmitted to bank with transaction reference. Updates invoice payment status and triggers reconciliation procedures.

**Data**:
- `payment_id`: Executed payment
- `transaction_reference`: Bank reference number
- `execution_method`: Actual method used
- `executed_at`: Execution timestamp
- `confirmation_expected`: Expected confirmation timing

**Downstream Effects**:
- Updates invoice payment status
- Creates receivable for confirmation
- Triggers GL posting for payment
- Updates vendor payment history

---

#### PaymentConfirmed Event
**Purpose**: Records bank confirmation of payment settlement.

**Description**: Emitted when bank confirms payment settlement with final status. Completes payment lifecycle and triggers final reconciliation activities.

**Data**:
- `payment_id`: Confirmed payment
- `settlement_date`: Bank settlement date
- `settlement_amount`: Final settled amount
- `bank_reference`: Bank confirmation reference
- `fees_charged`: Any bank fees

**Downstream Effects**:
- Completes payment reconciliation
- Updates cash position
- Finalizes vendor payment status
- Updates performance metrics

---

## Vendor Management Commands and Events

### Vendor Lifecycle

#### CreateVendor Command
**Purpose**: Creates a new vendor account in the system.

**Description**: Initiates vendor onboarding process including basic information capture, compliance validation setup, and initial risk assessment. Sets vendor status to pending approval.

**Parameters**:
- `vendor_id`: Unique vendor identifier
- `vendor_number`: System-assigned vendor number
- `legal_name`: Official business name
- `tax_id`: Federal tax identification
- `address`: Primary business address
- `contact_info`: Primary contact details

**Business Rules**:
- Tax ID uniqueness validation
- Business name format validation
- Initial compliance screening
- Duplicate vendor detection

---

#### OnboardVendor Command
**Purpose**: Completes vendor onboarding with full validation and approval.

**Description**: Executes comprehensive vendor onboarding including compliance checks, banking validation, insurance verification, and final approval. Transitions vendor to active status upon completion.

**Parameters**:
- `vendor_id`: Vendor being onboarded
- `compliance_documents`: Required compliance documentation
- `banking_details`: Payment method information
- `risk_assessment`: Risk evaluation results
- `approved_by`: Onboarding approver

**Business Rules**:
- All compliance documents must be current
- Banking information validation required
- Risk assessment must be within acceptable limits
- Final approval authority validation

---

#### UpdateVendorStatus Command
**Purpose**: Changes vendor status with proper authorization and audit trail.

**Description**: Manages vendor status transitions including activation, suspension, blocking, and termination. Handles impact on pending transactions and provides appropriate notifications.

**Parameters**:
- `vendor_id`: Vendor to update
- `new_status`: Target status
- `status_reason`: Reason for change
- `effective_date`: When change becomes effective
- `impact_analysis`: Effect on pending transactions

**Business Rules**:
- Status transition validation
- Impact analysis on open invoices and payments
- Authorization level requirements
- Notification requirements

---

#### ClassifyVendor Command
**Purpose**: Assigns or updates vendor classification for business rules.

**Description**: Sets vendor classification (strategic, preferred, critical, standard, one-time) based on spend analysis, strategic importance, and business rules. Affects payment terms, approval requirements, and monitoring frequency.

**Parameters**:
- `vendor_id`: Vendor to classify
- `classification`: New classification level
- `annual_spend`: Spend analysis data
- `strategic_importance`: Business criticality assessment
- `classification_reason`: Justification for classification

**Business Rules**:
- Classification must match spend and importance criteria
- Changes require appropriate authorization
- Affects payment terms and approval workflows

---

### Vendor Events

#### VendorCreated Event
**Purpose**: Records creation of new vendor account.

**Description**: Emitted when vendor account is successfully created in the system. Contains vendor master data and triggers initial setup activities.

**Data**:
- `vendor_id`: Created vendor identifier
- `vendor_number`: Assigned vendor number
- `legal_name`: Business legal name
- `initial_status`: Starting status (pending_approval)
- `created_by`: User creating vendor
- `created_at`: Creation timestamp

**Downstream Effects**:
- Initializes vendor projections
- Triggers onboarding workflow
- Creates audit trail entry
- Sets up compliance monitoring

---

#### VendorOnboarded Event
**Purpose**: Records completion of vendor onboarding process.

**Description**: Emitted when vendor successfully completes onboarding with all validations passed. Enables vendor for transaction processing.

**Data**:
- `vendor_id`: Onboarded vendor
- `classification`: Assigned classification
- `risk_level`: Risk assessment result
- `payment_methods`: Approved payment methods
- `onboarded_by`: Completing user
- `onboarded_at`: Completion timestamp

**Downstream Effects**:
- Enables transaction processing
- Updates vendor master projections
- Triggers payment setup completion
- Notifies relevant teams

---

#### VendorStatusChanged Event
**Purpose**: Records vendor status transitions with audit trail.

**Description**: Emitted when vendor status changes including activation, suspension, blocking, or termination. Provides complete audit trail and triggers appropriate business processes.

**Data**:
- `vendor_id`: Affected vendor
- `previous_status`: Former status
- `new_status`: Current status
- `change_reason`: Reason for change
- `effective_date`: When change became effective
- `changed_by`: Authorizing user

**Downstream Effects**:
- Updates vendor availability for transactions
- Triggers impact analysis on pending items
- Updates risk monitoring frequency
- Notifies affected stakeholders

---

## Payment Run Commands and Events

### Payment Run Processing

#### InitiatePaymentRun Command
**Purpose**: Starts a new payment run with selection criteria.

**Description**: Begins payment run process including invoice selection criteria definition, payment method preferences, and execution timeline. Sets up payment run for invoice selection and approval.

**Parameters**:
- `run_id`: Payment run identifier
- `run_date`: Execution date for payments
- `selection_criteria`: Invoice selection rules
- `payment_methods`: Preferred payment methods
- `cash_limit`: Maximum payment amount

**Business Rules**:
- Run date must allow for payment method lead times
- Cash availability validation
- No overlapping runs for same vendor set

---

#### SelectInvoicesForPayment Command
**Purpose**: Selects specific invoices for inclusion in payment run.

**Description**: Applies selection criteria to identify invoices for payment considering due dates, early payment discounts, vendor priorities, and cash availability. Optimizes selection for maximum benefit.

**Parameters**:
- `run_id`: Target payment run
- `selection_criteria`: Applied selection rules
- `discount_optimization`: Whether to optimize for discounts
- `vendor_priorities`: Priority vendor handling

**Business Rules**:
- All selected invoices must be approved
- Early payment discount calculation and NPV analysis
- Vendor payment term compliance
- Cash availability within limits

---

#### ApprovePaymentRun Command
**Purpose**: Approves payment run for execution.

**Description**: Provides authorization for payment run execution including final validation, approval authority verification, and execution scheduling. Enables payment file generation and transmission.

**Parameters**:
- `run_id`: Payment run to approve
- `approved_by`: Approving authority
- `approval_conditions`: Any special conditions
- `execution_schedule`: When to execute payments

**Business Rules**:
- Approver authority level validation
- Final cash availability check
- Payment method validation for all payments
- Compliance screening completion

---

#### ExecutePaymentRun Command
**Purpose**: Executes approved payment run including file generation and transmission.

**Description**: Processes payment run including payment file generation, bank transmission, status tracking, and error handling. Coordinates multiple payment methods and handles execution monitoring.

**Parameters**:
- `run_id`: Payment run to execute
- `execution_method`: File generation and transmission approach
- `bank_accounts`: Source accounts for payments
- `monitoring_config`: Execution monitoring parameters

**Business Rules**:
- All payments must be approved
- Bank account validation and authorization
- File format validation for each payment method
- Transmission security requirements

---

### Payment Run Events

#### PaymentRunInitiated Event
**Purpose**: Records start of new payment run process.

**Description**: Emitted when payment run process begins with criteria and configuration. Establishes payment run context for subsequent processing.

**Data**:
- `run_id`: Payment run identifier
- `run_date`: Scheduled execution date
- `selection_criteria`: Invoice selection rules
- `initiated_by`: User starting process
- `cash_limit`: Maximum payment amount

**Downstream Effects**:
- Initializes payment run projections
- Triggers invoice selection process
- Updates cash flow forecasting
- Creates audit trail entry

---

#### PaymentRunCompleted Event
**Purpose**: Records successful completion of payment run.

**Description**: Emitted when payment run completes successfully with all payments processed. Provides summary results and triggers final cleanup activities.

**Data**:
- `run_id`: Completed payment run
- `total_payments`: Number of payments processed
- `total_amount`: Total payment amount
- `payment_methods`: Methods used in run
- `execution_results`: Detailed results by payment
- `completed_at`: Completion timestamp

**Downstream Effects**:
- Updates payment run history
- Finalizes cash flow impact
- Triggers reconciliation procedures
- Updates vendor payment history

---

## Three-Way Matching Commands and Events

### Matching Process

#### InitiateThreeWayMatch Command
**Purpose**: Starts three-way matching process for purchase order, receipt, and invoice.

**Description**: Begins matching process when any of the three documents (PO, receipt, invoice) is received. Establishes matching context and applies tolerance rules for validation.

**Parameters**:
- `match_id`: Unique matching process identifier
- `purchase_order_id`: PO reference (if available)
- `receipt_id`: Goods receipt reference (if available)
- `invoice_id`: Invoice reference (if available)
- `tolerance_settings`: Matching tolerance configuration

**Business Rules**:
- At least one document must be present to initiate
- Tolerance settings must be within configured limits
- Documents must reference same vendor and items

---

#### CompleteThreeWayMatch Command
**Purpose**: Finalizes three-way matching with variance resolution.

**Description**: Completes matching process after all three documents are available and variances are within tolerance or approved. Authorizes invoice for payment processing.

**Parameters**:
- `match_id`: Matching process to complete
- `final_variances`: Resolved variance details
- `variance_approvals`: Approvals for out-of-tolerance items
- `completion_notes`: Any special notes or conditions

**Business Rules**:
- All variances must be within tolerance or approved
- Cannot complete with missing documents
- Variance approvals must have appropriate authority

---

### Three-Way Matching Events

#### ThreeWayMatchCompleted Event
**Purpose**: Records successful completion of three-way matching.

**Description**: Emitted when three-way matching completes successfully with all documents matched and variances resolved. Authorizes invoice for payment processing.

**Data**:
- `match_id`: Completed matching process
- `invoice_id`: Matched invoice
- `purchase_order_id`: Matched purchase order
- `receipt_id`: Matched goods receipt
- `final_variances`: Any remaining variances
- `completed_at`: Completion timestamp

**Downstream Effects**:
- Authorizes invoice for payment
- Updates matching status projections
- Triggers automatic payment scheduling if configured
- Updates vendor performance metrics

---

#### VarianceDetected Event
**Purpose**: Records detection of matching variances outside tolerance.

**Description**: Emitted when variances between documents exceed configured tolerances. Triggers exception handling workflow and approval routing.

**Data**:
- `match_id`: Matching process with variance
- `variance_type`: Type of variance (quantity, price, date)
- `variance_amount`: Magnitude of variance
- `tolerance_exceeded`: How much over tolerance
- `approval_required`: Required approval level

**Downstream Effects**:
- Routes to variance approval workflow
- Places invoice on hold
- Updates exception reporting
- Triggers notification to relevant parties

---

## Vendor Onboarding Commands and Events

### Onboarding Process

#### InitiateVendorOnboarding Command
**Purpose**: Starts comprehensive vendor onboarding process.

**Description**: Begins vendor onboarding workflow including compliance validation, risk assessment, banking setup, and approval routing. Manages onboarding checklist and progress tracking.

**Parameters**:
- `vendor_id`: Vendor being onboarded
- `onboarding_type`: Standard or expedited process
- `required_documents`: Compliance documentation needed
- `risk_tolerance`: Acceptable risk level
- `priority_level`: Processing priority

**Business Rules**:
- All required documents must be specified
- Risk tolerance must be within company policy
- Onboarding type determines validation requirements

---

#### ValidateVendorCompliance Command
**Purpose**: Validates vendor compliance with regulatory and company requirements.

**Description**: Executes compliance validation including tax ID verification, business license verification, insurance validation, and regulatory screening. Determines vendor risk level and monitoring requirements.

**Parameters**:
- `vendor_id`: Vendor to validate
- `compliance_requirements`: Specific requirements to check
- `validation_level`: Standard or enhanced validation
- `regulatory_jurisdiction`: Applicable regulatory framework

**Business Rules**:
- All compliance requirements must pass
- Enhanced validation for high-risk vendors
- Regulatory screening must be current
- Insurance coverage must be adequate

---

### Onboarding Events

#### VendorOnboardingInitiated Event
**Purpose**: Records start of vendor onboarding process.

**Description**: Emitted when vendor onboarding workflow begins. Establishes onboarding context and triggers initial validation activities.

**Data**:
- `vendor_id`: Vendor being onboarded
- `onboarding_type`: Process type (standard/expedited)
- `required_validations`: Checklist of required activities
- `initiated_by`: User starting process
- `target_completion`: Expected completion date

**Downstream Effects**:
- Initializes onboarding progress tracking
- Triggers compliance validation workflow
- Creates vendor setup projections
- Establishes audit trail

---

#### VendorValidated Event
**Purpose**: Records completion of vendor validation process.

**Description**: Emitted when vendor passes all compliance and business validations. Enables vendor activation and transaction processing authorization.

**Data**:
- `vendor_id`: Validated vendor
- `validation_results`: Results of all validation checks
- `risk_assessment`: Final risk evaluation
- `compliance_status`: Compliance verification results
- `validated_by`: Validator or system component

**Downstream Effects**:
- Enables vendor activation
- Updates risk monitoring configuration
- Completes onboarding workflow
- Triggers final approval if automatic

---

## Recurring Transaction Commands and Events

### Recurring Invoice Processing

#### CreateRecurringTemplate Command
**Purpose**: Creates template for recurring invoice processing.

**Description**: Sets up recurring invoice template including schedule, amounts, GL distributions, and processing rules. Enables automatic invoice generation based on configured schedule.

**Parameters**:
- `template_id`: Recurring template identifier
- `vendor_id`: Vendor for recurring invoices
- `recurrence_pattern`: Schedule pattern (monthly, quarterly, etc.)
- `template_amount`: Standard amount
- `gl_distributions`: Account coding template

**Business Rules**:
- Vendor must be active and approved
- Recurrence pattern must be valid
- GL distributions must be complete and valid
- Template amount must be reasonable

---

#### ProcessRecurringInvoice Command
**Purpose**: Generates invoice from recurring template.

**Description**: Creates actual invoice from recurring template including amount calculation, date determination, and automatic processing options. Handles template-based invoice generation with appropriate validations.

**Parameters**:
- `template_id`: Source template
- `generation_date`: Invoice generation date
- `amount_adjustments`: Any amount modifications
- `auto_approve`: Whether to auto-approve generated invoice

**Business Rules**:
- Template must be active
- Generation date must match schedule
- Amount adjustments require authorization
- Auto-approval based on template configuration

---

### Recurring Transaction Events

#### RecurringTemplateCreated Event
**Purpose**: Records creation of recurring invoice template.

**Description**: Emitted when recurring invoice template is successfully created and configured. Enables automatic invoice generation based on schedule.

**Data**:
- `template_id`: Created template identifier
- `vendor_id`: Associated vendor
- `recurrence_pattern`: Configured schedule
- `template_amount`: Standard invoice amount
- `next_generation_date`: Next scheduled generation

**Downstream Effects**:
- Enables automatic invoice generation
- Updates recurring processing schedule
- Creates template audit trail
- Configures monitoring and alerts

---

#### RecurringInvoiceGenerated Event
**Purpose**: Records automatic generation of invoice from template.

**Description**: Emitted when invoice is automatically generated from recurring template. Contains generated invoice details and template reference for audit trail.

**Data**:
- `template_id`: Source template
- `generated_invoice_id`: Created invoice
- `generation_date`: When generated
- `template_amount`: Template amount used
- `actual_amount`: Final invoice amount
- `next_generation_date`: Next scheduled generation

**Downstream Effects**:
- Creates new invoice for processing
- Updates template generation history
- Schedules next generation
- Updates recurring invoice projections

---

## Document Management Commands and Events

### Document Processing

#### StoreInvoiceDocument Command
**Purpose**: Stores invoice document image or electronic file.

**Description**: Captures and stores invoice documents including image processing, OCR extraction, metadata indexing, and retention management. Supports various document formats and compliance requirements.

**Parameters**:
- `document_id`: Document identifier
- `invoice_id`: Associated invoice
- `document_content`: Document content or image
- `document_type`: Type of document (image, PDF, etc.)
- `metadata`: Document metadata and indexing information

**Business Rules**:
- Document must be readable and valid
- OCR extraction validation
- Retention period compliance
- Security and access control requirements

---

#### RetrieveDocuments Command
**Purpose**: Retrieves stored documents for invoice or vendor.

**Description**: Fetches stored documents with proper access control validation. Supports various retrieval scenarios including audit requests, approval workflows, and compliance inquiries.

**Parameters**:
- `retrieval_id`: Request identifier
- `reference_type`: Type of reference (invoice, vendor, etc.)
- `reference_id`: Specific reference identifier
- `document_types`: Types of documents to retrieve
- `access_reason`: Reason for document access

**Business Rules**:
- Access authorization validation
- Document availability verification
- Audit trail for access requests
- Retention policy compliance

---

### Document Events

#### DocumentStored Event
**Purpose**: Records successful document storage.

**Description**: Emitted when invoice document is successfully stored with indexing and metadata. Enables document retrieval and supports audit trail requirements.

**Data**:
- `document_id`: Stored document identifier
- `invoice_id`: Associated invoice
- `storage_location`: Document storage reference
- `document_metadata`: Extracted metadata and indexing
- `retention_until`: Document retention expiration

**Downstream Effects**:
- Enables document retrieval
- Updates document index projections
- Triggers OCR processing if applicable
- Creates document audit trail

---

## Tax and Compliance Commands and Events

### Tax Processing

#### Generate1099Forms Command
**Purpose**: Generates 1099 tax forms for qualifying vendors.

**Description**: Creates 1099 tax forms for vendors meeting reporting thresholds including payment aggregation, tax calculation, form generation, and distribution preparation.

**Parameters**:
- `tax_year`: Year for 1099 reporting
- `vendor_qualifications`: Vendors meeting 1099 thresholds
- `form_types`: Types of 1099 forms to generate
- `distribution_method`: How to distribute forms

**Business Rules**:
- Only qualified vendors included
- Payment thresholds must be met
- Tax year must be complete
- Form generation compliance validation

---

#### ProcessComplianceCheck Command
**Purpose**: Executes compliance validation for vendors or transactions.

**Description**: Performs comprehensive compliance checking including OFAC screening, tax compliance validation, regulatory requirement verification, and compliance documentation review.

**Parameters**:
- `compliance_check_id`: Check identifier
- `entity_type`: Vendor or transaction being checked
- `entity_id`: Specific entity identifier
- `compliance_requirements`: Requirements to validate
- `check_priority`: Processing priority

**Business Rules**:
- All applicable requirements must be checked
- Enhanced screening for high-risk entities
- Current compliance documentation required
- Automated blocking for violations

---

### Tax and Compliance Events

#### ComplianceValidated Event
**Purpose**: Records successful compliance validation.

**Description**: Emitted when entity passes all required compliance checks. Enables continued processing and establishes compliance status for monitoring.

**Data**:
- `entity_id`: Validated entity
- `entity_type`: Type of entity (vendor/transaction)
- `validation_results`: Results of all compliance checks
- `compliance_expiry`: When validation expires
- `validated_at`: Validation completion timestamp

**Downstream Effects**:
- Enables continued transaction processing
- Updates compliance monitoring schedule
- Creates compliance audit trail
- Triggers renewal reminders if applicable

---

#### ComplianceViolationDetected Event
**Purpose**: Records detection of compliance violation.

**Description**: Emitted when compliance violation is detected requiring immediate action. Triggers blocking, investigation, and remediation workflows.

**Data**:
- `entity_id`: Entity with violation
- `violation_type`: Type of compliance violation
- `violation_severity`: Impact level of violation
- `required_actions`: Immediate actions required
- `detected_at`: Detection timestamp

**Downstream Effects**:
- Blocks further processing
- Triggers investigation workflow
- Updates risk assessment
- Notifies compliance team

---

## Error Handling and Recovery Commands and Events

### Error Processing

#### HandleProcessingError Command
**Purpose**: Manages processing errors with appropriate recovery actions.

**Description**: Coordinates error handling including error classification, recovery action determination, compensation processing, and escalation management. Ensures system integrity during error conditions.

**Parameters**:
- `error_id`: Error incident identifier
- `error_type`: Classification of error
- `affected_entities`: Entities impacted by error
- `recovery_strategy`: Approach for recovery
- `escalation_required`: Whether to escalate

**Business Rules**:
- Error classification must be accurate
- Recovery strategy must be appropriate for error type
- Escalation based on error severity and impact
- Compensation requirements for financial impact

---

#### InitiateErrorRecovery Command
**Purpose**: Begins systematic error recovery process.

**Description**: Executes error recovery including state restoration, compensation transactions, data correction, and process restart. Handles complex recovery scenarios with validation and audit requirements.

**Parameters**:
- `recovery_id`: Recovery process identifier
- `error_context`: Original error information
- `recovery_actions`: Specific actions to take
- `validation_requirements`: Recovery validation needed

**Business Rules**:
- Recovery actions must be appropriate and safe
- Validation required before process restart
- Audit trail maintained throughout recovery
- Stakeholder notification for significant recoveries

---

### Error and Recovery Events

#### ProcessingErrorOccurred Event
**Purpose**: Records occurrence of processing error requiring attention.

**Description**: Emitted when processing error occurs that requires intervention or recovery action. Provides error context and triggers appropriate response workflows.

**Data**:
- `error_id`: Error incident identifier
- `error_type`: Classification of error
- `error_context`: Details about error conditions
- `affected_processes`: Processes impacted
- `severity_level`: Impact assessment
- `occurred_at`: Error occurrence timestamp

**Downstream Effects**:
- Triggers error handling workflow
- Updates system health monitoring
- Creates error tracking entry
- Notifies appropriate personnel

---

#### ErrorRecoveryCompleted Event
**Purpose**: Records successful completion of error recovery.

**Description**: Emitted when error recovery completes successfully with system restored to consistent state. Validates recovery success and resumes normal processing.

**Data**:
- `recovery_id`: Recovery process identifier
- `original_error_id`: Original error that was recovered
- `recovery_actions`: Actions taken for recovery
- `validation_results`: Recovery validation results
- `completed_at`: Recovery completion timestamp

**Downstream Effects**:
- Resumes normal processing
- Updates error recovery metrics
- Completes error incident tracking
- Provides lessons learned for process improvement

---

## Summary

The Accounts Payable domain contains **25 primary command types** and **20 primary event types** organized into:

**Invoice Management**: Invoice creation, validation, approval, and cancellation commands with corresponding lifecycle events
**Payment Processing**: Payment scheduling, execution, and management commands with confirmation and status events
**Vendor Management**: Vendor lifecycle, onboarding, and status management commands with vendor state change events
**Payment Runs**: Payment run initiation, selection, approval, and execution commands with run lifecycle events
**Three-Way Matching**: Matching process initiation and completion commands with variance and completion events
**Recurring Transactions**: Template creation and processing commands with generation and lifecycle events
**Document Management**: Document storage and retrieval commands with document lifecycle events
**Tax and Compliance**: Compliance validation and tax processing commands with validation and violation events
**Error Handling**: Error processing and recovery commands with error occurrence and recovery events

Each command includes detailed parameters, business rules, and validation requirements, while events provide comprehensive data about system state changes and trigger appropriate downstream processing. The design supports complex AP business processes while maintaining data integrity, audit compliance, and system reliability through sophisticated error handling and recovery mechanisms.