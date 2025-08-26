# Accounts Payables Business Logic Requirements

## Executive Summary

This document defines comprehensive business logic requirements for the Accounts Payables (AP) module within the Accountex ERP system. The requirements focus on core business processes, event-driven architecture patterns using Elixir/Ash/Commanded/AshCommanded, integration points with other ERP modules, and detailed business rules and validations. All implementation follows an event-sourced, CQRS architecture pattern suitable for financial transaction processing.

## 1. Core Business Logic Architecture

### 1.1 Domain Aggregates

The AP domain is organized into the following primary aggregates:

```elixir
# Primary Aggregates
AP.Aggregates.Invoice
AP.Aggregates.Payment  
AP.Aggregates.Vendor
AP.Aggregates.PaymentRun
AP.Aggregates.ThreeWayMatch
```

### 1.2 Command/Event Structure

Each aggregate processes commands and emits domain events following CQRS patterns:

```elixir
# Invoice Commands → Events
CreateInvoice → InvoiceReceived
ValidateInvoice → InvoiceValidated  
ApproveInvoice → InvoiceApproved
RejectInvoice → InvoiceRejected
CancelInvoice → InvoiceCancelled
MarkInvoicePaid → InvoiceMarkedAsPaid

# Payment Commands → Events
SchedulePayment → PaymentScheduled
ExecutePayment → PaymentExecuted
CancelPayment → PaymentCancelled
ReversePayment → PaymentReversed
```

### 1.3 State Machines

#### Invoice State Machine

```
States:
- draft: Initial data entry state
- pending_validation: System validation in progress  
- pending_match: Three-way matching in process
- on_hold: Various hold types (matching, pricing, approval)
- pending_approval: Routed to designated approvers
- approved: Ready for payment processing
- paid: Payment processed and reconciled
- rejected: Returned to originator
- cancelled: Voided before processing

Valid Transitions:
- draft → pending_validation
- pending_validation → pending_match | on_hold
- pending_match → on_hold | pending_approval  
- on_hold → pending_approval | rejected
- pending_approval → approved | rejected
- approved → paid | cancelled
- any_state → cancelled (with authorization)
```

#### Payment State Machine

```
States:
- created: Payment instruction generated
- pending_approval: Awaiting authorization
- approved: Authorization complete
- processing: In transmission to bank
- sent: Successfully transmitted
- confirmed: Settlement confirmed  
- failed: Payment rejected
- reversed: Payment recalled

Valid Transitions:
- created → pending_approval
- pending_approval → approved | cancelled
- approved → processing
- processing → sent | failed
- sent → confirmed | failed  
- confirmed → reversed (compensation)
- failed → created (retry)
```

## 2. Invoice Processing Business Logic

### 2.1 Invoice Receipt and Capture

#### Business Rules
- All invoices must have unique invoice number per vendor
- Invoice date cannot be future-dated
- Invoice date cannot be more than 90 days in the past
- Due date must be calculated based on vendor payment terms
- Currency must match vendor's approved currency list

#### Validation Requirements
```elixir
defmodule AP.Validations.Invoice do
  # Mandatory field validation
  validate :vendor_id, presence: true, vendor_active: true
  validate :invoice_number, presence: true, uniqueness: {scope: :vendor_id}
  validate :invoice_date, presence: true, not_future_dated: true
  validate :amount, presence: true, numericality: {greater_than: 0}
  
  # Business rule validation  
  validate :currency, inclusion: {in: vendor_approved_currencies}
  validate :payment_terms, consistency_with_vendor_terms: true
  validate :tax_calculation, accuracy_check: {tolerance: 0.01}
  
  # Duplicate detection
  validate :duplicate_check, using: [:invoice_number, :vendor_id, :amount, :date]
end
```

### 2.2 Three-Way Matching Logic

#### Matching Process Manager
```elixir
defmodule AP.ProcessManagers.ThreeWayMatching do
  # Process initiated when any of the three documents arrive
  # Completes when all three match within tolerance
  
  defstruct [
    :purchase_order_id,
    :invoice_id, 
    :receipt_id,
    :po_received?,
    :invoice_received?,
    :goods_received?,
    :matching_status,
    :variances
  ]
  
  # Matching tolerance rules
  @quantity_tolerance 0.05  # 5%
  @price_tolerance 0.05     # 5%  
  @amount_tolerance 100     # $100 absolute
end
```

#### Tolerance Configuration
- **Quantity Variance**: ±5% for standard items, ±2% for high-value items, 0% for controlled items
- **Price Variance**: ±5% of PO price, with absolute maximum of $100
- **Date Variance**: Invoice date within 7 days of receipt date
- **Tax Variance**: ±$0.01 rounding tolerance

#### Exception Handling
- Variances outside tolerance trigger hold status
- Automatic routing based on variance type and amount
- Required approval levels based on variance severity
- Reason codes required for override approvals

### 2.3 Approval Workflows

#### Approval Matrix Configuration
```elixir
defmodule AP.ApprovalMatrix do
  def determine_approvers(invoice_amount, vendor_type, department) do
    cond do
      invoice_amount > 100_000 -> [:cfo, :ceo]
      invoice_amount > 50_000 -> [:controller, :cfo]  
      invoice_amount > 10_000 -> [:finance_manager, :controller]
      invoice_amount > 1_000 -> [:department_manager, :finance_manager]
      true -> [:supervisor]
    end
  end
  
  def escalation_rules do
    %{
      reminder_after: {2, :days},
      escalate_after: {5, :days},
      auto_approve_after: {10, :days}  # For amounts < $1000
    }
  end
end
```

#### Delegation Rules
- Temporary delegation with start/end dates
- Approval limits can be inherited or reduced
- Delegation chains limited to 2 levels
- Audit trail of all delegated approvals

### 2.4 GL Coding and Distribution

#### Account Determination Rules
```elixir
defmodule AP.GLCoding do
  def determine_gl_accounts(invoice, vendor) do
    %{
      debit_account: derive_expense_account(invoice, vendor),
      credit_account: "2000-00-000",  # Accounts Payable
      tax_account: derive_tax_account(invoice.tax_jurisdiction),
      cost_center: invoice.department_code,
      project_code: invoice.project_id
    }
  end
  
  # Automatic coding based on vendor category
  def derive_expense_account(invoice, vendor) do
    case vendor.category do
      :utilities -> "7100-00-000"
      :supplies -> "7200-00-000"  
      :professional_services -> "7300-00-000"
      :capital_equipment -> "1500-00-000"
      _ -> vendor.default_gl_account
    end
  end
end
```

#### Split Distribution Rules
- Support percentage-based splits across multiple accounts
- Support quantity-based splits for allocation
- Maintain audit trail of distribution changes
- Validate sum of distributions equals invoice total

## 3. Payment Processing Business Logic

### 3.1 Payment Run Processing

#### Payment Selection Criteria
```elixir
defmodule AP.PaymentRun do
  def select_invoices_for_payment(run_date) do
    invoices
    |> filter_by_due_date(run_date + lead_time())
    |> filter_by_early_payment_discount_eligibility()
    |> filter_by_vendor_priority()
    |> filter_by_cash_availability()
    |> group_by_payment_method()
    |> apply_payment_limits()
  end
  
  def lead_time do
    %{
      check: 5,      # 5 days for check printing/mailing
      ach: 2,        # 2 days for ACH processing
      wire: 0,       # Same day for wire transfers
      virtual_card: 1 # 1 day for virtual card generation
    }
  end
end
```

#### Early Payment Discount Logic
- Calculate NPV of discount vs. cost of capital
- Automatically select invoices with positive NPV
- Track discount captured vs. discount available metrics
- Generate exception report for missed discounts

### 3.2 Payment Method Selection

#### Payment Method Rules Engine
```elixir
defmodule AP.PaymentMethodSelection do
  def determine_payment_method(vendor, amount, urgency) do
    cond do
      urgency == :immediate && amount > 10_000 -> :wire
      vendor.preferred_method == :virtual_card -> :virtual_card
      amount > 50_000 -> :ach
      vendor.international? -> :wire
      true -> vendor.preferred_method || :check
    end
  end
  
  def validate_payment_method(vendor, method) do
    method in vendor.approved_payment_methods &&
    validate_bank_account(vendor, method) &&
    validate_payment_limits(vendor, method)
  end
end
```

#### Payment Validation Rules
- Bank account validation via prenote or microdeposit
- OFAC/sanctions screening before payment execution
- Duplicate payment prevention checks
- Payment limit validation by method and vendor

### 3.3 Payment Approval Workflows

#### Dual Control Requirements
```elixir
defmodule AP.PaymentApproval do
  def approval_requirements(payment) do
    %{
      requires_dual_control: payment.amount > 10_000,
      approval_levels: determine_approval_levels(payment.amount),
      segregation_of_duties: [
        creator: :cannot_approve,
        approver: :cannot_execute,
        executor: :cannot_reconcile
      ]
    }
  end
end
```

### 3.4 Bank Integration

#### Payment File Generation
```elixir
defmodule AP.BankIntegration do
  def generate_payment_file(payments, format) do
    case format do
      :nacha -> generate_nacha_file(payments)
      :positive_pay -> generate_positive_pay_file(payments)
      :swift_mt103 -> generate_swift_message(payments)
      :iso20022 -> generate_iso20022_file(payments)
    end
  end
  
  def payment_confirmation_handling(bank_response) do
    case bank_response.status do
      :accepted -> emit_payment_confirmed_event()
      :rejected -> emit_payment_failed_event()
      :pending -> schedule_status_check()
    end
  end
end
```

## 4. Vendor Management Business Logic

### 4.1 Vendor Lifecycle Management

#### Vendor State Machine
```
States:
- prospect: Initial inquiry/interest
- pending_approval: Under review
- active: Approved for transactions
- on_hold: Temporarily suspended
- inactive: Not currently used
- blocked: Compliance violation
- terminated: Relationship ended

Valid Transitions:
- prospect → pending_approval
- pending_approval → active | rejected
- active → on_hold | inactive | blocked
- on_hold → active | terminated
- inactive → active | terminated
- blocked → terminated
```

### 4.2 Vendor Onboarding

#### Required Validations
```elixir
defmodule AP.VendorOnboarding do
  def validation_requirements do
    %{
      tax_id: :tin_matching_required,
      business_verification: :secretary_of_state_check,
      bank_account: :prenote_validation,
      insurance: :certificate_required,
      w9_status: :current_required,
      ofac_screening: :pass_required
    }
  end
  
  def risk_assessment(vendor) do
    score = 0
    score = score + assess_financial_stability(vendor)
    score = score + assess_compliance_history(vendor)
    score = score + assess_geographic_risk(vendor)
    
    %{
      risk_score: score,
      risk_level: categorize_risk(score),
      monitoring_frequency: determine_monitoring_frequency(score)
    }
  end
end
```

### 4.3 Vendor Classification

#### Classification Rules
```elixir
defmodule AP.VendorClassification do
  def classify_vendor(vendor, annual_spend) do
    cond do
      annual_spend > 1_000_000 -> :strategic
      annual_spend > 100_000 -> :preferred
      vendor.critical_supplier? -> :critical
      vendor.one_time? -> :one_time
      true -> :standard
    end
  end
  
  def apply_classification_rules(vendor, classification) do
    case classification do
      :strategic -> 
        %{payment_terms: :net_15, payment_priority: :high}
      :critical -> 
        %{monitoring: :enhanced, review_frequency: :quarterly}
      :one_time -> 
        %{simplified_onboarding: true, payment_hold: 10}
      _ -> 
        %{payment_terms: :net_30, payment_priority: :normal}
    end
  end
end
```

### 4.4 Vendor Performance Management

#### Performance Metrics
```elixir
defmodule AP.VendorPerformance do
  def calculate_scorecard(vendor_id, period) do
    %{
      invoice_accuracy: calculate_invoice_accuracy_rate(vendor_id, period),
      on_time_delivery: calculate_otd_rate(vendor_id, period),
      quality_score: calculate_quality_metrics(vendor_id, period),
      compliance_score: calculate_compliance_score(vendor_id, period),
      overall_rating: weighted_average_score()
    }
  end
  
  def performance_thresholds do
    %{
      excellent: 90..100,
      good: 75..89,
      acceptable: 60..74,
      needs_improvement: 0..59
    }
  end
end
```

## 5. Event-Driven Architecture Patterns

### 5.1 Domain Events

#### Core AP Events
```elixir
defmodule AP.Events do
  # Invoice Events
  defmodule InvoiceReceived do
    defstruct [:invoice_id, :vendor_id, :amount, :due_date, :received_at]
  end
  
  defmodule InvoiceValidated do
    defstruct [:invoice_id, :validation_results, :validated_at]
  end
  
  defmodule InvoiceApproved do
    defstruct [:invoice_id, :approved_by, :approval_level, :approved_at]
  end
  
  defmodule ThreeWayMatchCompleted do
    defstruct [:match_id, :invoice_id, :po_id, :receipt_id, :variances]
  end
  
  # Payment Events  
  defmodule PaymentScheduled do
    defstruct [:payment_id, :invoice_ids, :amount, :payment_date]
  end
  
  defmodule PaymentExecuted do
    defstruct [:payment_id, :transaction_ref, :executed_at, :status]
  end
  
  # Vendor Events
  defmodule VendorOnboarded do
    defstruct [:vendor_id, :classification, :risk_level, :onboarded_at]
  end
  
  defmodule VendorStatusChanged do
    defstruct [:vendor_id, :from_status, :to_status, :reason, :changed_at]
  end
end
```

### 5.2 Process Managers

#### Payment Run Process Manager
```elixir
defmodule AP.ProcessManagers.PaymentRun do
  use Commanded.ProcessManagers.ProcessManager
  
  defstruct [:run_id, :scheduled_date, :invoices, :total_amount, :status]
  
  def handle(%{status: :initiated} = state, %PaymentRunScheduled{}) do
    [
      %SelectInvoicesForPayment{run_id: state.run_id},
      %ValidatePaymentBudget{amount: state.total_amount},
      %GeneratePaymentBatch{invoices: state.invoices}
    ]
  end
  
  def handle(state, %PaymentBatchGenerated{}) do
    [%RequestPaymentApproval{batch_id: event.batch_id}]
  end
  
  def handle(state, %PaymentApproved{}) do
    [%ExecutePaymentBatch{batch_id: event.batch_id}]
  end
end
```

#### Invoice Approval Workflow
```elixir
defmodule AP.ProcessManagers.InvoiceApprovalWorkflow do
  use Commanded.ProcessManagers.ProcessManager
  
  def handle(state, %InvoiceSubmittedForApproval{amount: amount}) do
    approvers = determine_required_approvers(amount)
    
    Enum.map(approvers, fn approver_id ->
      %RequestApproval{
        invoice_id: state.invoice_id,
        approver_id: approver_id,
        due_date: calculate_due_date()
      }
    end)
  end
  
  def handle(state, %ApprovalReceived{}) do
    if all_approvals_received?(state) do
      [%CompleteApprovalWorkflow{invoice_id: state.invoice_id}]
    else
      []  # Wait for more approvals
    end
  end
  
  def handle(state, %ApprovalTimeout{}) do
    [%EscalateApproval{invoice_id: state.invoice_id}]
  end
end
```

### 5.3 Read Model Projections

#### AP Aging Report Projection
```elixir
defmodule AP.Projections.AgingReport do
  use Commanded.Projections.Ecto
  
  project %InvoiceApproved{} = event, fn multi ->
    aging_entry = %AgingReportEntry{
      invoice_id: event.invoice_id,
      vendor_id: event.vendor_id,
      amount: event.amount,
      due_date: event.due_date,
      aging_bucket: calculate_aging_bucket(event.due_date)
    }
    
    Ecto.Multi.insert(multi, :aging_entry, aging_entry)
  end
  
  project %PaymentExecuted{} = event, fn multi ->
    Ecto.Multi.update_all(multi, :mark_paid,
      from(e in AgingReportEntry, where: e.invoice_id == ^event.invoice_id),
      set: [status: :paid, paid_date: event.executed_at])
  end
  
  defp calculate_aging_bucket(due_date) do
    days_overdue = Date.diff(Date.utc_today(), due_date)
    
    cond do
      days_overdue <= 0 -> :current
      days_overdue <= 30 -> :days_1_30
      days_overdue <= 60 -> :days_31_60
      days_overdue <= 90 -> :days_61_90
      true -> :over_90_days
    end
  end
end
```

#### Vendor Statement Projection
```elixir
defmodule AP.Projections.VendorStatement do
  use Commanded.Projections.Ecto
  
  project %InvoiceReceived{}, fn multi ->
    statement_entry = %VendorStatementEntry{
      vendor_id: event.vendor_id,
      transaction_type: :invoice,
      reference: event.invoice_number,
      debit: event.amount,
      balance: calculate_running_balance(event.vendor_id, event.amount)
    }
    
    Ecto.Multi.insert(multi, :statement_entry, statement_entry)
  end
  
  project %PaymentExecuted{}, fn multi ->
    statement_entry = %VendorStatementEntry{
      vendor_id: event.vendor_id,
      transaction_type: :payment,
      reference: event.transaction_ref,
      credit: event.amount,
      balance: calculate_running_balance(event.vendor_id, -event.amount)
    }
    
    Ecto.Multi.insert(multi, :statement_entry, statement_entry)
  end
end
```

## 6. Integration Points

### 6.1 Purchasing/Procurement Integration

#### Purchase Order Integration
```elixir
defmodule AP.Integration.Purchasing do
  # Events from Purchasing
  def handle_event(%PurchaseOrderCreated{} = event) do
    %CreatePOEncumbrance{
      po_id: event.po_id,
      amount: event.total_amount,
      gl_account: event.expense_account
    }
  end
  
  def handle_event(%GoodsReceived{} = event) do
    %UpdateThreeWayMatch{
      po_id: event.po_id,
      receipt_id: event.receipt_id,
      quantity_received: event.quantity
    }
  end
  
  # Events to Purchasing  
  def invoice_matched(invoice_id, po_id) do
    %NotifyPurchasing{
      event_type: :invoice_matched,
      invoice_id: invoice_id,
      po_id: po_id
    }
  end
end
```

### 6.2 General Ledger Integration

#### GL Posting Rules
```elixir
defmodule AP.Integration.GeneralLedger do
  def create_journal_entry(invoice) do
    %GLJournalEntry{
      entry_date: Date.utc_today(),
      description: "AP Invoice #{invoice.invoice_number}",
      lines: [
        %JournalLine{
          account: invoice.expense_account,
          debit: invoice.net_amount,
          cost_center: invoice.cost_center
        },
        %JournalLine{
          account: invoice.tax_account,
          debit: invoice.tax_amount
        },
        %JournalLine{
          account: "2000",  # Accounts Payable
          credit: invoice.total_amount
        }
      ]
    }
  end
  
  def payment_journal_entry(payment) do
    %GLJournalEntry{
      entry_date: payment.payment_date,
      description: "AP Payment #{payment.reference}",
      lines: [
        %JournalLine{
          account: "2000",  # Accounts Payable
          debit: payment.amount
        },
        %JournalLine{
          account: payment.bank_account,
          credit: payment.amount
        }
      ]
    }
  end
end
```

### 6.3 Cash Management Integration

#### Cash Position Updates
```elixir
defmodule AP.Integration.CashManagement do
  def update_cash_forecast(payment_scheduled) do
    %UpdateCashForecast{
      date: payment_scheduled.payment_date,
      amount: -payment_scheduled.amount,
      currency: payment_scheduled.currency,
      probability: calculate_payment_probability()
    }
  end
  
  def request_cash_availability(amount, date) do
    %CheckCashAvailability{
      requested_amount: amount,
      requested_date: date,
      priority: :normal
    }
  end
end
```

### 6.4 Tax Engine Integration

#### Tax Calculation Integration
```elixir
defmodule AP.Integration.TaxEngine do
  def calculate_tax(invoice) do
    %CalculateTax{
      vendor_id: invoice.vendor_id,
      amount: invoice.net_amount,
      tax_date: invoice.invoice_date,
      ship_to: invoice.delivery_location,
      tax_codes: invoice.line_items |> Enum.map(&(&1.tax_code))
    }
  end
  
  def validate_tax_compliance(vendor) do
    %ValidateTaxCompliance{
      tax_id: vendor.tax_id,
      jurisdiction: vendor.tax_jurisdiction,
      exemption_certificates: vendor.tax_exemptions
    }
  end
end
```

### 6.5 Document Management Integration

#### Document Storage and Retrieval
```elixir
defmodule AP.Integration.DocumentManagement do
  def store_invoice_image(invoice_id, document) do
    %StoreDocument{
      document_type: :invoice,
      reference_id: invoice_id,
      content: document.content,
      metadata: %{
        vendor_id: document.vendor_id,
        invoice_number: document.invoice_number,
        retention_period: {7, :years}
      }
    }
  end
  
  def retrieve_supporting_documents(invoice_id) do
    %RetrieveDocuments{
      reference_type: :invoice,
      reference_id: invoice_id,
      include_types: [:invoice_image, :purchase_order, :receipt]
    }
  end
end
```

## 7. Business Rules and Validations

### 7.1 Invoice Validations

#### Core Validation Rules
```elixir
defmodule AP.BusinessRules.InvoiceValidation do
  def validation_rules do
    [
      # Vendor validations
      {:vendor_active, "Vendor must be active"},
      {:vendor_not_blocked, "Vendor is blocked from transactions"},
      
      # Amount validations  
      {:amount_positive, "Invoice amount must be positive"},
      {:amount_within_po_tolerance, "Amount exceeds PO tolerance"},
      
      # Date validations
      {:invoice_date_valid, "Invoice date invalid"},
      {:due_date_reasonable, "Due date unreasonable"},
      
      # Duplicate checking
      {:no_duplicate_invoice, "Duplicate invoice detected"},
      
      # Tax validations
      {:tax_calculation_valid, "Tax calculation incorrect"},
      {:tax_rate_current, "Tax rate outdated"}
    ]
  end
end
```

### 7.2 Payment Validations

#### Payment Processing Rules
```elixir
defmodule AP.BusinessRules.PaymentValidation do
  def validation_rules do
    [
      # Bank account validations
      {:bank_account_valid, "Invalid bank account"},
      {:bank_account_verified, "Bank account not verified"},
      
      # Compliance validations
      {:ofac_check_passed, "OFAC screening failed"},
      {:payment_limit_check, "Payment exceeds limit"},
      
      # Duplicate prevention
      {:no_duplicate_payment, "Duplicate payment detected"},
      
      # Budget validations
      {:budget_available, "Insufficient budget"},
      {:cash_available, "Insufficient cash"}
    ]
  end
end
```

### 7.3 Vendor Validations

#### Vendor Management Rules
```elixir
defmodule AP.BusinessRules.VendorValidation do
  def onboarding_validations do
    [
      {:tax_id_valid, "Invalid tax ID"},
      {:tin_match_successful, "TIN matching failed"},
      {:w9_current, "W9 expired or missing"},
      {:insurance_current, "Insurance certificate expired"},
      {:business_verified, "Business verification failed"}
    ]
  end
  
  def transaction_validations do
    [
      {:vendor_active, "Vendor not active"},
      {:credit_limit_available, "Credit limit exceeded"},
      {:payment_terms_valid, "Invalid payment terms"},
      {:currency_approved, "Currency not approved for vendor"}
    ]
  end
end
```

## 8. Compliance and Controls

### 8.1 Segregation of Duties

```elixir
defmodule AP.Compliance.SegregationOfDuties do
  def role_restrictions do
    %{
      invoice_entry: [:cannot_approve_own, :cannot_process_payment],
      invoice_approval: [:cannot_enter, :cannot_execute_payment],
      payment_execution: [:cannot_approve, :cannot_reconcile],
      bank_reconciliation: [:cannot_execute_payment, :cannot_approve],
      vendor_maintenance: [:cannot_approve_invoices, :cannot_execute_payments]
    }
  end
end
```

### 8.2 Audit Trail Requirements

```elixir
defmodule AP.Compliance.AuditTrail do
  def required_audit_events do
    [
      # Invoice events
      :invoice_created, :invoice_modified, :invoice_approved, :invoice_rejected,
      
      # Payment events
      :payment_initiated, :payment_approved, :payment_executed, :payment_failed,
      
      # Vendor events
      :vendor_created, :vendor_modified, :vendor_activated, :vendor_blocked,
      
      # Override events
      :approval_overridden, :validation_overridden, :limit_exceeded
    ]
  end
  
  def audit_retention_period do
    {7, :years}  # 7 year retention for financial records
  end
end
```

### 8.3 Regulatory Compliance

```elixir
defmodule AP.Compliance.Regulatory do
  def compliance_checks do
    %{
      ofac_screening: :required_before_payment,
      tin_matching: :required_for_new_vendors,
      form_1099: :required_for_qualifying_vendors,
      escheatment: :monitor_unclaimed_payments,
      sox_controls: :enforce_approval_limits
    }
  end
  
  def reporting_requirements do
    %{
      form_1099: :annual,
      unclaimed_property: :annual,
      vat_reporting: :quarterly,
      audit_reports: :on_demand
    }
  end
end
```

## 9. Error Handling and Recovery

### 9.1 Compensation Patterns

```elixir
defmodule AP.ErrorHandling.Compensation do
  def payment_failure_compensation(payment_id) do
    [
      %ReverseGLEntry{payment_id: payment_id},
      %ResetInvoiceStatus{payment_id: payment_id, status: :approved},
      %NotifyVendor{payment_id: payment_id, reason: :payment_failed},
      %ScheduleRetry{payment_id: payment_id, retry_after: {24, :hours}}
    ]
  end
  
  def invoice_rejection_compensation(invoice_id) do
    [
      %NotifyOriginator{invoice_id: invoice_id},
      %ReverseEncumbrance{invoice_id: invoice_id},
      %UpdateVendorMetrics{invoice_id: invoice_id, metric: :rejection_count}
    ]
  end
end
```

### 9.2 Retry Policies

```elixir
defmodule AP.ErrorHandling.RetryPolicy do
  def retry_configuration do
    %{
      bank_api_timeout: {max_retries: 5, backoff: :exponential},
      validation_failure: {max_retries: 3, backoff: :linear},
      approval_timeout: {max_retries: 2, escalate: true},
      payment_failure: {max_retries: 3, manual_intervention: true}
    }
  end
end
```

## 10. Performance and Scalability Requirements

### 10.1 Processing Volume Targets

- Support 100,000+ invoices per month
- Process 50,000+ payments per month
- Handle 10,000+ active vendors
- Support 1,000+ concurrent users

### 10.2 Response Time Requirements

- Invoice validation: < 2 seconds
- Payment processing: < 5 seconds
- Three-way matching: < 3 seconds
- Report generation: < 10 seconds for standard reports

### 10.3 Event Processing Requirements

- Event persistence: < 100ms
- Event projection update: < 500ms
- Process manager reaction: < 1 second
- Read model query: < 200ms

## Conclusion

This comprehensive business logic specification provides the foundation for implementing a robust, scalable Accounts Payables system within the Accountex ERP platform. The event-driven architecture using Elixir/Ash/Commanded ensures strong consistency for financial transactions while providing the flexibility and performance required for modern AP processing. The defined business rules, validations, and integration points ensure compliance with financial regulations while supporting efficient operations.
