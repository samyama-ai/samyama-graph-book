# Paper 7: Scaling Knowledge Graph Federation to One Billion Edges on Commodity Hardware

**Target:** arxiv preprint → seeds VLDB 2027 submission

**Status:** In preparation

**Authors:** Madhulatha Mandarapu, Sandeep Kunkunuru

## Motivation

No existing open-source graph database has demonstrated billion-edge knowledge graph federation with cross-domain queries on commodity hardware at sub-$5 cost. This paper presents the engineering and data architecture that makes it possible, and evaluates it with 140 benchmark queries across 8 knowledge graphs spanning molecular biology to population health.

## Key Claims

1. **74.3 million nodes and 1.07 billion edges** loaded from 4 biomedical KGs (PubMed, Clinical Trials, Pathways, Drug Interactions) in 3 hours 46 minutes on a single r6a.8xlarge AWS spot instance for **$2.50 total cost**
2. **96 of 100 cross-KG queries return data** on the biomedical trifecta, with latencies from 1.3s to 19.4s
3. **305K public health nodes** across 3 additional KGs (Surveillance, Health Determinants, Health Systems) with **40/40 queries passing** in under 500ms each
4. **6-KG federation** from molecular biology to population health in a single Cypher query, bridged by shared properties (Country.iso_code, Drug.drugbank_id, Gene.gene_name)

## Outline (10 pages)

### 1. Introduction (1.5 pages)
- The fragmentation problem: biomedical + public health data spread across silos
- Why graph databases for cross-domain federation
- Contribution summary: scale (1B edges), cost ($2.50), breadth (6 KGs, 8 open data sources)

### 2. Architecture (2 pages)
- Hybrid CSR adjacency (frozen segments + write buffer)
- Two-phase bulk loading: node stubs (777 B/node) + edge stubs (52 B/edge)
- Mid-phase compaction (every 50M edges)
- Memory optimization: sparse ColumnStore, edge arena removal
- Key insight: 13.6x memory reduction via stubs enables 1B edges on 256GB

### 3. Knowledge Graph Catalog (1.5 pages)

| KG | Source | Nodes | Edges | Loader |
|---|---|---|---|---|
| PubMed/MEDLINE | NLM | 66.2M | 1.04B | Rust (pipe-delimited) |
| Clinical Trials | AACT | 7.8M | 27M | Rust (JSON) |
| Pathways | Reactome + STRING + GO | 119K | 835K | Rust (TSV/JSON) |
| Drug Interactions | DrugBank + 4 sources | 245K | 388K | Rust (TSV/CSV) |
| Surveillance | WHO GHO | 217K | 241K | Rust (JSON) |
| Health Determinants | World Bank WDI + WHO | 286K | 286K | Rust (JSON/CSV) |
| Health Systems | WHO SPAR + NHWA | 20K | 19K | Rust (JSON/CSV) |
| Cricket (baseline) | Cricsheet | 37K | 1.4M | Rust (JSON) |

### 4. Federation Architecture (1.5 pages)
- Bridge properties: iso_code (countries), drugbank_id (drugs), gene_name (genes), uniprot_id (proteins)
- No ETL between KGs — federation via property-value matching in Cypher MATCH clauses
- Example: molecular pathway → drug → clinical trial → disease surveillance → country vulnerability

### 5. Benchmark Design (1 page)
- 100 biomedical queries: 35 PubMed, 20 Clinical Trials, 15 Pathways, 15 Drug Interactions, 15 cross-KG
- 40 public health queries: 20 Health Determinants, 10 Health Systems, 10 cross-KG
- Query categories: point lookup, 1-hop traversal, aggregation, cross-indicator, cross-KG federation

### 6. Evaluation (2 pages)

#### 6.1 Scale (biomedical trifecta)
- Load time: 3h46m on r6a.8xlarge (32 vCPU, 256GB), $2.50 spot
- 96/100 queries pass, 3 empty (data gaps), 1 timeout (cartesian explosion)
- Latency: 1.3s – 19.4s per query

#### 6.2 Federation (public health)
- 40/40 queries pass
- Point lookups: 1-4ms, single-hop: 2-25ms, aggregations: 10-134ms, cross-KG: 66-478ms
- Import time: 1.6s (286K nodes) + 0.1s (20K nodes) from .sgsnap

#### 6.3 Cost comparison
- Samyama: $2.50 (spot) / $200-480/mo (persistent)
- Neo4j Aura: $2,000+/mo for comparable scale
- AWS Neptune: $1,500+/mo
- TigerGraph: $5,000+/mo

### 7. Discussion & Limitations (0.5 pages)
- 4 failing queries: PM10 (missing grant data), PM28 (timeout), CT18 (missing edge type), DI05 (data gap)
- Snapshot export limitation for edge-stub-loaded graphs (P0 fix in v0.8)
- Single-node architecture — distributed federation is future work
- No MVCC yet — read-snapshot isolation in progress

### 8. Related Work (1 page)
- LDBC benchmarking council, Neo4j GDS, TigerGraph GSQL, Kuzu, Memgraph
- Microsoft GraphRAG, knowledge graph construction (OpenIE, DeepDive)
- Biomedical KGs: Bio2RDF, Hetionet, PrimeKG

### 9. Conclusion
- First open-source demonstration of billion-edge cross-domain KG federation
- Reproducible: all data open, all loaders open-source, all queries published
- 8 KGs, 8.6M+ nodes, 30M+ edges in registry, all on S3

## Data Availability

All data, loaders, snapshots, queries, and results are open:
- Snapshots: `s3://samyama-data/snapshots/` + GitHub releases
- Queries: `samyama-graph-book/src/data/benchmark/`
- Loaders: `samyama-graph-enterprise/examples/`
- Registry: Supabase `kg_registry` table (8 entries)
