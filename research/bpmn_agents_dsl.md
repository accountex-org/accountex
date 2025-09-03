# BPMN DSL Extension for Jido Using Spark Framework

## Executive Summary

This design provides a comprehensive BPMN (Business Process Model and Notation) Domain-Specific Language for Jido, built on the Spark DSL framework. It enables developers to declare business processes as code, which then compile into executable Jido agents, actions, and workflows.

## 1. Architecture Overview

### Core Design Principles

The BPMN DSL leverages Spark's powerful DSL building capabilities to:
- **Declare** business processes using BPMN notation in Elixir code
- **Validate** process correctness at compile time
- **Generate** executable Jido agents, actions, and signals
- **Transform** BPMN elements into Jido concepts seamlessly

### Concept Mapping

| BPMN Element | Jido Concept | Implementation |
|--------------|--------------|----------------|
| Process | Agent | GenServer with state machine |
| Task | Action | Jido.Action module |
| User Task | Action + UI | Action with form integration |
| Service Task | Action | External service action |
| Gateway | Decision Logic | Pattern matching in agent |
| Event | Signal | Jido.Signal |
| Message Flow | Signal Dispatch | Signal routing |
| Data Object | Instruction | Jido.Instruction |
| Pool/Lane | Agent Group | Supervised agent pool |
| Subprocess | Workflow | Jido.Workflow |

## 2. Core DSL Module Structure

### Main DSL Extension

```elixir
defmodule Jido.BPMN.DSL do
  @moduledoc """
  BPMN DSL for declaring executable business processes in Jido.
  Built on Spark framework for compile-time validation and code generation.
  """
  
  use Spark.Dsl.Extension,
    sections: [
      process_section(),
      collaboration_section(),
      choreography_section(),
      data_section()
    ],
    transformers: [
      Jido.BPMN.Transformers.ValidateStructure,
      Jido.BPMN.Transformers.LinkElements,
      Jido.BPMN.Transformers.ValidateFlow,
      Jido.BPMN.Transformers.GenerateAgents,
      Jido.BPMN.Transformers.GenerateActions,
      Jido.BPMN.Transformers.GenerateSignals
    ],
    verifiers: [
      Jido.BPMN.Verifiers.CheckDeadlocks,
      Jido.BPMN.Verifiers.ValidateGateways,
      Jido.BPMN.Verifiers.EnsureCompensation
    ]

  defp process_section do
    %Spark.Dsl.Section{
      name: :process,
      describe: "Define a BPMN process",
      top_level?: true,
      schema: [
        id: [type: :atom, required: true, doc: "Unique process identifier"],
        name: [type: :string, required: true, doc: "Human-readable process name"],
        version: [type: :string, default: "1.0"],
        executable: [type: :boolean, default: true],
        monitoring: [type: :boolean, default: true]
      ],
      entities: [
        events_entities(),
        tasks_entities(),
        gateways_entities(),
        flows_entities(),
        data_entities()
      ]
    }
  end
end
```

### Entity Definitions

```elixir
defmodule Jido.BPMN.Entities do
  @moduledoc "BPMN element entity definitions for Spark DSL"
  
  def task_entity do
    %Spark.Dsl.Entity{
      name: :task,
      target: __MODULE__.Task,
      args: [:id, :name],
      describe: "A BPMN task that executes as a Jido action",
      schema: [
        id: [type: :atom, required: true],
        name: [type: :string, required: true],
        type: [type: {:in, [:service, :user, :script, :manual, :business_rule]}, 
               default: :service],
        jido_action: [type: {:behaviour, Jido.Action}, 
                      doc: "The Jido action module to execute"],
        inputs: [type: {:list, :atom}, default: []],
        outputs: [type: {:list, :atom}, default: []],
        retry: [type: :keyword_list, default: [max_attempts: 3]],
        timeout: [type: :pos_integer, default: 30_000],
        compensation: [type: {:behaviour, Jido.Action}]
      ],
      entities: [
        boundary_event_entity()
      ]
    }
  end

  def gateway_entity do
    %Spark.Dsl.Entity{
      name: :gateway,
      target: __MODULE__.Gateway,
      args: [:id, :type],
      schema: [
        id: [type: :atom, required: true],
        type: [type: {:in, [:exclusive, :parallel, :inclusive, :event_based]}],
        default_flow: [type: :atom]
      ],
      entities: [
        condition_entity()
      ]
    }
  end
  
  def event_entity do
    %Spark.Dsl.Entity{
      name: :event,
      target: __MODULE__.Event,
      args: [:id, :type],
      schema: [
        id: [type: :atom, required: true],
        type: [type: {:in, [:start, :end, :intermediate, :boundary]}],
        trigger: [type: {:in, [:none, :message, :timer, :error, :signal, :compensation]}],
        interrupting: [type: :boolean, default: true]
      ]
    }
  end
end
```

## 3. DSL Syntax Examples

### Basic Process Definition

```elixir
defmodule SimpleOrderProcess do
  use Jido.BPMN
  
  process id: :simple_order, name: "Simple Order Processing" do
    # Define process variables
    variables do
      order_id :string, required: true
      customer_id :string, required: true  
      total_amount :decimal
      status :string, default: "pending"
    end
    
    # Start event
    start_event :order_received
    
    # Tasks
    task :validate_order, "Validate Order" do
      jido_action OrderActions.Validate
      inputs [:order_id]
      outputs [:validation_result]
    end
    
    task :process_payment, "Process Payment" do
      jido_action PaymentActions.Charge
      inputs [:customer_id, :total_amount]
      outputs [:transaction_id]
      timeout 60_000
      retry max_attempts: 5, backoff: :exponential
    end
    
    task :fulfill_order, "Fulfill Order" do
      jido_action FulfillmentActions.Ship
      inputs [:order_id]
      outputs [:tracking_number]
    end
    
    # End event
    end_event :order_completed
    
    # Define the flow
    flow do
      :order_received --> :validate_order
      :validate_order --> :process_payment
      :process_payment --> :fulfill_order
      :fulfill_order --> :order_completed
    end
  end
end
```

### Advanced Process with Gateways and Error Handling

```elixir
defmodule AdvancedLoanProcess do
  use Jido.BPMN
  
  process id: :loan_approval, name: "Loan Approval Process" do
    
    start_event :application_received do
      message "loan_application"
    end
    
    # Parallel processing
    parallel_gateway :start_checks
    
    task :credit_check, "Check Credit Score" do
      jido_action CreditActions.CheckScore
      
      # Boundary event for timeout
      boundary_timer :credit_timeout do
        duration "PT10M"  # 10 minutes
        interrupting true
        flows_to :manual_credit_review
      end
    end
    
    task :fraud_check, "Fraud Detection" do
      jido_action FraudActions.Analyze
    end
    
    task :income_verification, "Verify Income" do
      jido_action IncomeActions.Verify
    end
    
    parallel_gateway :complete_checks
    
    # Decision gateway
    exclusive_gateway :approval_decision do
      condition :approve, expr: "credit_score > 700 && fraud_risk < 0.3"
      condition :reject, expr: "credit_score < 500 || fraud_risk > 0.7"
      default :manual_review
    end
    
    # User task for manual review
    user_task :manual_review, "Manual Review Required" do
      assignee role: "loan_officer"
      form "loan_review_form"
      due_date "P2D"  # 2 days
    end
    
    # Subprocess for approval
    subprocess :approval_process, transaction: true do
      task :generate_contract do
        jido_action ContractActions.Generate
        compensation ContractActions.Void
      end
      
      task :setup_account do
        jido_action AccountActions.Create
        compensation AccountActions.Delete
      end
      
      # Error boundary event
      boundary_error :processing_error do
        error_code "PROCESSING_FAILED"
        flows_to :compensation_handler
      end
    end
    
    # Compensation handler
    compensation_event :compensation_handler do
      triggers_compensation_for :approval_process
    end
    
    end_event :application_approved
    end_event :application_rejected
    
    # Define complex flows
    flow do
      :application_received --> :start_checks
      :start_checks --> [:credit_check, :fraud_check, :income_verification]
      [:credit_check, :fraud_check, :income_verification] --> :complete_checks
      :complete_checks --> :approval_decision
      
      :approval_decision --> :approval_process, when: :approve
      :approval_decision --> :application_rejected, when: :reject
      :approval_decision --> :manual_review, when: :default
      
      :manual_review --> :approval_decision
      :approval_process --> :application_approved
      :compensation_handler --> :application_rejected
    end
  end
end
```

### Collaboration Between Multiple Participants

```elixir
defmodule B2BProcurement do
  use Jido.BPMN
  
  collaboration id: :b2b_procurement do
    
    participant :buyer, "Buyer Organization" do
      agent_pool size: 5, supervisor: :one_for_one
      
      lane :procurement, "Procurement Dept" do
        task :create_purchase_order
        task :approve_order
      end
      
      lane :finance, "Finance Dept" do
        task :process_invoice
        task :make_payment
      end
    end
    
    participant :supplier, "Supplier Organization" do
      agent_pool size: 3
      
      lane :sales do
        task :receive_order
        task :confirm_availability
      end
      
      lane :shipping do
        task :prepare_shipment
        task :dispatch_goods
      end
    end
    
    # Message flows between participants
    message_flow do
      from :buyer, :create_purchase_order
      to :supplier, :receive_order
      message "purchase_order"
      correlation [:order_id, :buyer_id]
    end
    
    message_flow do
      from :supplier, :confirm_availability
      to :buyer, :approve_order
      message "order_confirmation"
    end
    
    message_flow do
      from :supplier, :dispatch_goods
      to :buyer, :process_invoice
      message "shipment_notice"
    end
  end
end
```

### Event-Driven Process

```elixir
defmodule EventDrivenMonitoring do
  use Jido.BPMN
  
  process id: :system_monitoring do
    
    # Multiple start events
    start_event :high_cpu_detected do
      signal "monitoring.cpu.high"
    end
    
    start_event :memory_alert do
      signal "monitoring.memory.critical"  
    end
    
    start_event :scheduled_check do
      timer cycle: "*/5 * * * *"  # Every 5 minutes
    end
    
    # Event-based gateway
    event_gateway :wait_for_events do
      intermediate_event :cpu_normal do
        signal "monitoring.cpu.normal"
        timeout "PT10M"
        flows_to :log_recovery
      end
      
      intermediate_event :escalation_timeout do
        timer duration: "PT5M"
        flows_to :escalate_to_ops
      end
      
      intermediate_event :manual_intervention do
        message "ops.manual.override"
        flows_to :apply_manual_fix
      end
    end
    
    # Escalation subprocess
    subprocess :escalation_handler, event: true do
      start_event :escalation_timer do
        timer duration: "PT30M"
        interrupting false
      end
      
      task :notify_manager do
        jido_action NotificationActions.AlertManager
      end
      
      task :create_incident do
        jido_action IncidentActions.Create
        outputs [:incident_id]
      end
    end
  end
end
```

## 4. Transformer Implementation

### Process to Agent Transformer

```elixir
defmodule Jido.BPMN.Transformers.GenerateAgents do
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  
  @impl true
  def transform(dsl_state) do
    process = get_process_definition(dsl_state)
    
    agent_module = generate_agent_module(process)
    action_modules = generate_action_modules(process)
    signal_handlers = generate_signal_handlers(process)
    
    dsl_state
    |> Transformer.eval(agent_module)
    |> Transformer.eval(action_modules)
    |> Transformer.eval(signal_handlers)
    |> persist_metadata(process)
    |> validate_generated_code()
    |> then(&{:ok, &1})
  end
  
  defp generate_agent_module(process) do
    quote do
      defmodule unquote(agent_name(process)) do
        use Jido.Agent,
          name: unquote(process.id),
          description: unquote(process.name)
        
        # State schema from process variables
        unquote(generate_schema(process.variables))
        
        # Process lifecycle states
        @states [:ready, :running, :waiting, :suspended, :completed, :failed]
        @initial_state :ready
        
        # Token-based execution
        defstruct [
          :process_id,
          :instance_id,
          :state,
          :tokens,
          :variables,
          :correlation_keys,
          :active_tasks,
          :event_subscriptions
        ]
        
        # Start process instance
        def handle_instruction({:start, init_data}, state) do
          instance = %{
            instance_id: Uniq.UUID.uuid4(),
            state: :running,
            tokens: [create_start_token()],
            variables: Map.merge(state.variables, init_data)
          }
          
          execute_element(unquote(process.start_event), instance)
        end
        
        # Task completion
        def handle_instruction({:complete_task, task_id, result}, state) do
          case Map.get(state.active_tasks, task_id) do
            nil -> 
              {:error, :task_not_found}
            task ->
              state
              |> complete_task(task, result)
              |> move_tokens(task_id)
              |> continue_execution()
          end
        end
        
        # Generate task executors
        unquote_splicing(generate_task_executors(process.tasks))
        
        # Generate gateway evaluators
        unquote_splicing(generate_gateway_evaluators(process.gateways))
        
        # Generate event handlers
        unquote_splicing(generate_event_handlers(process.events))
      end
    end
  end
  
  defp generate_task_executors(tasks) do
    Enum.map(tasks, fn task ->
      quote do
        defp execute_task(unquote(task.id), variables, context) do
          action = unquote(task.jido_action)
          inputs = prepare_inputs(variables, unquote(task.inputs))
          
          case action.run(inputs, context) do
            {:ok, result} ->
              variables = merge_outputs(variables, result, unquote(task.outputs))
              {:ok, variables}
              
            {:error, reason} when unquote(task.compensation) != nil ->
              # Trigger compensation
              unquote(task.compensation).run(inputs, context)
              {:compensated, reason}
              
            error ->
              error
          end
        end
      end
    end)
  end
end
```

### Flow Validator Transformer

```elixir
defmodule Jido.BPMN.Transformers.ValidateFlow do
  use Spark.Dsl.Transformer
  
  @impl true
  def after?(Jido.BPMN.Transformers.LinkElements), do: true
  
  @impl true
  def transform(dsl_state) do
    with :ok <- validate_connectivity(dsl_state),
         :ok <- validate_gateway_rules(dsl_state),
         :ok <- validate_event_flows(dsl_state),
         :ok <- validate_data_flow(dsl_state) do
      {:ok, dsl_state}
    else
      {:error, reason} ->
        {:error, Spark.Error.DslError.exception(
          message: reason,
          path: [:process]
        )}
    end
  end
  
  defp validate_connectivity(dsl_state) do
    # Build process graph
    graph = build_process_graph(dsl_state)
    
    # Check all nodes are reachable from start
    start_nodes = get_start_events(dsl_state)
    unreachable = find_unreachable_nodes(graph, start_nodes)
    
    if Enum.empty?(unreachable) do
      :ok
    else
      {:error, "Unreachable elements: #{inspect(unreachable)}"}
    end
  end
  
  defp validate_gateway_rules(dsl_state) do
    gateways = Transformer.get_entities(dsl_state, [:process, :gateways])
    
    Enum.reduce_while(gateways, :ok, fn gateway, _ ->
      case validate_gateway(gateway) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
  
  defp validate_gateway(gateway) do
    case gateway.type do
      :exclusive ->
        # Must have conditions for all non-default flows
        validate_exclusive_conditions(gateway)
        
      :parallel ->
        # Must have matching split/join pairs
        validate_parallel_balance(gateway)
        
      :inclusive ->
        # Must have at least one valid path
        validate_inclusive_paths(gateway)
        
      :event_based ->
        # Must have only event-type outgoing flows
        validate_event_gateway(gateway)
    end
  end
end
```

## 5. Verifier Implementation

### Deadlock Detection Verifier

```elixir
defmodule Jido.BPMN.Verifiers.CheckDeadlocks do
  use Spark.Dsl.Verifier
  
  @impl true
  def verify(dsl_state) do
    graph = build_process_graph(dsl_state)
    
    deadlock_patterns = [
      check_unmatched_parallels(graph),
      check_exclusive_loops(graph),
      check_event_starvation(graph),
      check_token_traps(graph)
    ]
    |> List.flatten()
    
    case deadlock_patterns do
      [] -> :ok
      patterns ->
        {:error, format_deadlock_error(patterns)}
    end
  end
  
  defp check_unmatched_parallels(graph) do
    splits = get_parallel_splits(graph)
    joins = get_parallel_joins(graph)
    
    unmatched = MapSet.difference(
      MapSet.new(splits),
      MapSet.new(joins)
    )
    
    if MapSet.size(unmatched) > 0 do
      [{:unmatched_parallel, MapSet.to_list(unmatched)}]
    else
      []
    end
  end
  
  defp check_exclusive_loops(graph) do
    # Detect loops without exit conditions
    cycles = Graph.find_cycles(graph)
    
    cycles
    |> Enum.filter(&has_no_exit_condition?/1)
    |> Enum.map(&{:infinite_loop, &1})
  end
end
```

### Compensation Verifier

```elixir
defmodule Jido.BPMN.Verifiers.EnsureCompensation do
  use Spark.Dsl.Verifier
  
  @impl true
  def verify(dsl_state) do
    transactions = get_transaction_subprocesses(dsl_state)
    
    Enum.reduce_while(transactions, :ok, fn transaction, _ ->
      case verify_transaction_compensation(transaction) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
  
  defp verify_transaction_compensation(transaction) do
    compensatable_tasks = get_compensatable_tasks(transaction)
    compensation_handlers = get_compensation_handlers(transaction)
    
    missing = compensatable_tasks -- compensation_handlers
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing compensation for: #{inspect(missing)}"}
    end
  end
end
```

## 6. Code Generation

### Action Generator

```elixir
defmodule Jido.BPMN.CodeGen.ActionGenerator do
  @moduledoc "Generates Jido actions from BPMN tasks"
  
  def generate(task) do
    quote do
      defmodule unquote(action_module(task)) do
        use Jido.Action,
          name: unquote(task.id),
          description: unquote(task.name)
        
        schema unquote(generate_schema(task))
        
        @impl true
        def run(params, context) do
          # Map BPMN inputs to action parameters
          inputs = unquote(map_inputs(task.inputs))
          
          # Execute the actual action
          result = unquote(task.jido_action).run(inputs, context)
          
          # Map outputs back to BPMN variables
          case result do
            {:ok, data} ->
              outputs = unquote(map_outputs(task.outputs))
              {:ok, Map.take(data, outputs)}
            error ->
              error
          end
        end
        
        # Compensation support
        if unquote(task.compensation) do
          def compensate(original_params, context) do
            unquote(task.compensation).run(original_params, context)
          end
        end
        
        # Multi-instance support
        if unquote(task.multi_instance) do
          def run_multi(collection, params, context) do
            unquote(generate_multi_instance(task.multi_instance))
          end
        end
      end
    end
  end
end
```

### Signal Generator

```elixir
defmodule Jido.BPMN.CodeGen.SignalGenerator do
  @moduledoc "Generates Jido signals from BPMN message flows"
  
  def generate(message_flow) do
    quote do
      defmodule unquote(signal_module(message_flow)) do
        @behaviour Jido.Signal.Producer
        
        def produce(data, metadata \\ %{}) do
          Jido.Signal.new(%{
            type: unquote(message_type(message_flow)),
            source: unquote(message_flow.from),
            subject: unquote(message_flow.to),
            data: data,
            metadata: Map.merge(metadata, %{
              correlation: unquote(message_flow.correlation),
              flow_id: unquote(message_flow.id)
            })
          })
        end
        
        def route(signal) do
          [unquote_splicing(generate_routes(message_flow))]
        end
      end
    end
  end
end
```

## 7. Runtime Execution Engine

### Process Engine

```elixir
defmodule Jido.BPMN.Engine do
  @moduledoc "BPMN process execution engine"
  
  use GenServer
  
  def start_process(process_module, initial_data \\ %{}) do
    with {:ok, metadata} <- process_module.__bpmn_metadata__(),
         {:ok, agent} <- start_process_agent(process_module),
         {:ok, instance_id} <- create_instance(metadata, initial_data) do
      
      # Send start instruction
      Jido.Agent.instruction(agent, {:start, initial_data})
      
      {:ok, instance_id}
    end
  end
  
  def get_active_tasks(instance_id) do
    GenServer.call(__MODULE__, {:get_tasks, instance_id})
  end
  
  def complete_task(instance_id, task_id, result) do
    GenServer.call(__MODULE__, {:complete_task, instance_id, task_id, result})
  end
  
  def suspend_process(instance_id) do
    GenServer.cast(__MODULE__, {:suspend, instance_id})
  end
  
  def resume_process(instance_id) do
    GenServer.cast(__MODULE__, {:resume, instance_id})
  end
end
```

### Token-Based Execution

```elixir
defmodule Jido.BPMN.Token do
  @moduledoc "BPMN token for process flow execution"
  
  defstruct [
    :id,
    :location,
    :variables,
    :path,
    :created_at,
    :parent_token
  ]
  
  def create(location, variables \\ %{}) do
    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      location: location,
      variables: variables,
      path: [location],
      created_at: DateTime.utc_now()
    }
  end
  
  def move(token, new_location) do
    %{token | 
      location: new_location,
      path: [new_location | token.path]
    }
  end
  
  def split(token, locations) do
    Enum.map(locations, fn location ->
      %{token | 
        id: Uniq.UUID.uuid4(),
        location: location,
        parent_token: token.id
      }
    end)
  end
  
  def join(tokens, join_location) do
    # Merge variables from all tokens
    variables = Enum.reduce(tokens, %{}, fn token, acc ->
      Map.merge(acc, token.variables)
    end)
    
    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      location: join_location,
      variables: variables,
      path: [join_location],
      created_at: DateTime.utc_now()
    }
  end
end
```

## 8. Extension Points

### Custom Task Types

```elixir
defmodule Jido.BPMN.Extensions.AITask do
  @moduledoc "AI/ML-powered task extension"
  
  use Spark.Dsl.Extension
  
  dsl do
    @ai_task %Spark.Dsl.Entity{
      name: :ai_task,
      args: [:id, :name],
      schema: [
        model: [type: :string, required: true],
        prompt_template: [type: :string],
        confidence_threshold: [type: :float, default: 0.8],
        fallback_action: [type: {:behaviour, Jido.Action}]
      ]
    }
  end
  
  transformers do
    quote do
      def transform_ai_task(task) do
        # Generate Jido.AI.Agent integration
        quote do
          def execute_ai_task(unquote(task.id), inputs) do
            Jido.AI.Agent.query(
              unquote(task.model),
              unquote(task.prompt_template),
              inputs
            )
          end
        end
      end
    end
  end
end
```

### Custom Gateways

```elixir
defmodule Jido.BPMN.Extensions.MLGateway do
  @moduledoc "Machine learning based routing gateway"
  
  defstruct [:id, :model, :features, :routes]
  
  def evaluate(%__MODULE__{} = gateway, context) do
    features = extract_features(context, gateway.features)
    
    prediction = MLService.predict(gateway.model, features)
    
    route = Map.get(gateway.routes, prediction.class, :default)
    
    {:ok, route}
  end
end
```

## 9. Integration with Existing Jido Libraries

### Using Jido Actions

```elixir
defmodule IntegratedProcess do
  use Jido.BPMN
  
  # Import existing Jido actions
  alias MyApp.Actions.{ValidateData, ProcessPayment, SendNotification}
  alias MyApp.Agents.DataProcessor
  
  process id: :integrated_flow do
    # Directly use existing Jido actions
    task :validate, "Validate Input" do
      jido_action ValidateData
    end
    
    # Delegate to existing agents
    task :process_data, "Process Data" do
      delegate_to DataProcessor
      method :process
    end
    
    # Use Jido.AI actions
    ai_task :analyze, "AI Analysis" do
      jido_action Jido.AI.Actions.Instructor
      model "gpt-4"
      response_schema AnalysisResult
    end
  end
end
```

### Signal Integration

```elixir
defmodule SignalIntegratedProcess do
  use Jido.BPMN
  
  process id: :signal_aware do
    # Listen for Jido signals
    start_event :signal_received do
      signal "jido.agent.started"
      correlation [:agent_id]
    end
    
    # Emit Jido signals
    intermediate_event :emit_status do
      type :throw
      signal "process.milestone.reached"
      data fn state -> %{
        process: state.process_id,
        milestone: "validation_complete"
      } end
    end
    
    # Subscribe to PubSub topics
    receive_task :await_confirmation do
      message_subscription topic: "confirmations"
      timeout 30_000
    end
  end
end
```

## 10. Deployment and Monitoring

### Process Deployment

```elixir
defmodule Jido.BPMN.Deployer do
  def deploy(process_module, opts \\ []) do
    with {:ok, compiled} <- compile_process(process_module),
         {:ok, validated} <- validate_deployment(compiled),
         {:ok, _supervisor} <- start_process_supervisor(compiled, opts) do
      
      # Register in process registry
      Jido.BPMN.Registry.register(process_module)
      
      # Setup monitoring
      setup_telemetry(process_module)
      
      {:ok, process_module}
    end
  end
  
  defp setup_telemetry(process_module) do
    events = [
      [:jido_bpmn, :process, :started],
      [:jido_bpmn, :task, :completed],
      [:jido_bpmn, :gateway, :evaluated],
      [:jido_bpmn, :token, :moved]
    ]
    
    :telemetry.attach_many(
      "#{process_module}-metrics",
      events,
      &Jido.BPMN.Telemetry.handle_event/4,
      %{process: process_module}
    )
  end
end
```

## Complete Usage Example

```elixir
# Define the process
defmodule InvoiceApprovalProcess do
  use Jido.BPMN
  
  process id: :invoice_approval, name: "Invoice Approval Workflow" do
    variables do
      invoice_id :string
      amount :decimal
      vendor_id :string
      approval_level :integer
    end
    
    start_event :invoice_received
    
    task :validate_invoice do
      jido_action InvoiceActions.Validate
      boundary_error :validation_error do
        flows_to :handle_invalid
      end
    end
    
    exclusive_gateway :check_amount do
      condition :small, expr: "amount < 1000"
      condition :medium, expr: "amount < 10000"
      default :large
    end
    
    task :auto_approve do
      jido_action InvoiceActions.AutoApprove
    end
    
    user_task :manager_approval do
      assignee "manager"
      due_date "P1D"
    end
    
    user_task :director_approval do
      assignee "director"
      due_date "P2D"
    end
    
    task :process_payment do
      jido_action PaymentActions.Process
      compensation PaymentActions.Reverse
    end
    
    end_event :invoice_processed
    
    flow do
      :invoice_received --> :validate_invoice
      :validate_invoice --> :check_amount
      :check_amount --> :auto_approve, when: :small
      :check_amount --> :manager_approval, when: :medium
      :check_amount --> :director_approval, when: :large
      [:auto_approve, :manager_approval, :director_approval] --> :process_payment
      :process_payment --> :invoice_processed
    end
  end
end

# Deploy the process
{:ok, _} = Jido.BPMN.Deployer.deploy(InvoiceApprovalProcess)

# Start an instance
{:ok, instance} = Jido.BPMN.Engine.start_process(
  InvoiceApprovalProcess,
  %{
    invoice_id: "INV-2024-001",
    amount: Decimal.new("5000.00"),
    vendor_id: "VENDOR-123"
  }
)

# Query active tasks
{:ok, tasks} = Jido.BPMN.Engine.get_active_tasks(instance)

# Complete a user task
Jido.BPMN.Engine.complete_task(
  instance,
  :manager_approval,
  %{approved: true, notes: "Approved for payment"}
)
```

This comprehensive design provides everything needed to implement a production-ready BPMN DSL for Jido using the Spark framework, enabling developers to declare business processes that compile into executable Jido agents and workflows.
