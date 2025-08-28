# Distributed Semantic Knowledge Databases – Comparison Matrix

This document provides a detailed comparison of major **distributed semantic knowledge databases** (triplestores / quadstores) relevant for ERP ontology and semantic-web projects.

---

## 📊 Comparison Matrix

| System        | Open Source | Distributed / Cluster | SPARQL Support | Reasoning (RDFS/OWL/SHACL) | Notes / Strengths |
|---------------|-------------|-----------------------|----------------|----------------------------|-------------------|
| **Amazon Neptune** | ❌ (AWS managed) | ✅ (native in AWS) | ✅ SPARQL 1.1, Gremlin | ❌ Limited (no OWL/SHACL) | Fully managed, integrates with AWS stack |
| **Stardog**   | ❌ (Commercial) | ✅ | ✅ SPARQL 1.1 | ✅ Full reasoning (RDFS, OWL2, SHACL) | Enterprise-grade, strong inference & virtualization |
| **GraphDB (Ontotext)** | ❌ (Commercial, free version limited) | ✅ (Enterprise clustering) | ✅ SPARQL 1.1 | ✅ RDFS, OWL-Horst, SHACL | Widely used in publishing, healthcare, finance |
| **AllegroGraph** | ❌ (Commercial) | ✅ | ✅ SPARQL 1.1, GraphQL, JSON-LD | ✅ Advanced reasoning + temporal/geo | Large-scale enterprise & government deployments |
| **Virtuoso (OpenLink)** | ✅ (Community edition, Enterprise for cluster) | ✅ (Enterprise only) | ✅ SPARQL 1.1 + SQL | ⚠️ Limited inference compared to Stardog/GraphDB | Popular for Linked Open Data (LOD) cloud |
| **TerminusDB** | ✅ (Open source, TerminusX cloud) | ✅ (via cloud / replication) | ✅ SPARQL subset + JSON-LD | ❌ Limited | Git-like versioning of knowledge graphs |
| **Blazegraph** | ✅ (but unmaintained) | ⚠️ Yes, but legacy | ✅ SPARQL 1.1 | ❌ Limited | Former Wikidata backend, very fast but abandoned |
| **QLever**    | ✅ (Research project) | ⚠️ Experimental distributed support | ✅ SPARQL 1.1 | ❌ No reasoning | Very fast query engine, academic/research focus |

---

## 📝 Detailed Notes

### Amazon Neptune
- **Managed service only** (not open source).  
- Excellent for **scalability and cloud-native integration**.  
- Limited reasoning capabilities (mostly query-only).  

### Stardog
- Best for **enterprise reasoning use-cases** (RDFS, OWL2, SHACL).  
- **Virtualization** allows querying across heterogeneous sources.  
- Commercial licensing required.  

### GraphDB (Ontotext)
- Strong reasoning support, especially in SHACL validation.  
- Offers **replication and clustering** in enterprise edition.  
- Frequently used in publishing and life sciences.  

### AllegroGraph
- Distributed, fault-tolerant design.  
- Unique features: **temporal and geospatial reasoning**.  
- Enterprise deployments in finance, healthcare, and defense.  

### Virtuoso Universal Server
- **Community edition** supports single-node RDF.  
- **Enterprise edition** adds clustering & replication.  
- De facto choice for **Linked Open Data (LOD)** hosting.  

### TerminusDB
- Open source with **document + RDF hybrid model**.  
- Version-control-like operations on graphs.  
- Distributed mainly through **TerminusX SaaS**.  

### Blazegraph
- High performance, especially in analytic queries.  
- No longer actively maintained since AWS acquisition.  
- Still used in some research environments.  

### QLever
- Extremely fast query engine for RDF data.  
- Good for **research and prototyping**.  
- Limited in reasoning and enterprise features.  

---

## ✅ Recommendations

- **For enterprise-scale ERP ontologies with reasoning** → **Stardog** or **GraphDB**.  
- **For AWS-native distributed deployment** → **Amazon Neptune**.  
- **For research, prototyping, or Elixir integration with SPARQL** → **QLever**.  
- **For open data publishing at scale** → **Virtuoso Enterprise**.  

---

