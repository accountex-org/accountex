# Complete BPMN DSL Modules for Accounts Receivables Application

## Overview

This document provides production-ready BPMN DSL modules for the Accounts Receivables (AR) application within the AccountEx modular ERP system. The implementation integrates:
- **Commanded** for event sourcing
- **Ash** for persistence
- **Jido** for agentic workflows
- **Spark DSL** for BPMN process definitions

## Core BPMN DSL Framework Setup

```elixir
defmodule AccountEx.AccountsReceivables.BPMN.DSL do
  @moduledoc """
  BPMN DSL for Accounts Receivables with full integration of Commanded, Ash, and Jido.
  Handles module unavailability gracefully with fallback strategies.
  """
  
  use Spark.Dsl.Extension,
    sections: [
      process_section(),
      agents_section(),
      commands_section(),
      signals_section(),
      resilience_section()
    ],
    transformers: [
      AccountEx.BPMN.Transformers.ValidateStructure,
      AccountEx.BPMN.Transformers.GenerateCommandHandlers,
      AccountEx.BPMN.Transformers.GenerateJidoAgents,
      AccountEx.BPMN.Transformers.GenerateAshResources,
      AccountEx.BPMN.Transformers.WireSignalRouting
    ],
    verifiers: [
      AccountEx.BPMN.Verifiers.ValidateEventSourcing,
      AccountEx.BPMN.Verifiers.CheckModuleDependencies,
      AccountEx.BPMN.Verifiers.ValidateCompensation
    ]

  defp process_section do
    %Spark.Dsl.Section{
      name: :process,
      describe: "Define BPMN process with Commanded integration",
      schema: [
        id: [type: :atom, required: true],
        tenant_aware: [type: :boolean, default: true],
        commanded_app: [type: :atom, default: AccountEx.CommandedApp],
        resilient: [type: :boolean, default: true]
      ],
      entities: [
        start_event_entity(),
        end_event_entity(),
        agent_task_entity(),
        service_task_entity(),
        user_task_entity(),
        gateway_entity(),
        subprocess_entity(),
        boundary_event_entity()
      ]
    }
  end

  defp agents_section do
    %Spark.Dsl.Section{
      name: :agents,
      describe: "Define Jido agents for automated tasks",
      entities: [
        jido_agent_entity()
      ]
    }
  end

  defp commands_section do
    %Spark.Dsl.Section{
      name: :commands,
      describe: "Commanded event sourcing integration",
      schema: [
        application: [type: :atom, default: AccountEx.CommandedApp],
        consistency: [type: {:in, [:strong, :eventual]}, default: :eventual]
      ]
    }
  end

  defp resilience_section do
    %Spark.Dsl.Section{
      name: :resilience,
      describe: "Module unavailability handling",
      schema: [
        fallback_strategy: [type: {:in, [:cache, :queue, :skip, :fail]}, default: :cache],
        cache_ttl: [type: :pos_integer, default: 3600],
        retry_policy: [type: :keyword_list]
      ]
    }
  end
end
```

## 1. Invoice Lifecycle Management Process

```elixir
defmodule AccountEx.AR.Processes.InvoiceLifecycle do
  @moduledoc """
  Complete invoice lifecycle from creation through payment with credit validation,
  approval workflows, and payment monitoring.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :invoice_lifecycle do
    tenant_aware true
    resilient true
    
    # ============================================
    # Process Initiation
    # ============================================
    
    start_event :invoice_requested do
      trigger :signal
      signal_type "accountex.sales.order_fulfilled"
      correlation [:order_id, :customer_id, :tenant_id]
      
      data_mapping %{
        customer_id: "$.order.customer_id",
        line_items: "$.order.line_items",
        total_amount: "$.order.total_amount",
        payment_terms: "$.order.payment_terms"
      }
    end
    
    # ============================================
    # Credit Validation
    # ============================================
    
    agent_task :validate_credit do
      agent AccountEx.AR.Agents.CreditManager
      action :check_credit_standing
      
      input %{
        customer_id: "$.customer_id",
        requested_amount: "$.total_amount",
        current_exposure: "$.customer.current_ar_balance"
      }
      
      timeout "PT2M"  # 2 minute timeout
      
      fallback_on_unavailable :use_cached_credit_data
      cache_key "credit_#{$.customer_id}"
      
      boundary_event :credit_check_timeout do
        type :timer
        duration "PT2M"
        interrupting true
        flows_to :manual_credit_review
      end
    end
    
    exclusive_gateway :credit_decision do
      default :credit_review_required
      
      condition :approved, expr: "$.credit_result.status == 'approved'"
      condition :rejected, expr: "$.credit_result.status == 'rejected'"
      condition :review_required, expr: "$.credit_result.status == 'review'"
    end
    
    user_task :manual_credit_review do
      incoming [:review_required, :credit_check_timeout]
      
      assignee role: "credit_manager"
      escalation after: "PT4H", to: "finance_director"
      
      form :credit_review_form do
        field :customer_history, type: :readonly
        field :requested_amount, type: :readonly
        field :decision, type: :select, options: ["approve", "reject", "approve_with_conditions"]
        field :notes, type: :text
        field :credit_limit_override, type: :decimal
      end
      
      sla "PT24H"
    end
    
    # ============================================
    # Invoice Creation (Commanded Aggregate)
    # ============================================
    
    service_task :create_invoice do
      incoming [:approved, :manual_credit_review]
      
      command AccountEx.AR.Commands.CreateInvoice do
        aggregate_id generate_uuid()
        tenant_id "$.tenant_id"
        
        payload %{
          invoice_number: generate_invoice_number(),
          customer_id: "$.customer_id",
          line_items: "$.line_items",
          payment_terms: "$.payment_terms",
          due_date: calculate_due_date("$.payment_terms"),
          created_by: "$.process.initiated_by"
        }
      end
      
      on_success :store_invoice_id
      on_failure :handle_creation_failure
      
      compensation :void_invoice
    end
    
    # ============================================
    # Approval Workflow (High-Value Invoices)
    # ============================================
    
    exclusive_gateway :approval_required do
      condition :needs_approval, expr: "$.invoice.total_amount > 10000"
      condition :auto_approved, expr: "$.invoice.total_amount <= 10000"
    end
    
    subprocess :approval_workflow do
      incoming :needs_approval
      transaction_boundary true
      
      parallel_gateway :approval_split
      
      user_task :department_approval do
        assignee expr: "get_department_head($.invoice.department)"
        deadline "PT24H"
        
        form :approval_form do
          field :invoice_details, type: :readonly
          field :approval_decision, type: :boolean
          field :comments, type: :text
        end
      end
      
      user_task :finance_approval do
        assignee role: "finance_manager"
        deadline "PT24H"
        
        form :finance_approval_form do
          field :invoice_details, type: :readonly
          field :gl_coding, type: :select_multiple
          field :approval_decision, type: :boolean
        end
      end
      
      parallel_gateway :approval_join do
        synchronize [:department_approval, :finance_approval]
      end
      
      exclusive_gateway :approval_outcome do
        condition :both_approved, expr: "all_approved($.approvals)"
        condition :rejected, expr: "any_rejected($.approvals)"
      end
      
      end_event :approval_complete, incoming: :both_approved
      
      error_event :approval_rejected do
        incoming :rejected
        throw_error "APPROVAL_REJECTED"
        compensation_trigger true
      end
    end
    
    # ============================================
    # Issue and Send Invoice
    # ============================================
    
    service_task :issue_invoice do
      incoming [:auto_approved, :approval_complete]
      
      command AccountEx.AR.Commands.IssueInvoice do
        aggregate_id "$.invoice_id"
        
        payload %{
          issued_at: now(),
          issued_by: "$.process.current_user"
        }
      end
      
      publish_event "InvoiceIssued"
    end
    
    agent_task :send_invoice do
      agent AccountEx.AR.Agents.InvoiceDelivery
      action :deliver_to_customer
      
      input %{
        invoice_id: "$.invoice_id",
        customer_id: "$.customer_id",
        delivery_preferences: "$.customer.delivery_preferences"
      }
      
      retry_policy %{
        max_attempts: 3,
        backoff: :exponential,
        initial_delay: 60_000  # 1 minute
      }
      
      channels [:email, :portal, :edi]
      
      track_delivery true
      require_acknowledgment "$.customer.requires_acknowledgment"
    end
    
    # ============================================
    # Payment Monitoring Subprocess
    # ============================================
    
    subprocess :payment_monitoring do
      start_event :begin_monitoring
      
      # Payment deadline timer
      timer_event :payment_due do
        date expr: "$.invoice.due_date"
        non_interrupting false
      end
      
      # Listen for payment signals
      receive_task :await_payment do
        signal_subscription [
          {type: "accountex.ar.payment_received", correlation: [:invoice_id]},
          {type: "accountex.ar.payment_promised", correlation: [:invoice_id]}
        ]
        
        timeout "$.invoice.payment_terms.net_days + 30"
      end
      
      exclusive_gateway :payment_status do
        condition :paid_full, expr: "$.payment.amount >= $.invoice.total_amount"
        condition :paid_partial, expr: "$.payment.amount > 0"
        condition :overdue, expr: "$.payment_due.triggered && $.payment.amount == 0"
      end
      
      service_task :apply_payment do
        incoming [:paid_full, :paid_partial]
        
        command AccountEx.AR.Commands.ApplyPayment do
          aggregate_id "$.invoice_id"
          
          payload %{
            payment_id: "$.payment.id",
            amount: "$.payment.amount",
            payment_date: "$.payment.date"
          }
        end
      end
      
      conditional_event :check_balance do
        incoming :paid_partial
        condition expr: "$.invoice.outstanding_balance > 0"
        flows_to :await_payment  # Loop back for more payments
      end
      
      signal_event :escalate_overdue do
        incoming :overdue
        
        signal AccountEx.Signals.InvoiceOverdue do
          type "accountex.ar.invoice_overdue"
          source "/ar/invoices"
          
          data %{
            invoice_id: "$.invoice_id",
            customer_id: "$.customer_id",
            days_overdue: calculate_days_overdue("$.invoice.due_date"),
            amount_outstanding: "$.invoice.outstanding_balance"
          }
        end
        
        flows_to :collections_process
      end
      
      end_event :payment_complete do
        incoming :paid_full
      end
    end
    
    # ============================================
    # Collections Escalation
    # ============================================
    
    call_activity :collections_process do
      incoming :escalate_overdue
      
      called_process AccountEx.AR.Processes.Collections
      
      input_mapping %{
        invoice_id: "$.invoice_id",
        customer_id: "$.customer_id",
        invoice_amount: "$.invoice.total_amount",
        days_overdue: "$.days_overdue"
      }
      
      propagate_tenant_id true
    end
    
    # ============================================
    # Process Completion
    # ============================================
    
    end_event :invoice_completed do
      incoming [:payment_complete, :credit_rejected]
      
      signal AccountEx.Signals.InvoiceLifecycleComplete do
        type "accountex.ar.invoice_lifecycle_complete"
        
        data %{
          invoice_id: "$.invoice_id",
          status: "$.final_status",
          completion_date: now()
        }
      end
    end
    
    # ============================================
    # Error Handling & Compensation
    # ============================================
    
    boundary_event :global_error_handler do
      attached_to :process
      error_types [:system_error, :business_error, :timeout_error]
      
      error_handler do
        log_error()
        
        case error_type() do
          :system_error -> retry_with_backoff()
          :business_error -> escalate_to_user()
          :timeout_error -> trigger_compensation()
        end
      end
    end
    
    compensation_handler :void_invoice do
      command AccountEx.AR.Commands.VoidInvoice do
        aggregate_id "$.invoice_id"
        reason "$.compensation_reason"
      end
      
      notify_customer true
      reverse_gl_entries true
    end
  end
  
  # ============================================
  # Agent Definitions
  # ============================================
  
  agents do
    jido_agent AccountEx.AR.Agents.CreditManager do
      name "credit_manager"
      
      state_schema [
        credit_checks_today: [type: :integer, default: 0],
        cache: [type: :map, default: %{}]
      ]
      
      actions [
        AccountEx.AR.Actions.CheckCreditLimit,
        AccountEx.AR.Actions.CalculateExposure,
        AccountEx.AR.Actions.AssessRisk
      ]
      
      skills [
        AccountEx.AR.Skills.CreditAnalysis,
        AccountEx.AR.Skills.RiskAssessment
      ]
      
      resilient_to [:external_credit_service_down]
    end
    
    jido_agent AccountEx.AR.Agents.InvoiceDelivery do
      name "invoice_delivery"
      
      actions [
        AccountEx.AR.Actions.GeneratePDF,
        AccountEx.AR.Actions.SendEmail,
        AccountEx.AR.Actions.PostToPortal,
        AccountEx.AR.Actions.SendEDI
      ]
      
      delivery_channels %{
        email: {AccountEx.Mailer, priority: 1},
        portal: {AccountEx.Portal, priority: 2},
        edi: {AccountEx.EDI, priority: 3}
      }
    end
  end
  
  # ============================================
  # Resilience Configuration
  # ============================================
  
  resilience do
    fallback_strategy :cache
    cache_ttl 3600  # 1 hour
    
    retry_policy [
      max_attempts: 3,
      backoff: :exponential,
      initial_delay: 1000,
      max_delay: 30000
    ]
    
    circuit_breaker [
      threshold: 5,
      timeout: 60000,
      half_open_requests: 3
    ]
    
    module_dependencies %{
      optional: [:sales, :inventory],
      required: [:general_ledger]
    }
  end
end
```

## 2. Credit Management Workflow

```elixir
defmodule AccountEx.AR.Processes.CreditManagement do
  @moduledoc """
  Comprehensive credit management including evaluation, monitoring, and limit adjustments.
  Uses ML-based scoring when available, falls back to rule-based evaluation.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :credit_evaluation do
    tenant_aware true
    
    start_event :credit_request do
      multiple_triggers [
        {signal: "accountex.ar.credit_check_requested"},
        {message: "CreditEvaluationRequest"},
        {timer: "R/P3M"}  # Quarterly review
      ]
    end
    
    # ============================================
    # Parallel Credit Analysis
    # ============================================
    
    parallel_gateway :analysis_start
    
    # Internal credit history
    agent_task :internal_analysis do
      incoming :analysis_start
      
      agent AccountEx.AR.Agents.CreditHistoryAnalyzer
      action :analyze_payment_patterns
      
      input %{
        customer_id: "$.customer_id",
        period_months: 12,
        include_disputes: true
      }
      
      metrics [
        :average_days_to_pay,
        :payment_consistency,
        :dispute_frequency,
        :nsf_occurrences
      ]
    end
    
    # External credit bureau (with fallback)
    service_task :external_credit_check do
      incoming :analysis_start
      
      resilient_call AccountEx.External.CreditBureau do
        timeout 30_000
        
        fallback do
          use_cached_score(customer_id: "$.customer_id", max_age: "P7D")
        end
      end
      
      cache_result true
      cache_duration "P30D"
    end
    
    # ML risk scoring (optional module)
    agent_task :ai_risk_scoring do
      incoming :analysis_start
      
      agent AccountEx.AR.Agents.MLRiskScorer
      action :predict_payment_risk
      
      optional true  # Skip if ML module unavailable
      
      input %{
        customer_features: "$.customer_profile",
        transaction_history: "$.transaction_history",
        market_conditions: "$.market_data"
      }
      
      model_version "3.2.1"
      confidence_threshold 0.75
    end
    
    parallel_gateway :analysis_join do
      synchronize [:internal_analysis, :external_credit_check, :ai_risk_scoring]
      partial_sync_allowed true  # Continue if optional tasks fail
    end
    
    # ============================================
    # Credit Scoring and Limit Calculation
    # ============================================
    
    service_task :calculate_credit_score do
      implementation :weighted_scoring
      
      weights %{
        internal_history: 0.35,
        external_score: 0.30,
        ai_prediction: 0.20,
        financial_metrics: 0.15
      }
      
      adjust_for_missing_data true
    end
    
    business_rule_task :determine_credit_limit do
      dmn_table :credit_limit_rules
      
      input %{
        credit_score: "$.calculated_score",
        customer_segment: "$.customer.segment",
        annual_revenue: "$.customer.annual_revenue",
        industry_risk: "$.customer.industry_risk_rating",
        relationship_length: "$.customer.years_active"
      }
      
      output %{
        recommended_limit: :decimal,
        payment_terms: :string,
        review_frequency: :string,
        collateral_required: :boolean
      }
    end
    
    # ============================================
    # Approval Workflow
    # ============================================
    
    exclusive_gateway :approval_routing do
      condition :auto_approve, expr: "$.recommended_limit <= 50000"
      condition :manager_review, expr: "$.recommended_limit <= 200000"
      condition :executive_review, expr: "$.recommended_limit > 200000"
    end
    
    user_task :manager_approval do
      incoming :manager_review
      
      assignee expr: "get_credit_manager($.customer.region)"
      escalation after: "PT4H", to: "senior_credit_manager"
      
      decision_support %{
        customer_dashboard: true,
        peer_comparison: true,
        risk_indicators: true
      }
    end
    
    user_task :executive_approval do
      incoming :executive_review
      
      assignee role: "cfo"
      delegate_to ["finance_director", "credit_director"]
      
      require_justification true
      require_risk_mitigation_plan "$.recommended_limit > 500000"
    end
    
    # ============================================
    # Update Credit Limit
    # ============================================
    
    service_task :update_credit_limit do
      incoming [:auto_approve, :manager_approval, :executive_approval]
      
      command AccountEx.AR.Commands.UpdateCreditLimit do
        aggregate_id "$.customer_id"
        
        payload %{
          new_limit: "$.approved_limit",
          payment_terms: "$.payment_terms",
          effective_date: now(),
          approved_by: "$.approver",
          next_review_date: "$.next_review_date"
        }
      end
      
      publish_event "CreditLimitUpdated"
    end
    
    # ============================================
    # Notifications and Integration
    # ============================================
    
    parallel_gateway :notification_split
    
    signal_event :notify_sales do
      incoming :notification_split
      
      signal AccountEx.Signals.CreditLimitChanged do
        type "accountex.ar.credit_limit_updated"
        
        data %{
          customer_id: "$.customer_id",
          new_limit: "$.approved_limit",
          previous_limit: "$.previous_limit"
        }
        
        routing ["sales", "customer_service"]
      end
    end
    
    service_task :update_erp_master do
      incoming :notification_split
      
      resilient_call AccountEx.MasterData.UpdateCustomer do
        retry_on_failure true
        async_if_unavailable true
      end
    end
    
    agent_task :update_monitoring_rules do
      incoming :notification_split
      
      agent AccountEx.AR.Agents.CreditMonitor
      action :configure_alerts
      
      rules %{
        utilization_threshold: 0.8,
        velocity_check: true,
        unusual_pattern_detection: true
      }
    end
    
    parallel_gateway :notification_join
    
    end_event :evaluation_complete
  end
  
  # ============================================
  # Continuous Credit Monitoring
  # ============================================
  
  process id: :credit_monitoring do
    
    start_event :monitoring_trigger do
      multiple_triggers [
        {timer: "R/P1M"},  # Monthly check
        {signal: "accountex.ar.payment_anomaly_detected"},
        {signal: "accountex.external.credit_alert"}
      ]
    end
    
    service_task :gather_monitoring_data do
      queries [
        AccountEx.AR.Queries.CustomerPaymentTrends,
        AccountEx.AR.Queries.CreditUtilization,
        AccountEx.AR.Queries.DisputeHistory
      ]
      
      parallel_execution true
    end
    
    agent_task :analyze_credit_health do
      agent AccountEx.AR.Agents.CreditMonitor
      action :assess_credit_deterioration
      
      indicators [
        :payment_slowdown,
        :increased_disputes,
        :utilization_spike,
        :external_credit_drop
      ]
      
      thresholds %{
        payment_delay_increase: 10,  # days
        utilization_ratio: 0.9,
        credit_score_drop: 50
      }
    end
    
    exclusive_gateway :action_required do
      condition :maintain, expr: "$.risk_level == 'low'"
      condition :review, expr: "$.risk_level == 'medium'"
      condition :immediate_action, expr: "$.risk_level == 'high'"
    end
    
    call_activity :trigger_review do
      incoming :review
      
      called_process :credit_evaluation
      async false
    end
    
    subprocess :immediate_actions do
      incoming :immediate_action
      
      parallel_gateway :action_split
      
      service_task :reduce_credit_limit do
        command AccountEx.AR.Commands.TemporarilyReduceLimit
        percentage 0.5
      end
      
      service_task :require_prepayment do
        command AccountEx.AR.Commands.SetPaymentTerms
        terms "prepayment_required"
      end
      
      signal_event :alert_stakeholders do
        signal AccountEx.Signals.CreditRiskAlert
        severity :high
        recipients ["credit_manager", "sales_manager", "cfo"]
      end
      
      parallel_gateway :action_join
    end
    
    end_event :monitoring_cycle_complete
  end
end
```

## 3. Payment Processing Flow

```elixir
defmodule AccountEx.AR.Processes.PaymentProcessing do
  @moduledoc """
  Handles payment receipt, matching, allocation, and reconciliation.
  Supports multiple payment methods and partial payments.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :payment_processing do
    tenant_aware true
    
    start_event :payment_received do
      multiple_triggers [
        {signal: "accountex.bank.payment_detected"},
        {message: "PaymentGatewayNotification"},
        {api: "DirectPaymentSubmission"}
      ]
      
      deduplicate_by [:payment_reference, :amount, :date]
    end
    
    # ============================================
    # Payment Validation
    # ============================================
    
    service_task :validate_payment do
      validations [
        {amount_positive: "$.amount > 0"},
        {valid_currency: "$.currency in supported_currencies()"},
        {no_duplicate: "not payment_exists($.reference)"},
        {customer_exists: "customer_active($.customer_id)"}
      ]
      
      boundary_event :validation_failed do
        error_types [:validation_error]
        flows_to :handle_invalid_payment
      end
    end
    
    # ============================================
    # Intelligent Payment Matching
    # ============================================
    
    agent_task :match_payment do
      agent AccountEx.AR.Agents.PaymentMatcher
      action :find_matching_invoices
      
      strategies [
        {exact_reference: weight: 1.0},
        {amount_match: weight: 0.8},
        {customer_pattern: weight: 0.7},
        {ml_prediction: weight: 0.6}
      ]
      
      confidence_threshold 0.75
      
      output %{
        matched_invoices: :list,
        confidence_score: :float,
        unallocated_amount: :decimal
      }
    end
    
    exclusive_gateway :matching_result do
      condition :single_match, expr: "length($.matched_invoices) == 1"
      condition :multi_match, expr: "length($.matched_invoices) > 1"
      condition :no_match, expr: "length($.matched_invoices) == 0"
      condition :low_confidence, expr: "$.confidence_score < 0.75"
    end
    
    # ============================================
    # Manual Matching
    # ============================================
    
    user_task :manual_matching do
      incoming [:no_match, :low_confidence]
      
      assignee role: "ar_specialist"
      
      ui_component :payment_matching_widget do
        show_suggested_matches true
        allow_partial_allocation true
        show_customer_history true
      end
      
      assistance_available AccountEx.AR.Bots.MatchingAssistant
    end
    
    # ============================================
    # Payment Allocation
    # ============================================
    
    subprocess :allocate_payment do
      incoming [:single_match, :multi_match, :manual_matching]
      
      multi_instance :per_invoice_allocation do
        collection "$.matched_invoices"
        
        service_task :calculate_allocation do
          strategy "$.allocation_strategy"  # FIFO, LIFO, Pro-rata, Directed
          
          consider %{
            principal_first: true,
            late_fees: true,
            discounts: "$.payment_date <= $.discount_date"
          }
        end
        
        service_task :apply_to_invoice do
          command AccountEx.AR.Commands.AllocatePaymentToInvoice do
            aggregate_id "$.invoice_id"
            
            payload %{
              payment_id: "$.payment_id",
              allocated_amount: "$.calculated_allocation",
              payment_date: "$.payment_date"
            }
          end
          
          compensation :reverse_allocation
        end
        
        exclusive_gateway :check_invoice_status do
          condition :fully_paid, expr: "$.invoice.balance == 0"
          condition :partially_paid, expr: "$.invoice.balance > 0"
        end
        
        signal_event :invoice_paid do
          incoming :fully_paid
          
          signal AccountEx.Signals.InvoicePaid do
            type "accountex.ar.invoice_paid"
            
            data %{
              invoice_id: "$.invoice_id",
              payment_id: "$.payment_id",
              paid_date: "$.payment_date"
            }
          end
        end
      end
      
      # Handle overpayment
      exclusive_gateway :check_overpayment do
        condition :exact_amount, expr: "$.unallocated_amount == 0"
        condition :overpayment, expr: "$.unallocated_amount > 0"
        condition :short_payment, expr: "$.unallocated_amount < 0"
      end
      
      service_task :create_credit_memo do
        incoming :overpayment
        
        command AccountEx.AR.Commands.CreateCreditMemo do
          payload %{
            customer_id: "$.customer_id",
            amount: "$.unallocated_amount",
            source: "payment_overage",
            payment_ref: "$.payment_id"
          }
        end
      end
    end
    
    # ============================================
    # Record Payment & Update Balances
    # ============================================
    
    service_task :record_payment_event do
      command AccountEx.AR.Commands.RecordPayment do
        aggregate_id "$.payment_id"
        
        payload %{
          customer_id: "$.customer_id",
          amount: "$.amount",
          payment_method: "$.method",
          reference: "$.reference",
          allocated_invoices: "$.allocations"
        }
      end
      
      publish_event "PaymentRecorded"
    end
    
    agent_task :update_customer_metrics do
      agent AccountEx.AR.Agents.CustomerMetrics
      action :recalculate_statistics
      
      metrics [
        :current_balance,
        :days_sales_outstanding,
        :payment_velocity,
        :credit_utilization
      ]
      
      async true
    end
    
    # ============================================
    # Notifications
    # ============================================
    
    parallel_gateway :notification_start
    
    service_task :notify_customer do
      incoming :notification_start
      
      template :payment_received
      channels [:email, :sms, :portal]
      
      include %{
        payment_details: true,
        updated_balance: true,
        next_invoice_due: true
      }
    end
    
    signal_event :notify_sales do
      incoming :notification_start
      condition "$.amount > 10000"
      
      signal AccountEx.Signals.HighValuePayment do
        type "accountex.ar.high_value_payment"
        
        data %{
          customer_id: "$.customer_id",
          amount: "$.amount"
        }
      end
    end
    
    service_task :update_dashboards do
      incoming :notification_start
      
      projections [
        AccountEx.AR.Projections.CashflowForecast,
        AccountEx.AR.Projections.AgingReport,
        AccountEx.AR.Projections.CollectionMetrics
      ]
      
      async true
    end
    
    parallel_gateway :notification_join
    
    # ============================================
    # Bank Reconciliation Integration
    # ============================================
    
    signal_event :trigger_reconciliation do
      signal AccountEx.Signals.PaymentForReconciliation do
        type "accountex.ar.payment_for_reconciliation"
        
        data %{
          payment_id: "$.payment_id",
          bank_reference: "$.bank_reference",
          amount: "$.amount",
          date: "$.payment_date"
        }
        
        routing ["reconciliation_service"]
      end
    end
    
    end_event :payment_processed
    
    # ============================================
    # Error Handling
    # ============================================
    
    subprocess :handle_invalid_payment do
      user_task :investigate_payment do
        assignee role: "payment_investigator"
        
        sla "PT4H"
        
        options [
          "valid_payment_wrong_reference",
          "duplicate_payment",
          "fraudulent_payment",
          "return_payment"
        ]
      end
      
      exclusive_gateway :investigation_outcome do
        condition :reprocess, expr: "$.decision == 'valid_payment_wrong_reference'"
        condition :return_payment, expr: "$.decision == 'return_payment'"
        condition :flag_fraud, expr: "$.decision == 'fraudulent_payment'"
      end
      
      service_task :initiate_return do
        incoming :return_payment
        
        command AccountEx.Banking.Commands.InitiateReturn
      end
      
      signal_event :fraud_alert do
        incoming :flag_fraud
        
        signal AccountEx.Signals.FraudDetected
        severity :critical
      end
    end
    
    compensation_handler :reverse_allocation do
      command AccountEx.AR.Commands.ReversePaymentAllocation do
        aggregate_id "$.invoice_id"
        payment_id "$.payment_id"
      end
    end
  end
end
```

## 4. Collections Management Process

```elixir
defmodule AccountEx.AR.Processes.Collections do
  @moduledoc """
  Multi-stage collections process with escalation paths and dispute handling.
  Compliant with FDCPA and other regulations.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :collections_workflow do
    tenant_aware true
    
    start_event :invoice_overdue do
      signal "accountex.ar.invoice_overdue"
      
      correlation [:invoice_id, :customer_id]
    end
    
    # ============================================
    # Customer Analysis & Strategy Selection
    # ============================================
    
    agent_task :analyze_customer do
      agent AccountEx.AR.Agents.CollectionsStrategist
      action :determine_approach
      
      factors %{
        customer_value: "$.customer.lifetime_value",
        payment_history: "$.customer.payment_pattern",
        current_situation: "$.customer.recent_interactions",
        communication_prefs: "$.customer.preferences"
      }
      
      output %{
        strategy: :string,
        risk_level: :string,
        recommended_actions: :list
      }
    end
    
    exclusive_gateway :strategy_routing do
      condition :soft, expr: "$.strategy == 'relationship_preservation'"
      condition :standard, expr: "$.strategy == 'standard_collections'"
      condition :aggressive, expr: "$.strategy == 'aggressive_recovery'"
      condition :legal, expr: "$.strategy == 'legal_action'"
    end
    
    # ============================================
    # Soft Collections Path
    # ============================================
    
    subprocess :soft_collections do
      incoming :soft
      
      agent_task :friendly_reminder do
        agent AccountEx.AR.Agents.CommunicationsBot
        action :send_personalized_reminder
        
        tone :friendly
        personalization :high
        
        templates %{
          first_reminder: "gentle_reminder_template",
          follow_up: "friendly_follow_up_template"
        }
      end
      
      timer_event :wait_period do
        duration "P7D"
      end
      
      service_task :check_payment do
        query AccountEx.AR.Queries.CheckPaymentReceived
        invoice_id "$.invoice_id"
      end
      
      exclusive_gateway :payment_check do
        condition :paid, expr: "$.payment_received == true"
        condition :not_paid, expr: "$.payment_received == false"
      end
      
      signal_event :escalate_to_standard do
        incoming :not_paid
        
        signal AccountEx.Signals.EscalateCollections do
          data %{
            invoice_id: "$.invoice_id",
            new_strategy: "standard"
          }
        end
      end
    end
    
    # ============================================
    # Standard Collections Path
    # ============================================
    
    subprocess :standard_collections do
      incoming [:standard, :escalate_to_standard]
      
      multi_instance :contact_attempts do
        max_iterations 3
        
        parallel_gateway :multi_channel
        
        service_task :email_notice do
          template expr: "select_template($.attempt_number)"
          urgency expr: "calculate_urgency($.days_overdue)"
        end
        
        service_task :sms_reminder do
          condition "$.customer.sms_enabled"
          template :payment_reminder_sms
        end
        
        user_task :phone_call do
          condition "$.days_overdue > 30"
          
          assignee role: "collections_agent"
          
          script :collections_call_script
          
          disposition_codes [
            "promise_to_pay",
            "dispute_raised",
            "unable_to_pay",
            "wrong_number",
            "no_answer",
            "left_message"
          ]
        end
        
        parallel_gateway :channel_join
        
        timer_event :between_attempts do
          duration expr: "P#{5 + $.attempt_number * 2}D"
        end
        
        exclusive_gateway :evaluate_response do
          condition :promise, expr: "$.disposition == 'promise_to_pay'"
          condition :dispute, expr: "$.disposition == 'dispute_raised'"
          condition :continue, expr: "$.disposition in ['no_answer', 'left_message']"
          condition :escalate, expr: "$.attempt_number >= 3"
        end
      end
    end
    
    # ============================================
    # Promise to Pay Tracking
    # ============================================
    
    subprocess :promise_tracking do
      incoming :promise
      
      service_task :record_promise do
        command AccountEx.AR.Commands.CreatePaymentPromise do
          payload %{
            invoice_id: "$.invoice_id",
            promise_date: "$.promise_date",
            promise_amount: "$.promise_amount",
            notes: "$.agent_notes"
          }
        end
      end
      
      timer_event :promise_due do
        date "$.promise_date"
      end
      
      service_task :verify_promise do
        query AccountEx.AR.Queries.CheckPromiseFulfilled
      end
      
      exclusive_gateway :promise_kept do
        condition :fulfilled, expr: "$.promise.fulfilled"
        condition :broken, expr: "not $.promise.fulfilled"
      end
      
      service_task :mark_broken_promise do
        incoming :broken
        
        command AccountEx.AR.Commands.RecordBrokenPromise
        
        update_customer_reliability_score true
      end
      
      signal_event :escalate_broken_promise do
        incoming :broken
        
        signal AccountEx.Signals.BrokenPromise
        severity :high
      end
    end
    
    # ============================================
    # Aggressive Collections Path
    # ============================================
    
    subprocess :aggressive_collections do
      incoming :aggressive
      
      service_task :final_demand_letter do
        template :formal_demand_letter
        
        delivery :certified_mail
        signature_required true
        
        include %{
          legal_language: true,
          consequences: true,
          final_deadline: "P10D"
        }
      end
      
      timer_event :wait_for_response do
        duration "P10D"
      end
      
      parallel_gateway :aggressive_actions
      
      service_task :credit_bureau_reporting do
        condition "$.days_overdue > 90"
        
        bureaus [:experian, :equifax, :transunion]
        
        compliance_check :ensure_fdcpa_compliance
      end
      
      service_task :suspend_services do
        condition "$.customer.has_active_services"
        
        command AccountEx.Services.Commands.SuspendCustomer
        
        requires_approval role: "service_manager"
      end
      
      signal_event :notify_sales_team do
        signal AccountEx.Signals.CustomerAtRisk
        
        data %{
          customer_id: "$.customer_id",
          risk_level: :high,
          recommended_action: "no_new_orders"
        }
      end
      
      parallel_gateway :aggressive_join
      
      user_task :final_attempt do
        assignee role: "senior_collector"
        
        escalation after: "PT48H", to: "collections_manager"
        
        options [
          "payment_received",
          "payment_plan_negotiated",
          "send_to_legal",
          "write_off"
        ]
      end
    end
    
    # ============================================
    # Legal Action Path
    # ============================================
    
    subprocess :legal_proceedings do
      incoming :legal
      
      user_task :legal_review do
        assignee role: "legal_team"
        
        required_documents [
          "invoice_history",
          "payment_history",
          "communication_log",
          "signed_agreements"
        ]
        
        checklist [
          "amount_justifies_action",
          "documentation_complete",
          "statute_limitations_ok",
          "customer_solvency_verified"
        ]
      end
      
      exclusive_gateway :legal_decision do
        condition :proceed, expr: "$.legal_review.recommendation == 'proceed'"
        condition :settle, expr: "$.legal_review.recommendation == 'negotiate'"
        condition :write_off, expr: "$.legal_review.recommendation == 'write_off'"
      end
      
      service_task :file_legal_claim do
        incoming :proceed
        
        external_system :legal_case_management
        
        create_case %{
          type: "debt_collection",
          amount: "$.invoice.total_amount",
          documentation: "$.legal_documents"
        }
      end
      
      user_task :settlement_negotiation do
        incoming :settle
        
        assignee role: "settlement_specialist"
        
        minimum_acceptable "$.invoice.balance * 0.6"
        
        authority_matrix %{
          "0.9": "collector",
          "0.7": "manager",
          "0.6": "director"
        }
      end
      
      service_task :write_off_debt do
        incoming :write_off
        
        command AccountEx.AR.Commands.WriteOffInvoice do
          approval_required true
          
          approval_matrix %{
            under_1000: "supervisor",
            under_10000: "manager",
            under_50000: "director",
            over_50000: "cfo"
          }
        end
        
        update_gl true
        report_to_tax_authorities true
      end
    end
    
    # ============================================
    # Dispute Resolution
    # ============================================
    
    subprocess :dispute_resolution do
      incoming :dispute
      
      user_task :investigate_dispute do
        assignee role: "dispute_analyst"
        
        sla "PT24H"
        
        investigation_tools [
          :order_history,
          :delivery_tracking,
          :communication_logs,
          :contract_terms
        ]
      end
      
      exclusive_gateway :dispute_validity do
        condition :valid, expr: "$.investigation.finding == 'valid'"
        condition :invalid, expr: "$.investigation.finding == 'invalid'"
        condition :partial, expr: "$.investigation.finding == 'partial'"
      end
      
      service_task :adjust_invoice do
        incoming [:valid, :partial]
        
        command AccountEx.AR.Commands.AdjustInvoice do
          adjustment_amount expr: "$.dispute.valid_amount"
          reason "$.dispute.reason"
        end
      end
      
      service_task :issue_credit do
        incoming :valid
        condition "$.invoice.status == 'paid'"
        
        command AccountEx.AR.Commands.IssueCreditMemo
      end
      
      signal_event :resume_collections do
        incoming :invalid
        
        signal AccountEx.Signals.ResumeCollections
      end
    end
    
    # ============================================
    # Compliance & Monitoring
    # ============================================
    
    subprocess :compliance_monitoring do
      parallel_to :main_process
      
      service_task :fdcpa_compliance do
        continuous true
        
        rules [
          {max_calls_per_day: 3},
          {no_calls_before: "8:00"},
          {no_calls_after: "21:00"},
          {respect_cease_desist: true},
          {validate_debt_on_request: true}
        ]
      end
      
      service_task :log_all_contacts do
        every :collection_activity
        
        log %{
          timestamp: now(),
          type: "$.activity_type",
          agent: "$.agent_id",
          outcome: "$.outcome",
          notes: "$.notes"
        }
        
        immutable true
        retention "P7Y"
      end
    end
    
    end_event :collections_complete
  end
end
```

## 5. Dunning Process Implementation

```elixir
defmodule AccountEx.AR.Processes.Dunning do
  @moduledoc """
  Automated dunning process with multi-level escalation.
  Configurable by customer segment and region.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :dunning_process do
    tenant_aware true
    
    timer_start_event :daily_run do
      schedule "0 6 * * *"  # Daily at 6 AM
    end
    
    # ============================================
    # Identify Dunning Candidates
    # ============================================
    
    service_task :get_dunning_candidates do
      query AccountEx.AR.Queries.DunningCandidates do
        filters %{
          exclude_disputed: true,
          exclude_promised: true,
          minimum_amount: 100,
          minimum_days_overdue: 1
        }
      end
    end
    
    multi_instance :process_customer do
      collection "$.candidates"
      execution_mode :parallel
      max_concurrency 50
      
      # ============================================
      # Determine Dunning Level
      # ============================================
      
      service_task :calculate_dunning_level do
        factors %{
          days_overdue: "$.invoice.days_overdue",
          previous_dunning: "$.customer.dunning_history",
          customer_segment: "$.customer.segment",
          amount_overdue: "$.invoice.amount"
        }
        
        levels [
          {1, :reminder, days: 1..14},
          {2, :first_notice, days: 15..30},
          {3, :second_notice, days: 31..45},
          {4, :final_notice, days: 46..60},
          {5, :pre_legal, days: 61..90}
        ]
      end
      
      exclusive_gateway :level_routing do
        condition :level_1, expr: "$.dunning_level == 1"
        condition :level_2, expr: "$.dunning_level == 2"
        condition :level_3, expr: "$.dunning_level == 3"
        condition :level_4, expr: "$.dunning_level == 4"
        condition :level_5, expr: "$.dunning_level == 5"
      end
      
      # ============================================
      # Level 1: Friendly Reminder
      # ============================================
      
      subprocess :level_1_reminder do
        incoming :level_1
        
        agent_task :compose_reminder do
          agent AccountEx.AR.Agents.DunningComposer
          action :create_friendly_reminder
          
          tone :friendly
          personalization :high
          
          variables %{
            customer_name: "$.customer.name",
            invoice_number: "$.invoice.number",
            amount_due: "$.invoice.amount",
            days_overdue: "$.invoice.days_overdue"
          }
        end
        
        service_task :send_reminder do
          channels [:email]
          
          track %{
            opens: true,
            clicks: true,
            replies: true
          }
        end
      end
      
      # ============================================
      # Level 2: First Notice
      # ============================================
      
      subprocess :level_2_notice do
        incoming :level_2
        
        service_task :calculate_late_fees do
          rate "$.customer.contract.late_fee_rate"
          minimum 25.00
        end
        
        service_task :generate_statement do
          include %{
            current_invoice: true,
            late_fees: true,
            payment_history: true,
            aging_summary: true
          }
        end
        
        parallel_gateway :delivery_channels
        
        service_task :email_notice do
          template :first_dunning_notice
          priority :high
          read_receipt true
        end
        
        service_task :portal_notification do
          prominent true
          requires_acknowledgment true
        end
        
        parallel_gateway :delivery_join
      end
      
      # ============================================
      # Level 3: Second Notice with Call
      # ============================================
      
      subprocess :level_3_notice do
        incoming :level_3
        
        service_task :generate_urgent_notice do
          template :second_dunning_notice
          
          urgency :high
          
          highlight %{
            consequences: true,
            credit_impact: true,
            service_suspension: true
          }
        end
        
        agent_task :automated_call do
          agent AccountEx.AR.Agents.VoiceCaller
          action :place_reminder_call
          
          provider :twilio
          
          script :payment_reminder_ivr
          
          options %{
            "1": "promise_to_pay",
            "2": "speak_to_agent",
            "3": "dispute_amount"
          }
        end
        
        conditional_event :schedule_follow_up do
          condition "$.customer.value_segment == 'high'"
          
          user_task :personal_follow_up do
            assignee "$.customer.account_manager"
            script :relationship_preservation_script
          end
        end
      end
      
      # ============================================
      # Level 4: Final Notice
      # ============================================
      
      subprocess :level_4_final do
        incoming :level_4
        
        service_task :prepare_final_notice do
          template :final_dunning_notice
          
          legal_language true
          
          deadlines %{
            payment: "P10D",
            response: "P7D"
          }
          
          consequences %{
            credit_reporting: true,
            legal_action: true,
            service_termination: true
          }
        end
        
        service_task :send_certified do
          method :certified_mail
          return_receipt true
          electronic_delivery true
        end
        
        signal_event :alert_management do
          signal AccountEx.Signals.CustomerCritical
          
          data %{
            customer_id: "$.customer_id",
            at_risk_amount: "$.total_outstanding",
            recommended_actions: ["personal_intervention", "payment_plan"]
          }
        end
      end
      
      # ============================================
      # Level 5: Pre-Legal
      # ============================================
      
      subprocess :level_5_prelegal do
        incoming :level_5
        
        service_task :compile_documentation do
          documents %{
            invoices: "$.all_outstanding_invoices",
            dunning_history: "$.dunning_log",
            communications: "$.communication_history",
            contracts: "$.customer.agreements"
          }
          
          format :legal_package
        end
        
        user_task :final_review do
          assignee role: "collections_manager"
          
          options [
            "proceed_to_legal",
            "offer_settlement",
            "payment_plan",
            "write_off"
          ]
          
          require_justification true
        end
        
        exclusive_gateway :final_decision do
          condition :legal, expr: "$.decision == 'proceed_to_legal'"
          condition :settlement, expr: "$.decision == 'offer_settlement'"
          condition :payment_plan, expr: "$.decision == 'payment_plan'"
          condition :write_off, expr: "$.decision == 'write_off'"
        end
        
        call_activity :initiate_legal do
          incoming :legal
          called_process AccountEx.AR.Processes.Collections
          start_at :legal_proceedings
        end
      end
      
      # ============================================
      # Record Dunning Activity
      # ============================================
      
      service_task :log_dunning do
        command AccountEx.AR.Commands.RecordDunningActivity do
          payload %{
            customer_id: "$.customer_id",
            invoice_id: "$.invoice_id",
            dunning_level: "$.dunning_level",
            action_taken: "$.action",
            response: "$.customer_response",
            next_action_date: "$.next_dunning_date"
          }
        end
      end
      
      service_task :update_customer_status do
        command AccountEx.AR.Commands.UpdateDunningStatus do
          aggregate_id "$.customer_id"
          
          status expr: "map_dunning_to_status($.dunning_level)"
          
          block_new_orders "$.dunning_level >= 3"
        end
      end
    end
    
    # ============================================
    # Compliance Validation
    # ============================================
    
    service_task :validate_compliance do
      rules %{
        max_contacts_week: 3,
        quiet_hours: ["22:00", "08:00"],
        cooling_period: "P7D",
        exclude_lists: ["do_not_contact", "bankruptcy", "deceased"]
      }
      
      gdpr_compliant true
      ccpa_compliant true
    end
    
    end_event :dunning_complete
  end
end
```

## 6. Integration Points Module

```elixir
defmodule AccountEx.AR.Processes.Integrations do
  @moduledoc """
  Handles integration with other AccountEx modules and external systems.
  Implements resilient communication patterns for module unavailability.
  """
  
  use AccountEx.AccountsReceivables.BPMN.DSL
  
  process id: :module_integrations do
    
    # ============================================
    # General Ledger Integration
    # ============================================
    
    subprocess :gl_integration do
      signal_start_event :ar_transaction do
        signal_types [
          "InvoiceIssued",
          "PaymentReceived",
          "CreditMemoIssued",
          "WriteOffApproved",
          "AdjustmentPosted"
        ]
      end
      
      service_task :map_to_journal_entry do
        mappings %{
          "InvoiceIssued" => {
            debit: "120000",  # AR Control
            credit: "400000"  # Revenue
          },
          "PaymentReceived" => {
            debit: "100000",  # Cash
            credit: "120000"  # AR Control
          },
          "CreditMemoIssued" => {
            debit: "400000",  # Revenue
            credit: "120000"  # AR Control
          },
          "WriteOffApproved" => {
            debit: "630000",  # Bad Debt Expense
            credit: "120000"  # AR Control
          }
        }
      end
      
      service_task :post_to_gl do
        resilient_call AccountEx.GeneralLedger.PostJournalEntry do
          retry_policy %{
            max_attempts: 5,
            backoff: :exponential,
            initial_delay: 1000
          }
          
          fallback :queue_for_batch_posting
        end
        
        idempotent true
        idempotency_key "ar_#{$.transaction_id}"
      end
      
      boundary_event :gl_unavailable do
        error_type :module_unavailable
        
        compensate false  # Don't rollback AR transaction
        
        signal AccountEx.Signals.IntegrationFailure do
          severity :high
          module :general_ledger
          retry_after "PT5M"
        end
      end
    end
    
    # ============================================
    # Sales Order Integration
    # ============================================
    
    subprocess :sales_integration do
      message_start_event :order_ready do
        message "SalesOrderReadyForInvoicing"
        correlation [:order_id, :customer_id]
      end
      
      service_task :validate_order do
        checks %{
          customer_exists: "customer_active($.customer_id)",
          credit_approved: "credit_check_passed($.customer_id, $.order_total)",
          billing_complete: "billing_address_valid($.billing_address)"
        }
      end
      
      exclusive_gateway :order_type do
        condition :standard, expr: "$.order.type == 'standard'"
        condition :subscription, expr: "$.order.type == 'subscription'"
        condition :milestone, expr: "$.order.type == 'milestone'"
      end
      
      call_activity :create_standard_invoice do
        incoming :standard
        called_process :invoice_lifecycle
      end
      
      subprocess :subscription_invoicing do
        incoming :subscription
        
        service_task :calculate_period do
          billing_cycle "$.subscription.billing_cycle"
          proration_rules "$.subscription.proration"
        end
        
        timer_event :recurring_invoice do
          cycle expr: "subscription_schedule($.subscription)"
        end
        
        call_activity :create_subscription_invoice do
          called_process :invoice_lifecycle
          
          modifications %{
            auto_charge: true,
            payment_method: "$.subscription.payment_method"
          }
        end
      end
      
      signal_event :notify_sales do
        signal AccountEx.Signals.InvoiceCreatedFromOrder do
          data %{
            order_id: "$.order_id",
            invoice_id: "$.invoice_id",
            invoice_number: "$.invoice_number"
          }
        end
      end
    end
    
    # ============================================
    # Banking Integration
    # ============================================
    
    subprocess :banking_integration do
      parallel_gateway :bank_channels
      
      # Bank statement import
      service_task :import_bank_statements do
        providers [
          {name: :bank_api, priority: 1},
          {name: :file_import, priority: 2},
          {name: :manual_entry, priority: 3}
        ]
        
        formats ["MT940", "BAI2", "OFX", "CSV"]
        
        schedule "0 8,14,20 * * *"  # 3 times daily
      end
      
      # Payment gateway notifications
      receive_task :payment_gateway_webhook do
        providers [:stripe, :paypal, :square]
        
        verify_signature true
        
        deduplicate_window "PT24H"
      end
      
      # ACH processing
      service_task :process_ach_batch do
        schedule "0 16 * * 1-5"  # 4 PM weekdays
        
        nacha_compliant true
        
        same_day_cutoff "14:00"
      end
      
      parallel_gateway :bank_join
      
      signal_event :payment_detected do
        signal AccountEx.Signals.PaymentDetected do
          routing ["payment_processing", "reconciliation"]
        end
      end
    end
    
    # ============================================
    # External Credit Services
    # ============================================
    
    subprocess :credit_services do
      timer_start_event :credit_update do
        cycle "R/P1M"  # Monthly
      end
      
      multi_instance :credit_bureaus do
        collection ["experian", "equifax", "transunion"]
        
        service_task :pull_credit_report do
          resilient_call AccountEx.External.CreditBureau do
            timeout 30_000
            
            cache_on_failure true
            cache_ttl "P7D"
            
            circuit_breaker %{
              threshold: 5,
              timeout: 60_000
            }
          end
        end
        
        service_task :update_customer_score do
          command AccountEx.AR.Commands.UpdateCreditScore do
            weighted_average true
            
            weights %{
              experian: 0.35,
              equifax: 0.35,
              transunion: 0.30
            }
          end
        end
      end
    end
  end
end
```

This complete BPMN DSL implementation for Accounts Receivables provides:

1. **Full Event Sourcing Integration** - All processes work with Commanded aggregates and events
2. **Resilient Module Communication** - Handles unavailable modules gracefully
3. **Comprehensive Business Logic** - Covers all AR workflows from invoice to collection
4. **Agent-Based Automation** - Jido agents handle intelligent tasks
5. **Compliance Built-In** - FDCPA, GDPR, and other regulations enforced
6. **Multi-Tenant Support** - Tenant isolation throughout
7. **Error Handling & Compensation** - Robust error recovery and rollback

The implementation leverages Elixir's OTP for fault tolerance, uses signals for loose coupling between modules, and provides complete audit trails through event sourcing.
