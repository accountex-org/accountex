# Ontologies for ERP Accounting and Manufacturing Domains

Enterprise Resource Planning (ERP) spans multiple domains. Below we present existing ontologies covering **accounting/finance** (e.g. accounts payable, receivable, inventory, general ledger) and **manufacturing** (production processes, supply chain), along with relevant research. We also suggest base vocabularies (schema.org, FOAF, GoodRelations) for integration. Each ontology entry includes available RDF/OWL links, key coverage, maintenance status, and usage context.

## Accounting and Financial Ontologies

- **REA (Resource-Event-Agent) Ontology:** A foundational accounting ontology modeling economic transactions in terms of resources, events, and agents. Originally a semantic accounting model, REA eliminates traditional double-entry artifacts (e.g. debits/credits, AR/AP ledgers) by deriving them from economic event data. REA underpins the ISO/IEC 15944-4 “Accounting and Economic Ontology” standard for business transactions, and has influenced ERP process modeling. *Key concepts:* economic **Resource** (goods, services, money), **Event** (increment or decrement of resources), **Agent** (party involved). *Status:* Conceptual model standardized via ISO; used in academic and industry frameworks. Several OWL formalizations exist in literature.

- **FIBO – Financial Industry Business Ontology:** A comprehensive ontology suite (OWL 2 DL) covering financial concepts, maintained by EDM Council (an OMG standard). FIBO includes modules for basic accounting and financial reporting. For example, it defines **Account** and **Transaction** concepts aligned with REA’s economic exchanges. It also models general ledger structures and equity elements. *Key concepts:* financial accounts, account holders, journal entries, contracts, etc. *Maintenance:* Actively maintained with regular releases (open-source on EDM Council GitHub). Part of an industry standard initiative, used in enterprise data modeling.

- **XBRL and Financial Reporting Ontologies:** While not OWL ontologies per se, the XBRL standard provides rich taxonomies for financial statements. Research efforts like **COFRIS** (Convergence of Financial Reporting Standards) use ontologies to align IFRS and US GAAP conceptual frameworks. For example, Blums & Weigand (2024) ground the IFRS and GAAP Conceptual Frameworks in a unified UFO-based ontology, modeling elements like **Asset**, **Liability**, **Revenue** etc., to reconcile semantics across standards. These ontologies are often in OWL/OntoUML and support semantic consistency in financial reporting.

- **ValueFlows Vocabulary:** An open community-developed vocabulary (JSON-LD/OWL) for economic networks and resource planning, based on the REA ontology. It treats all economic activities as **events**, enabling real-time derivation of ledgers and reports. *Key coverage:* material and financial flows (inventory moves, exchanges, production events), linking **Transfers** of goods/money between agents to traditional accounting views. ValueFlows extends REA to collaborative supply chains and even ecological accounting. *Status:* Active open-source effort (GitHub valueflows).

## E-Commerce and Business Ontologies

- **GoodRelations Ontology (OWL):** A widely used e-commerce ontology for products, offers, pricing, and business entities. GoodRelations defines classes for **Product/Service**, **Offer**, **Business**, and properties for price, payment, warranty, inventory level, etc. It was incorporated into **schema.org** (the schema.org commercial extension). *Key concepts:* Product catalogs, store locations, opening hours, payment methods, available quantity. *Status:* Stable and broadly adopted.

- **Schema.org Vocabulary:** A general web vocabulary covering many domains. In ERP context, schema.org (which includes GoodRelations terms) provides types like **Product**, **Offer**, **Organization**, **Invoice**, **Order**, etc. *Key concepts:* broad coverage – products, monetary amounts, customers, payments, delivery. *Status:* Continuously maintained by an open consortium.

- **FOAF Ontology:** A lightweight ontology for describing people, organizations, and their relationships. FOAF defines classes like **foaf:Person**, **foaf:Organization**, and properties for names, contacts, and social links. *Key concepts:* Person, Organization, and their attributes. *Status:* Stable and widely used.

- **W3C Organization Ontology (ORG):** A W3C-recommended OWL ontology for organizational structure. ORG models hierarchies of organizations, sub-units, roles, and sites. *Key concepts:* Organization, OrganizationalUnit, Role, Post, and membership relations.

## Manufacturing and Supply Chain Ontologies

- **Industrial Ontologies Foundry (IOF) Core:** An open reference ontology suite for digital manufacturing. The **IOF Core** ontology is a mid-level ontology (OWL) that defines generic manufacturing and enterprise terms used across multiple sub-domains. *Key concepts:* asset, facility, material, process. *Status:* Actively developed (OAGi/IOF).

- **IOF Supply Chain Reference Ontology (SCRO):** A modular ontology under IOF focused on supply chain and logistics. *Key concepts:* Supplier, Shipment, Order, Logistics Facility, Inventory. *Status:* Provisional, under development.

- **Enterprise Control Ontology (ECO):** An ontology aligned with ISA-95 standard for enterprise-control system integration. Includes classes for **Inventory**, **ProductionSchedule**, **Equipment**, **Order dispatching**, and **Maintenance** activities. *Status:* Research prototype.

- **MASON – Manufacturing Semantics Ontology:** An upper ontology for manufacturing domain. Defines abstract classes for **Manufacturing Resource**, **Material**, and **Operation**. *Status:* Academic proposal.

- **Process Specification Language (PSL):** ISO 18629 ontology for manufacturing process representation. Covers concepts for **processes, activities, and sequencing**. *Status:* ISO standard, maintained by NIST.

- **Maintenance Ontologies:** Focus on maintenance and asset management – relevant if ERP covers plant maintenance (e.g. MaintRefOnto, ROMAIN).

## Summary and Recommendations

**Direct ERP Ontologies:** Research prototypes exist (e.g. ERPI4.0-Onto) that model ERP modules like Finance, Inventory, CRM, SCM, HR, etc.

**Base Ontologies for ERP:** Recommended modular approach:
- *Accounting/Finance:* REA ontology or FIBO for economic events and accounts.
- *Products & Orders:* GoodRelations/schema.org.
- *Organizations & People:* FOAF and ORG ontology.
- *Manufacturing Processes:* PSL and IOF Core, ECO, MASON.
- *Supply Chain & Inventory:* SCRO and ValueFlows.

## Sources

- Amara, F.Z. et al. “Ontological Modeling of ERP for Industry 4.0.” CEUR-WS (2022).
- McCarthy, W.E. “The REA Accounting Model.” The Accounting Review (1982).
- EDM Council FIBO Specification.
- Hepp, M. GoodRelations Ontology Specification.
- W3C FOAF Spec 0.99.
- Sapel, P. et al. “A review and classification of manufacturing ontologies.” J. Intelligent Manufacturing (2025).
