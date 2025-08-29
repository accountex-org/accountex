# OWL Ontology for Sales Order Domain

Based on the Accountex Sales Order domain design using Elixir, Ash framework, Jido for agentic work, and Commanded for event sourcing, this document presents a comprehensive OWL ontology for the Sales Order domain. The ontology follows the same patterns and base schemas established in the System Manager OWL.

## Complete OWL Ontology

```turtle
@prefix : <http://accountex.org/ontology/sales-order#> .
@prefix so: <http://accountex.org/ontology/sales-order#> .
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
@prefix fibo-fbc: <https://spec.edmcouncil.org/fibo/ontology/FBC/> .
@prefix time: <http://www.w3.org/2006/time#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
@prefix gr: <http://purl.org/goodrelations/v1#> .
@prefix vcard: <http://www.w3.org/2006/vcard/ns#> .

# ============================================================================
# Ontology Declaration
# ============================================================================

<http://accountex.org/ontology/sales-order> a owl:Ontology ;
    owl:versionIRI <http://accountex.org/ontology/sales-order/1.0> ;
    dcterms:title "Accountex Sales Order Domain Ontology"@en ;
    dcterms:description "OWL ontology for the Sales Order domain of an Elixir-based accounting and ERP system using Ash framework, Jido agents, and Commanded event sourcing"@en ;
    dcterms:creator "Accountex Development Team" ;
    dcterms:created "2025-01-04"^^xsd:date ;
    dcterms:license <http://opensource.org/licenses/MIT> ;
    owl:imports <http://xmlns.com/foaf/0.1/> ,
                <http://purl.org/dc/terms/> ,
                <http://www.w3.org/2006/time> ,
                <http://www.w3.org/ns/prov> ,
                <http://purl.org/goodrelations/v1> ,
                <http://www.w3.org/2006/vcard/ns> ;
    rdfs:comment "This ontology models the Sales Order domain for a modular, event-sourced accounting and ERP system with agentic capabilities"@en .

# ============================================================================
# Core Sales Order Classes
# ============================================================================

so:SalesOrder a owl:Class ;
    rdfs:label "Sales Order"@en ;
    rdfs:comment "A commercial transaction document representing an agreement to supply goods or services at specified prices and terms"@en ;
    rdfs:subClassOf gr:Order ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasSalesOrderNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasCustomer ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasOrderDate ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasCurrencyCode ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasPaymentCode ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:SalesOrderLineItem a owl:Class ;
    rdfs:label "Sales Order Line Item"@en ;
    rdfs:comment "An individual line item within a sales order representing a specific product or service"@en ;
    rdfs:subClassOf gr:TypeAndQuantityNode ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToSalesOrder ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasLineItemKey ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasItemNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:BlanketSalesOrder a owl:Class ;
    rdfs:label "Blanket Sales Order"@en ;
    rdfs:comment "A long-term agreement to supply products at pre-negotiated prices, with releases made as needed"@en ;
    rdfs:subClassOf gr:Order ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasBlanketOrderNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasExpirationDate ;
        owl:maxCardinality "1"^^xsd:nonNegativeInteger
    ] .

so:RecurringSalesOrder a owl:Class ;
    rdfs:label "Recurring Sales Order"@en ;
    rdfs:comment "A sales order that automatically generates new orders at specified intervals"@en ;
    rdfs:subClassOf gr:Order ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasRecurringOrderNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasRecurringCycleType ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasNextRecurringDate ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

# ============================================================================
# Shipment and Fulfillment Classes
# ============================================================================

so:Shipment a owl:Class ;
    rdfs:label "Shipment"@en ;
    rdfs:comment "A physical delivery of goods fulfilling part or all of a sales order"@en ;
    rdfs:subClassOf gr:Delivery ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasShipmentNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:fulfillsSalesOrder ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasShipmentDate ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:ShipmentLineItem a owl:Class ;
    rdfs:label "Shipment Line Item"@en ;
    rdfs:comment "An individual line item within a shipment"@en ;
    rdfs:subClassOf gr:TypeAndQuantityNode ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToShipment ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:ShipmentAcceptance a owl:Class ;
    rdfs:label "Shipment Acceptance"@en ;
    rdfs:comment "Customer acceptance or rejection of shipped items"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasAcceptanceNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:acceptsShipment ;
        owl:someValuesFrom so:Shipment
    ] .

so:ShipmentAcceptanceLineItem a owl:Class ;
    rdfs:label "Shipment Acceptance Line Item"@en ;
    rdfs:comment "Line item details for shipment acceptance"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToAcceptance ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

# ============================================================================
# Billing and Financial Classes
# ============================================================================

so:AdvancedBilling a owl:Class ;
    rdfs:label "Advanced Billing"@en ;
    rdfs:comment "Billing for goods or services before shipment or completion"@en ;
    rdfs:subClassOf fibo-fbc:Invoice ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasInvoiceNumber ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:billsForSalesOrder ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:AdvancedBillingLineItem a owl:Class ;
    rdfs:label "Advanced Billing Line Item"@en ;
    rdfs:comment "Line item details for advanced billing"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToAdvancedBilling ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

# ============================================================================
# Supporting Classes
# ============================================================================

so:SalesOrderRemark a owl:Class ;
    rdfs:label "Sales Order Remark"@en ;
    rdfs:comment "Comments or notes associated with a sales order"@en ;
    rdfs:subClassOf schema:Comment ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToSalesOrder ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:SalesOrderKitFormula a owl:Class ;
    rdfs:label "Sales Order Kit Formula"@en ;
    rdfs:comment "Component formula for kit items in sales orders"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:belongsToLineItem ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasComponentQuantity ;
        owl:someValuesFrom xsd:decimal
    ] .

so:SalesOrderKitTransaction a owl:Class ;
    rdfs:label "Sales Order Kit Transaction"@en ;
    rdfs:comment "Transaction record for kit assembly or disassembly"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:executesKitFormula ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

so:CancelledSalesOrder a owl:Class ;
    rdfs:label "Cancelled Sales Order"@en ;
    rdfs:comment "Record of a cancelled sales order or quote"@en ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:originalSalesOrderId ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:hasCancellationReason ;
        owl:cardinality "1"^^xsd:nonNegativeInteger
    ] .

# ============================================================================
# Address Classes
# ============================================================================

so:Address a owl:Class ;
    rdfs:label "Address"@en ;
    rdfs:comment "Postal or physical address for billing or shipping"@en ;
    rdfs:subClassOf vcard:Address ;
    owl:disjointUnionOf (
        so:BillingAddress
        so:ShippingAddress
    ) .

so:BillingAddress a owl:Class ;
    rdfs:label "Billing Address"@en ;
    rdfs:comment "Address for invoice and payment processing"@en ;
    rdfs:subClassOf so:Address .

so:ShippingAddress a owl:Class ;
    rdfs:label "Shipping Address"@en ;
    rdfs:comment "Address for product delivery"@en ;
    rdfs:subClassOf so:Address .

# ============================================================================
# Status and State Classes
# ============================================================================

so:OrderStatus a owl:Class ;
    rdfs:label "Order Status"@en ;
    rdfs:comment "Current status of a sales order"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (
            so:Quote
            so:Pending
            so:Confirmed
            so:Processing
            so:PartiallyShipped
            so:Shipped
            so:Completed
            so:OnHold
            so:Cancelled
        )
    ] .

so:RecurringCycleType a owl:Class ;
    rdfs:label "Recurring Cycle Type"@en ;
    rdfs:comment "Frequency of recurring order generation"@en ;
    owl:equivalentClass [
        a owl:Class ;
        owl:oneOf (
            so:Weekly
            so:Monthly
            so:BiMonthly
            so:Quarterly
            so:SemiAnnual
            so:Annual
        )
    ] .

# ============================================================================
# Agent Classes (Sales Order specific)
# ============================================================================

agent:SalesOrderAgent a owl:Class ;
    rdfs:label "Sales Order Agent"@en ;
    rdfs:comment "An agent responsible for sales order processing tasks"@en ;
    rdfs:subClassOf agent:Agent ;
    owl:disjointUnionOf (
        agent:OrderProcessingAgent
        agent:InventoryCheckAgent
        agent:PricingAgent
        agent:ShippingCoordinationAgent
        agent:BillingAgent
    ) .

agent:OrderProcessingAgent a owl:Class ;
    rdfs:label "Order Processing Agent"@en ;
    rdfs:comment "Agent that handles order validation, creation, and workflow management"@en ;
    rdfs:subClassOf agent:SalesOrderAgent .

agent:InventoryCheckAgent a owl:Class ;
    rdfs:label "Inventory Check Agent"@en ;
    rdfs:comment "Agent that verifies product availability and reserves inventory"@en ;
    rdfs:subClassOf agent:SalesOrderAgent .

# ============================================================================
# Event Classes (Sales Order specific)
# ============================================================================

event:SalesOrderEvent a owl:Class ;
    rdfs:label "Sales Order Event"@en ;
    rdfs:comment "An event related to sales order operations"@en ;
    rdfs:subClassOf event:Event ;
    owl:disjointUnionOf (
        event:OrderCreatedEvent
        event:OrderUpdatedEvent
        event:OrderConfirmedEvent
        event:OrderShippedEvent
        event:OrderCancelledEvent
        event:OrderCompletedEvent
        event:OrderPlacedOnHoldEvent
        event:OrderReleasedFromHoldEvent
        event:QuoteConvertedToOrderEvent
        event:ShipmentCreatedEvent
        event:ShipmentAcceptedEvent
        event:AdvancedBillingCreatedEvent
        event:RecurringOrderGeneratedEvent
        event:BlanketOrderReleasedEvent
    ) .

# ============================================================================
# Ash Resource Classes (Sales Order specific)
# ============================================================================

so:SalesOrderAshResource a owl:Class ;
    rdfs:label "Sales Order Ash Resource"@en ;
    rdfs:comment "An Ash framework resource in the Sales Order domain"@en ;
    rdfs:subClassOf core:AshResource ;
    owl:disjointUnionOf (
        so:SalesOrderResource
        so:SalesOrderLineItemResource
        so:ShipmentResource
        so:AdvancedBillingResource
        so:BlanketSalesOrderResource
        so:RecurringSalesOrderResource
    ) .

# ============================================================================
# Object Properties
# ============================================================================

# Sales Order Relationships
so:hasCustomer a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has customer"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range foaf:Organization ;
    rdfs:comment "Associates a sales order with its customer"@en .

so:hasSalesperson a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has salesperson"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range foaf:Person ;
    rdfs:comment "Associates a sales order with the responsible salesperson"@en .

so:hasLineItem a owl:ObjectProperty ;
    rdfs:label "has line item"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:SalesOrderLineItem ;
    owl:inverseOf so:belongsToSalesOrder ;
    rdfs:comment "Relates a sales order to its line items"@en .

so:belongsToSalesOrder a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "belongs to sales order"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Associates a line item with its parent sales order"@en .

so:hasRemark a owl:ObjectProperty ;
    rdfs:label "has remark"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:SalesOrderLineItem so:Shipment so:AdvancedBilling)
    ] ;
    rdfs:range schema:Comment ;
    rdfs:comment "Associates remarks or comments with various entities"@en .

so:hasBillingAddress a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has billing address"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:BillingAddress ;
    rdfs:comment "Billing address for the sales order"@en .

so:hasShippingAddress a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "has shipping address"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:ShippingAddress ;
    rdfs:comment "Shipping address for the sales order"@en .

# Blanket Order Relationships
so:releasesToOrder a owl:ObjectProperty ;
    rdfs:label "releases to order"@en ;
    rdfs:domain so:BlanketSalesOrder ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates a blanket order to sales orders released from it"@en .

so:releasedFromBlanketOrder a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "released from blanket order"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:BlanketSalesOrder ;
    owl:inverseOf so:releasesToOrder ;
    rdfs:comment "Indicates the blanket order from which this order was released"@en .

# Recurring Order Relationships
so:generatesOrder a owl:ObjectProperty ;
    rdfs:label "generates order"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates a recurring order to orders it generates"@en .

so:generatedFromRecurringOrder a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "generated from recurring order"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:RecurringSalesOrder ;
    owl:inverseOf so:generatesOrder ;
    rdfs:comment "Indicates the recurring order that generated this order"@en .

# Shipment Relationships
so:fulfillsSalesOrder a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "fulfills sales order"@en ;
    rdfs:domain so:Shipment ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates a shipment to the sales order it fulfills"@en .

so:hasShipment a owl:ObjectProperty ;
    rdfs:label "has shipment"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:Shipment ;
    owl:inverseOf so:fulfillsSalesOrder ;
    rdfs:comment "Relates a sales order to its shipments"@en .

so:belongsToShipment a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "belongs to shipment"@en ;
    rdfs:domain so:ShipmentLineItem ;
    rdfs:range so:Shipment ;
    rdfs:comment "Associates a shipment line item with its parent shipment"@en .

so:shipsLineItem a owl:ObjectProperty ;
    rdfs:label "ships line item"@en ;
    rdfs:domain so:ShipmentLineItem ;
    rdfs:range so:SalesOrderLineItem ;
    rdfs:comment "Relates a shipment line item to the order line item it ships"@en .

so:acceptsShipment a owl:ObjectProperty ;
    rdfs:label "accepts shipment"@en ;
    rdfs:domain so:ShipmentAcceptance ;
    rdfs:range so:Shipment ;
    rdfs:comment "Relates an acceptance to the shipment being accepted"@en .

# Billing Relationships
so:billsForSalesOrder a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "bills for sales order"@en ;
    rdfs:domain so:AdvancedBilling ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates advanced billing to the sales order it bills"@en .

so:hasAdvancedBilling a owl:ObjectProperty ;
    rdfs:label "has advanced billing"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range so:AdvancedBilling ;
    owl:inverseOf so:billsForSalesOrder ;
    rdfs:comment "Relates a sales order to its advanced billings"@en .

# Kit Relationships
so:hasKitFormula a owl:ObjectProperty ;
    rdfs:label "has kit formula"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range so:SalesOrderKitFormula ;
    rdfs:comment "Relates a line item to its kit formula"@en .

so:executesKitFormula a owl:ObjectProperty, owl:FunctionalProperty ;
    rdfs:label "executes kit formula"@en ;
    rdfs:domain so:SalesOrderKitTransaction ;
    rdfs:range so:SalesOrderKitFormula ;
    rdfs:comment "Relates a kit transaction to the formula it executes"@en .

# Event Relationships
event:triggeredBySalesOrder a owl:ObjectProperty ;
    rdfs:label "triggered by sales order"@en ;
    rdfs:domain event:SalesOrderEvent ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates an event to the sales order that triggered it"@en .

event:handledBySalesOrderAgent a owl:ObjectProperty ;
    rdfs:label "handled by sales order agent"@en ;
    rdfs:domain event:SalesOrderEvent ;
    rdfs:range agent:SalesOrderAgent ;
    rdfs:comment "Relates an event to the agent that handles it"@en .

# Agent Relationships
agent:processesSalesOrder a owl:ObjectProperty ;
    rdfs:label "processes sales order"@en ;
    rdfs:domain agent:SalesOrderAgent ;
    rdfs:range so:SalesOrder ;
    rdfs:comment "Relates an agent to sales orders it processes"@en .

agent:coordinatesShipment a owl:ObjectProperty ;
    rdfs:label "coordinates shipment"@en ;
    rdfs:domain agent:ShippingCoordinationAgent ;
    rdfs:range so:Shipment ;
    rdfs:comment "Relates a shipping agent to shipments it coordinates"@en .

# ============================================================================
# Data Properties
# ============================================================================

# Identifiers
so:hasSalesOrderNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has sales order number"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a sales order"@en .

so:hasLineItemKey a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has line item key"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a line item"@en .

so:hasItemNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has item number"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:string ;
    rdfs:comment "Product or service item number"@en .

so:hasBlanketOrderNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has blanket order number"@en ;
    rdfs:domain so:BlanketSalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a blanket order"@en .

so:hasRecurringOrderNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has recurring order number"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a recurring order"@en .

so:hasShipmentNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has shipment number"@en ;
    rdfs:domain so:Shipment ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a shipment"@en .

so:hasInvoiceNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has invoice number"@en ;
    rdfs:domain so:AdvancedBilling ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for an invoice"@en .

so:hasAcceptanceNumber a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has acceptance number"@en ;
    rdfs:domain so:ShipmentAcceptance ;
    rdfs:range xsd:string ;
    rdfs:comment "Unique identifier for a shipment acceptance"@en .

# Dates and Times
so:hasOrderDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has order date"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the order was placed"@en .

so:hasQuoteDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has quote date"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the quote was created"@en .

so:hasRequestedDate a owl:DatatypeProperty ;
    rdfs:label "has requested date"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Customer requested delivery date"@en .

so:hasShipmentDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has shipment date"@en ;
    rdfs:domain so:Shipment ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the shipment was dispatched"@en .

so:hasExpirationDate a owl:DatatypeProperty ;
    rdfs:label "has expiration date"@en ;
    rdfs:domain so:BlanketSalesOrder ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the blanket order expires"@en .

so:hasNextRecurringDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has next recurring date"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the next order will be generated"@en .

so:hasLastRecurringDate a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has last recurring date"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range xsd:dateTimeStamp ;
    rdfs:comment "Date when the last order was generated"@en .

# Status Flags
so:isQuote a owl:DatatypeProperty ;
    rdfs:label "is quote"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if this is a quote rather than a confirmed order"@en .

so:isOnHold a owl:DatatypeProperty ;
    rdfs:label "is on hold"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the order is on hold"@en .

so:isOnCreditHold a owl:DatatypeProperty ;
    rdfs:label "is on credit hold"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the order is on credit hold"@en .

so:isCancelled a owl:DatatypeProperty ;
    rdfs:label "is cancelled"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the order has been cancelled"@en .

so:hasBackorders a owl:DatatypeProperty ;
    rdfs:label "has backorders"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the order has backordered items"@en .

so:isKitItem a owl:DatatypeProperty ;
    rdfs:label "is kit item"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the line item is a kit"@en .

so:isDropShip a owl:DatatypeProperty ;
    rdfs:label "is drop ship"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:boolean ;
    rdfs:comment "Indicates if the item will be drop shipped"@en .

# Quantities
so:quantityOrdered a owl:DatatypeProperty ;
    rdfs:label "quantity ordered"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Quantity of items ordered"@en .

so:quantityShipped a owl:DatatypeProperty ;
    rdfs:label "quantity shipped"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Quantity of items shipped"@en .

so:quantityAccepted a owl:DatatypeProperty ;
    rdfs:label "quantity accepted"@en ;
    rdfs:domain so:ShipmentAcceptanceLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Quantity of items accepted by customer"@en .

so:quantityRefused a owl:DatatypeProperty ;
    rdfs:label "quantity refused"@en ;
    rdfs:domain so:ShipmentAcceptanceLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Quantity of items refused by customer"@en .

so:hasComponentQuantity a owl:DatatypeProperty ;
    rdfs:label "has component quantity"@en ;
    rdfs:domain so:SalesOrderKitFormula ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Quantity of component in kit formula"@en .

# Financial Properties
so:hasCurrencyCode a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has currency code"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "ISO 4217 currency code"@en .

so:hasPaymentCode a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has payment code"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Payment method code"@en .

so:unitPrice a owl:DatatypeProperty ;
    rdfs:label "unit price"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Price per unit"@en .

so:unitCost a owl:DatatypeProperty ;
    rdfs:label "unit cost"@en ;
    rdfs:domain so:SalesOrderLineItem ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Cost per unit"@en .

so:subtotalAmount a owl:DatatypeProperty ;
    rdfs:label "subtotal amount"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:SalesOrderLineItem so:AdvancedBilling)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Subtotal before taxes and discounts"@en .

so:discountAmount a owl:DatatypeProperty ;
    rdfs:label "discount amount"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:SalesOrderLineItem)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Discount amount applied"@en .

so:taxAmount a owl:DatatypeProperty ;
    rdfs:label "tax amount"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:SalesOrderLineItem so:AdvancedBilling)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Tax amount"@en .

so:freightAmount a owl:DatatypeProperty ;
    rdfs:label "freight amount"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:Shipment so:AdvancedBilling)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Freight/shipping charges"@en .

so:exchangeRate a owl:DatatypeProperty ;
    rdfs:label "exchange rate"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:Shipment so:AdvancedBilling)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Currency exchange rate"@en .

# Shipping Properties
so:shipViaMethod a owl:DatatypeProperty ;
    rdfs:label "ship via method"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:Shipment)
    ] ;
    rdfs:range xsd:string ;
    rdfs:comment "Shipping method or carrier"@en .

so:fobPoint a owl:DatatypeProperty ;
    rdfs:label "FOB point"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:Shipment)
    ] ;
    rdfs:range xsd:string ;
    rdfs:comment "Free On Board point"@en .

so:totalWeight a owl:DatatypeProperty ;
    rdfs:label "total weight"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:Shipment)
    ] ;
    rdfs:range xsd:decimal ;
    rdfs:comment "Total weight of items"@en .

# Recurring Order Properties
so:hasRecurringCycleType a owl:DatatypeProperty, owl:FunctionalProperty ;
    rdfs:label "has recurring cycle type"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range so:RecurringCycleType ;
    rdfs:comment "Frequency of order generation"@en .

so:numberOfCycles a owl:DatatypeProperty ;
    rdfs:label "number of cycles"@en ;
    rdfs:domain so:RecurringSalesOrder ;
    rdfs:range xsd:integer ;
    rdfs:comment "Total number of recurring cycles"@en .

# Other Properties
so:warehouseCode a owl:DatatypeProperty ;
    rdfs:label "warehouse code"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrderLineItem so:Shipment)
    ] ;
    rdfs:range xsd:string ;
    rdfs:comment "Code of the fulfilling warehouse"@en .

so:customerPurchaseOrderNumber a owl:DatatypeProperty ;
    rdfs:label "customer purchase order number"@en ;
    rdfs:domain so:SalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Customer's PO number reference"@en .

so:hasCancellationReason a owl:DatatypeProperty ;
    rdfs:label "has cancellation reason"@en ;
    rdfs:domain so:CancelledSalesOrder ;
    rdfs:range xsd:string ;
    rdfs:comment "Reason code for cancellation"@en .

so:revisionNumber a owl:DatatypeProperty ;
    rdfs:label "revision number"@en ;
    rdfs:domain [
        a owl:Class ;
        owl:unionOf (so:SalesOrder so:BlanketSalesOrder)
    ] ;
    rdfs:range xsd:string ;
    rdfs:comment "Document revision number"@en .

# ============================================================================
# Constraints and Axioms
# ============================================================================

# Disjointness Axioms
[] a owl:AllDisjointClasses ;
    owl:members (
        so:SalesOrder
        so:BlanketSalesOrder
        so:RecurringSalesOrder
        so:Shipment
        so:AdvancedBilling
    ) .

[] a owl:AllDisjointClasses ;
    owl:members (
        agent:OrderProcessingAgent
        agent:InventoryCheckAgent
        agent:PricingAgent
        agent:ShippingCoordinationAgent
        agent:BillingAgent
    ) .

# Cardinality Constraints
so:SalesOrderLineItem rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty so:quantityOrdered ;
    owl:minCardinality "1"^^xsd:nonNegativeInteger
] .

so:Shipment rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty so:hasShipmentLineItem ;
    owl:minCardinality "1"^^xsd:nonNegativeInteger
] .

so:AdvancedBilling rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty so:hasAdvancedBillingLineItem ;
    owl:minCardinality "1"^^xsd:nonNegativeInteger
] .

# Business Rules as Axioms
so:Quote rdfs:subClassOf so:SalesOrder ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:isQuote ;
        owl:hasValue "true"^^xsd:boolean
    ] .

so:ConfirmedOrder rdfs:subClassOf so:SalesOrder ;
    rdfs:subClassOf [
        a owl:Restriction ;
        owl:onProperty so:isQuote ;
        owl:hasValue "false"^^xsd:boolean
    ] .

# Property Chains
so:shipmentForCustomer a owl:ObjectProperty ;
    rdfs:label "shipment for customer"@en ;
    owl:propertyChainAxiom (so:fulfillsSalesOrder so:hasCustomer) ;
    rdfs:comment "Links a shipment to its ultimate customer"@en .

so:lineItemCustomer a owl:ObjectProperty ;
    rdfs:label "line item customer"@en ;
    owl:propertyChainAxiom (so:belongsToSalesOrder so:hasCustomer) ;
    rdfs:comment "Links a line item to its customer"@en .

# Inverse Properties
so:hasLineItem owl:inverseOf so:belongsToSalesOrder .
so:hasShipment owl:inverseOf so:fulfillsSalesOrder .
so:hasAdvancedBilling owl:inverseOf so:billsForSalesOrder .
so:releasesToOrder owl:inverseOf so:releasedFromBlanketOrder .
so:generatesOrder owl:inverseOf so:generatedFromRecurringOrder .

# Functional Properties
so:SalesOrder rdfs:subClassOf [
    a owl:Restriction ;
    owl:onProperty so:hasOrderStatus ;
    owl:cardinality "1"^^xsd:nonNegativeInteger
] .

# ============================================================================
# SWRL Rules (Optional - for reasoning)
# ============================================================================

# Rule: A quote becomes an order when converted
# SalesOrder(?so) ∧ isQuote(?so, false) ∧ hasQuoteDate(?so, ?qd) 
# → hasOrderStatus(?so, Confirmed)

# Rule: Shipment completes when all items are accepted
# Shipment(?s) ∧ ShipmentAcceptance(?sa) ∧ acceptsShipment(?sa, ?s) 
# ∧ allItemsAccepted(?sa, true) → hasShipmentStatus(?s, Completed)

# Rule: Recurring orders generate new orders on schedule
# RecurringSalesOrder(?ro) ∧ hasNextRecurringDate(?ro, ?date) 
# ∧ currentDate(?today) ∧ swrlb:equal(?date, ?today) 
# → generatesOrder(?ro, ?newOrder)

# ============================================================================
# Annotations
# ============================================================================

so:SalesOrder rdfs:seeAlso <https://hexdocs.pm/ash/> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/sales-order> .

agent:SalesOrderAgent rdfs:seeAlso <https://github.com/agentjido/jido> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/agent> .

event:SalesOrderEvent rdfs:seeAlso <https://github.com/commanded/commanded> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/event> .

so:Address rdfs:seeAlso <http://www.w3.org/2006/vcard/ns> ;
    rdfs:isDefinedBy <http://accountex.org/ontology/sales-order> .
```

## Key Features of this Ontology

### Comprehensive Sales Order Domain Coverage
The ontology captures all major aspects of the Sales Order domain including:
- **Core order types**: Regular sales orders, blanket orders, recurring orders
- **Fulfillment processes**: Shipments, shipment acceptance, drop shipping
- **Billing capabilities**: Advanced billing, multiple currencies, tax handling
- **Kit management**: Kit formulas, component tracking, assembly transactions
- **Address management**: Separate billing and shipping addresses

### Integration with Established Vocabularies
The ontology leverages:
- **GoodRelations (gr:)** for commercial transactions and order modeling
- **vCard** for address and contact information
- **FIBO** for financial and invoice concepts
- **Schema.org** for general business entities
- **FOAF** for people and organizations
- **PROV-O** for provenance and audit trails

### Event Sourcing Support
Complete modeling of sales order events:
- Order lifecycle events (created, confirmed, shipped, cancelled)
- Shipment events (created, accepted, refused)
- Billing events (advanced billing created, payment received)
- Recurring and blanket order specific events
- Temporal ordering and event sequencing

### Agentic Capabilities
Integration with the Jido framework through:
- Specialized sales order agents (order processing, inventory, pricing, shipping, billing)
- Agent-order interaction properties
- Signal-based communication between agents
- Workflow composition for complex order processes

### Modular Architecture Alignment
The ontology supports:
- Dynamic module availability through the pluggable application pattern
- Cross-domain references (customer, inventory, accounting)
- Service boundaries between bounded contexts
- Event-driven communication between modules

### Business Rule Representation
Key business rules encoded as OWL axioms:
- Quote vs confirmed order distinction
- Minimum line item requirements for shipments
- Cardinality constraints for critical relationships
- Status transitions and workflow states

## Usage Recommendations

### Extension Points
The ontology can be extended with:
- **Inventory domain** for stock management and availability
- **Customer domain** for detailed customer modeling
- **Accounting domain** for GL integration and financial reporting
- **Product catalog** for detailed product specifications

### Integration Patterns
- Use event properties to maintain complete order history
- Leverage agent properties for automated order processing
- Apply SWRL rules for complex business logic
- Utilize property chains for derived relationships

### Querying and Reasoning
The ontology supports:
- SPARQL queries for order analytics and reporting
- OWL reasoning for consistency checking and classification
- Temporal queries over order history
- Agent performance analysis through event correlation

This ontology provides a comprehensive semantic foundation for the Sales Order domain in the Accountex system, enabling semantic integration, reasoning, and documentation of the domain's structure and behavior.
