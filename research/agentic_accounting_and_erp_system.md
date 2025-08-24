# Agentic accounting and ERP system architecture with Elixir, Ash, and Commanded

## Research synthesis and architectural guidance

This comprehensive research report provides architectural guidance and implementation patterns for building an agentic accounting and ERP system focused on inventory management, using Elixir's Commanded event-sourcing, Ash framework, Jido library, and a modular applications architecture where components may be dynamically available at runtime.

## Academic foundations for agent-based inventory management

Recent academic research demonstrates significant advances in applying intelligent agents to business processes, particularly in inventory management and supply chain optimization. The **InvAgent** system (2024) represents a breakthrough in applying Large Language Models to multi-agent inventory management, achieving competitive performance against traditional reinforcement learning approaches while providing superior explainability through chain-of-thought reasoning. This zero-shot learning capability enables adaptive decision-making without prior training, making it particularly suitable for dynamic inventory scenarios.

Multi-Agent Reinforcement Learning (MARL) implementations have shown **30-40% efficiency gains** in AI-enabled manufacturing facilities, with **41% improvement in forecasting accuracy** when using LLM assistants. Organizations investing heavily in AI agent systems report an average **61% revenue growth premium** and **$37M savings** from faster supply chain disruption response. The research identifies four dominant multi-agent coordination mechanisms: Independent Action Learners (IALs), Joint Action Learners (JALs), communication-based approaches, and parameter sharing techniques, each offering different trade-offs between autonomy and coordination.

## Hybrid agent architectures combining deterministic and AI approaches

The optimal architecture for business-critical systems combines rule-based engines for predictable, auditable decisions with LLM-based agents for handling ambiguous, context-rich scenarios. The **MRKL (Modular Reasoning, Knowledge and Language)** architecture exemplifies this approach, where a general-purpose LLM acts as a router to direct inquiries to specialized expert modules that can be either neural (deep learning models) or symbolic (rule engines, calculators, databases).

Five key integration patterns emerge for hybrid systems. First, **Natural Language Understanding → Rule Reasoning** where LLMs extract structured data from natural language for rule engine processing. Second, **Rule Reasoning → Natural Language Generation** where rule engines make decisions and LLMs generate explanations. Third, **Rule-Driven NLP Processing** where rule engines act as masters calling LLMs on demand. Fourth, **LLM Rule Extraction** where LLMs extract business rules from policy documents for deployment to traditional engines. Fifth, **Chatbot with Rule-Based Decisions** where LLMs drive conversational experiences while rule engines handle business logic.

IBM's ODM + LLM integration for HR benefits calculation demonstrates the power of this approach, achieving **100% accuracy** compared to 70% for LLM-only solutions. The key is using rule-based components for compliance-critical operations (invoice approval under €500, regulatory calculations) while leveraging AI for tasks requiring natural language understanding, flexible decision-making, and creative problem-solving.

## Elixir implementation patterns with Commanded, Ash, and Jido

### Event-sourced agent integration with Commanded

Agents integrate with Commanded's CQRS/ES architecture through several key patterns. Agents can act as **event handlers** that subscribe to domain event streams and react autonomously:

```elixir
defmodule MyApp.EventHandlers.AgentOrchestrator do
  use Commanded.EventHandler,
    application: MyApp.Application,
    name: "agent_orchestrator"

  def handle(%OrderPlaced{} = event, _metadata) do
    {:ok, agent} = MyApp.OrderProcessingAgent.start_link(
      order_id: event.order_id,
      customer_id: event.customer_id
    )
    
    MyApp.OrderProcessingAgent.cmd(agent, [
      %Jido.Instruction{
        action: "validate_order",
        params: %{order_data: event.order_data}
      }
    ])
    
    :ok
  end
end
```

Agents can also function as **process managers** maintaining workflow state across multiple aggregates, or as **command handlers** that validate and execute business logic before emitting domain events. The pattern of agents as event-sourced aggregates themselves enables full auditability, where agent decision-making state and learning history persist as event streams (AgentLearned, DecisionMade, ContextUpdated, GoalAchieved).

### Ash framework integration at medium abstraction level

Ash resources provide natural boundaries for agent coordination through declarative DSLs:

```elixir
defmodule MyApp.Inventory.Product do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  actions do
    update :reorder do
      accept [:quantity]
      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, product ->
          if product.quantity < product.reorder_point do
            MyApp.ReorderAgent.trigger_reorder(product)
          end
          {:ok, product}
        end)
      end
    end
  end
  
  calculations do
    calculate :optimal_order_quantity, :integer do
      calculation fn records, _opts ->
        Enum.map(records, &MyApp.ForecastingAgent.calculate_eoq/1)
      end
    end
  end
end
```

The **AshCommanded** extension enables declarative CQRS/ES integration where agents can listen to command dispatch events and react to domain events through configured handlers. This provides a clean separation between the domain model (Ash resources) and the event-sourced command processing layer.

### Jido agent framework for autonomous workflows

Jido provides comprehensive agent primitives with built-in support for actions, sensors, and workflow orchestration:

```elixir
defmodule MyApp.InventoryControlAgent do
  use Jido.Agent,
    name: "inventory_controller",
    description: "Monitors stock levels and triggers reordering",
    actions: [
      MyApp.Actions.CheckStockLevels,
      MyApp.Actions.CalculateReorderPoint,
      MyApp.Actions.GeneratePurchaseOrder,
      MyApp.Actions.NotifySupplier
    ],
    schema: [
      warehouse_id: [type: :string, required: true],
      check_interval: [type: :integer, default: 3600],
      safety_stock_days: [type: :integer, default: 7]
    ]
end

defmodule MyApp.Sensors.EventStreamMonitor do
  use Jido.Sensor,
    name: "inventory_event_monitor"

  def mount(opts) do
    Commanded.EventStore.subscribe_to_all_streams(
      "inventory_agent", 
      &handle_event/3, 
      start_from: :current
    )
    {:ok, opts}
  end

  def handle_event(%StockLevelChanged{} = event, metadata, state) do
    Jido.Signal.emit(%{
      type: "inventory.stock_level_changed",
      data: event,
      metadata: metadata
    })
    {:noreply, state}
  end
end
```

## Agent interaction patterns with event-sourced systems

Agents integrate with CQRS/Event Sourcing through four primary architectural models. The **Event-Driven Agent Framework** models agents as reactive components with Input (consuming events/commands), Processing (applying reasoning), and Output (emitting actions) interfaces. The **Agent as Aggregate Pattern** treats agents themselves as event-sourced entities, enabling full replay and auditability of agent behavior.

For event choreography versus orchestration, hybrid approaches prove most effective. Use **orchestration** within bounded contexts where strong consistency is required, with a central coordinator agent managing workflow state. Use **choreography** between contexts for loose coupling, where agents react to events autonomously without central control. This balances process visibility with system resilience.

Saga patterns for distributed transactions work particularly well with agents. In **choreography-based sagas**, agents participate through event publication with distributed compensation logic. In **orchestration-based sagas**, a coordinator agent manages the entire transaction with centralized compensation. Critical considerations include idempotency of agent operations, timeout handling for non-responsive agents, and event versioning for long-running sagas.

Event replay techniques enable powerful agent capabilities. Historical event streams provide rich training datasets for agent learning. New agent versions can be tested by replaying historical events and comparing decisions. Deployment strategies include full replay from stream beginning, snapshot + incremental replay, and selective replay of specific event types. Side effect management requires distinguishing replay mode from live mode to prevent duplicate actions.

## Modular architecture patterns for dynamic component availability

The Core application orchestrates pluggable Elixir applications using a component registry pattern that handles dynamic availability:

```elixir
defmodule MyApp.ComponentRegistry do
  use GenServer

  def maybe_call_component(name, function, args) do
    case component_available?(name) do
      true -> apply(get_component(name), function, args)
      false -> {:error, :component_unavailable}
    end
  end

  def with_fallback(name, function, args, fallback_fn) do
    case maybe_call_component(name, function, args) do
      {:error, :component_unavailable} -> fallback_fn.()
      result -> result
    end
  end
end
```

Resilience patterns are essential for agent systems in modular architectures. The **Circuit Breaker pattern** prevents cascading failures by monitoring service health with three states: Closed (normal operation), Open (failing fast without calling service), and Half-Open (testing recovery). Combined with **retry mechanisms** using exponential backoff and **fallback patterns** providing degraded functionality, agents can maintain operations even when dependencies fail.

Service discovery enables dynamic routing through either client-side discovery (agents query registry directly) or server-side discovery (load balancer handles routing). The plugin architecture supports runtime module loading:

```elixir
defmodule MyApp.AgentPluginManager do
  def load_plugin(plugin_module) when is_atom(plugin_module) do
    if Code.ensure_loaded?(plugin_module) do
      plugin_module.initialize()
      ComponentRegistry.register_component(
        plugin_module.name(), 
        plugin_module
      )
      {:ok, plugin_module}
    else
      {:error, :plugin_not_found}
    end
  end
end
```

Message queue and event bus patterns provide loose coupling between agents. Using **RabbitMQ headers exchange**, agents subscribe to specific events based on multiple attributes. **Apache Kafka** enables event streaming with topic partitioning for scalability. The key is choosing between command-oriented message queues (one consumer per message) and event-oriented pub/sub (multiple consumers per event).

## Inventory management agent use cases and implementation

Seven critical inventory control agent types emerge from the research:

**Stock Level Monitoring Agents** continuously track inventory levels using IoT sensors and event streams, triggering alerts when thresholds are breached. They maintain real-time visibility across multiple warehouses and automatically escalate critical stock situations.

**Reorder Point Calculation Agents** use machine learning to dynamically adjust reorder points based on demand patterns, lead time variability, and service level requirements. They consider seasonality, promotions, and external factors like weather or economic indicators.

**Demand Forecasting Agents** employ ensemble methods combining LSTM networks, gradient boosting, and transformer models to achieve 80%+ prediction accuracy. They integrate external data sources and provide confidence intervals for planning.

**Supplier Management Agents** automate supplier performance evaluation using multi-criteria analysis, assess risks in real-time, and handle dynamic supplier selection based on performance metrics, pricing, and reliability. They can even automate contract negotiation within predefined parameters.

**Warehouse Optimization Agents** use MARL approaches for AGV coordination, implement QMIX algorithms for collaborative robot control, and optimize warehouse layout and pick paths. They achieve significant improvements in throughput and space utilization.

**Order Processing Agents** validate orders against business rules, process payments through integrated systems, coordinate fulfillment across multiple channels, and handle exceptions through escalation workflows.

**Quality Control Agents** monitor product quality metrics from IoT sensors, predict maintenance requirements for equipment, identify patterns indicating quality issues, and trigger corrective actions automatically.

## CQRS/Event Sourcing integration for agents

The implementation leverages Commanded's event sourcing capabilities for complete agent auditability:

```elixir
defmodule MyApp.Aggregates.AgentDecision do
  defstruct [:agent_id, :decisions, :state]

  def execute(%AgentDecision{}, %MakeDecision{} = command) do
    %DecisionMade{
      agent_id: command.agent_id,
      decision_type: command.decision_type,
      input_context: command.context,
      reasoning: command.reasoning,
      output: command.output,
      confidence: command.confidence,
      timestamp: DateTime.utc_now()
    }
  end

  def apply(%AgentDecision{} = aggregate, %DecisionMade{} = event) do
    %{aggregate | 
      decisions: [event | aggregate.decisions],
      state: update_agent_state(aggregate.state, event)
    }
  end
end
```

Event schema design for agents requires careful consideration. Include rich context in events for agent decision-making. Use correlation IDs to link related events across agent interactions. Capture agent metadata including ID, version, and confidence scores. Document the complete decision context with input state, reasoning process, and output decisions.

Schema evolution strategies ensure backward and forward compatibility. Add optional fields with sensible defaults rather than changing existing fields. Use event type versioning (OrderCreated_V2) for breaking changes. Implement upcasting to convert old events to new formats during read. Never change the semantic meaning of existing properties.

## Transparency, auditability, and human collaboration patterns

Implementing explainable AI requires stakeholder-specific transparency. Executive decision makers need high-level summaries showing strategic alignment. Business users require actionable insights for operational decisions. Affected users deserve clear explanations of outcomes. Governance teams need technical details for compliance verification.

Comprehensive audit trails must capture data lineage (sources, transformations, versions), decision provenance (reasoning with timestamps), model metadata (versions, training data, performance), human interactions (interventions, approvals, overrides), and configuration changes (modifications and authorization). Implement immutable logging with cryptographic integrity, automated metadata capture during execution, real-time monitoring dashboards, and tamper-proof storage with retention policies.

Human-agent collaboration follows three primary UX patterns. **Collaborative (chat-based)** enables two-way interaction for complex decision-making. **Embedded (invisible)** seamlessly integrates AI into existing workflows. **Asynchronous (background)** allows agents to work independently with periodic checkpoints. Approval workflows implement multi-level systems with sequential escalation, parallel consensus requirements, conditional routing based on risk, and emergency override procedures.

Exception handling patterns include confidence-based escalation for low-certainty decisions, threshold-based routing for high-value transactions, pattern recognition alerts for anomalies, and manual override capabilities for authorized users. Trust building requires gradual rollout starting with low-risk applications, extensive training programs, transparent communication about capabilities and limitations, and success story sharing.

## Implementation recommendations and best practices

Start with a phased deployment strategy. Phase 1 focuses on low-risk, high-value use cases like demand forecasting and stock level monitoring to build confidence. Phase 2 expands to critical processes like automated reordering with enhanced monitoring. Phase 3 scales to enterprise-wide deployment with full governance frameworks including supplier management and warehouse optimization.

Design agents for modularity and reusability. Create specialized agents for specific domains (inventory, purchasing, quality) that can be composed into complex workflows. Use the plugin architecture to add capabilities without modifying core systems. Implement standardized interfaces for agent communication and coordination.

Leverage OTP patterns for fault tolerance. Use supervision trees to restart failed agents automatically. Implement GenServer for stateful agents requiring persistence. Apply GenStateMachine for complex workflow orchestration. Employ Registry for dynamic agent discovery and routing.

Monitor critical metrics including technical measures (model accuracy, response time, system availability), business metrics (inventory turnover, stockout rates, order fulfillment time), user metrics (adoption rate, satisfaction scores, trust levels), and compliance metrics (audit findings, regulatory compliance scores).

Handle eventual consistency carefully in distributed agent systems. Design for partition tolerance with agents operating independently when network splits occur. Implement conflict resolution strategies for concurrent agent actions. Use event sourcing to maintain consistency through event ordering. Apply saga patterns for distributed transactions requiring coordination.

## Architecture synthesis and implementation roadmap

The recommended architecture combines Commanded for event sourcing and CQRS, Ash for declarative resource management and business logic, Jido for agent orchestration and autonomous workflows, AshCommanded for seamless integration between frameworks, and a modular Core application managing dynamic component availability.

Agents operate at multiple levels: domain agents within bounded contexts handling specific business capabilities, orchestration agents coordinating across contexts and managing workflows, and infrastructure agents providing cross-cutting concerns like monitoring and security. Event streams serve as the primary communication mechanism, enabling loose coupling, full auditability, and replay capabilities.

The implementation roadmap begins with establishing the foundational event-sourced architecture using Commanded and implementing basic Ash resources for inventory domain modeling. Next, integrate Jido for simple agent workflows like stock monitoring and deploy the component registry for modular architecture support. Then add hybrid rule-based and AI agents for demand forecasting, implement human-in-the-loop approval workflows, and expand to supplier management and warehouse optimization agents. Finally, add advanced features including distributed saga coordination, machine learning model training from event history, and comprehensive monitoring and observability.

  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "arden claude hook Stop"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "arden claude hook SubagentStop"
          }
        ]
      }
    ]
  },
  "feedbackSurveyState": {
    "lastShownTime": 1754078347577
  }
This architecture provides a robust foundation for building sophisticated agentic accounting and ERP systems that balance automation with human oversight, maintain full auditability while enabling flexible decision-making, scale through modular component architecture, and adapt to changing business requirements through event-driven design. The combination of Elixir's fault-tolerant runtime, Commanded's event sourcing capabilities, Ash's declarative modeling, and Jido's agent primitives creates a powerful platform for next-generation business automation.
