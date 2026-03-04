# Frequently Asked Questions

This FAQ covers common questions about Samyama's architecture, usage, and capabilities. Use your browser's search (Ctrl+F / Cmd+F) or the mdBook search bar to quickly find answers.

---

## Getting Started

### How do I install and run Samyama?

```bash
# Clone and build
git clone https://github.com/samyama-ai/samyama-graph.git
cd samyama-graph
cargo build --release

# Start the server (RESP on :6379, HTTP on :8080)
cargo run --release

# Run a demo
cargo run --example banking_demo
```

### What protocols does Samyama support?

Samyama exposes two protocols:
- **RESP (Redis Protocol)** on port 6379 — use any Redis client. Commands: `GRAPH.QUERY`, `GRAPH.RO_QUERY`
- **HTTP API** on port 8080 — `POST /api/query`, `GET /api/status`. See the [SDKs, CLI & API](./sdk_cli_api.md) chapter

### What query language does Samyama use?

Samyama supports **OpenCypher** with ~90% coverage. Supported clauses: MATCH, OPTIONAL MATCH, CREATE, DELETE, SET, REMOVE, MERGE, WITH, UNWIND, UNION, RETURN DISTINCT, ORDER BY, SKIP, LIMIT, EXPLAIN, EXISTS subqueries. See the [Query Engine](./query_engine.md) chapter.

### What are the minimum system requirements?

Samyama runs on any system with a Rust 1.83+ toolchain:
- **CPU**: Any x86_64 or ARM64 (M-series Macs fully supported)
- **RAM**: 512MB minimum; 4GB+ recommended for production
- **Disk**: Depends on data size; RocksDB with LZ4 compression is space-efficient
- **GPU** (Enterprise only): Any Metal, Vulkan, or DX12-compatible GPU

### What is the difference between Community and Enterprise?

| | Community (OSS) | Enterprise |
| :--- | :--- | :--- |
| **License** | Apache 2.0 | Commercial (JET token) |
| **Core Engine** | ✅ Full | ✅ Full |
| **Monitoring** | Logging only | Prometheus, health checks, audit trail |
| **Backup** | WAL only | Full/incremental backup, PITR |
| **HA** | Basic Raft | HTTP/2 transport, snapshot streaming |
| **GPU** | ❌ | ✅ (wgpu: Metal, Vulkan, DX12) |

See the [Enterprise Edition](./samyama_enterprise.md) chapter for full details.

---

## Query Engine

### What Cypher features are NOT yet supported?

Remaining gaps: list slicing (`[1..3]`), pattern comprehensions, named paths, `CASE` expressions, `collect(DISTINCT x)`. The [Future Roadmap](./future_roadmap.md) tracks planned additions.

### How do I check if my query is using an index?

Use `EXPLAIN` before your query:
```cypher
EXPLAIN MATCH (n:Person {name: 'Alice'}) RETURN n
```
If you see `IndexScanOperator` instead of `NodeScanOperator`, the index is being used. See the [Query Optimization](./query_optimization.md) chapter.

### How do I create a property index?

```cypher
CREATE INDEX ON :Person(name)
CREATE INDEX ON :Person(age)
```

### Can I use EXPLAIN to see estimated costs?

Yes. `EXPLAIN` returns the operator tree with estimated row counts and graph statistics (label counts, edge type counts, property selectivity). `PROFILE` (with actual execution timing) is on the roadmap.

### How many physical operators does the engine have?

28 operators covering scan, traversal, filter, join, aggregation, sort, write, index, and specialized operations. See the [operator table](./query_engine.md#all-28-physical-operators).

### Does Samyama support transactions?

Samyama provides per-query atomicity via RocksDB `WriteBatch` + WAL. Interactive `BEGIN...COMMIT` transactions are on the roadmap. See the [ACID Guarantees](./managing_state.md#acid-guarantees) section.

---

## Query Planner & Optimizer

### What cost model does the query planner use?

Samyama currently uses a **heuristic-based planner** rather than a full cost-based optimizer. The planner collects statistics via `GraphStatistics` (label counts, edge type counts, average degree, and per-property selectivity estimates), and these are displayed in `EXPLAIN` output. However, the planner does not yet generate multiple candidate plans and compare them by estimated cost — it follows a single greedy path based on heuristic rules:

1. **Index priority**: If a property index exists for a WHERE predicate, use `IndexScanOperator`; otherwise fall back to `NodeScanOperator` (full label scan).
2. **Join strategy**: If MATCH clauses share a variable, use `JoinOperator` (hash join); otherwise use `CartesianProductOperator`.
3. **Operator stacking**: Filter → Unwind → Write → Project → Sort → Limit, in fixed order.

A full cost-based optimizer that evaluates alternative plans (join reordering, index intersection, scan strategy comparison) is on the roadmap. See the [Query Optimization](./query_optimization.md) chapter.

### What cardinality estimation techniques are used?

`GraphStatistics` provides three estimation methods:

| Method | What It Returns | Complexity |
| :--- | :--- | :---: |
| `estimate_label_scan(label)` | Exact node count for a label (from `label_index`) | O(1) |
| `estimate_expand(edge_type)` | Edge count for a type (from `edge_type_index`) | O(1) |
| `estimate_equality_selectivity(label, prop)` | `1.0 / distinct_count` for the property | O(1) |

Statistics are computed by sampling the first 1,000 nodes per label and tracking property presence, null fractions, and distinct value counts. These estimates are currently surfaced in `EXPLAIN` output but are **not yet used to drive plan selection**. Future work includes histogram-based estimation, multi-column correlation tracking, and using these estimates to rank candidate plans.

### Does Samyama support parameterized or templatized queries?

**Not yet.** All queries must include literal values inline:

```cypher
-- This works:
MATCH (n:Person {age: 30}) RETURN n

-- This does NOT work (no parameter syntax):
MATCH (n:Person {age: $age}) RETURN n
```

Parameterized queries (`$param` syntax), prepared statements (`PREPARE`/`EXECUTE`), and query templates are on the roadmap. Today, applications must construct complete Cypher strings with interpolated values. Use the NLQ pipeline or SDK helper methods to safely construct queries.

### What join algorithms does Samyama use?

Three join strategies are available:

| Operator | Algorithm | When Used |
| :--- | :--- | :--- |
| **JoinOperator** | Hash Join | MATCH clauses share a variable (e.g., `MATCH (a)-[:X]->(b), (b)-[:Y]->(c)`) |
| **LeftOuterJoinOperator** | Left Outer Hash Join | `OPTIONAL MATCH` — returns left record with NULLs when no right match |
| **CartesianProductOperator** | Cross Product | No shared variables between MATCH clauses |

The hash join materializes the left side into a `HashMap<Value, Vec<Record>>` and probes it for each right-side record. This is efficient for equality joins on node identity but does not support range joins.

**Not yet implemented**: Merge join (sorted inputs), nested-loop join (for small right sides), or adaptive/streaming joins. Join order follows the query text order — the planner does not reorder joins based on estimated cardinalities.

### What scan operators are available, and how is one chosen?

Three scan operators:

| Operator | Access Method | When Chosen |
| :--- | :--- | :--- |
| **NodeScanOperator** | Full label scan via `label_index` | Default — no index matches the WHERE predicate |
| **IndexScanOperator** | B-tree range scan on property index | Index exists on `(label, property)` and WHERE has a matching `=`, `>`, `>=`, `<`, or `<=` predicate |
| **VectorSearchOperator** | HNSW approximate nearest neighbor | `CALL db.index.vector.queryNodes(...)` |

**Selection logic**: The planner checks whether the WHERE clause contains a simple binary comparison (`n.prop OP literal`) on the start node's property. If an index exists for that `(label, property)` pair, it emits an `IndexScanOperator`; otherwise it falls back to `NodeScanOperator`.

**Current limitations**:
- Only the **start node** of each MATCH path is considered for index scans
- Only **single predicate** conditions trigger index use — `AND` chains with multiple indexed properties do not yet use index intersection
- Multi-label nodes use the first matching index only

To verify which scan your query uses, prefix with `EXPLAIN`.

### How does the query planner choose between possible plans?

Currently, the planner generates a **single plan** using heuristic rules — it does not enumerate or compare alternative plans:

1. Parse the Cypher AST
2. For each MATCH clause, check for index applicability → emit `IndexScanOperator` or `NodeScanOperator`
3. Combine multiple MATCH clauses via shared-variable detection → `JoinOperator` or `CartesianProductOperator`
4. Stack remaining operators (filter, project, sort, limit) in fixed order

There is no plan enumeration, no cost comparison between alternatives, and no join reordering. The `_optimize` field exists in the `QueryPlanner` struct as a placeholder for future cost-based optimization.

**Practical tip**: Since the planner follows query text order, you can influence performance by placing the most selective MATCH clause (the one that returns fewest results) first.

### Can I force a specific execution plan or provide optimizer hints?

**Not yet.** Samyama does not currently support:
- `USING INDEX` directives (Neo4j-style)
- `USING SCAN` to force a label scan
- `USING JOIN ON` to force a specific join variable
- Query hints or optimizer directives of any kind

The only way to influence plan selection today is:
1. **Create property indexes** (`CREATE INDEX ON :Label(prop)`) — the planner will automatically prefer index scans when available
2. **Reorder MATCH clauses** — place the most selective pattern first, since the planner processes them in text order
3. **Use EXPLAIN** to verify the plan and adjust your query accordingly

Optimizer hints and plan forcing are planned for a future release.

---

## Graph Algorithms

### What algorithms are available?

14 algorithms in the `samyama-graph-algorithms` crate:

| Category | Algorithms |
| :--- | :--- |
| Centrality | PageRank, Local Clustering Coefficient (directed + undirected) |
| Community | WCC, SCC, CDLP, Triangle Counting |
| Pathfinding | BFS, Dijkstra, BFS All Shortest Paths |
| Network Flow | Edmonds-Karp (Max Flow), Prim's MST |
| Statistical | PCA (Randomized SVD + Power Iteration) |

### How do I run PageRank?

Via Cypher:
```cypher
CALL algo.pagerank({label: 'Person', edge_type: 'KNOWS', damping: 0.85, iterations: 20})
YIELD node, score
```

Via SDK (Rust):
```rust
let scores = client.page_rank(config, "Person", "KNOWS").await;
```

### What is the CSR format and why is it used?

**Compressed Sparse Row (CSR)** is a cache-efficient array-based representation of a graph. Algorithms project from `GraphStore` into CSR for OLAP workloads because sequential memory access patterns allow CPU prefetching with ~100% accuracy. See the [Analytical Power](./analytical_power.md) chapter.

### Does PCA support auto-selection of the solver?

Yes. `PcaSolver::Auto` selects Randomized SVD when `n > 500` and `k < 0.8 * min(n, d)`, otherwise falls back to Power Iteration. The Randomized SVD solver uses the Halko-Martinsson-Tropp algorithm.

---

## Vector Search & AI

### What distance metrics are supported?

Three metrics: **Cosine**, **L2 (Euclidean)**, and **Dot Product**. The metric is specified when creating the vector index and is automatically matched during search.

### What is Graph RAG?

Graph RAG combines vector search with graph traversal in a single query. Instead of retrieving vectors and filtering in the application layer, Samyama applies graph filters *inside* the execution engine. This prevents the "filter-out-all-results" problem. See [AI & Vector Search](./ai_vector_search.md).

### What is Agentic Enrichment (GAK)?

**Generation-Augmented Knowledge (GAK)** is the inverse of RAG. Instead of using the database to help an LLM, the database uses an LLM to help build itself. When data is missing, an `AgentRuntime` autonomously fetches information and creates new nodes/edges. See [Agentic Enrichment](./agentic_enrichment.md).

### What LLM providers are supported for NLQ?

The `NLQClient` supports: **OpenAI**, **Google Gemini**, **Ollama** (local), and **Claude**. Configure via `NLQConfig` with provider, model, and API key.

---

## Optimization

### How many solvers are available?

22 metaheuristic solvers in the `samyama-optimization` crate:
- **Metaphor-less**: Jaya, QOJAYA, Rao (1-3), TLBO, ITLBO, GOTLBO
- **Swarm/Evolutionary**: PSO, DE, GA, GWO, ABC, BAT, Cuckoo, Firefly, FPA
- **Physics-based**: GSA, SA, HS, BMR, BWR
- **Multi-objective**: NSGA-II, MOTLBO

### Are the optimization solvers open-source or enterprise-only?

All 22 solvers are in the **open-source** `samyama-optimization` crate. Enterprise adds GPU-accelerated constraint evaluation for large-scale problems.

### How do I choose the right solver?

- **Single objective, no constraints**: Start with **Jaya** (parameter-free, good baseline)
- **Single objective with constraints**: Try **PSO** or **GWO** (good constraint handling)
- **Multi-objective**: Use **NSGA-II** (with Constrained Dominance Principle)
- **Large search space**: Try **DE** (good for high-dimensional problems)

---

## Performance & Scaling

### What are the latest benchmark numbers?

On Mac Mini M4 (16GB RAM), v0.5.12:
- **Node Ingestion**: 255K/s (CPU), 412K/s (GPU)
- **Edge Ingestion**: 4.2M/s (CPU), 5.2M/s (GPU)
- **Cypher OLTP**: 115K QPS at 1M nodes
- **PageRank (1M)**: 92ms (CPU), 11ms (GPU, 8.2x speedup)
- **Vector Search**: 15K QPS (128-dim, k=10)

### When should I use GPU acceleration?

GPU acceleration is beneficial for graphs with **> 100,000 nodes**. Below this threshold, CPU-GPU memory transfer overhead dominates. For PCA specifically, the threshold is 50,000 nodes and > 32 dimensions.

### Has Samyama been validated against industry benchmarks?

Yes. Samyama achieved **28/28 (100%)** on the LDBC Graphalytics benchmark suite across 6 algorithms (BFS, PageRank, WCC, CDLP, LCC, SSSP) on both XS and S-size datasets. See [Performance & Benchmarks](./performance_benchmarks.md#ldbc-graphalytics-validation).

### What is the bottleneck in query execution?

At 1M nodes, the bottleneck is the **language frontend** (parsing: 54%, planning: 44%), not execution (2%). The roadmap includes AST caching and plan memoization to reduce warm-query latency to ~10ms.

---

## Enterprise & Operations

### How does licensing work?

Enterprise uses **JET (JSON Enablement Token)**—an Ed25519-signed token containing org, edition, features, expiry, and machine fingerprint. 30-day grace period after expiry. See [Enterprise Edition](./samyama_enterprise.md#5-licensing--governance).

### How do I create a backup?

```bash
redis-cli ADMIN.BACKUP CREATE    # Full snapshot
redis-cli ADMIN.BACKUP LIST      # List backups
redis-cli ADMIN.BACKUP VERIFY 5  # Verify integrity
```

### What is Point-in-Time Recovery (PITR)?

PITR replays archived WAL entries against a snapshot to restore the database to an exact moment. If someone accidentally deletes data at 10:30:05, you can restore to 10:30:04 with microsecond precision.

### How does multi-tenancy work?

Each tenant gets a dedicated RocksDB Column Family with per-tenant resource quotas (memory, storage, query time). Compaction is independent per tenant—one tenant's write-heavy workload won't affect others. See [Observability & Multi-tenancy](./observability_multi_tenancy.md).

---

## RDF & SPARQL

### What RDF serialization formats are supported?

| Format | Read | Write |
| :--- | :---: | :---: |
| Turtle (.ttl) | ✅ | ✅ |
| N-Triples (.nt) | ✅ | ✅ |
| RDF/XML (.rdf) | ✅ | ✅ |
| JSON-LD (.jsonld) | ❌ | ✅ |

### Is SPARQL fully implemented?

SPARQL parser infrastructure is in place (via the `spargebra` crate), but query execution is not yet operational. The focus is on the OpenCypher engine. See [RDF & SPARQL](./rdf_sparql.md).

### Can I use RDF and property graph data together?

A mapping framework (`MappingConfig`) is defined for converting between RDF triples and property graph nodes/edges. Automatic bidirectional conversion is on the roadmap.

---

## SDKs & Integration

### Which SDKs are available?

| SDK | Language | Transport | Install |
| :--- | :--- | :--- | :--- |
| `samyama-sdk` | Rust | Embedded + HTTP | `cargo add samyama-sdk` |
| `samyama` | Python | Embedded + HTTP (PyO3) | `pip install samyama` |
| `samyama-sdk` | TypeScript | HTTP only | `npm install samyama-sdk` |
| `samyama-cli` | CLI | HTTP | `cargo install samyama-cli` |

### Can I embed Samyama in my application without running a server?

Yes. The Rust SDK's `EmbeddedClient` runs the full engine in-process with zero network overhead:
```rust
let client = EmbeddedClient::new();
client.query("default", "CREATE (n:Person {name: 'Alice'})").await?;
```

### Does the Python SDK support algorithms directly?

The Python SDK supports Cypher queries (including algorithm calls via `CALL algo.*`). Direct method-level algorithm access (like the Rust SDK's `AlgorithmClient`) is available only in the Rust SDK's embedded mode.
