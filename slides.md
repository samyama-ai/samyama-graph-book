---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
style: |
  section {
    font-family: 'Inter', 'Helvetica Neue', sans-serif;
  }
  h1 {
    color: #1a1a2e;
  }
  h2 {
    color: #16213e;
  }
  table {
    font-size: 0.85em;
  }
  code {
    font-size: 0.8em;
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1em;
  }
---

# Samyama Graph Database
## A Unified Graph-Vector Engine with In-Database Optimization

**v0.5.12** | Built in Rust | Powered by Mechanical Sympathy
*Sandeep Kunkunuru & Madhulatha Sandeep*

---

## The Fragmentation Problem

Modern AI and industrial applications require **four distinct workloads**:

| Workload | Typical Solution | Pain Point |
| :--- | :--- | :--- |
| Graph Traversal (OLTP) | Neo4j | JVM GC pauses, pointer-heavy storage |
| Vector Search | Pinecone / Weaviate | Separate store, sync overhead |
| Graph Analytics (OLAP) | Spark / GraphX | ETL pipeline, minutes of latency |
| Optimization / OR | Python / Gurobi | Data movement, license costs |

**Result**: Data silos, synchronization overhead, operational complexity.

---

## The Samyama Solution

**One binary. Four workloads. Zero GC pauses.**

```
                    ┌──────────────────────────────────┐
                    │        OpenCypher + RESP          │
                    ├──────────┬───────────┬────────────┤
                    │  Graph   │  Vector   │ Optimization│
                    │  Engine  │  Search   │  22 Solvers │
                    ├──────────┴───────────┴────────────┤
                    │    Vectorized Executor (28 ops)    │
                    ├───────────────────────────────────┤
                    │  RocksDB + MVCC + Raft Consensus  │
                    └───────────────────────────────────┘
```

- **Property Graph** with ~90% OpenCypher coverage
- **HNSW Vector Index** with Cosine, L2, Dot Product
- **CSR Analytics Engine** with 14 graph algorithms
- **22 Metaheuristic Solvers** (Jaya, PSO, DE, NSGA-II, ...)

---

## Why Rust?

| Metric | Rust (Samyama) | Go (Ref) | Java (Ref) |
| :--- | :---: | :---: | :---: |
| **2-Hop Execution** | **12 ms** | 45 ms | 38 ms |
| **Memory Footprint** | **450 MB** | 850 MB | 1,200 MB |
| **GC Pauses** | **0 ms** | 5-50 ms | 10-100 ms |

- **Memory safety** without garbage collection (ownership + borrowing)
- **Zero-cost abstractions** (traits, generics, iterators)
- **Fearless concurrency** (`Send`/`Sync` + Rayon data parallelism)
- Compiles to a single static binary

---

## Core Architecture: Mechanical Sympathy

```
  NodeId (u64) ──→ Vec<Vec<Node>>     ← Versioned Arena (O(1) access)
  EdgeId (u64) ──→ Vec<Vec<Edge>>     ← Contiguous memory layout

  ColumnStore:  "age"  → [25, 30, 42, 28, ...]   ← Cache-friendly arrays
                "name" → ["Alice", "Bob", ...]
```

**Key Design Decisions**:

| Pattern | Benefit |
| :--- | :--- |
| Arena allocation (`Vec<Vec<T>>`) | Cache-friendly, no hash lookups |
| Columnar property storage | CPU prefetch, SIMD-friendly layout |
| Vectorized batches (1,024) | Amortize function call overhead |
| Late materialization (`NodeRef`) | 4-5x memory bandwidth reduction |

---

## Late Materialization (ADR-012)

**Before**: Scan clones full nodes at every operator stage.
**After**: Scan produces `Value::NodeRef(id)` — properties resolved only at RETURN.

```
  Scan ──→ Filter ──→ Expand ──→ Project ──→ Limit
  (IDs)    (IDs)      (IDs)     (resolve)   (output)
```

| Query Type | Before | After | Speedup |
| :--- | :---: | :---: | :---: |
| **1-Hop Traversal** | 164 ms | **41 ms** | **4.0x** |
| **2-Hop Traversal** | 1,220 ms | **259 ms** | **4.7x** |

Bottleneck analysis: Parse (54%) + Plan (44%) >> Execute (2%).

---

## Query Engine: 28 Physical Operators

Hybrid **Volcano-Vectorized** model with batch size 1,024:

| Category | Operators |
| :--- | :--- |
| **Scan** | NodeScan, IndexScan |
| **Traversal** | Expand, OptionalExpand, VariableLengthExpand |
| **Filter** | Filter, LabelFilter |
| **Join** | HashJoin, CartesianProduct |
| **Aggregation** | Aggregate (COUNT, SUM, AVG, MIN, MAX, COLLECT) |
| **Write** | Create, Delete, Set, Remove, Merge |
| **Sort/Limit** | Sort, Limit, Skip, Distinct |
| **Specialized** | Unwind, Union, Algorithm, VectorSearch, Exists, Project |

Cost-based optimizer uses `GraphStatistics` for index selection and predicate pushdown.

---

## Graph Analytics: CSR Projection

The `GraphView` projects into **Compressed Sparse Row** for OLAP:

```
  out_offsets:  [ 0,  2,  4,  5,  7 ]
  out_targets:  [ 1,  3,  0,  2,  3,  0,  1 ]
  weights:      [1.0,2.0,1.0,3.0,1.0,2.0,4.0]
```

**14 algorithms** across 5 categories:

| Category | Algorithms |
| :--- | :--- |
| Centrality | PageRank (with dangling redistribution), LCC (directed + undirected) |
| Community | WCC (Union-Find), SCC (Tarjan), CDLP, Triangle Counting |
| Pathfinding | BFS, Dijkstra, BFS All Shortest Paths |
| Network Flow | Edmonds-Karp (Max Flow), Prim's MST |
| Statistical | PCA (Randomized SVD + Power Iteration) |

---

## PCA & Dimensionality Reduction

Two solvers with automatic selection:

| Solver | Algorithm | Complexity | When Used |
| :--- | :--- | :--- | :--- |
| **Randomized SVD** | Halko-Martinsson-Tropp | O(n*d*k) | n > 500 (default) |
| **Power Iteration** | Classical deflation | O(n*d*k*iter) | n <= 500 |

```rust
// Via SDK
let result = client.pca("Person", &["age", "income", "score"],
    PcaConfig { n_components: 2, solver: PcaSolver::Auto, ..default() }
).await?;
// result.components, result.explained_variance, result.transform()
```

**GPU PCA** (Enterprise): 5 WGSL shaders with tiled covariance (64-sample tiles), fused power iteration + normalize in single dispatch. Threshold: 50K nodes, d > 32.

---

## In-Database Optimization

**22 metaheuristic solvers** — no data movement to Python.

```cypher
CALL algo.or.solve({
  algorithm: 'NSGA2',
  label: 'Generator',
  objectives: ['cost', 'emissions'],
  constraints: [{ property: 'load', max: 500.0 }],
  population_size: 100
}) YIELD pareto_front
```

| Family | Solvers |
| :--- | :--- |
| Metaphor-less | Jaya, QOJAYA, Rao (1-3), TLBO, ITLBO, GOTLBO |
| Swarm/Evolutionary | PSO, DE, GA, GWO, ABC, BAT, Cuckoo, Firefly, FPA |
| Physics-based | GSA, SA, HS, BMR, BWR |
| Multi-objective | NSGA-II, MOTLBO |

All solvers leverage Rayon for parallel fitness evaluation. Multi-objective solvers use the **Constrained Dominance Principle** for feasibility-first Pareto optimization.

---

## Vector Search & Graph RAG

**HNSW indexing** (via `hnsw_rs`) with three distance metrics:

| Metric (128-dim, k=10) | Performance |
| :--- | :--- |
| Cosine distance (10K vectors) | 15,872 QPS |
| L2 distance (10K vectors) | 15,014 QPS |
| Search 50K vectors | 10,446 QPS |

**Graph RAG** = Vector search + Graph traversal in one query:
```cypher
CALL vector.search('embedding_idx', $query_vector, 10) YIELD node, score
MATCH (node)-[:AUTHORED]->(paper)-[:CITES]->(ref)
RETURN paper.title, ref.title, score
```

Filters applied *inside* the execution engine, not post-hoc.

---

## Agentic Enrichment (GAK)

**Generation-Augmented Knowledge**: The inverse of RAG.

```
  Query hits missing data
       │
       ▼
  Event Trigger fires
       │
       ▼
  AgentRuntime activates
       │
       ├──→ WebSearchTool (discovers information)
       ├──→ NLQClient (generates Cypher)
       │
       ▼
  CREATE commands fill knowledge gap
       │
       ▼
  Database self-evolves
```

**Safety**: Schema validation, destructive query rejection, rate limiting.
**NLQ Providers**: OpenAI, Gemini, Ollama, Claude.

---

## RDF & SPARQL Support

Native RDF support via the `oxrdf` crate:

| Feature | Status |
| :--- | :--- |
| Triple/Quad Store | In-memory with SPO/POS/OSP indices |
| Turtle (.ttl) | Read + Write |
| N-Triples (.nt) | Read + Write |
| RDF/XML (.rdf) | Read + Write |
| JSON-LD (.jsonld) | Write only |
| SPARQL | Parser (spargebra); execution in progress |
| Namespaces | rdf, rdfs, xsd, owl, foaf, dc pre-loaded |

Property Graph to RDF bidirectional mapping framework defined.

---

## Developer Ecosystem (v0.5.12)

| SDK | Transport | Install |
| :--- | :--- | :--- |
| **Rust** (`samyama-sdk`) | Embedded + HTTP | `cargo add samyama-sdk` |
| **Python** (PyO3) | Embedded + HTTP | `pip install samyama` |
| **TypeScript** | HTTP | `npm install samyama-sdk` |
| **CLI** | HTTP | `cargo install samyama-cli` |
| **OpenAPI** | HTTP | `POST /api/query`, `GET /api/status` |

```rust
// Rust SDK — Embedded (zero overhead)
let client = EmbeddedClient::new();
client.query("default", "CREATE (n:Person {name: 'Alice'})").await?;

// Extension traits for algorithms & vectors
let scores = client.page_rank(config, "Person", "KNOWS").await?;
let results = client.vector_search("idx", &query_vec, 10).await?;
```

---

## Samyama Enterprise Edition

Production-grade capabilities for mission-critical deployments:

| Feature | Details |
| :--- | :--- |
| **GPU Acceleration** | wgpu (Metal/Vulkan/DX12): PageRank, CDLP, LCC, PCA, Bitonic Sort |
| **High Availability** | HTTP/2 Raft, TLS, snapshot streaming, cluster metrics |
| **Backup & PITR** | Full + incremental snapshots, microsecond-precision restore |
| **Observability** | 200+ Prometheus metrics, health probes, audit trail |
| **Multi-tenancy** | Column Family isolation, per-tenant quotas |
| **License** | Ed25519 JET tokens, machine fingerprint, revocation lists |

RPO: zero data loss. RTO: minutes (full), seconds (WAL replay).

---

## GPU Acceleration: The Crossover Point

| Algorithm | Scale | CPU | GPU | Speedup |
| :--- | :---: | :---: | :---: | :---: |
| PageRank | 10K | **0.6 ms** | 9.3 ms | 0.06x |
| PageRank | 100K | 8.2 ms | **3.1 ms** | **2.6x** |
| PageRank | 1M | 92.4 ms | **11.2 ms** | **8.2x** |
| LCC | 3.8M (cit-Patents) | 9.6s | **4.7s** | **2.0x** |

GPU crossover: **~100K nodes** for general algorithms, **~50K** for PCA.
Below threshold, CPU-GPU memory transfer overhead dominates.

---

## Performance Summary (Mac Mini M4, 16GB)

| Benchmark | Result |
| :--- | :--- |
| **Node Ingestion (CPU)** | 255,120 ops/s |
| **Node Ingestion (GPU)** | 412,036 ops/s |
| **Edge Ingestion (CPU)** | 4,211,342 ops/s |
| **Edge Ingestion (GPU)** | 5,242,096 ops/s |
| **Cypher OLTP (1M nodes)** | 115,320 QPS, 0.008 ms avg |
| **Late Materialization** | 4.0-4.7x speedup |
| **GPU PageRank (1M)** | 8.2x speedup (11.2 ms) |
| **Vector Search (10K, 128d)** | 15,872 QPS |
| **LDBC Graphalytics** | **28/28 tests (100%)** |

---

## LDBC Graphalytics Validation

Industry-standard benchmark for graph analytics correctness:

| Algorithm | XS (2 datasets) | S (3 datasets) | Total |
| :--- | :---: | :---: | :---: |
| BFS | 2/2 | 3/3 | **5/5** |
| PageRank | 2/2 | 3/3 | **5/5** |
| WCC | 2/2 | 3/3 | **5/5** |
| CDLP | 2/2 | 3/3 | **5/5** |
| LCC | 2/2 | 3/3 | **5/5** |
| SSSP | 2/2 | 1/1 | **3/3** |
| **Total** | **12/12** | **16/16** | **28/28** |

S-size datasets: cit-Patents (3.8M vertices, 16.5M edges), datagen-7_5-fb (633K vertices, 68.4M edges), wiki-Talk (2.4M vertices, 5.0M edges).

---

## Distributed Consensus (Raft)

```
  Client ──→ Leader ──→ Append to Log
                  │
                  ├──→ Follower 1 (AppendEntries)
                  ├──→ Follower 2 (AppendEntries)
                  │
                  ← Quorum (2/3) ──→ Commit to GraphStore
                  │
                  └──→ OK to Client
```

- **CP trade-off**: Strong consistency via quorum commits
- **Leader election**: Automatic failover within 1-2 heartbeat intervals
- **Tenant-level sharding**: `SeaHash(tenant_id) % num_shards`
- **Enterprise**: HTTP/2 transport, TLS, snapshot streaming to lagging followers

---

## Research Foundation

Samyama implements algorithms from **30+ peer-reviewed papers**:

| Area | Key Papers |
| :--- | :--- |
| Query Execution | Graefe 1994 (Volcano), Abadi et al. 2008 (Late Materialization) |
| Storage | O'Neil et al. 1996 (LSM-Tree), Mohan et al. 1992 (ARIES WAL) |
| Consensus | Ongaro & Ousterhout 2014 (Raft) |
| Vector Search | Malkov & Yashunin 2018 (HNSW) |
| Graph Analytics | Page et al. 1999, Watts & Strogatz 1998, Tarjan 1972 |
| Optimization | Rao 2016 (Jaya), Deb et al. 2002 (NSGA-II), Kennedy 1995 (PSO) |
| PCA | Halko, Martinsson & Tropp 2011 (Randomized SVD) |
| Benchmarks | Iosup et al. 2016 (LDBC Graphalytics) |

---

## Summary

Samyama is a **unified graph-vector database** that eliminates the need for separate systems:

- **4 workloads in 1 binary**: Graph + Vector + Analytics + Optimization
- **Memory safe**: Rust ownership — zero GC pauses, zero data races
- **Hardware accelerated**: GPU compute shaders for large-scale analytics
- **AI-native**: Graph RAG, Agentic Enrichment, Natural Language Queries
- **Industry validated**: 28/28 LDBC Graphalytics, 115K QPS OLTP
- **Multi-language**: Rust, Python, TypeScript SDKs + CLI + OpenAPI

*https://samyama.ai* | *https://x.com/Samyama_AI*
