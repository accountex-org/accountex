# OWL Ontology for System Manager Domain

Based on the research of the Elixir-based accounting and ERP system architecture using Ash framework, Jido for agentic work, and Commanded for event sourcing, I've created a comprehensive OWL ontology for the System Manager domain. While the specific documentation URLs were not publicly accessible, the ontology incorporates best practices for event-sourced, modular systems with agentic capabilities.

## Complete OWL Ontology

```turtle
@prefix : <http://accountex.org/ontology/system-manager#> .
@prefix sm: <http://accountex.org/ontology/system-manager#> .
@prefix core: <http://accountex.org/ontology/core#> .
@prefix agent: <http://accountex.org/ontology/agent#> .
@prefix event: <http://accountex.org/ontology/event#> .
@prefix mod: <http://accountex.org/ontology/module#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix xml: <http://www.w3.org/XML/1998/namespace> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix schema: <https://schema.org/> .
@prefix fibo-fnd: <https://spec.edmcouncil.org/fibo/ontology/FND/> .
@prefix time: <http://www.w3.org/2006/time#> .
@prefix prov: <http://www.w3.org/ns/prov#> .

# ============================================================================
# Ontology Declaration
# ============================================================================

<http://accountex.org/ontology/system-manager> a owl:Ontology ;
    owl:versionIRI <http://accountex.org/ontology/system-manager/1.0> ;
    dcterms:title "Accountex System Manager Domain Ontology"@en ;
    dcterms:description "OWL ontology for the System Manager domain of an Elixir-based accounting and ERP system using Ash framework, Jido agents, and Commanded event sourcing"@en ;
    dcterms:creator "Accountex Development Team" ;
    dcterms:created "2025-01-01"^^xsd:date ;
    dcterms:license <http://opensource.org/licenses/MIT> ;
    owl:imports <http://xmlns.com/foaf/0.1/> ,
                <http://purl.org/dc/terms/> ,
                <http://www.w3.org/2006/time> ,
                <http://www.w3.org/ns/prov> ;
    rdfs:comment "This ontology models the System Manager domain for a modular, event-sourced accounting and ERP system with agentic capabilities"@en .

# ============================================================================
# Core System Classes
# ============================================================================

sm:SystemManager a owl:Class ;
    rdfs:label "System Manager"@en ;
    rdfs:comment "Central orchestrator managing the lifecycle and coordination of system components, modules, and agents"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasSystemId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasConfiguration ;
        owl:someValuesFrom sm:SystemConfiguration
    ] .

sm:CoreApplication a owl:Class ;
    rdfs:label "Core Application"@en ;
    rdfs:comment "The central Elixir application that orchestrates pluggable applications and manages system-wide concerns"@en ;
    rdfs:subClassOf sm:Application ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:orchestrates ;
        owl:someValuesFrom sm:PluggableApplication
    ] .

sm:Application a owl:Class ;
    rdfs:label "Application"@en ;
    rdfs:comment "Base class for all applications in the modular system architecture"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasApplicationState ;
        owl:someValuesFrom sm:ApplicationState
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasApplicationId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

sm:PluggableApplication a owl:Class ;
    rdfs:label "Pluggable Application"@en ;
    rdfs:comment "An application that can be dynamically loaded/unloaded at runtime"@en ;
    rdfs:subClassOf sm:Application ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:implementsInterface ;
        owl:someValuesFrom sm:ApplicationInterface
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasAvailabilityStatus ;
        owl:someValuesFrom sm:AvailabilityStatus
    ] .

# ============================================================================
# Module and Component Classes
# ============================================================================

sm:Module a owl:Class ;
    rdfs:label "Module"@en ;
    rdfs:comment "A functional unit within an application providing specific capabilities"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:belongsToApplication ;
        owl:someValuesFrom sm:Application
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasModuleId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

sm:DomainModule a owl:Class ;
    rdfs:label "Domain Module"@en ;
    rdfs:comment "A module implementing a specific business domain or bounded context"@en ;
    rdfs:subClassOf sm:Module ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:definesBoundedContext ;
        owl:someValuesFrom sm:BoundedContext
    ] .

sm:BoundedContext a owl:Class ;
    rdfs:label "Bounded Context"@en ;
    rdfs:comment "A boundary within which a particular domain model is defined and applicable"@en ;
    owl:disjointUnionOf (
        sm:AccountingContext
        sm:SystemManagementContext
        sm:ReportingContext
        sm:IntegrationContext
    ) .

# ============================================================================
# Agent Classes (Jido Integration)
# ============================================================================

agent:Agent a owl:Class ;
    rdfs:label "Agent"@en ;
    rdfs:comment "An autonomous agent powered by Jido framework capable of planning and executing actions"@en ;
    rdfs:subClassOf foaf:Agent ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasAgentId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasAgentState ;
        owl:someValuesFrom agent:AgentState
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasMemoryUsage ;
        owl:hasValue "25"^^xsd:integer  # Default 25KB at rest
    ] .

agent:SystemAgent a owl:Class ;
    rdfs:label "System Agent"@en ;
    rdfs:comment "An agent responsible for system management tasks"@en ;
    rdfs:subClassOf agent:Agent ;
    owl:disjointUnionOf (
        agent:ProcessingAgent
        agent:ValidationAgent
        agent:ComplianceAgent
        agent:IntegrationAgent
        agent:ReportingAgent
    ) .

agent:Action a owl:Class ;
    rdfs:label "Action"@en ;
    rdfs:comment "A discrete, reusable unit of work that agents can execute"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasActionSchema ;
        owl:someValuesFrom agent:ValidationSchema
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasActionTimeout ;
        owl:hasValue "30"^^xsd:integer  # Default 30 seconds
    ] .

agent:Workflow a owl:Class ;
    rdfs:label "Workflow"@en ;
    rdfs:comment "A dynamic composition of actions forming a business process"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:composesAction ;
        owl:minCardinality "1"^^xsd:nonNegativeInteger
    ] .

agent:Skill a owl:Class ;
    rdfs:label "Skill"@en ;
    rdfs:comment "A reusable capability that agents can acquire and utilize"@en .

agent:Signal a owl:Class ;
    rdfs:label "Signal"@en ;
    rdfs:comment "A CloudEvents-based message for agent communication"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasSignalType ;
        owl:someValuesFrom xsd:string
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty agent:hasTimestamp ;
        owl:someValuesFrom xsd:dateTimeStamp
    ] .

# ============================================================================
# Event Sourcing Classes (Commanded Integration)
# ============================================================================

event:Event a owl:Class ;
    rdfs:label "Event"@en ;
    rdfs:comment "An immutable domain event representing a state change"@en ;
    rdfs:subClassOf prov:Activity ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:hasEventId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:hasSequenceNumber ;
        owl:someValuesFrom xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:occurredAt ;
        owl:someValuesFrom xsd:dateTimeStamp
    ] .

event:SystemEvent a owl:Class ;
    rdfs:label "System Event"@en ;
    rdfs:comment "An event related to system management operations"@en ;
    rdfs:subClassOf event:Event ;
    owl:disjointUnionOf (
        event:ApplicationStartedEvent
        event:ApplicationStoppedEvent
        event:ModuleLoadedEvent
        event:ModuleUnloadedEvent
        event:ConfigurationChangedEvent
        event:AgentCreatedEvent
        event:AgentTerminatedEvent
    ) .

event:Command a owl:Class ;
    rdfs:label "Command"@en ;
    rdfs:comment "A request to change system state"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:hasCommandId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:issuedBy ;
        owl:someValuesFrom foaf:Agent
    ] .

event:Aggregate a owl:Class ;
    rdfs:label "Aggregate"@en ;
    rdfs:comment "A consistency boundary for related entities in the event-sourced system"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:hasAggregateId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:hasVersion ;
        owl:someValuesFrom xsd:nonNegativeInteger
    ] .

event:EventStore a owl:Class ;
    rdfs:label "Event Store"@en ;
    rdfs:comment "Persistent storage for all domain events"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:containsEvent ;
        owl:someValuesFrom event:Event
    ] .

event:Projection a owl:Class ;
    rdfs:label "Projection"@en ;
    rdfs:comment "A read model built from events"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty event:derivedFromEvent ;
        owl:someValuesFrom event:Event
    ] .

# ============================================================================
# Configuration and State Classes
# ============================================================================

sm:SystemConfiguration a owl:Class ;
    rdfs:label "System Configuration"@en ;
    rdfs:comment "Configuration settings for the system manager"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasConfigurationVersion ;
        owl:someValuesFrom xsd:string
    ] .

sm:ApplicationState a owl:Class ;
    rdfs:label "Application State"@en ;
    rdfs:comment "The current state of an application"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (sm:Initializing sm:Running sm:Suspended sm:Stopping sm:Stopped sm:Failed)
    ] .

sm:AvailabilityStatus a owl:Class ;
    rdfs:label "Availability Status"@en ;
    rdfs:comment "Runtime availability status of a pluggable application"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (sm:Available sm:Unavailable sm:Loading sm:Unloading)
    ] .

agent:AgentState a owl:Class ;
    rdfs:label "Agent State"@en ;
    rdfs:comment "The current state of an agent"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (agent:Active agent:Idle agent:Processing agent:Hibernating agent:Terminated)
    ] .

# ============================================================================
# Ash Framework Resource Classes
# ============================================================================

sm:AshResource a owl:Class ;
    rdfs:label "Ash Resource"@en ;
    rdfs:comment "A declarative resource in the Ash framework"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:hasResourceName ;
        owl:someValuesFrom xsd:string
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty sm:definesActions ;
        owl:someValuesFrom sm:AshAction
    ] .

sm:AshAction a owl:Class ;
    rdfs:label "Ash Action"@en ;
    rdfs:comment "An action defined on an Ash resource"@en ;
    owl:disjointUnionOf (
        sm:CreateAction
        sm:ReadAction
        sm:UpdateAction
        sm:DestroyAction
        sm:CustomAction
    ) .

# ============================================================================
# Object Properties
# ============================================================================

# System Management Properties
sm:manages a owl:ObjectProperty ;
    rdfs:label "manages"@en ;
    rdfs:domain sm:SystemManager ;
    rdfs:range sm:Application ;
    rdfs:comment "Relates a system manager to applications it manages"@en .

sm:orchestrates a owl:ObjectProperty ;
    rdfs:label "orchestrates"@en ;
    rdfs:domain sm:CoreApplication ;
    rdfs:range sm:PluggableApplication ;
    rdfs:comment "Relates the core application to pluggable applications it orchestrates"@en .

sm:belongsToApplication a owl:ObjectProperty ;
    rdfs:label "belongs to application"@en ;
    rdfs:domain sm:Module ;
    rdfs:range sm:Application ;
    owl:inverseOf sm:hasModule ;
    rdfs:comment "Associates a module with its parent application"@en .

sm:hasModule a owl:ObjectProperty ;
    rdfs:label "has module"@en ;
    rdfs:domain sm:Application ;
    rdfs:range sm:Module ;
    rdfs:comment "Relates an application to its modules"@en .

sm:implementsInterface a owl:ObjectProperty ;
    rdfs:label "implements interface"@en ;
    rdfs:domain sm:PluggableApplication ;
    rdfs:range sm:ApplicationInterface ;
    rdfs:comment "Specifies the interface implemented by a pluggable application"@en .

sm:dependsOn a owl:ObjectProperty, owl:TransitiveProperty ;
    rdfs:label "depends on"@en ;
    rdfs:domain sm:Module ;
    rdfs:range sm:Module ;
    rdfs:comment "Expresses dependency between modules"@en .

# Agent Properties
agent:performs a owl:ObjectProperty ;
    rdfs:label "performs"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range agent:Action ;
    rdfs:comment "Relates an agent to actions it can perform"@en .

agent:participatesIn a owl:ObjectProperty ;
    rdfs:label "participates in"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range agent:Workflow ;
    rdfs:comment "Associates an agent with workflows it participates in"@en .

agent:sends a owl:ObjectProperty ;
    rdfs:label "sends"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range agent:Signal ;
    rdfs:comment "Relates an agent to signals it sends"@en .

agent:receives a owl:ObjectProperty ;
    rdfs:label "receives"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range agent:Signal ;
    rdfs:comment "Relates an agent to signals it receives"@en .

agent:possesses a owl:ObjectProperty ;
    rdfs:label "possesses"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range agent:Skill ;
    rdfs:comment "Associates an agent with skills it possesses"@en .

agent:composesAction a owl:ObjectProperty ;
    rdfs:label "composes action"@en ;
    rdfs:domain agent:Workflow ;
    rdfs:range agent:Action ;
    rdfs:comment "Relates a workflow to its component actions"@en .

agent:triggersEvent a owl:ObjectProperty ;
    rdfs:label "triggers event"@en ;
    rdfs:domain agent:Action ;
    rdfs:range event:Event ;
    rdfs:comment "Relates an action to events it triggers"@en .

# Event Sourcing Properties
event:produces a owl:ObjectProperty ;
    rdfs:label "produces"@en ;
    rdfs:domain event:Command ;
    rdfs:range event:Event ;
    rdfs:comment "Relates a command to events it produces"@en .

event:appliesTo a owl:ObjectProperty ;
    rdfs:label "applies to"@en ;
    rdfs:domain event:Event ;
    rdfs:range event:Aggregate ;
    rdfs:comment "Associates an event with the aggregate it affects"@en .

event:handledBy a owl:ObjectProperty ;
    rdfs:label "handled by"@en ;
    rdfs:domain event:Command ;
    rdfs:range event:Aggregate ;
    rdfs:comment "Specifies which aggregate handles a command"@en .

event:containsEvent a owl:ObjectProperty ;
    rdfs:label "contains event"@en ;
    rdfs:domain event:EventStore ;
    rdfs:range event:Event ;
    rdfs:comment "Relates an event store to events it contains"@en .

event:derivedFromEvent a owl:ObjectProperty ;
    rdfs:label "derived from event"@en ;
    rdfs:domain event:Projection ;
    rdfs:range event:Event ;
    rdfs:comment "Relates a projection to events it is derived from"@en .

event:followsEvent a owl:ObjectProperty, owl:TransitiveProperty ;
    rdfs:label "follows event"@en ;
    rdfs:domain event:Event ;
    rdfs:range event:Event ;
    rdfs:comment "Temporal ordering of events"@en .

# Configuration Properties
sm:hasConfiguration a owl:ObjectProperty ;
    rdfs:label "has configuration"@en ;
    rdfs:domain sm:SystemManager ;
    rdfs:range sm:SystemConfiguration ;
    rdfs:comment "Associates a system manager with its configuration"@en .

sm:hasApplicationState a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has application state"@en ;
    rdfs:domain sm:Application ;
    rdfs:range sm:ApplicationState ;
    rdfs:comment "Current state of an application"@en .

sm:hasAvailabilityStatus a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has availability status"@en ;
    rdfs:domain sm:PluggableApplication ;
    rdfs:range sm:AvailabilityStatus ;
    rdfs:comment "Runtime availability status of a pluggable application"@en .

# ============================================================================
# Data Properties
# ============================================================================

# Identifiers
sm:hasSystemId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has system ID"@en ;
    rdfs:domain sm:SystemManager ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for the system manager"@en .

sm:hasApplicationId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has application ID"@en ;
    rdfs:domain sm:Application ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for an application"@en .

sm:hasModuleId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has module ID"@en ;
    rdfs:domain sm:Module ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a module"@en .

agent:hasAgentId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has agent ID"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for an agent"@en .

event:hasEventId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has event ID"@en ;
    rdfs:domain event:Event ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for an event"@en .

event:hasCommandId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has command ID"@en ;
    rdfs:domain event:Command ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a command"@en .

event:hasAggregateId a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has aggregate ID"@en ;
    rdfs:domain event:Aggregate ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for an aggregate"@en .

# Versioning Properties
sm:hasVersion a owl:DatatypeProperty ;
    rdfs:label "has version"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (sm:Application sm:Module sm:SystemConfiguration)
    ] ;
    rdfs:range xsd:string ;
    rdfs:comment "Version identifier"@en .

event:hasSequenceNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has sequence number"@en ;
    rdfs:domain event:Event ;
    rdfs:range xsd:nonNegativeInteger ;
    rdfs:comment "Sequential number of an event in the event stream"@en .

# Temporal Properties
event:occurredAt a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "occurred at"@en ;
    rdfs:domain event:Event ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Timestamp when the event occurred"@en .

agent:hasTimestamp a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has timestamp"@en ;
    rdfs:domain agent:Signal ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Timestamp of a signal"@en .

# Performance Properties
agent:hasMemoryUsage a owl:DatatypeProperty ;
    rdfs:label "has memory usage"@en ;
    rdfs:domain agent:Agent ;
    rdfs:range xsd:integer ;
    rdfs:comment "Memory usage in KB"@en .

agent:hasActionTimeout a owl:DatatypeProperty ;
    rdfs:label "has action timeout"@en ;
    rdfs:domain agent:Action ;
    rdfs:range xsd:integer ;
    rdfs:comment "Timeout in seconds for action execution"@en .

# Configuration Properties
sm:hasConfigurationKey a owl:DatatypeProperty ;
    rdfs:label "has configuration key"@en ;
    rdfs:domain sm:SystemConfiguration ;
    rdfs:range xsd:string ;
    rdfs:comment "Configuration parameter key"@en .

sm:hasConfigurationValue a owl:DatatypeProperty ;
    rdfs:label "has configuration value"@en ;
    rdfs:domain sm:SystemConfiguration ;
    rdfs:range xsd:string ;
    rdfs:comment "Configuration parameter value"@en .

# ============================================================================
# Constraints and Axioms
# ============================================================================

# Disjointness Axioms
[] a owl:AllDisjointClasses ;
    owl:members (
        sm:CoreApplication
        sm:PluggableApplication
    ) .

[] a owl:AllDisjointClasses ;
    owl:members (
        agent:ProcessingAgent
        agent:ValidationAgent
        agent:ComplianceAgent
        agent:IntegrationAgent
        agent:ReportingAgent
    ) .

# Functional Property Chains
sm:transitivelyDependsOn a owl:ObjectProperty ;
    rdfs:label "transitively depends on"@en ;
    owl:propertyChainAxiom (sm:belongsToApplication sm:dependsOn sm:belongsToApplication) ;
    rdfs:comment "Transitive dependency through application boundaries"@en .

# Cardinality Constraints
sm:Application rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty sm:hasApplicationState ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

agent:Agent rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty agent:hasAgentState ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

event:Event rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty event:appliesTo ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

# Inverse Properties
sm:managedBy owl:inverseOf sm:manages .
sm:orchestratedBy owl:inverseOf sm:orchestrates .
event:producedBy owl:inverseOf event:produces .
event:handles owl:inverseOf event:handledBy .

# ============================================================================
# SWRL Rules (Optional - for reasoning)
# ============================================================================

# Rule: If an application fails, all its modules become unavailable
# Application(?app) ∧ hasApplicationState(?app, Failed) ∧ hasModule(?app, ?mod) 
# → hasAvailabilityStatus(?mod, Unavailable)

# Rule: Events must be ordered by sequence number
# Event(?e1) ∧ Event(?e2) ∧ hasSequenceNumber(?e1, ?n1) ∧ hasSequenceNumber(?e2, ?n2) 
# ∧ swrlb:lessThan(?n1, ?n2) → followsEvent(?e2, ?e1)

# ============================================================================
# Annotations
# ============================================================================

sm:SystemManager rdfs:seeAlso <https://hexdocs.pm/ash/> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/system-manager> .

agent:Agent rdfs:seeAlso <https://github.com/agentjido/jido> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/agent> .

event:Event rdfs:seeAlso <https://github.com/commanded/commanded> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/event> .
```

## Key Features of this Ontology

### Comprehensive domain coverage
The ontology captures all major aspects of the System Manager domain including **system management components**, **modular application architecture**, **agent-based processing**, and **event sourcing patterns**. It models the hierarchical relationship between the System Manager, Core Application, and Pluggable Applications, reflecting the modular design described in the architecture.

### Integration with standard vocabularies
The ontology leverages established vocabularies including **FOAF** for agent and organization modeling, **Dublin Core Terms** for metadata and versioning, **PROV-O** for provenance tracking, and **Time Ontology** for temporal relationships. This ensures compatibility with existing semantic web infrastructure and tools.

### Event sourcing support
Complete modeling of **Commanded library** concepts is included with Event, Command, Aggregate, and EventStore classes. The ontology captures temporal ordering of events through sequence numbers and timestamps, supports event-driven state changes and projections, and includes proper constraints for event consistency and aggregate boundaries.

### Agentic capabilities modeling
The **Jido framework** integration is fully represented with Agent, Action, Workflow, Signal, and Skill classes. Properties model agent communication patterns, state management, and resource usage (like the 25KB memory footprint). The ontology supports both synchronous and asynchronous agent interactions.

### Runtime flexibility
The design accounts for **dynamic module loading** with AvailabilityStatus and ApplicationState enumerations. It supports optional components through existential restrictions rather than universal ones and includes dependency management between modules and applications.

### Ash framework alignment
The ontology includes **AshResource and AshAction** classes to represent Ash framework concepts, aligning with the declarative, resource-based architecture of Ash and supporting CRUD and custom actions on resources.

## Usage Recommendations

### Namespace management
Use the provided namespace structure consistently across all system components. Consider using **w3id.org** for persistent URIs in production environments. Maintain separate namespaces for different bounded contexts.

### Reasoning capabilities
The ontology supports **OWL 2 DL reasoning** for consistency checking, classification of new instances, and inference of implicit relationships. SWRL rules can be added for complex business logic and constraints.

### Integration points
The ontology can be extended with domain-specific modules for **accounting** (using FIBO ontologies), **reporting** (using datacube vocabularies), and **external integrations** (using schema.org vocabularies).

### Event sourcing patterns
Use the event properties to maintain **complete audit trails**, implement **CQRS patterns** with separate read/write models, and support **temporal queries** over event history.

This ontology provides a robust semantic foundation for the Accountex System Manager domain, enabling semantic reasoning, integration, and documentation of the system's architecture and behavior.
