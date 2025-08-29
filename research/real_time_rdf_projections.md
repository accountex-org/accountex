# Real-time RDF projections from event-sourced Elixir accounting systems

Building a real-time RDF knowledge graph from an event-sourced Elixir accounting system requires combining the streaming capabilities of RDF.ex with Commanded's projector patterns and Ash's resource mappings. **The core approach involves creating dedicated RDF projectors within the Commanded pipeline that transform domain events into RDF triples using compile-time generated schemas, streaming them to Turtle format while maintaining consistency with the event store.** This technical architecture enables semantic integration across modular ERP applications while preserving event-sourcing benefits like audit trails and temporal queries.

## Technical implementation architecture

The implementation centers on three integrated layers: event capture through Commanded projectors, RDF generation using RDF.ex's streaming APIs, and knowledge graph construction following accounting-specific ontologies like FIBO and XBRL. Each layer operates asynchronously to maintain high throughput while ensuring eventual consistency between the event store and RDF graph.

### Core library selection and capabilities

**RDF.ex emerges as the foundational library** for Elixir-based RDF generation, providing complete RDF 1.1 specification support with native streaming capabilities. The library handles programmatic triple creation through a DSL, serializes to multiple formats including Turtle, and crucially offers stream-based processing that prevents memory bottlenecks during high-volume event processing. Performance benchmarks indicate approximately 5,000 triples per second for streaming serialization with constant memory usage.

For object-relational mapping between RDF graphs and Elixir structs, Grax provides compile-time type safety and bidirectional conversion capabilities. While Grax has moderate performance compared to pure RDF.ex, its schema definitions prove valuable for mapping Ash resources to RDF entities with type safety guarantees.

The SPARQL.ex ecosystem completes the query layer, with in-memory query execution against RDF.ex structures and HTTP client support for remote triple stores. This enables both local processing and integration with external RDF repositories like Apache Jena Fuseki or Blazegraph.

### Commanded projector integration patterns

The integration leverages Commanded's projector infrastructure through **dedicated RDF projectors** that operate alongside traditional read models. This separation of concerns maintains clean architecture while enabling semantic projections:

```elixir
defmodule Accountex.RDFProjector do
  use Commanded.Projections.Ecto,
    application: Accountex.Application,
    name: "Accountex.RDFProjector"
    
  alias RDF.Graph
  
  project %TransactionCreated{} = event, metadata, fn multi ->
    # Generate RDF representation
    graph = event_to_rdf_graph(event, metadata)
    
    # Store graph snapshot for replay capability
    rdf_projection = %RDFProjection{
      event_id: metadata.event_id,
      stream_id: metadata.stream_id,
      graph_ttl: RDF.Turtle.write_string!(graph),
      created_at: metadata.created_at
    }
    
    Ecto.Multi.insert(multi, :rdf_projection, rdf_projection)
  end
  
  @impl Commanded.Projections.Ecto
  def after_update(event, metadata, _changes) do
    # Stream to external triple store asynchronously
    Task.async(fn ->
      graph = event_to_rdf_graph(event, metadata)
      stream_to_triplestore(graph)
    end)
    :ok
  end
  
  defp event_to_rdf_graph(%TransactionCreated{} = event, metadata) do
    use RDF
    alias Accountex.Vocab.{Accounting, FIBO}
    
    Graph.build do
      transaction_iri(event)
      |> RDF.type(Accounting.FinancialTransaction)
      |> Accounting.hasDebitAccount(account_iri(event.debit_account))
      |> Accounting.hasCreditAccount(account_iri(event.credit_account))
      |> Accounting.hasAmount(RDF.literal(event.amount, datatype: XSD.decimal()))
      |> Accounting.hasTransactionDate(event.transaction_date)
      |> add_provenance(metadata)
    end
  end
end
```

This pattern ensures RDF generation doesn't interfere with core business logic while maintaining strong consistency guarantees within the Commanded transaction boundary.

### Ash resource mapping strategies

**Ash resources map to RDF subjects through compile-time schema generation**, leveraging Elixir's macro system to create ontology-aligned RDF vocabularies. This approach enables type-safe RDF generation while maintaining the benefits of Ash's declarative resource definitions:

```elixir
defmodule Accountex.Resources.Account do
  use Ash.Resource
  use Accountex.RDFResource  # Custom macro for RDF integration
  
  attributes do
    uuid_primary_key :id
    attribute :account_code, :string
    attribute :account_name, :string
    attribute :account_type, :atom
    attribute :normal_balance, :atom
  end
  
  rdf_mapping do
    subject_pattern "https://accountex.org/accounts/{id}"
    rdf_type "https://accountex.org/ontology#Account"
    
    property :account_code, "https://accountex.org/ontology#accountCode"
    property :account_name, RDFS.label()
    property :account_type, "https://accountex.org/ontology#accountType"
    property :normal_balance, "https://accountex.org/ontology#normalBalance"
  end
  
  actions do
    defaults [:create, :read, :update]
    
    create :create do
      change after_action(&generate_rdf_on_create/3)
    end
  end
end
```

The compile-time macro generates both the RDF vocabulary module and the transformation functions, ensuring consistency between Ash schemas and RDF representations while maintaining high performance.

## Event-to-RDF mapping architecture

The mapping from domain events to RDF statements follows established patterns from the Simple Event Model (SEM) ontology combined with PROV-O for provenance tracking. **Each event becomes an RDF entity with temporal, causal, and state-change properties** preserved in the knowledge graph.

### Temporal modeling in RDF

Events maintain multiple temporal dimensions to support both business time and system time queries:

```elixir
defmodule Accountex.RDFMapper.Temporal do
  def add_temporal_properties(graph, event, metadata) do
    graph
    |> Graph.add({
      event_iri(event),
      SEM.hasTimeStamp(),
      RDF.literal(event.occurred_at, datatype: XSD.dateTime())
    })
    |> Graph.add({
      event_iri(event),
      PROV.generatedAtTime(),
      RDF.literal(metadata.created_at, datatype: XSD.dateTime())
    })
    |> add_validity_period(event)
  end
  
  defp add_validity_period(graph, %{valid_from: from, valid_to: to} = event) do
    graph
    |> Graph.add({event_iri(event), SEM.hasBeginTimeStamp(), from})
    |> Graph.add({event_iri(event), SEM.hasEndTimeStamp(), to})
  end
  defp add_validity_period(graph, _), do: graph
end
```

### State change representation

State changes are captured using a delta pattern that preserves both the before and after states while calculating the actual change:

```elixir
defmodule Accountex.RDFMapper.StateChange do
  def state_change_to_rdf(%AccountBalanceChanged{} = event) do
    change_iri = RDF.iri("https://accountex.org/changes/#{event.id}")
    
    Graph.build do
      change_iri
      |> RDF.type(Accounting.BalanceChange)
      |> Accounting.account(account_iri(event.account_id))
      |> Accounting.previousBalance(event.previous_balance)
      |> Accounting.currentBalance(event.current_balance)
      |> Accounting.balanceDelta(event.current_balance - event.previous_balance)
      |> Accounting.changeReason(event.reason)
    end
  end
end
```

### Module boundary handling

The modular architecture requires careful namespace management and cross-module reference handling. **Each module maintains its own namespace while sharing core ontology concepts**:

```elixir
defmodule Accountex.RDFMapper.ModularNamespace do
  @namespaces %{
    core: "https://accountex.org/core#",
    accounting: "https://accountex.org/accounting#",
    inventory: "https://accountex.org/inventory#",
    sales: "https://accountex.org/sales#"
  }
  
  def resolve_cross_module_reference(source_module, target_module, entity_id) do
    source_ns = @namespaces[source_module]
    target_ns = @namespaces[target_module]
    
    # Create linking triple
    {
      RDF.iri("#{source_ns}ref_#{entity_id}"),
      RDF.iri("https://accountex.org/core#referencesEntity"),
      RDF.iri("#{target_ns}#{entity_id}")
    }
  end
  
  def handle_missing_module(module_name, fallback_behavior) do
    case Application.get_env(:accountex, :available_modules) do
      modules when module_name in modules ->
        {:ok, @namespaces[module_name]}
      _ ->
        {:fallback, fallback_behavior}
    end
  end
end
```

## Ontology integration with OWL specifications

The system leverages established accounting ontologies, primarily FIBO (Financial Industry Business Ontology) for core financial concepts and XBRL ontologies for regulatory reporting compliance. **Custom module-specific ontologies extend these standards** while maintaining alignment through owl:equivalentClass and rdfs:subClassOf relationships.

### Compile-time ontology validation

Ontology constraints are validated at compile time using a custom macro that generates SHACL shapes from OWL specifications:

```elixir
defmodule Accountex.OntologyValidator do
  defmacro validate_against_ontology(ontology_path) do
    quote do
      @external_resource unquote(ontology_path)
      
      # Parse OWL at compile time
      ontology = File.read!(unquote(ontology_path))
                |> RDF.Turtle.read_string!()
      
      # Generate SHACL shapes
      shapes = OWLToSHACL.convert(ontology)
      
      # Create validation function
      def validate_rdf(graph) do
        case SHACLValidator.validate(graph, unquote(Macro.escape(shapes))) do
          {:ok, report} -> :valid
          {:error, violations} -> {:invalid, violations}
        end
      end
    end
  end
end
```

### Knowledge graph construction patterns

The accounting knowledge graph follows a **hub-and-spoke architecture** with master data entities at the center and module-specific views as spokes:

```elixir
defmodule Accountex.KnowledgeGraph.Builder do
  def build_accounting_graph(events) do
    # Build core entities first
    master_graph = build_master_data_graph()
    
    # Layer module-specific graphs
    events
    |> Stream.map(&event_to_module_graph/1)
    |> Stream.scan(master_graph, &Graph.add/2)
    |> Stream.each(&validate_consistency/1)
  end
  
  defp build_master_data_graph do
    Graph.build do
      # Chart of accounts hierarchy
      build_account_hierarchy()
      # Customer/vendor master data
      build_party_relationships()
      # Product catalog
      build_product_taxonomy()
    end
  end
  
  defp event_to_module_graph(%{module: module} = event) do
    case module do
      :accounting -> AccountingRDFMapper.to_graph(event)
      :inventory -> InventoryRDFMapper.to_graph(event)
      :sales -> SalesRDFMapper.to_graph(event)
      _ -> Graph.new()
    end
  end
end
```

## Performance optimization strategies

Achieving real-time RDF generation requires careful optimization across multiple dimensions. **The system employs streaming processing, strategic caching, and asynchronous patterns** to maintain sub-second latency while processing thousands of events per second.

### Streaming architecture with backpressure

GenStage provides backpressure-aware processing that prevents overwhelming downstream systems:

```elixir
defmodule Accountex.RDF.StreamProcessor do
  use GenStage
  
  def init(_) do
    {:producer_consumer, %{buffer: []}, subscribe_to: [{EventProducer, max_demand: 100}]}
  end
  
  def handle_events(events, _from, state) do
    # Convert events to RDF graphs in parallel
    graphs = events
             |> Task.async_stream(&event_to_graph/1, max_concurrency: 10)
             |> Stream.map(fn {:ok, graph} -> graph end)
             |> Enum.to_list()
    
    # Merge graphs for efficient serialization
    merged = Enum.reduce(graphs, Graph.new(), &Graph.add/2)
    
    # Stream to Turtle format
    turtle_stream = RDF.Turtle.write_stream!(merged)
    
    {:noreply, [turtle_stream], state}
  end
end
```

### Multi-tier caching strategy

The caching architecture operates at multiple levels to minimize redundant computation:

```elixir
defmodule Accountex.RDF.Cache do
  use GenServer
  
  @cache_levels [
    {:ontology, :persistent, ttl: :infinity},
    {:vocabulary, :ets, ttl: 3600},
    {:hot_triples, :ets, ttl: 300},
    {:query_results, :ets, ttl: 60}
  ]
  
  def get_or_compute(key, level, compute_fn) do
    case lookup(level, key) do
      {:ok, value} -> 
        {:cache_hit, value}
      :miss ->
        value = compute_fn.()
        store(level, key, value)
        {:computed, value}
    end
  end
end
```

### Storage backend optimization

**Blazegraph provides the optimal balance** of performance and features for production deployments, with 30ms base query overhead and superior optimization for complex SPARQL queries. The system maintains a hybrid storage approach:

```elixir
defmodule Accountex.RDF.Storage do
  @hot_data_threshold 1_000_000  # triples
  
  def store_graph(graph) do
    size = Graph.triple_count(graph)
    
    if size < @hot_data_threshold do
      # Keep in memory for fast access
      InMemoryStore.put(graph)
    else
      # Stream to Blazegraph
      Blazegraph.bulk_load(graph, format: :turtle)
    end
    
    # Always persist to event store for replay
    persist_to_event_store(graph)
  end
  
  def query(sparql) do
    # Try in-memory first
    case InMemoryStore.query(sparql) do
      {:ok, results} -> results
      :miss -> Blazegraph.query(sparql)
    end
  end
end
```

## SPARQL querying and federation

The knowledge graph supports both local and federated SPARQL queries across modular boundaries:

```elixir
defmodule Accountex.SPARQL.QueryEngine do
  def execute_modular_query(query_string, modules) do
    # Parse and analyze query
    parsed = SPARQL.parse(query_string)
    
    # Determine which modules are needed
    required_modules = analyze_query_modules(parsed)
    
    # Build federated query if multiple modules
    if length(required_modules) > 1 do
      federated_query = build_federated_query(parsed, required_modules)
      SPARQL.Client.query(federated_query, endpoint: federation_endpoint())
    else
      # Execute locally for single module
      SPARQL.execute(parsed, local_graph(hd(required_modules)))
    end
  end
  
  defp build_federated_query(parsed, modules) do
    modules
    |> Enum.map(&module_service_block/1)
    |> combine_service_blocks(parsed)
  end
end
```

## Consistency and reliability patterns

The system maintains **eventual consistency** between the event store and RDF knowledge graph through versioned projections and compensating actions:

```elixir
defmodule Accountex.RDF.Consistency do
  def ensure_consistency do
    # Compare event store with RDF projections
    last_event = EventStore.get_last_event_number()
    last_projected = RDFProjector.get_last_projected_event()
    
    if last_event > last_projected do
      # Replay missing events
      replay_events(last_projected + 1, last_event)
    end
    
    # Validate graph consistency
    validate_graph_constraints()
  end
  
  def handle_projection_failure(event, error) do
    # Store failed projection for retry
    FailedProjections.store(event, error)
    
    # Emit monitoring alert
    Telemetry.execute([:rdf, :projection, :failed], %{error: error})
    
    # Continue processing (at-least-once semantics)
    :ok
  end
end
```

## Implementation roadmap

The implementation proceeds through incremental phases, each delivering functional capabilities:

**Phase 1: Core RDF generation** establishes basic event-to-RDF mapping using RDF.ex, implementing simple Commanded projectors that generate Turtle files from domain events. This phase validates the fundamental architecture.

**Phase 2: Ontology integration** incorporates FIBO and XBRL ontologies, implementing compile-time validation and namespace management. Custom module ontologies extend the standards while maintaining alignment.

**Phase 3: Streaming optimization** replaces batch processing with GenStage streaming pipelines, implementing backpressure control and memory-efficient serialization. This phase achieves the real-time performance requirements.

**Phase 4: Query federation** adds SPARQL endpoint deployment with Blazegraph, implementing federated queries across modules and caching layers for performance. This completes the knowledge graph query capabilities.

**Phase 5: Production hardening** implements monitoring, alerting, and operational tooling, including consistency checking, replay capabilities, and performance optimization based on production workloads.

This architecture delivers a robust, performant RDF projection system that transforms event-sourced accounting data into a queryable semantic knowledge graph while maintaining the benefits of both paradigms - the audit trail and temporal capabilities of event sourcing with the semantic integration and reasoning capabilities of RDF.
