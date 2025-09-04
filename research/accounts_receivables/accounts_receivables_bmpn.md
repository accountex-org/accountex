defmodule AccountsReceivables.BPMN.ProcessBase do
  @moduledoc """
  Base module providing common BPMN process functionality with Jido.Agent integration
  """
  
  defmacro __using__(opts) do
    quote do
      use Jido.Process
      
      import Jido.Signal
      import AccountsReceivables.BPMN.ProcessBase
      
      @process_name unquote(opts[:name])
      @process_version unquote(opts[:version] || "1.0.0")
      
      def metadata do
        %{
          name: @process_name,
          version: @process_version,
          created_at: DateTime.utc_now()
        }
      end
    end
  end
  
  def handle_unavailable_application(app_name, fallback_action) do
    case Application.ensure_started(app_name) do
      :ok -> :continue
      {:error, _} -> fallback_action.()
    end
  end
  
  def emit_domain_event(event, metadata) do
    AshCommanded.Router.dispatch(%{
      event: event,
      metadata: Map.merge(metadata, %{
        process_id: self(),
        timestamp: DateTime.utc_now()
      })
    })
  end
end

defmodule AccountsReceivables.BPMN.InvoiceLifecycle do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "invoice_lifecycle",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "invoice_lifecycle" do
    @doc """
    Complete invoice lifecycle from creation to payment/write-off
    """
    
    # Start event - triggered by sales order completion
    start_event :invoice_requested do
      message_ref "sales.order.completed"
      
      output :order_data
    end
    
    # Service task - Create invoice with agent
    service_task :create_invoice do
      name "Create Invoice"
      input [:order_data]
      
      agent AccountsReceivables.Agents.InvoiceAgent do
        action :create_invoice
        timeout "PT30S"
        
        on_error :invoice_creation_failed
      end
      
      output :invoice
    end
    
    # Business rule task - Credit check
    business_rule_task :check_credit do
      name "Check Customer Credit"
      input [:invoice]
      
      agent AccountsReceivables.Agents.CreditAgent do
        action :evaluate_credit_worthiness
        params %{
          customer_id: "{{invoice.customer_id}}",
          invoice_amount: "{{invoice.amount}}",
          current_outstanding: "{{invoice.customer_outstanding}}"
        }
      end
      
      output :credit_decision
    end
    
    # Exclusive gateway - Credit decision
    exclusive_gateway :credit_gateway do
      name "Credit Approved?"
      
      flow :approved do
        condition "{{credit_decision.approved}} == true"
        target :send_invoice
      end
      
      flow :rejected do
        condition "{{credit_decision.approved}} == false"
        target :credit_hold_process
      end
      
      default :manual_review
    end
    
    # Sub-process for credit hold
    sub_process :credit_hold_process do
      name "Credit Hold Management"
      
      start_event :credit_hold_start
      
      user_task :review_credit_hold do
        name "Manual Credit Review"
        assignee "credit_manager"
        
        form do
          field :approval_decision, :boolean
          field :override_reason, :string
          field :new_credit_limit, :decimal
        end
        
        output :credit_override
      end
      
      exclusive_gateway :override_decision do
        flow :approved do
          condition "{{credit_override.approval_decision}} == true"
          target :update_credit_limit
        end
        
        flow :rejected do
          target :cancel_invoice
        end
      end
      
      service_task :update_credit_limit do
        agent AccountsReceivables.Agents.CustomerAgent do
          action :update_credit_limit
          params %{
            customer_id: "{{invoice.customer_id}}",
            new_limit: "{{credit_override.new_credit_limit}}"
          }
        end
        
        output :credit_updated
      end
      
      end_event :credit_hold_resolved
    end
    
    # Send invoice task
    service_task :send_invoice do
      name "Send Invoice to Customer"
      input [:invoice]
      
      agent AccountsReceivables.Agents.InvoiceDeliveryAgent do
        action :deliver_invoice
        
        retry_policy do
          max_attempts 3
          backoff :exponential
          initial_delay "PT1M"
        end
      end
      
      output :delivery_confirmation
    end
    
    # Timer intermediate event - Payment due date
    timer_intermediate_event :payment_due_timer do
      name "Payment Due Date"
      
      time_date "{{invoice.due_date}}"
      
      on_timeout :check_payment_status
    end
    
    # Service task - Check payment status
    service_task :check_payment_status do
      name "Check Payment Status"
      
      agent AccountsReceivables.Agents.PaymentAgent do
        action :get_payment_status
        params %{invoice_id: "{{invoice.id}}"}
      end
      
      output :payment_status
    end
    
    # Event-based gateway for payment handling
    event_based_gateway :payment_gateway do
      name "Payment Processing"
      
      # Payment received path
      intermediate_catch_event :payment_received do
        message_ref "payment.received"
        correlation_key "{{invoice.id}}"
        
        flow_to :apply_payment
      end
      
      # Timeout path - no payment received
      timer_intermediate_event :payment_timeout do
        time_duration "P7D"  # 7 days grace period
        
        flow_to :initiate_collections
      end
      
      # Dispute raised path
      intermediate_catch_event :dispute_raised do
        message_ref "invoice.disputed"
        correlation_key "{{invoice.id}}"
        
        flow_to :dispute_resolution
      end
    end
    
    # Apply payment
    service_task :apply_payment do
      name "Apply Payment to Invoice"
      
      agent AccountsReceivables.Agents.PaymentAgent do
        action :apply_payment
        params %{
          invoice_id: "{{invoice.id}}",
          payment_data: "{{payment_received.data}}"
        }
        
        compensate :reverse_payment_application
      end
      
      output :payment_result
    end
    
    # Collections sub-process
    call_activity :initiate_collections do
      name "Collections Process"
      called_element :collections_workflow
      
      input_mapping do
        map :invoice_id, "{{invoice.id}}"
        map :customer_id, "{{invoice.customer_id}}"
        map :amount_due, "{{invoice.outstanding_amount}}"
      end
      
      output :collection_result
    end
    
    # Dispute resolution sub-process
    call_activity :dispute_resolution do
      name "Dispute Resolution"
      called_element :dispute_workflow
      
      input_mapping do
        map :invoice_id, "{{invoice.id}}"
        map :dispute_data, "{{dispute_raised.data}}"
      end
      
      output :resolution_result
    end
    
    # Parallel gateway for final processing
    parallel_gateway :final_processing do
      name "Final Invoice Processing"
      
      flow :update_ledger
      flow :send_notification
      flow :update_metrics
    end
    
    # Update general ledger
    service_task :update_ledger do
      name "Update General Ledger"
      
      handle_unavailable_application :general_ledger do
        agent AccountsReceivables.Agents.FallbackLedgerAgent do
          action :queue_ledger_update
        end
      end
      
      agent GeneralLedger.Agents.PostingAgent do
        action :post_ar_transaction
        params %{
          invoice: "{{invoice}}",
          payment: "{{payment_result}}"
        }
      end
    end
    
    # Send notification
    send_task :send_notification do
      name "Send Confirmation"
      
      signal do
        type "invoice.completed"
        source "/accounts_receivables/invoice_lifecycle"
        data %{
          invoice_id: "{{invoice.id}}",
          status: "{{payment_result.status}}"
        }
        
        dispatch do
          pubsub topic: "ar_events"
          bus target: :notification_service
          pid target: "{{invoice.sales_agent_pid}}"
        end
      end
    end
    
    # Update metrics
    service_task :update_metrics do
      name "Update AR Metrics"
      
      agent AccountsReceivables.Agents.MetricsAgent do
        action :update_dso
        action :update_collection_effectiveness
      end
    end
    
    # End events
    end_event :invoice_paid do
      name "Invoice Paid"
      condition "{{payment_result.status}} == :paid"
    end
    
    end_event :invoice_written_off do
      name "Invoice Written Off"
      condition "{{collection_result.status}} == :write_off"
    end
    
    # Error handling
    boundary_event :invoice_creation_failed do
      attached_to :create_invoice
      error_ref "InvoiceCreationError"
      
      flow_to :manual_invoice_creation
    end
    
    # Manual fallback
    user_task :manual_invoice_creation do
      name "Manual Invoice Creation"
      assignee "ar_clerk"
      
      form do
        field :invoice_number, :string
        field :amount, :decimal
        field :due_date, :date
      end
    end
    
    # Compensation handlers
    compensation :reverse_payment_application do
      agent AccountsReceivables.Agents.PaymentAgent do
        action :reverse_payment
        params %{payment_id: "{{payment_result.payment_id}}"}
      end
    end
  end
end

defmodule AccountsReceivables.BPMN.CollectionsWorkflow do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "collections_workflow",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "collections_workflow" do
    @doc """
    Multi-stage collections process with escalating actions
    """
    
    start_event :collection_initiated do
      input [:invoice_id, :customer_id, :amount_due]
      
      output :collection_context
    end
    
    # Determine collection strategy using AI
    service_task :determine_strategy do
      name "AI Collection Strategy"
      
      agent AccountsReceivables.Agents.AICollectionAgent do
        action :analyze_customer_profile
        params %{
          customer_id: "{{customer_id}}",
          payment_history: "{{collection_context.payment_history}}",
          outstanding_amount: "{{amount_due}}",
          account_age: "{{collection_context.account_age}}"
        }
        
        ai_enabled true
        model "gpt-4"
      end
      
      output :collection_strategy
    end
    
    # Multi-instance subprocess for dunning levels
    multi_instance_subprocess :dunning_sequence do
      name "Execute Dunning Levels"
      
      collection "{{collection_strategy.dunning_levels}}"
      variable :dunning_level
      
      start_event :level_start
      
      # Check current status
      service_task :check_current_status do
        name "Check Payment Status"
        
        agent AccountsReceivables.Agents.PaymentAgent do
          action :check_invoice_status
          params %{invoice_id: "{{invoice_id}}"}
        end
        
        output :current_status
      end
      
      # Skip if paid
      exclusive_gateway :payment_check do
        flow :already_paid do
          condition "{{current_status.paid}} == true"
          target :dunning_complete
        end
        
        flow :continue_dunning do
          target :execute_dunning_action
        end
      end
      
      # Execute dunning action based on level
      service_task :execute_dunning_action do
        name "Execute Dunning Action"
        
        agent AccountsReceivables.Agents.DunningAgent do
          action :execute_level
          params %{
            level: "{{dunning_level.level}}",
            channel: "{{dunning_level.channel}}",
            template: "{{dunning_level.template_id}}",
            customer_id: "{{customer_id}}",
            invoice_id: "{{invoice_id}}"
          }
        end
        
        output :dunning_result
      end
      
      # Log dunning action
      service_task :log_dunning do
        name "Log Collection Activity"
        
        emit_event do
          type "collection.dunning.executed"
          data %{
            invoice_id: "{{invoice_id}}",
            level: "{{dunning_level.level}}",
            channel: "{{dunning_level.channel}}",
            result: "{{dunning_result}}"
          }
        end
      end
      
      # Wait between levels
      timer_intermediate_event :wait_for_response do
        name "Wait for Customer Response"
        time_duration "{{dunning_level.wait_period}}"
      end
      
      end_event :dunning_complete
    end
    
    # Check if payment plan needed
    exclusive_gateway :payment_plan_decision do
      name "Payment Plan Needed?"
      
      flow :plan_requested do
        condition "{{collection_strategy.offer_payment_plan}} == true"
        target :create_payment_plan
      end
      
      flow :escalate do
        condition "{{collection_strategy.escalate_to_agency}} == true"
        target :external_collection
      end
      
      default :continue_internal
    end
    
    # Payment plan creation
    sub_process :create_payment_plan do
      name "Payment Plan Management"
      
      start_event :plan_start
      
      # Calculate plan options
      service_task :calculate_options do
        name "Calculate Payment Plan Options"
        
        agent AccountsReceivables.Agents.PaymentPlanAgent do
          action :generate_plan_options
          params %{
            total_amount: "{{amount_due}}",
            customer_credit_score: "{{collection_strategy.credit_score}}",
            max_term: "{{collection_strategy.max_payment_term}}"
          }
        end
        
        output :plan_options
      end
      
      # Customer approval
      user_task :approve_plan do
        name "Customer Plan Selection"
        assignee "{{customer_id}}"
        
        form do
          field :selected_plan, :enum, options: "{{plan_options}}"
          field :first_payment_date, :date
          field :payment_method, :string
        end
        
        timeout "P3D"
        on_timeout :plan_rejected
        
        output :selected_plan
      end
      
      # Create plan agreement
      service_task :create_agreement do
        name "Create Payment Agreement"
        
        agent AccountsReceivables.Agents.AgreementAgent do
          action :create_payment_agreement
          params %{
            invoice_id: "{{invoice_id}}",
            plan: "{{selected_plan}}",
            terms: "{{plan_options[selected_plan.selected_plan]}}"
          }
        end
        
        output :agreement
      end
      
      # Schedule payments
      service_task :schedule_payments do
        name "Schedule Automated Payments"
        
        agent AccountsReceivables.Agents.PaymentScheduler do
          action :create_recurring_schedule
          params %{
            agreement_id: "{{agreement.id}}",
            schedule: "{{agreement.payment_schedule}}"
          }
        end
      end
      
      end_event :plan_created
    end
    
    # External collection agency
    sub_process :external_collection do
      name "External Agency Collection"
      
      start_event :agency_start
      
      # Select agency
      business_rule_task :select_agency do
        name "Select Collection Agency"
        
        dmn_table "collection_agency_selection"
        input %{
          amount: "{{amount_due}}",
          region: "{{collection_context.customer_region}}",
          invoice_age: "{{collection_context.days_overdue}}"
        }
        
        output :selected_agency
      end
      
      # Transfer to agency
      service_task :transfer_to_agency do
        name "Transfer to Collection Agency"
        
        handle_unavailable_application :external_collections do
          agent AccountsReceivables.Agents.FallbackCollectionAgent do
            action :queue_for_manual_transfer
          end
        end
        
        agent ExternalCollections.Agents.TransferAgent do
          action :transfer_account
          params %{
            agency_id: "{{selected_agency.id}}",
            invoice_id: "{{invoice_id}}",
            documentation: "{{collection_context.documentation}}"
          }
        end
        
        output :transfer_result
      end
      
      # Monitor agency progress
      receive_task :agency_updates do
        name "Receive Agency Updates"
        
        message_ref "agency.collection.update"
        correlation_key "{{transfer_result.case_id}}"
        
        loop do
          condition "{{agency_update.status}} != 'closed'"
          max_iterations 12  # Monitor for up to 12 months
          
          timer_event "P1M"  # Check monthly
        end
        
        output :agency_results
      end
      
      end_event :agency_collection_complete
    end
    
    # Write-off decision
    exclusive_gateway :write_off_decision do
      name "Write-off Decision"
      
      flow :recovered do
        condition "{{collection_result.amount_recovered}} > 0"
        target :apply_recovery
      end
      
      flow :write_off do
        condition "{{collection_strategy.recommend_write_off}} == true"
        target :process_write_off
      end
      
      default :continue_monitoring
    end
    
    # Apply recovered amount
    service_task :apply_recovery do
      name "Apply Recovered Amount"
      
      agent AccountsReceivables.Agents.PaymentAgent do
        action :apply_partial_payment
        params %{
          invoice_id: "{{invoice_id}}",
          amount: "{{collection_result.amount_recovered}}",
          source: "collection_recovery"
        }
      end
    end
    
    # Process write-off
    service_task :process_write_off do
      name "Process Bad Debt Write-off"
      
      agent AccountsReceivables.Agents.WriteOffAgent do
        action :create_write_off
        params %{
          invoice_id: "{{invoice_id}}",
          reason: "{{collection_result.write_off_reason}}",
          approval: "{{collection_strategy.write_off_approval}}"
        }
        
        compensate :reverse_write_off
      end
      
      emit_event do
        type "invoice.written_off"
        data %{
          invoice_id: "{{invoice_id}}",
          amount: "{{amount_due}}",
          reason: "{{collection_result.write_off_reason}}"
        }
      end
    end
    
    # Continue monitoring
    timer_intermediate_event :continue_monitoring do
      name "Continue Monitoring"
      time_duration "P30D"
      
      flow_to :check_current_status
    end
    
    end_event :collection_complete do
      name "Collection Process Complete"
    end
  end
end

defmodule AccountsReceivables.BPMN.CreditManagement do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "credit_management",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "credit_management" do
    @doc """
    Customer credit assessment and management process
    """
    
    start_event :credit_request do
      conditional do
        any_of [
          message_ref: "customer.credit.requested",
          timer_cycle: "R/P1M"  # Monthly review
        ]
      end
      
      output :credit_context
    end
    
    # Parallel gateway for multiple credit checks
    parallel_gateway :credit_checks_start do
      name "Initiate Credit Checks"
      
      flow :internal_assessment
      flow :external_bureau_check
      flow :trade_reference_check
    end
    
    # Internal credit assessment
    service_task :internal_assessment do
      name "Internal Credit Score"
      
      agent AccountsReceivables.Agents.CreditScoringAgent do
        action :calculate_internal_score
        params %{
          customer_id: "{{credit_context.customer_id}}",
          payment_history: "{{credit_context.payment_history}}",
          account_age: "{{credit_context.account_age}}",
          order_frequency: "{{credit_context.order_patterns}}"
        }
      end
      
      output :internal_score
    end
    
    # External credit bureau check
    service_task :external_bureau_check do
      name "Credit Bureau Check"
      
      agent AccountsReceivables.Agents.CreditBureauAgent do
        action :get_credit_report
        params %{
          business_id: "{{credit_context.business_id}}",
          authorized: "{{credit_context.bureau_consent}}"
        }
        
        timeout "PT30S"
        retry_policy do
          max_attempts 2
          backoff :linear
        end
      end
      
      output :bureau_report
    end
    
    # Trade references
    multi_instance_task :trade_reference_check do
      name "Check Trade References"
      
      collection "{{credit_context.trade_references}}"
      variable :reference
      completion_condition "{{completed_count}} >= 2"  # Need at least 2 references
      
      agent AccountsReceivables.Agents.ReferenceAgent do
        action :verify_trade_reference
        params %{
          reference_contact: "{{reference}}",
          customer_name: "{{credit_context.customer_name}}"
        }
      end
      
      output :reference_results
    end
    
    # Synchronize results
    parallel_gateway :credit_checks_complete do
      name "Aggregate Credit Data"
      converge true
    end
    
    # AI-powered credit decision
    service_task :ai_credit_decision do
      name "AI Credit Analysis"
      
      agent AccountsReceivables.Agents.AICreditAgent do
        action :comprehensive_credit_analysis
        params %{
          internal_score: "{{internal_score}}",
          bureau_report: "{{bureau_report}}",
          trade_references: "{{reference_results}}",
          requested_limit: "{{credit_context.requested_limit}}",
          industry_risk: "{{credit_context.industry_risk_factor}}"
        }
        
        ai_enabled true
        model "credit-risk-model-v2"
        confidence_threshold 0.85
      end
      
      output :ai_recommendation
    end
    
    # Credit decision gateway
    exclusive_gateway :credit_decision do
      name "Credit Decision"
      
      flow :auto_approved do
        condition "{{ai_recommendation.decision}} == 'approve' && {{ai_recommendation.confidence}} >= 0.95"
        target :approve_credit
      end
      
      flow :auto_rejected do
        condition "{{ai_recommendation.decision}} == 'reject' && {{ai_recommendation.confidence}} >= 0.95"
        target :reject_credit
      end
      
      flow :manual_review do
        condition "{{ai_recommendation.confidence}} < 0.95"
        target :manual_credit_review
      end
    end
    
    # Manual review process
    user_task :manual_credit_review do
      name "Manual Credit Review"
      assignee role: "credit_manager"
      
      form do
        field :decision, :enum, options: [:approve, :reject, :conditional]
        field :approved_limit, :decimal
        field :conditions, :text
        field :review_notes, :text
      end
      
      sla "PT4H"  # 4 hour SLA
      escalation do
        after "PT2H"
        to role: "credit_director"
      end
      
      output :manual_decision
    end
    
    # Approve credit
    service_task :approve_credit do
      name "Approve Credit Limit"
      
      agent AccountsReceivables.Agents.CustomerAgent do
        action :update_credit_terms
        params %{
          customer_id: "{{credit_context.customer_id}}",
          credit_limit: "{{ai_recommendation.recommended_limit}}",
          payment_terms: "{{ai_recommendation.payment_terms}}",
          review_date: "{{ai_recommendation.next_review_date}}"
        }
      end
      
      emit_event do
        type "credit.approved"
        data %{
          customer_id: "{{credit_context.customer_id}}",
          limit: "{{ai_recommendation.recommended_limit}}",
          terms: "{{ai_recommendation.payment_terms}}"
        }
      end
      
      output :approval_result
    end
    
    # Reject credit
    service_task :reject_credit do
      name "Reject Credit Request"
      
      agent AccountsReceivables.Agents.CustomerAgent do
        action :reject_credit_request
        params %{
          customer_id: "{{credit_context.customer_id}}",
          reason: "{{ai_recommendation.rejection_reason}}",
          suggestions: "{{ai_recommendation.improvement_suggestions}}"
        }
      end
      
      output :rejection_result
    end
    
    # Set up monitoring
    service_task :setup_monitoring do
      name "Setup Credit Monitoring"
      
      agent AccountsReceivables.Agents.MonitoringAgent do
        action :create_credit_monitor
        params %{
          customer_id: "{{credit_context.customer_id}}",
          triggers: "{{ai_recommendation.monitoring_triggers}}",
          frequency: "{{ai_recommendation.review_frequency}}"
        }
      end
    end
    
    # Send notification
    send_task :notify_stakeholders do
      name "Notify Stakeholders"
      
      signal do
        type "credit.decision.complete"
        source "/accounts_receivables/credit_management"
        data %{
          customer_id: "{{credit_context.customer_id}}",
          decision: "{{credit_decision}}",
          limit: "{{approval_result.credit_limit}}"
        }
        
        dispatch do
          pubsub topic: "credit_decisions"
          bus target: :sales_team
          email to: "{{credit_context.requestor_email}}"
        end
      end
    end
    
    end_event :credit_process_complete
  end
end

defmodule AccountsReceivables.BPMN.PaymentProcessing do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "payment_processing",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "payment_processing" do
    @doc """
    Payment receipt, validation, and application process
    """
    
    start_event :payment_received do
      message_ref "payment.incoming"
      
      output :payment_data
    end
    
    # Validate payment
    service_task :validate_payment do
      name "Validate Payment"
      
      agent AccountsReceivables.Agents.ValidationAgent do
        action :validate_payment
        params %{
          payment_method: "{{payment_data.method}}",
          amount: "{{payment_data.amount}}",
          reference: "{{payment_data.reference}}",
          payer_info: "{{payment_data.payer}}"
        }
      end
      
      output :validation_result
    end
    
    # Check validation result
    exclusive_gateway :validation_check do
      name "Payment Valid?"
      
      flow :valid do
        condition "{{validation_result.valid}} == true"
        target :identify_customer
      end
      
      flow :invalid do
        condition "{{validation_result.valid}} == false"
        target :handle_invalid_payment
      end
    end
    
    # Handle invalid payment
    sub_process :handle_invalid_payment do
      name "Invalid Payment Handling"
      
      start_event :invalid_start
      
      user_task :review_payment do
        name "Manual Payment Review"
        assignee "ar_specialist"
        
        form do
          field :action, :enum, options: [:return, :hold, :accept_with_adjustment]
          field :adjustment_amount, :decimal
          field :notes, :text
        end
        
        output :review_decision
      end
      
      service_task :process_return do
        name "Process Payment Return"
        condition "{{review_decision.action}} == :return"
        
        agent AccountsReceivables.Agents.PaymentAgent do
          action :return_payment
          params %{
            payment_id: "{{payment_data.id}}",
            reason: "{{validation_result.errors}}"
          }
        end
      end
      
      end_event :invalid_handled
    end
    
    # Identify customer and invoices
    service_task :identify_customer do
      name "Identify Customer"
      
      agent AccountsReceivables.Agents.CustomerMatchingAgent do
        action :match_payment_to_customer
        params %{
          payment_reference: "{{payment_data.reference}}",
          payer_name: "{{payment_data.payer.name}}",
          payer_account: "{{payment_data.payer.account}}"
        }
        
        ai_enabled true
        confidence_threshold 0.9
      end
      
      output :customer_match
    end
    
    # AI-powered invoice matching
    service_task :match_invoices do
      name "AI Invoice Matching"
      
      agent AccountsReceivables.Agents.AIMatchingAgent do
        action :match_payment_to_invoices
        params %{
          customer_id: "{{customer_match.customer_id}}",
          payment_amount: "{{payment_data.amount}}",
          payment_reference: "{{payment_data.reference}}",
          open_invoices: "{{customer_match.open_invoices}}"
        }
        
        ai_enabled true
        model "payment-matching-v3"
      end
      
      output :invoice_matches
    end
    
    # Check matching confidence
    exclusive_gateway :matching_confidence do
      name "Matching Confidence"
      
      flow :high_confidence do
        condition "{{invoice_matches.confidence}} >= 0.95"
        target :auto_apply_payment
      end
      
      flow :medium_confidence do
        condition "{{invoice_matches.confidence}} >= 0.75"
        target :review_matches
      end
      
      flow :low_confidence do
        condition "{{invoice_matches.confidence}} < 0.75"
        target :manual_allocation
      end
    end
    
    # Review suggested matches
    user_task :review_matches do
      name "Review Suggested Matches"
      assignee "ar_clerk"
      
      form do
        field :confirm_matches, :boolean
        field :adjustments, :array
        field :notes, :text
      end
      
      timeout "PT2H"
      
      output :review_result
    end
    
    # Manual allocation
    user_task :manual_allocation do
      name "Manual Payment Allocation"
      assignee "ar_specialist"
      
      form do
        field :allocations, :array do
          field :invoice_id, :string
          field :amount, :decimal
        end
        field :unapplied_amount, :decimal
        field :notes, :text
      end
      
      output :manual_allocations
    end
    
    # Auto-apply payment
    service_task :auto_apply_payment do
      name "Auto-Apply Payment"
      
      agent AccountsReceivables.Agents.PaymentApplicationAgent do
        action :apply_payment_to_invoices
        params %{
          payment_id: "{{payment_data.id}}",
          allocations: "{{invoice_matches.allocations}}",
          customer_id: "{{customer_match.customer_id}}"
        }
        
        compensate :reverse_payment_application
      end
      
      output :application_result
    end
    
    # Handle payment differences
    exclusive_gateway :payment_difference do
      name "Payment Difference?"
      
      flow :exact_match do
        condition "{{application_result.difference}} == 0"
        target :update_records
      end
      
      flow :overpayment do
        condition "{{application_result.difference}} > 0"
        target :handle_overpayment
      end
      
      flow :underpayment do
        condition "{{application_result.difference}} < 0"
        target :handle_underpayment
      end
    end
    
    # Handle overpayment
    sub_process :handle_overpayment do
      name "Overpayment Processing"
      
      start_event :overpayment_start
      
      exclusive_gateway :overpayment_action do
        flow :apply_credit do
          condition "{{application_result.difference}} < {{customer_match.credit_threshold}}"
          target :create_credit_memo
        end
        
        flow :refund do
          condition "{{customer_match.prefers_refund}} == true"
          target :process_refund
        end
        
        default :hold_as_credit
      end
      
      service_task :create_credit_memo do
        name "Create Credit Memo"
        
        agent AccountsReceivables.Agents.CreditMemoAgent do
          action :create_credit
          params %{
            customer_id: "{{customer_match.customer_id}}",
            amount: "{{application_result.difference}}",
            payment_ref: "{{payment_data.id}}"
          }
        end
      end
      
      service_task :process_refund do
        name "Process Refund"
        
        agent AccountsReceivables.Agents.RefundAgent do
          action :initiate_refund
          params %{
            payment_id: "{{payment_data.id}}",
            amount: "{{application_result.difference}}",
            method: "{{payment_data.method}}"
          }
        end
      end
      
      end_event :overpayment_handled
    end
    
    # Handle underpayment
    service_task :handle_underpayment do
      name "Handle Short Payment"
      
      agent AccountsReceivables.Agents.ShortPaymentAgent do
        action :process_short_payment
        params %{
          invoice_id: "{{application_result.primary_invoice}}",
          short_amount: "{{application_result.difference * -1}}",
          tolerance: "{{customer_match.payment_tolerance}}"
        }
      end
      
      output :short_payment_result
    end
    
    # Update all records
    parallel_gateway :update_start do
      name "Update Systems"
      
      flow :update_ar
      flow :update_gl
      flow :update_bank_rec
    end
    
    service_task :update_records do
      name "Update AR Records"
      
      agent AccountsReceivables.Agents.RecordAgent do
        action :update_payment_records
        params %{
          payment: "{{application_result}}",
          invoices: "{{application_result.updated_invoices}}"
        }
      end
    end
    
    service_task :update_gl do
      name "Update General Ledger"
      
      handle_unavailable_application :general_ledger do
        agent AccountsReceivables.Agents.GLQueueAgent do
          action :queue_gl_update
        end
      end
      
      agent GeneralLedger.Agents.PostingAgent do
        action :post_cash_receipt
        params %{
          payment: "{{application_result}}",
          gl_accounts: "{{application_result.gl_mapping}}"
        }
      end
    end
    
    service_task :update_bank_rec do
      name "Update Bank Reconciliation"
      
      agent AccountsReceivables.Agents.BankRecAgent do
        action :mark_payment_cleared
        params %{
          payment_id: "{{payment_data.id}}",
          bank_reference: "{{payment_data.bank_reference}}"
        }
      end
    end
    
    parallel_gateway :update_complete do
      converge true
    end
    
    # Send confirmation
    send_task :send_confirmation do
      name "Send Payment Confirmation"
      
      signal do
        type "payment.processed"
        source "/accounts_receivables/payment_processing"
        data %{
          payment_id: "{{payment_data.id}}",
          customer_id: "{{customer_match.customer_id}}",
          amount: "{{payment_data.amount}}",
          invoices_paid: "{{application_result.invoices_paid}}"
        }
        
        dispatch do
          email to: "{{customer_match.email}}"
          pubsub topic: "payment_confirmations"
        end
      end
    end
    
    end_event :payment_complete
    
    # Compensation handler
    compensation :reverse_payment_application do
      agent AccountsReceivables.Agents.PaymentAgent do
        action :reverse_application
        params %{
          payment_id: "{{payment_data.id}}",
          application_id: "{{application_result.id}}"
        }
      end
    end
  end
end

defmodule AccountsReceivables.BPMN.DisputeResolution do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "dispute_resolution",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "dispute_resolution" do
    @doc """
    Invoice dispute handling and resolution process
    """
    
    start_event :dispute_raised do
      message_ref "invoice.dispute.raised"
      
      output :dispute_data
    end
    
    # Categorize dispute
    business_rule_task :categorize_dispute do
      name "Categorize Dispute Type"
      
      dmn_table "dispute_categorization"
      input %{
        dispute_reason: "{{dispute_data.reason}}",
        amount: "{{dispute_data.disputed_amount}}",
        invoice_age: "{{dispute_data.invoice_age}}"
      }
      
      output :dispute_category
    end
    
    # Log dispute
    service_task :log_dispute do
      name "Log Dispute"
      
      agent AccountsReceivables.Agents.DisputeAgent do
        action :create_dispute_record
        params %{
          invoice_id: "{{dispute_data.invoice_id}}",
          customer_id: "{{dispute_data.customer_id}}",
          category: "{{dispute_category}}",
          details: "{{dispute_data.details}}"
        }
      end
      
      emit_event do
        type "dispute.created"
        data %{
          dispute_id: "{{dispute_record.id}}",
          invoice_id: "{{dispute_data.invoice_id}}"
        }
      end
      
      output :dispute_record
    end
    
    # Put invoice on hold
    service_task :hold_invoice do
      name "Place Invoice on Hold"
      
      agent AccountsReceivables.Agents.InvoiceAgent do
        action :place_on_hold
        params %{
          invoice_id: "{{dispute_data.invoice_id}}",
          reason: "dispute",
          dispute_id: "{{dispute_record.id}}"
        }
      end
    end
    
    # Route based on dispute type
    exclusive_gateway :dispute_routing do
      name "Route by Dispute Type"
      
      flow :pricing_dispute do
        condition "{{dispute_category.type}} == 'pricing'"
        target :investigate_pricing
      end
      
      flow :quality_dispute do
        condition "{{dispute_category.type}} == 'quality'"
        target :investigate_quality
      end
      
      flow :delivery_dispute do
        condition "{{dispute_category.type}} == 'delivery'"
        target :investigate_delivery
      end
      
      flow :billing_error do
        condition "{{dispute_category.type}} == 'billing_error'"
        target :investigate_billing
      end
      
      default :general_investigation
    end
    
    # Pricing investigation
    sub_process :investigate_pricing do
      name "Pricing Dispute Investigation"
      
      start_event :pricing_start
      
      parallel_gateway :gather_pricing_data do
        flow :get_contract
        flow :get_quote
        flow :get_order
      end
      
      service_task :get_contract do
        name "Retrieve Contract Terms"
        
        agent AccountsReceivables.Agents.ContractAgent do
          action :get_pricing_terms
          params %{customer_id: "{{dispute_data.customer_id}}"}
        end
        
        output :contract_terms
      end
      
      service_task :get_quote do
        name "Retrieve Quote"
        
        agent Sales.Agents.QuoteAgent do
          action :get_quote
          params %{order_id: "{{dispute_data.order_id}}"}
        end
        
        output :quote_data
      end
      
      service_task :get_order do
        name "Retrieve Order"
        
        agent Sales.Agents.OrderAgent do
          action :get_order_details
          params %{order_id: "{{dispute_data.order_id}}"}
        end
        
        output :order_data
      end
      
      parallel_gateway :pricing_data_complete do
        converge true
      end
      
      service_task :analyze_pricing do
        name "AI Pricing Analysis"
        
        agent AccountsReceivables.Agents.AIPricingAgent do
          action :analyze_pricing_dispute
          params %{
            contract: "{{contract_terms}}",
            quote: "{{quote_data}}",
            order: "{{order_data}}",
            invoice: "{{dispute_data.invoice_data}}",
            dispute_claim: "{{dispute_data.customer_claim}}"
          }
          
          ai_enabled true
        end
        
        output :pricing_analysis
      end
      
      end_event :pricing_investigated
    end
    
    # Quality investigation
    sub_process :investigate_quality do
      name "Quality Dispute Investigation"
      
      start_event :quality_start
      
      service_task :get_quality_records do
        name "Retrieve Quality Records"
        
        agent Quality.Agents.QualityAgent do
          action :get_quality_reports
          params %{
            order_id: "{{dispute_data.order_id}}",
            product_ids: "{{dispute_data.product_ids}}"
          }
        end
        
        output :quality_records
      end
      
      user_task :quality_review do
        name "Quality Team Review"
        assignee role: "quality_inspector"
        
        form do
          field :quality_issue_confirmed, :boolean
          field :issue_severity, :enum, options: [:minor, :major, :critical]
          field :recommended_action, :enum, options: [:credit, :replacement, :reject]
          field :evidence, :attachments
        end
        
        output :quality_decision
      end
      
      end_event :quality_investigated
    end
    
    # Delivery investigation
    sub_process :investigate_delivery do
      name "Delivery Dispute Investigation"
      
      start_event :delivery_start
      
      service_task :get_shipping_records do
        name "Get Shipping Records"
        
        agent Logistics.Agents.ShippingAgent do
          action :get_delivery_proof
          params %{
            order_id: "{{dispute_data.order_id}}",
            tracking_numbers: "{{dispute_data.tracking_numbers}}"
          }
        end
        
        output :shipping_records
      end
      
      service_task :verify_delivery do
        name "Verify Delivery Status"
        
        agent AccountsReceivables.Agents.DeliveryVerificationAgent do
          action :verify_delivery_claim
          params %{
            shipping_records: "{{shipping_records}}",
            customer_claim: "{{dispute_data.delivery_claim}}"
          }
        end
        
        output :delivery_verification
      end
      
      end_event :delivery_investigated
    end
    
    # Billing error investigation
    service_task :investigate_billing do
      name "Investigate Billing Error"
      
      agent AccountsReceivables.Agents.BillingAuditAgent do
        action :audit_invoice
        params %{
          invoice_id: "{{dispute_data.invoice_id}}",
          claimed_errors: "{{dispute_data.billing_errors}}"
        }
      end
      
      output :billing_audit
    end
    
    # General investigation
    user_task :general_investigation do
      name "General Dispute Investigation"
      assignee role: "dispute_specialist"
      
      form do
        field :investigation_findings, :text
        field :supporting_documents, :attachments
        field :recommended_resolution, :text
        field :adjustment_amount, :decimal
      end
      
      sla "P2D"
      
      output :investigation_result
    end
    
    # Consolidate investigation results
    service_task :consolidate_findings do
      name "Consolidate Investigation"
      
      agent AccountsReceivables.Agents.DisputeAgent do
        action :consolidate_investigation
        params %{
          dispute_id: "{{dispute_record.id}}",
          investigation_results: "{{investigation_outputs}}"
        }
      end
      
      output :consolidated_findings
    end
    
    # AI resolution recommendation
    service_task :ai_resolution do
      name "AI Resolution Recommendation"
      
      agent AccountsReceivables.Agents.AIDisputeAgent do
        action :recommend_resolution
        params %{
          dispute: "{{dispute_record}}",
          findings: "{{consolidated_findings}}",
          customer_history: "{{dispute_data.customer_history}}",
          similar_disputes: "{{dispute_data.similar_cases}}"
        }
        
        ai_enabled true
        model "dispute-resolution-v2"
      end
      
      output :ai_recommendation
    end
    
    # Resolution decision
    exclusive_gateway :resolution_decision do
      name "Resolution Decision"
      
      flow :auto_approve do
        condition "{{ai_recommendation.confidence}} >= 0.95 && {{ai_recommendation.adjustment}} <= {{dispute_category.auto_approval_limit}}"
        target :implement_resolution
      end
      
      flow :manager_approval do
        condition "{{ai_recommendation.adjustment}} > {{dispute_category.auto_approval_limit}}"
        target :manager_review
      end
      
      default :implement_resolution
    end
    
    # Manager review
    user_task :manager_review do
      name "Manager Approval"
      assignee role: "ar_manager"
      
      form do
        field :approve, :boolean
        field :approved_adjustment, :decimal
        field :resolution_notes, :text
      end
      
      escalation do
        after "PT4H"
        to role: "finance_director"
      end
      
      output :manager_decision
    end
    
    # Implement resolution
    sub_process :implement_resolution do
      name "Implement Resolution"
      
      start_event :resolution_start
      
      exclusive_gateway :resolution_type do
        flow :credit_note do
          condition "{{resolution.type}} == 'credit'"
          target :issue_credit_note
        end
        
        flow :invoice_adjustment do
          condition "{{resolution.type}} == 'adjustment'"
          target :adjust_invoice
        end
        
        flow :reject_dispute do
          condition "{{resolution.type}} == 'reject'"
          target :reject_dispute_task
        end
      end
      
      service_task :issue_credit_note do
        name "Issue Credit Note"
        
        agent AccountsReceivables.Agents.CreditNoteAgent do
          action :create_credit_note
          params %{
            invoice_id: "{{dispute_data.invoice_id}}",
            amount: "{{resolution.credit_amount}}",
            reason: "{{resolution.reason}}",
            dispute_id: "{{dispute_record.id}}"
          }
        end
        
        output :credit_note
      end
      
      service_task :adjust_invoice do
        name "Adjust Invoice"
        
        agent AccountsReceivables.Agents.InvoiceAgent do
          action :adjust_invoice
          params %{
            invoice_id: "{{dispute_data.invoice_id}}",
            adjustments: "{{resolution.adjustments}}",
            dispute_id: "{{dispute_record.id}}"
          }
        end
        
        output :adjusted_invoice
      end
      
      service_task :reject_dispute_task do
        name "Reject Dispute"
        
        agent AccountsReceivables.Agents.DisputeAgent do
          action :reject_dispute
          params %{
            dispute_id: "{{dispute_record.id}}",
            rejection_reason: "{{resolution.rejection_reason}}",
            supporting_evidence: "{{consolidated_findings}}"
          }
        end
      end
      
      end_event :resolution_implemented
    end
    
    # Release invoice hold
    service_task :release_hold do
      name "Release Invoice Hold"
      
      agent AccountsReceivables.Agents.InvoiceAgent do
        action :release_hold
        params %{
          invoice_id: "{{dispute_data.invoice_id}}",
          dispute_id: "{{dispute_record.id}}"
        }
      end
    end
    
    # Update dispute record
    service_task :close_dispute do
      name "Close Dispute"
      
      agent AccountsReceivables.Agents.DisputeAgent do
        action :close_dispute
        params %{
          dispute_id: "{{dispute_record.id}}",
          resolution: "{{resolution}}",
          closed_by: "{{process_instance_id}}"
        }
      end
    end
    
    # Notify customer
    send_task :notify_customer do
      name "Notify Customer of Resolution"
      
      signal do
        type "dispute.resolved"
        source "/accounts_receivables/dispute_resolution"
        data %{
          dispute_id: "{{dispute_record.id}}",
          invoice_id: "{{dispute_data.invoice_id}}",
          resolution: "{{resolution}}",
          credit_note: "{{credit_note.number}}"
        }
        
        dispatch do
          email to: "{{dispute_data.customer_email}}"
          pubsub topic: "dispute_resolutions"
        end
      end
    end
    
    end_event :dispute_resolved
  end
end

defmodule AccountsReceivables.BPMN.MonthEndClose do
  use AccountsReceivables.BPMN.ProcessBase,
    name: "month_end_close",
    version: "1.0.0"
  
  use Jido.BPMN
  
  process "month_end_close" do
    @doc """
    Month-end closing process for Accounts Receivables
    """
    
    start_event :month_end_trigger do
      timer_event do
        time_cycle "R/P1M/01T00:00:00"  # First day of each month at midnight
      end
      
      output :close_context
    end
    
    # Initialize close process
    service_task :initialize_close do
      name "Initialize Month-End Close"
      
      agent AccountsReceivables.Agents.CloseAgent do
        action :initialize_period_close
        params %{
          period: "{{close_context.period}}",
          cutoff_date: "{{close_context.cutoff_date}}"
        }
      end
      
      output :close_params
    end
    
    # Parallel processing of close tasks
    parallel_gateway :close_tasks_start do
      name "Start Close Tasks"
      
      flow :validate_transactions
      flow :age_receivables
      flow :calculate_provisions
      flow :reconcile_subledger
      flow :generate_accruals
    end
    
    # Validate all transactions
    service_task :validate_transactions do
      name "Validate Period Transactions"
      
      agent AccountsReceivables.Agents.ValidationAgent do
        action :validate_period_transactions
        params %{
          period: "{{close_params.period}}",
          validation_rules: "{{close_params.validation_rules}}"
        }
      end
      
      boundary_event :validation_errors do
        error_ref "ValidationException"
        
        flow_to :handle_validation_errors
      end
      
      output :validation_results
    end
    
    # Age receivables
    service_task :age_receivables do
      name "Age Receivables"
      
      agent AccountsReceivables.Agents.AgingAgent do
        action :calculate_aging_buckets
        params %{
          as_of_date: "{{close_params.cutoff_date}}",
          aging_buckets: [30, 60, 90, 120, "120+"]
        }
      end
      
      output :aging_analysis
    end
    
    # Calculate bad debt provision
    service_task :calculate_provisions do
      name "Calculate Bad Debt Provision"
      
      agent AccountsReceivables.Agents.AIProvisionAgent do
        action :calculate_expected_credit_loss
        params %{
          aging_data: "{{aging_analysis}}",
          historical_loss_rates: "{{close_params.loss_history}}",
          economic_factors: "{{close_params.economic_indicators}}",
          customer_risk_profiles: "{{close_params.risk_profiles}}"
        }
        
        ai_enabled true
        model "ecl-model-v3"
      end
      
      output :provision_calculation
    end
    
    # Reconcile AR subledger to GL
    service_task :reconcile_subledger do
      name "Reconcile to General Ledger"
      
      agent AccountsReceivables.Agents.ReconciliationAgent do
        action :reconcile_ar_to_gl
        params %{
          period: "{{close_params.period}}",
          ar_balance: "{{close_params.ar_total}}",
          gl_accounts: "{{close_params.gl_mapping}}"
        }
      end
      
      output :reconciliation_result
    end
    
    # Generate accruals
    service_task :generate_accruals do
      name "Generate Accruals"
      
      agent AccountsReceivables.Agents.AccrualAgent do
        action :calculate_period_accruals
        params %{
          period: "{{close_params.period}}",
          unbilled_revenue: "{{close_params.unbilled_items}}",
          deferred_revenue: "{{close_params.deferred_items}}"
        }
      end
      
      output :accrual_entries
    end
    
    # Handle validation errors
    user_task :handle_validation_errors do
      name "Review Validation Errors"
      assignee role: "ar_supervisor"
      
      form do
        field :error_resolutions, :array
        field :override_approval, :boolean
        field :notes, :text
      end
      
      output :error_resolution
    end
    
    # Converge parallel tasks
    parallel_gateway :close_tasks_complete do
      converge true
    end
    
    # Review provisions
    exclusive_gateway :provision_review do
      name "Provision Review Required?"
      
      flow :auto_approve do
        condition "{{provision_calculation.variance}} <= 0.05"
        target :post_adjustments
      end
      
      flow :manual_review do
        condition "{{provision_calculation.variance}} > 0.05"
        target :review_provisions
      end
    end
    
    # Manual provision review
    user_task :review_provisions do
      name "Review Bad Debt Provisions"
      assignee role: "controller"
      
      form do
        field :approved_provision, :decimal
        field :adjustment_reason, :text
        field :supporting_analysis, :attachment
      end
      
      sla "PT4H"
      
      output :provision_approval
    end
    
    # Post adjusting entries
    service_task :post_adjustments do
      name "Post Adjusting Entries"
      
      agent GeneralLedger.Agents.JournalAgent do
        action :post_journal_entries
        params %{
          entries: [
            "{{provision_calculation.journal_entry}}",
            "{{accrual_entries}}",
            "{{reconciliation_result.adjustments}}"
          ],
          period: "{{close_params.period}}",
          source: "ar_month_end"
        }
      end
      
      output :posted_entries
    end
    
    # Calculate KPIs
    service_task :calculate_kpis do
      name "Calculate AR KPIs"
      
      agent AccountsReceivables.Agents.KPIAgent do
        action :calculate_period_metrics
        params %{
          period: "{{close_params.period}}",
          metrics: [
            "days_sales_outstanding",
            "collection_effectiveness_index", 
            "average_days_delinquent",
            "bad_debt_ratio",
            "invoice_accuracy_rate"
          ]
        }
      end
      
      output :kpi_results
    end
    
    # Generate reports
    parallel_gateway :report_generation_start do
      name "Generate Reports"
      
      flow :aging_report
      flow :reconciliation_report
      flow :kpi_dashboard
      flow :exception_report
    end
    
    service_task :aging_report do
      name "Generate Aging Report"
      
      agent AccountsReceivables.Agents.ReportAgent do
        action :generate_aging_report
        params %{
          aging_data: "{{aging_analysis}}",
          period: "{{close_params.period}}"
        }
      end
      
      output :aging_report_file
    end
    
    service_task :reconciliation_report do
      name "Generate Reconciliation Report"
      
      agent AccountsReceivables.Agents.ReportAgent do
        action :generate_reconciliation_report
        params %{
          reconciliation: "{{reconciliation_result}}",
          adjustments: "{{posted_entries}}"
        }
      end
      
      output :recon_report_file
    end
    
    service_task :kpi_dashboard do
      name "Generate KPI Dashboard"
      
      agent AccountsReceivables.Agents.DashboardAgent do
        action :generate_executive_dashboard
        params %{
          kpis: "{{kpi_results}}",
          trends: "{{close_params.historical_trends}}",
          projections: "{{close_params.forecasts}}"
        }
      end
      
      output :dashboard_file
    end
    
    service_task :exception_report do
      name "Generate Exception Report"
      
      agent AccountsReceivables.Agents.ReportAgent do
        action :generate_exception_report
        params %{
          validation_errors: "{{validation_results.errors}}",
          reconciliation_breaks: "{{reconciliation_result.breaks}}",
          high_risk_accounts: "{{aging_analysis.high_risk}}"
        }
      end
      
      output :exception_report_file
    end
    
    parallel_gateway :report_generation_complete do
      converge true
    end
    
    # Final review and sign-off
    user_task :close_review do
      name "Month-End Close Review"
      assignee role: "cfo"
      
      form do
        field :review_status, :enum, options: [:approved, :rejected, :conditional]
        field :comments, :text
        field :sign_off, :boolean
      end
      
      sla "P1D"
      
      output :close_approval
    end
    
    # Lock period
    service_task :lock_period do
      name "Lock Accounting Period"
      condition "{{close_approval.sign_off}} == true"
      
      agent AccountsReceivables.Agents.PeriodAgent do
        action :lock_period
        params %{
          period: "{{close_params.period}}",
          locked_by: "{{close_approval.approver}}",
          locked_at: "{{close_approval.timestamp}}"
        }
      end
    end
    
    # Distribute reports
    send_task :distribute_reports do
      name "Distribute Close Reports"
      
      signal do
        type "month_end.complete"
        source "/accounts_receivables/month_end_close"
        data %{
          period: "{{close_params.period}}",
          reports: [
            "{{aging_report_file}}",
            "{{recon_report_file}}",
            "{{dashboard_file}}",
            "{{exception_report_file}}"
          ],
          kpis: "{{kpi_results}}"
        }
        
        dispatch do
          email to: "{{close_params.distribution_list}}"
          pubsub topic: "month_end_complete"
          storage path: "/reports/ar/{{close_params.period}}"
        end
      end
    end
    
    end_event :close_complete do
      name "Month-End Close Complete"
    end
  end
end
