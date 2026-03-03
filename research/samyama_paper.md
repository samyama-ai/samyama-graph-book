# Samyama: A Unified Graph-Vector Database with In-Database Optimization, Agentic Enrichment, and Hardware Acceleration

**Authors**: Sandeep Kunkunuru, Madhulatha Sandeep
**Date**: March 2026 | **Version**: v0.5.12
**Keywords**: Graph Databases, Vector Search, Distributed Systems, Metaheuristic Optimization, Rust, GPU Acceleration, Agentic AI, RDF, LDBC.

---

## Abstract

Modern data architectures are fragmented across graph databases, vector stores, analytics engines, and optimization solvers, resulting in complex ETL pipelines, synchronization overhead, and operational burden. We present **Samyama**, a high-performance, distributed graph-vector database written in Rust that unifies these workloads into a single engine. Samyama combines a RocksDB-backed persistent store with a versioned-arena MVCC model, a vectorized query executor with 28 physical operators, a dedicated CSR-based analytics engine, and native RDF/SPARQL support. The system integrates 22 metaheuristic optimization solvers directly into its query language, implements HNSW vector indexing with Graph RAG capabilities, and introduces "Agentic Enrichment" for autonomous graph expansion via LLMs. A comprehensive SDK ecosystem (Rust, Python, TypeScript) and CLI provide multiple access patterns.

The **Samyama Enterprise Edition** adds GPU acceleration via wgpu (Metal, Vulkan, DX12), production-grade observability, point-in-time recovery, and hardened high availability with HTTP/2 Raft transport.

Our evaluation on commodity hardware (Mac Mini M4, 16GB RAM) demonstrates:
- **Ingestion**: 255K nodes/s (CPU), 412K nodes/s (GPU-accelerated), 4.2M–5.2M edges/s
- **OLTP throughput**: 115K Cypher queries/sec at 1M nodes
- **Late materialization**: 4.0–4.7x latency reduction on multi-hop traversals
- **GPU PageRank**: 8.2x speedup at 1M nodes
- **LDBC Graphalytics**: 28/28 tests passed (100% validation)

These results establish Samyama as a robust foundation for next-generation AI and industrial applications.

---

## 1. Introduction

The rise of Large Language Models (LLMs) has popularized Retrieval-Augmented Generation (RAG), creating demand for systems that handle both relational structure (graphs) and semantic similarity (vectors). Simultaneously, industrial applications increasingly require in-database optimization for resource allocation, scheduling, and supply chain management. Existing solutions force developers to compose architectures from disparate systems—Neo4j for graphs, Pinecone for vectors, Spark for analytics, and Python/Gurobi for optimization—leading to data gravity problems and synchronization overhead.

Samyama (Sanskrit for "Integration") is designed as an AI-native database that treats graphs, vectors, and optimization as first-class citizens within a single memory-safe engine. Key contributions include:

1. **Unified engine**: Property graph + vector search + analytics + optimization in one binary
2. **Late materialization**: `NodeRef`-based lazy property resolution achieving 4.7x traversal speedup
3. **In-database optimization**: 22 metaheuristic solvers accessible directly via Cypher procedures
4. **Agentic Enrichment (GAK)**: Autonomous graph expansion using LLM tool-calling
5. **Cross-platform GPU acceleration**: wgpu-based compute shaders for graph algorithms and PCA
6. **SDK ecosystem**: Rust, Python (PyO3), TypeScript SDKs with embedded and remote access patterns
7. **RDF interoperability**: Native RDF data model with Turtle/N-Triples/RDF-XML serialization
8. **Industry validation**: 100% LDBC Graphalytics pass rate (28/28 tests)

## 2. System Architecture

Samyama is built on a modern Rust stack for memory safety and zero-cost abstractions.

### 2.1 Storage Engine

We utilize **RocksDB** for persistence, employing a tiered Log-Structured Merge (LSM) tree with LZ4 and Zstd compression. Data isolation is achieved through **Column Families**, providing independent compaction, backup, and key namespaces per tenant.

Key design: `NodeId` and `EdgeId` are direct `u64` indices into contiguous arena storage (`Vec<Vec<T>>`), eliminating hash lookups and providing O(1) access with cache-friendly memory layout.

### 2.2 Memory Management & MVCC

Samyama implements **Multi-Version Concurrency Control (MVCC)** within a versioned-arena structure. The inner vector stores version history, enabling **Snapshot Isolation** without read locks. Write atomicity is guaranteed via RocksDB `WriteBatch` + WAL.

ACID guarantees: Atomicity (WriteBatch), Consistency (schema validation + Raft quorum), Isolation (per-query via RwLock, MVCC foundation), Durability (RocksDB + Raft replication).

### 2.3 Query & Execution Engine

Samyama supports ~90% of **OpenCypher**. Queries are parsed via a PEG parser (`pest` crate with atomic keyword rules for word boundary enforcement) and executed using a hybrid **Volcano-Vectorized** model with batch size 1,024.

The engine implements **28 physical operators** organized across scan, traversal, filter, join, aggregation, sort, write, index, and specialized categories. A cost-based optimizer uses `GraphStatistics` (label counts, edge counts, property selectivity) for index selection, predicate pushdown, and join ordering.

**Late Materialization** (ADR-012): Scan operators produce `Value::NodeRef(id)` instead of full node clones. Properties are resolved on-demand via the `ColumnStore` at the final `ProjectOperator`, reducing memory bandwidth by 4–5x.

### 2.4 RDF & SPARQL

Samyama provides native RDF support via the `oxrdf` crate:
- **Triple Store**: In-memory with SPO/POS/OSP indices for O(1) pattern matching
- **Serialization**: Turtle, N-Triples, RDF/XML (read/write), JSON-LD (write)
- **Namespace Management**: Pre-loaded prefixes (rdf, rdfs, xsd, owl, foaf, dc)
- **SPARQL**: Parser infrastructure via `spargebra`; query execution in development

## 3. High-Performance Analytics

### 3.1 CSR Projection

For global graph analytics, Samyama projects the relevant subgraph into a **Compressed Sparse Row (CSR)** format (`GraphView`). Three contiguous arrays (`out_offsets`, `out_targets`, `weights`) enable sequential memory access with near-perfect CPU prefetch accuracy and zero-lock parallelism via `rayon`.

### 3.2 Algorithm Library

The `samyama-graph-algorithms` crate provides 14 algorithms:

| Category | Algorithms |
| :--- | :--- |
| **Centrality** | PageRank (with dangling redistribution), LCC (directed + undirected) |
| **Community** | WCC (Union-Find), SCC (Tarjan), CDLP, Triangle Counting |
| **Pathfinding** | BFS, Dijkstra, BFS All Shortest Paths |
| **Network Flow** | Edmonds-Karp (Max Flow), Prim's MST |
| **Statistical** | PCA (Randomized SVD + Power Iteration) |

PCA implements the Halko-Martinsson-Tropp algorithm for Randomized SVD with O(n·d·k) complexity, auto-selecting over Power Iteration when n > 500 nodes.

## 4. In-Database Optimization

Unique to Samyama is the integration of **22 metaheuristic optimization solvers** in the `samyama-optimization` crate, accessible directly through Cypher procedures:

```cypher
CALL algo.or.solve({
  algorithm: 'NSGA2',
  label: 'Generator',
  objectives: ['cost', 'emissions'],
  constraints: [{ property: 'load', max: 500.0 }],
  population_size: 100
}) YIELD pareto_front
```

Solvers include: Jaya, QOJAYA, Rao (1-3), TLBO, ITLBO, GOTLBO, PSO, DE, GA, GWO, ABC, BAT, Cuckoo, Firefly, FPA, GSA, SA, HS, BMR, BWR, NSGA-II, and MOTLBO. Multi-objective solvers implement the **Constrained Dominance Principle** for feasibility-first Pareto optimization. All solvers leverage Rayon for parallel fitness evaluation across CPU cores.

## 5. AI & Agentic Enrichment

### 5.1 Vector Search

Samyama implements **HNSW** indexing (via `hnsw_rs`) for millisecond-speed approximate nearest neighbor search with Cosine, L2, and Dot Product metrics. The `VectorSearchOperator` integrates with standard graph operators for **Graph RAG**—combining vector retrieval with graph traversal in a single query execution.

### 5.2 Agentic Enrichment (GAK)

We introduce **Generation-Augmented Knowledge (GAK)**: an autonomous loop where the database uses LLMs to fetch and create missing data. The `AgentRuntime` manages tool-calling agents (`WebSearchTool`, `NLQClient`) that discover information and generate Cypher `CREATE` commands, transforming the database from a passive store to a self-evolving knowledge graph. Safety validation includes schema checking, destructive query rejection, and rate limiting.

### 5.3 Natural Language Query (NLQ)

The `NLQPipeline` converts natural language questions to Cypher via LLM providers (OpenAI, Gemini, Ollama, Claude). Generated queries undergo safety validation (`is_safe_query()`) before execution.

## 6. SDK Ecosystem

Samyama provides a multi-language SDK ecosystem:

| SDK | Transport | Features |
| :--- | :--- | :--- |
| **Rust** (`samyama-sdk`) | Embedded + HTTP | Full: algorithms, vector, NLQ, persistence |
| **Python** (`samyama`, PyO3) | Embedded + HTTP | Cypher queries, status |
| **TypeScript** (`samyama-sdk`) | HTTP only | Cypher queries, status |
| **CLI** (`samyama-cli`) | HTTP | query, status, ping, shell (REPL) |
| **OpenAPI** | HTTP | `POST /api/query`, `GET /api/status` |

The Rust SDK's `SamyamaClient` trait provides `EmbeddedClient` (in-process, zero overhead) and `RemoteClient` (HTTP). Extension traits `AlgorithmClient` and `VectorClient` offer direct API access to algorithms and vector operations without Cypher.

## 7. Enterprise Edition

The Enterprise Edition adds production-grade capabilities:

### 7.1 GPU Acceleration (wgpu)

Cross-platform GPU acceleration via WGSL compute shaders targeting Metal (macOS), Vulkan (Linux), and DX12 (Windows). GPU-accelerated algorithms: PageRank, CDLP, LCC, Triangle Counting, and PCA. Additional GPU operators: parallel SUM aggregation and bitonic sort for ORDER BY on large result sets.

GPU PCA uses 5 specialized shaders with tiled covariance computation (64-sample tiles) and fused power iteration with in-GPU normalization. Thresholds: `MIN_GPU_PCA = 50,000` nodes, `d > 32` dimensions.

### 7.2 Observability & Operations

- **Prometheus `/metrics`**: 200+ real-time counters and histograms
- **Health API**: Liveness/readiness probes for Kubernetes
- **Slow Query Log**: Configurable threshold, ring buffer storage
- **Audit Trail**: Append-only JSONL with cryptographic integrity
- **ADMIN.* Commands**: STATUS, METRICS, TENANTS, SLOWLOG, CONFIG, BACKUP, LICENSE

### 7.3 Backup & Point-in-Time Recovery

Full snapshots via RocksDB `BackupEngine`, incremental WAL-based delta backups, and PITR with microsecond-precision timestamp restoration. RPO: zero data loss. RTO: minutes for full restore, seconds for WAL replay.

### 7.4 Hardened High Availability

HTTP/2 Raft transport with TLS, automated snapshot streaming to lagging followers, and cluster metrics (role, term, replication lag). +850 lines of code over OSS Raft implementation.

### 7.5 License Hardening

Ed25519-signed JET tokens with machine fingerprint binding (SHA-256 of hostname + MAC), clock drift protection (1-hour tolerance), usage enforcement (node count limits), and signed revocation lists.

## 8. Performance Evaluation

All benchmarks on Mac Mini M4 (Apple M4, 10-core, 16GB LPDDR5X, macOS Tahoe 26.2).

### 8.1 Ingestion Throughput

| Operation | CPU-Only | GPU-Accelerated |
| :--- | :---: | :---: |
| **Node Ingestion** | 255,120 ops/s | **412,036 ops/s** |
| **Edge Ingestion** | 4,211,342 ops/s | **5,242,096 ops/s** |

### 8.2 Cypher OLTP Throughput

| Graph Scale | Queries/sec | Avg Latency |
| :---: | :---: | :---: |
| 10,000 nodes | 35,360 QPS | 0.028 ms |
| 100,000 nodes | 116,373 QPS | 0.008 ms |
| 1,000,000 nodes | 115,320 QPS | 0.008 ms |

Index-driven O(1)/O(log n) access ensures near-constant throughput as graph size increases.

### 8.3 Late Materialization Impact

| Query Type | Before | After | Speedup |
| :--- | :---: | :---: | :---: |
| **1-Hop Traversal** | 164.11 ms | **41.00 ms** | **4.0x** |
| **2-Hop Traversal** | 1,220.00 ms | **259.00 ms** | **4.7x** |

Bottleneck analysis: Parse (54%) + Plan (44%) >> Execute (2%). AST caching is the next optimization target.

### 8.4 GPU Acceleration

| Algorithm | Scale | CPU | GPU | Speedup |
| :--- | :---: | :---: | :---: | :---: |
| PageRank | 10K | **0.6 ms** | 9.3 ms | 0.06x |
| PageRank | 100K | 8.2 ms | **3.1 ms** | **2.6x** |
| PageRank | 1M | 92.4 ms | **11.2 ms** | **8.2x** |
| LCC | 3.8M (cit-Patents) | 9.6s | **4.7s** | **2.0x** |

Crossover point: ~100K nodes for general algorithms; ~50K for PCA.

### 8.5 Vector Search

| Metric (128-dim, k=10) | Performance |
| :--- | :---: |
| Cosine distance (10K vectors) | 15,872 QPS |
| L2 distance (10K vectors) | 15,014 QPS |
| Search 50K vectors | 10,446 QPS |

### 8.6 LDBC Graphalytics Validation

| Algorithm | XS (2 datasets) | S (3 datasets) | Total |
| :--- | :---: | :---: | :---: |
| BFS | ✅ 2/2 | ✅ 3/3 | 5/5 |
| PageRank | ✅ 2/2 | ✅ 3/3 | 5/5 |
| WCC | ✅ 2/2 | ✅ 3/3 | 5/5 |
| CDLP | ✅ 2/2 | ✅ 3/3 | 5/5 |
| LCC | ✅ 2/2 | ✅ 3/3 | 5/5 |
| SSSP | ✅ 2/2 | ✅ 1/1 | 3/3 |
| **Total** | **12/12** | **16/16** | **28/28** |

S-size datasets: cit-Patents (3.8M vertices, 16.5M edges), datagen-7_5-fb (633K vertices, 68.4M edges), wiki-Talk (2.4M vertices, 5.0M edges).

### 8.7 Technology Comparison

| Metric | Rust (Samyama) | Go (Ref) | Java (Ref) |
| :--- | :---: | :---: | :---: |
| **2-Hop Execution** | **12 ms** | 45 ms | 38 ms |
| **Memory Footprint** | **450 MB** | 850 MB | 1,200 MB |
| **GC Pauses** | **0 ms** | 5–50 ms | 10–100 ms |

## 9. Related Work

**Neo4j** is the most widely deployed graph database but suffers from JVM garbage collection pauses and pointer-heavy storage causing cache misses in multi-hop traversals. **FalkorDB** (formerly RedisGraph, deprecated 2023) uses GraphBLAS sparse matrices for fast linear algebra but lacks vector search and optimization capabilities. **Kuzudb** is an embedded graph database with columnar storage but focuses on analytical queries without the transactional, vector, or optimization features of Samyama. **DuckDB** provides fast analytical processing but is a relational engine, requiring graph queries to be expressed as recursive CTEs.

Samyama differentiates by unifying all four workloads (OLTP, OLAP, vector, optimization) in a single memory-safe binary with hardware acceleration.

## 10. Conclusion

Samyama bridges the gap between transactional integrity and analytical intelligence. By unifying graphs, vectors, optimization, and RDF in a memory-safe distributed system with GPU acceleration, it provides a scalable architecture for the future of agentic AI. The SDK ecosystem lowers the barrier to adoption across Rust, Python, and TypeScript ecosystems, while the Enterprise Edition provides the operational maturity required for global industrial deployments.

100% LDBC Graphalytics validation confirms algorithmic correctness. Benchmark results demonstrate that Samyama achieves competitive performance on commodity hardware while maintaining the safety guarantees of Rust.

---

## Appendix: System Illustrations

1. **System Architecture Diagram**: Flow from OpenCypher queries through the Vectorized Executor to the RocksDB/MVCC storage layer.
![Samyama Architecture](./images/architecture.svg){width=90%}

2. **CSR Data Layout**: Mapping of `out_offsets` and `out_targets` for cache-efficient traversal.
![CSR Layout](./images/csr_layout.svg){width=90%}

3. **Agentic Enrichment Loop**: Event-driven trigger, LLM tool-calling, and graph update.
![Agentic Loop](./images/agentic_loop.svg){width=90%}

4. **Pareto Front Visualization**: NSGA-II multi-objective optimization results for supply chain scenario.
![Pareto Front](./images/pareto_front.svg){width=90%}
