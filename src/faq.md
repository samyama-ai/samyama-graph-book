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

### What protocols does Samyama support? Is it Postgres wire protocol?

No, Samyama does **not** use the Postgres wire protocol. It exposes two protocols:
- **RESP (Redis Protocol)** on port 6379 — use any Redis client (redis-cli, Jedis, ioredis, etc.)
- **HTTP API** on port 8080 — RESTful endpoints for queries and status

We chose RESP over Postgres wire protocol because: (1) RESP is simpler and faster (binary protocol, minimal framing overhead), (2) it enables drop-in compatibility with the RedisGraph ecosystem (which was sunset by Redis Ltd), and (3) graph queries are fundamentally different from SQL — we didn't want to shoehorn Cypher into a SQL-shaped protocol.

Example using `redis-cli`:
```bash
redis-cli GRAPH.QUERY default "CREATE (n:Person {name: 'Alice', age: 30})"
redis-cli GRAPH.QUERY default "MATCH (n:Person) RETURN n.name, n.age"
```

Example using HTTP:
```bash
curl -s -X POST http://localhost:8080/api/query \
  -d '{"query": "MATCH (n) RETURN count(n)", "graph": "default"}'

curl -s http://localhost:8080/api/status | python3 -m json.tool
```

See the [SDKs, CLI & API](./sdk_cli_api.md) chapter.

### What query language does Samyama use?

Samyama supports **OpenCypher** with ~90% coverage. Supported clauses: MATCH, OPTIONAL MATCH, CREATE, DELETE, SET, REMOVE, MERGE, WITH, UNWIND, UNION, RETURN DISTINCT, ORDER BY, SKIP, LIMIT, EXPLAIN, EXISTS subqueries.

Example — create a small social graph and query it:
```cypher
CREATE (a:Person {name: 'Alice', age: 30})-[:KNOWS]->(b:Person {name: 'Bob', age: 25})
CREATE (b)-[:KNOWS]->(c:Person {name: 'Charlie', age: 35})

MATCH (p:Person)-[:KNOWS]->(friend)
WHERE p.age > 28
RETURN p.name, friend.name
```

See the [Query Engine](./query_engine.md) chapter.

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
| **Multi-Tenancy** | Single namespace (`default`) | Tenant CRUD API, quotas, isolation |
| **Monitoring** | Logging only | Prometheus, health checks, audit trail |
| **Backup** | WAL only | Full/incremental backup, PITR |
| **HA** | Basic Raft | HTTP/2 transport, snapshot streaming |
| **GPU** | ❌ | ✅ (wgpu: Metal, Vulkan, DX12) |

See the [Enterprise Edition](./samyama_enterprise.md) chapter for full details.

---

## Query Engine

### What Cypher features are NOT yet supported?

Remaining gaps: list slicing (`[1..3]`) and pattern comprehensions. The [Future Roadmap](./future_roadmap.md) tracks planned additions.

**Added in v0.6.0:** Named paths (`p = (a)-[]->(b)`), `CASE` expressions, `collect(DISTINCT x)`, `datetime({year: 2026, month: 3})` constructor, parameterized queries (`$param`), and `PROFILE`.

```cypher
-- Named paths (v0.6.0):
MATCH p = (a:Person)-[:KNOWS]->(b:Person) RETURN p, length(p)

-- CASE expressions (v0.6.0):
MATCH (n:Person) RETURN n.name, CASE WHEN n.age > 30 THEN 'senior' ELSE 'junior' END AS category

-- collect(DISTINCT x) (v0.6.0):
MATCH (n:Person)-[:LIVES_IN]->(c:City) RETURN collect(DISTINCT c.name) AS cities

-- Parameterized queries (v0.6.0):
MATCH (n:Person {age: $age}) RETURN n
```

### How do I check if my query is using an index?

Use `EXPLAIN` before your query:
```cypher
EXPLAIN MATCH (n:Person {name: 'Alice'}) RETURN n
```

If you see `IndexScanOperator` in the output, the index is being used. If you see `NodeScanOperator`, the query is doing a full label scan — consider creating an index:

```cypher
-- Before: full scan (slow on large graphs)
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Output: NodeScanOperator(Person) → FilterOperator(n.name = 'Alice')

-- Create the index:
CREATE INDEX ON :Person(name)

-- After: index scan (fast O(log n))
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Output: IndexScanOperator(Person.name = 'Alice')
```

See the [Query Optimization](./query_optimization.md) chapter.

### Can I use EXPLAIN to see estimated costs?

Yes. `EXPLAIN` returns the operator tree with estimated row counts and graph statistics (label counts, edge type counts, property selectivity):

```cypher
EXPLAIN MATCH (a:Person)-[:KNOWS]->(b:Person)
WHERE a.age > 25
RETURN a.name, b.name
```

Output includes:
```
ProjectOperator [a.name, b.name]
  └── FilterOperator [a.age > 25]
        └── ExpandOperator [KNOWS]
              └── NodeScanOperator [Person]
--- Statistics ---
  Person: 10,000 nodes
  KNOWS: 45,000 edges
  avg_out_degree: 4.5
```

`PROFILE` (with actual execution timing and row counts per operator) is supported since v0.6.0:

```cypher
PROFILE MATCH (a:Person)-[:KNOWS]->(b:Person)
WHERE a.age > 25
RETURN a.name, b.name
```

### How many physical operators does the engine have?

33 operators covering scan, traversal, filter, join, aggregation, sort, write, index, constraint, and specialized operations. See the [operator table](./query_engine.md#all-33-physical-operators).

### Does Samyama support transactions?

Samyama provides per-query atomicity via RocksDB `WriteBatch` + WAL. Each write query (CREATE, DELETE, SET, MERGE) executes as an atomic unit — either all changes commit or none do.

```cypher
-- This entire query is atomic — both nodes and the edge are created together:
CREATE (a:Account {id: 'A1', balance: 1000})-[:TRANSFER {amount: 500}]->(b:Account {id: 'A2', balance: 2000})
```

Interactive `BEGIN...COMMIT` transactions (spanning multiple queries) are on the roadmap. See the [ACID Guarantees](./managing_state.md#acid-guarantees) section.

---

## Indexes & Data Access

### What types of indexes does Samyama support?

Samyama provides four index types:

| Index Type | Data Structure | Purpose | Created By |
| :--- | :--- | :--- | :--- |
| **Property Index** | `BTreeMap<PropertyValue, HashSet<NodeId>>` | Fast property lookups and range scans | `CREATE INDEX` |
| **Label Index** | `HashMap<Label, HashSet<NodeId>>` | Fast label-based node retrieval | Automatic (built-in) |
| **Edge Type Index** | `HashMap<EdgeType, HashSet<EdgeId>>` | Fast edge type lookups | Automatic (built-in) |
| **Vector Index** | HNSW (Hierarchical Navigable Small World) | Approximate nearest neighbor search | `CREATE VECTOR INDEX` |

### How do property indexes work?

Property indexes use a **B-tree** (`BTreeMap`) that maps property values to sets of node IDs. This gives O(log n) lookups for both exact matches and range queries.

**Creating a property index:**
```cypher
CREATE INDEX ON :Person(name)
CREATE INDEX ON :Person(age)
CREATE INDEX ON :Transaction(amount)
```

**How it's used** — the planner automatically selects an index scan when a WHERE predicate matches an indexed property:
```cypher
-- Exact match → index lookup, returns matching NodeIds directly
MATCH (n:Person) WHERE n.name = 'Alice' RETURN n

-- Range query → B-tree range scan
MATCH (n:Person) WHERE n.age > 25 RETURN n.name, n.age

-- Supported comparison operators: =, >, >=, <, <=
MATCH (t:Transaction) WHERE t.amount >= 10000 RETURN t
```

**Performance characteristics:**

| Operation | Complexity |
| :--- | :---: |
| Exact match (`=`) | O(log n) |
| Range query (`>`, `>=`, `<`, `<=`) | O(log n + k) where k = results |
| Insert (on node create/update) | O(log n) |
| Remove (on node delete/update) | O(log n) |

**Composite indexes** (v0.6.0): Multi-property indexes are supported — `CREATE INDEX ON :Person(firstName, lastName)` creates a composite index used when both properties appear in a WHERE clause.

### How do the built-in label and edge type indexes work?

These are **automatic indexes** maintained internally — you don't create or manage them.

**Label index** — maps each label to all nodes with that label:
```cypher
-- Uses label_index internally to find all Person nodes in O(1)
MATCH (n:Person) RETURN n

-- Statistics show label cardinality:
EXPLAIN MATCH (n:Person) RETURN n
-- Output: NodeScanOperator [Person] (est. 10,000 rows)
```

**Edge type index** — maps each edge type to all edges of that type:
```cypher
-- Uses edge_type_index to find all KNOWS edges
MATCH ()-[r:KNOWS]->() RETURN count(r)
```

Both indexes use `HashMap<Key, HashSet<Id>>` for O(1) lookup by label/type and O(m) iteration over all matching entities.

### How do vector indexes work?

Vector indexes use **HNSW (Hierarchical Navigable Small World)** for approximate nearest neighbor search, powered by the `hnsw_rs` crate.

**Creating a vector index:**
```cypher
CREATE VECTOR INDEX embedding_idx
FOR (d:Document) ON (d.embedding)
OPTIONS {dimensions: 768, similarity: 'cosine'}
```

**Supported distance metrics:**

| Metric | Best For | Formula |
| :--- | :--- | :--- |
| `cosine` | Text embeddings, normalized vectors | `1.0 - cos(a, b)` |
| `l2` | Spatial data, raw feature vectors | `sqrt(sum((a_i - b_i)^2))` |
| `dot_product` | Pre-normalized embeddings | `1.0 - dot(a, b)` |

**Querying:**
```cypher
-- Find the 5 documents most similar to a query vector
CALL db.index.vector.queryNodes('Document', 'embedding', [0.12, -0.34, ...], 5)
YIELD node, score
RETURN node.title, score
```

**HNSW parameters** (compile-time defaults):
- `max_elements`: 100,000
- `M`: 16 connections per layer
- `ef_construction`: 200
- `ef_search`: 2 × k (set at query time)

**Via the Rust SDK:**
```rust
client.create_vector_index("Document", "embedding", 768, DistanceMetric::Cosine).await?;
client.add_vector("Document", "embedding", node_id, &embedding_vec).await?;
let results = client.vector_search("Document", "embedding", &query_vec, 5).await?;
```

### Are composite (multi-property) indexes supported?

**Yes, since v0.6.0.** Composite indexes cover multiple properties on the same label:
```cypher
CREATE INDEX ON :Person(firstName, lastName)

-- The planner uses the composite index when both properties appear in WHERE:
MATCH (n:Person) WHERE n.firstName = 'Alice' AND n.lastName = 'Smith' RETURN n
-- Plan: IndexScanOperator(Person.firstName='Alice', Person.lastName='Smith')
```

Single-property indexes are also supported. When a WHERE clause has multiple indexed predicates with AND, the planner uses **AND-chain index selection** (v0.6.0) to pick the most selective index.

### Are unique constraints supported?

**Yes, since v0.6.0.** You can enforce property uniqueness within a label:
```cypher
CREATE CONSTRAINT ON (n:Person) ASSERT n.email IS UNIQUE
```

Attempting to create a node with a duplicate value on a unique-constrained property will return an error. Use `SHOW CONSTRAINTS` to list active constraints.

### Is DROP INDEX supported?

**Yes, since v0.6.0.** You can drop indexes via Cypher:
```cypher
DROP INDEX ON :Person(name)
```

### Can I list all indexes?

**Yes, since v0.6.0.** Use `SHOW INDEXES` and `SHOW CONSTRAINTS`:
```cypher
SHOW INDEXES
-- Returns: label, property, index type for all active indexes

SHOW CONSTRAINTS
-- Returns: label, property, constraint type for all active constraints
```

---

## Query Planner & Optimizer

### What cost model does the query planner use?

Since v0.6.1, Samyama has a **graph-native cost-based planner** (ADR-015) with a multiplicative cardinality model. The planner uses two tiers of statistics:

- **GraphCatalog** (incremental) — triple-level stats per `(source_label, edge_type, target_label)` pattern, maintained on every edge create/delete
- **GraphStatistics** (batch) — label counts, edge type counts, per-property selectivity (sampled from first 1,000 nodes per label)

The cost model in `cost_model.rs` assigns estimated cardinalities to each operator:

| Operator | Cost Formula |
| :--- | :--- |
| **LabelScan** | `label_count` (from catalog) |
| **IndexLookup** | Fixed `10.0` (highly selective) |
| **Expand (Forward)** | `input_cost × avg_out_degree` |
| **Expand (Reverse)** | `input_cost × avg_in_degree` |
| **ExpandInto** | `input_cost × edge_existence_probability` |
| **Filter** | `input_cost × 0.5` (default selectivity) |
| **Join** | `left_cost + right_cost` |
| **CartesianProduct** | `left_cost × right_cost` |

The planner pipeline:

1. **Plan enumeration**: For each node in the MATCH pattern, build a candidate plan via BFS (`plan_enumerator.rs`), choosing optimal traversal direction at each step
2. **Logical optimization**: Apply predicate pushdown and ExpandInto insertion (`logical_optimizer.rs`)
3. **Cost estimation**: Score each candidate using the multiplicative cost model (`cost_model.rs`)
4. **Plan selection**: Sort candidates by cost, pick the cheapest (up to 64 candidates evaluated)
5. **Physical translation**: Convert the logical plan to executable operators (`physical_planner.rs`)
6. **Index selection**: If a property index exists for a WHERE predicate, use `IndexScanOperator`; for AND-chains, select the most selective index
7. **Plan caching**: Plans cached with generation-based invalidation tied to catalog changes

Example — the planner selects different starting points based on catalog stats:
```cypher
-- 1,000 Person nodes, 10 Company nodes, each Person works at 1 Company
EXPLAIN MATCH (p:Person)-[:WORKS_AT]->(c:Company) RETURN p.name, c.name

-- Candidate 1 (start from Person): LabelScan(1000) × Expand(1.0) = 1000
-- Candidate 2 (start from Company): LabelScan(10) × ReverseExpand(100.0) = 1000
-- Planner evaluates BOTH, picks cheapest
```

Example — index selection:
```cypher
-- Without index: full label scan
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Plan: NodeScanOperator(Person) → FilterOperator(name = 'Alice') → ProjectOperator

-- With index: index scan
CREATE INDEX ON :Person(name)
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Plan: IndexScanOperator(Person.name = 'Alice') → ProjectOperator
```

See the [Query Optimization](./query_optimization.md) chapter.

### How are individual operator costs estimated?

Since v0.6.1, the graph-native planner assigns a **multiplicative cardinality estimate** to every operator in a candidate plan via `cost_model::estimate_plan_cost()`. The cost model is recursive — each operator's cost depends on its input's estimated cardinality:

```
Example: MATCH (p:Person)-[:KNOWS]->(q:Person) WHERE q.age > 30 RETURN q

Plan (start from p):
  LabelScan(Person)                     cost = 1,000        (label count)
  → Expand(:KNOWS, Forward)             cost = 1,000 × 5.0 = 5,000  (avg_out_degree)
  → Filter(age > 30)                    cost = 5,000 × 0.5 = 2,500  (default selectivity)
  Total plan cost: 2,500

Plan (start from q):
  LabelScan(Person)                     cost = 1,000
  → Filter(age > 30)                    cost = 1,000 × 0.5 = 500    (filter pushed down!)
  → Expand(:KNOWS, Reverse)             cost = 500 × 5.0 = 2,500
  Total plan cost: 2,500
```

The planner compares all candidate plans and selects the lowest-cost one. `EXPLAIN` shows the chosen plan with operator descriptions; `PLAN_DIAGNOSTICS` (accessible in EXPLAIN output) shows how many candidates were evaluated and their costs.

**Current limitations:**
- Filter selectivity is hardcoded at 0.5 (no property-level histograms yet)
- Sort/Aggregate operators are always appended after the chosen scan+expand plan
- Property-level `estimate_equality_selectivity` exists in GraphStatistics but is not yet wired into the graph-native cost model

### What cardinality estimation techniques are used?

Two tiers of estimation methods:

**GraphCatalog** (triple-level, used by graph-native planner):

| Method | What It Returns | Complexity |
| :--- | :--- | :---: |
| `estimate_label_scan(label)` | Exact node count for a label | O(1) |
| `estimate_expand_out(src_label, edge_type)` | Average outgoing degree (sum across target labels) | O(k) |
| `estimate_expand_in(tgt_label, edge_type)` | Average incoming degree (sum across source labels) | O(k) |
| `estimate_edge_existence(src, et, tgt)` | Probability a random (src, tgt) pair has an edge | O(1) |

**GraphStatistics** (batch, used for EXPLAIN display and legacy planner):

| Method | What It Returns | Complexity |
| :--- | :--- | :---: |
| `estimate_label_scan(label)` | Exact node count for a label | O(1) |
| `estimate_expand(edge_type)` | Total edge count for a type | O(1) |
| `estimate_equality_selectivity(label, prop)` | `1.0 / distinct_count` for the property | O(1) |

Example — GraphCatalog triple-level estimation:
```
Graph: 1,000 Persons, 10 Companies, 1,000 WORKS_AT edges (each person → 1 company)

Catalog TripleStats for (:Person, :WORKS_AT, :Company):
  count = 1,000, avg_out_degree = 1.0, avg_in_degree = 100.0

Plan A (start Person):  1,000 × 1.0 = 1,000 cost
Plan B (start Company): 10 × 100.0 = 1,000 cost  (same total, different shape)
```

Example — property selectivity:
```
10,000 Person nodes, 'name' has 8,000 distinct values:
estimate_equality_selectivity("Person", "name") → 1/8,000 = 0.000125
Estimated rows for WHERE name = 'Alice' → 10,000 × 0.000125 ≈ 1.25
```

### How are statistics collected and maintained?

Samyama maintains statistics at two levels:

**GraphCatalog** (incremental, always up-to-date):

The `GraphCatalog` tracks per-triple-pattern statistics `(source_label, edge_type, target_label)` and is updated **incrementally** on every graph mutation:

- `on_label_added(label)` / `on_label_removed(label)` — updates label counts
- `on_edge_created(src, src_labels, et, tgt, tgt_labels)` — updates triple stats for all label combinations
- `on_edge_deleted(...)` — mirrors edge creation

For each triple pattern, the catalog tracks:
- `count` — total edges matching this pattern
- `avg_out_degree` — count / distinct_sources
- `avg_in_degree` — count / distinct_targets
- `distinct_sources` / `distinct_targets` — unique endpoints
- `max_out_degree` — peak degree for worst-case estimation

A `generation` counter increments on every change, enabling plan cache invalidation.

**GraphStatistics** (batch, computed on demand):

Computed via `GraphStore::compute_statistics()`:
1. Iterates all labels in `label_index` and counts nodes per label
2. Iterates all edge types in `edge_type_index` and counts edges per type
3. **Samples** the first 1,000 nodes per label to compute per-property stats:
   - `null_fraction` — fraction of sampled nodes missing the property
   - `distinct_count` — number of distinct values observed
   - `selectivity` — `1.0 / distinct_count` (uniform distribution assumption)
4. Computes `avg_out_degree` across all nodes

GraphStatistics are recomputed on each `EXPLAIN` call. Adding histogram-based distributions and wiring property selectivity into the graph-native cost model is on the roadmap.

### How does the planner handle cardinality estimation errors?

Since v0.6.0, statistics drive cost-based plan selection (join order, index choice). This means cardinality estimation errors can now cause suboptimal plans — for example, choosing a less selective index or the wrong join order.

```cypher
-- If the planner estimates 100 rows but there are actually 1,000,000:
MATCH (a:Person)-[:KNOWS]->(b:Person)
WHERE a.city = 'Mumbai'
RETURN a.name, b.name

-- The CBO might build the hash table on the wrong side
-- or choose an index that isn't actually the most selective
```

Mitigations: use `EXPLAIN` to verify estimates, and ensure statistics are fresh (they are recomputed on each `EXPLAIN` call). In mature optimizers, cardinality estimation errors can cause severe performance problems. Tools like [Picasso](https://dsl.cds.iisc.ac.in/projects/PICASSO/) visualize these errors as **cardinality diagrams**, mapping estimation accuracy across the selectivity space to expose where the optimizer's statistics are most inaccurate.

### What about multi-column correlations and compound predicates?

Not yet handled. The current selectivity model assumes **independence** between properties — `selectivity(A AND B) = selectivity(A) × selectivity(B)`. This is the standard simplifying assumption but can be wildly wrong when properties are correlated.

Example:
```cypher
MATCH (n:Person) WHERE n.city = 'Mumbai' AND n.country = 'India' RETURN n
-- Independence assumption: selectivity = (1/500 cities) × (1/200 countries) = 1/100,000
-- Reality: everyone in Mumbai is in India, so selectivity = 1/500
-- The estimate is off by 200x!
```

Future work includes:
- **Multi-column statistics** (joint distinct counts or dependency graphs)
- **Histogram-based estimation** (equi-width or equi-depth histograms per property)
- **Sketch-based estimation** (HyperLogLog for distinct counts, Count-Min Sketch for frequency estimation)

### Does Samyama support parameterized or templatized queries?

**Yes, since v0.6.0.** Use `$param` syntax with parameter bindings:

```cypher
-- Parameterized query:
MATCH (n:Person {age: $age}) RETURN n
-- Pass parameters via the SDK or RESP protocol

-- Literal values also work:
MATCH (n:Person {age: 30}) RETURN n
```

Parameterized queries enable plan cache reuse across different parameter values, reducing parsing and planning overhead. Prepared statements (`PREPARE`/`EXECUTE`) are on the roadmap.

### How do parameterized queries affect plan stability?

In optimizers that support parameterized queries, a key concern is **plan stability** — whether the same query template produces different plans for different parameter values. This is the phenomenon visualized by tools like [Picasso](https://dsl.cds.iisc.ac.in/projects/PICASSO/) as **plan diagrams**: color-coded maps showing how the optimal plan changes as selectivity varies.

Example of plan instability in a hypothetical future CBO:
```cypher
-- Template: MATCH (n:Person) WHERE n.age > $threshold RETURN n
-- With $threshold = 99 (selectivity 1%):  IndexScan is optimal
-- With $threshold = 10 (selectivity 90%): LabelScan is optimal
-- The optimizer must pick the right plan for each value
```

Since v0.6.0, parameterized queries are supported and plans are cached. The plan cache uses query string hashing to avoid re-parsing and re-planning for repeated queries. This means the "plan sniffing" concern is relevant — a cached plan may not be optimal for all parameter values. Currently Samyama uses a simple cache with statistics-based invalidation. Adaptive re-planning (when estimated vs. actual cardinalities diverge) is on the roadmap.

### What join algorithms does Samyama use?

Three join strategies are available:

| Operator | Algorithm | When Used |
| :--- | :--- | :--- |
| **JoinOperator** | Hash Join | MATCH clauses share a variable |
| **LeftOuterJoinOperator** | Left Outer Hash Join | `OPTIONAL MATCH` |
| **CartesianProductOperator** | Cross Product | No shared variables |

Example — hash join on a shared variable `b`:
```cypher
-- Two patterns sharing variable 'b' → HashJoin
MATCH (a:Person)-[:WORKS_AT]->(b:Company)
MATCH (b)<-[:INVESTED_IN]-(c:Fund)
RETURN a.name, b.name, c.name
-- Plan: HashJoin on 'b'
--   Left:  NodeScan(Person) → Expand(WORKS_AT)
--   Right: NodeScan(Fund) → Expand(INVESTED_IN)
```

Example — cross product with no shared variable:
```cypher
-- No shared variable → CartesianProduct (expensive!)
MATCH (a:Person), (b:Product)
RETURN a.name, b.name
-- Plan: CartesianProduct (|Person| × |Product| rows)
```

Example — left outer join for optional patterns:
```cypher
-- OPTIONAL MATCH → LeftOuterHashJoin (NULLs for non-matches)
MATCH (p:Person)
OPTIONAL MATCH (p)-[:HAS_ADDRESS]->(a:Address)
RETURN p.name, a.city
-- Persons without addresses appear with a.city = NULL
```

The hash join materializes the left side into a `HashMap<Value, Vec<Record>>` and probes it for each right-side record.

### How is join order determined?

Since v0.6.0, the planner performs **join reordering** based on cardinality estimates — it places the smaller (more selective) side as the build side of the hash join, regardless of the order in the query text.

```cypher
-- Both versions now produce the same optimal plan:
MATCH (a:Person), (b:Company) WHERE a.worksAt = b.name RETURN a, b
MATCH (b:Company), (a:Person) WHERE a.worksAt = b.name RETURN a, b
-- Planner puts Company (1K nodes) as build side, Person (1M) as probe side
```

**Not yet implemented**: Bushy join trees (the planner always produces left-deep trees) or adaptive joins that switch strategy mid-execution.

### Are there additional join strategies on the roadmap?

Yes. Future join strategies under consideration:

| Algorithm | Best For | Complexity |
| :--- | :--- | :---: |
| **Nested-Loop Join** | Small right side, or when index exists on join key | O(n × m) worst case |
| **Merge Join** | Both sides already sorted on join key | O(n + m) |
| **Index Nested-Loop Join** | Right side has index on join key | O(n × log m) |
| **Adaptive Join** | Switches strategy based on runtime cardinalities | Variable |

### What scan and traversal operators are available?

Samyama has **42 physical operators** in total. The key scan and traversal operators:

| Operator | Access Method | When Chosen |
| :--- | :--- | :--- |
| **NodeScanOperator** | Full label scan via `label_index` | Default — no index matches the WHERE predicate |
| **IndexScanOperator** | B-tree range scan on property index | Index exists on `(label, property)` and WHERE has a matching `=`, `>`, `>=`, `<`, or `<=` predicate |
| **VectorSearchOperator** | HNSW approximate nearest neighbor | `CALL db.index.vector.queryNodes(...)` |
| **ExpandOperator** | Adjacency list traversal (outgoing or incoming) | Graph-native planner chooses direction based on catalog stats |
| **ExpandIntoOperator** | Binary search edge existence check O(log d) | Both endpoints already bound (triangle/clique patterns) |
| **NodeByIdOperator** | Direct node lookup from pre-computed set | Internal use (subquery results) |
| **ShortestPathOperator** | BFS shortest path with predicates | `shortestPath()` function in MATCH |

Example showing the scan selection logic:
```cypher
-- No index on :Person(age) → NodeScanOperator + FilterOperator
MATCH (n:Person) WHERE n.age > 30 RETURN n
-- Plan: NodeScan(Person) → Filter(age > 30) → Project
-- Scans ALL Person nodes, filters in memory

-- After: CREATE INDEX ON :Person(age)
MATCH (n:Person) WHERE n.age > 30 RETURN n
-- Plan: IndexScan(Person.age > 30) → Project
-- Scans ONLY nodes with age > 30 via B-tree range query
```

### Can multiple indexes be used for a single query (index intersection)?

Since v0.6.0, the planner uses **AND-chain index selection** to pick the most selective index when a WHERE clause has multiple indexed predicates:

```cypher
CREATE INDEX ON :Person(age)
CREATE INDEX ON :Person(city)

MATCH (n:Person) WHERE n.age > 30 AND n.city = 'Mumbai' RETURN n
-- Planner picks the more selective index (e.g., city = 'Mumbai' if fewer matches)
-- and applies the other predicate as a post-scan filter
```

Full **index intersection** (scanning both indexes independently and intersecting the result sets) is on the roadmap for further optimization.

### Are there other scan limitations I should know about?

Yes:
- Only the **start node** of each MATCH path is considered for index scans — intermediate or end nodes always use label scan + filter:
  ```cypher
  -- Index on :Person(name) is used for 'a' (start node):
  MATCH (a:Person {name: 'Alice'})-[:KNOWS]->(b:Person {name: 'Bob'}) RETURN b
  -- Plan: IndexScan(a) → Expand(KNOWS) → Filter(b.name = 'Bob')
  -- Note: b.name = 'Bob' is filtered in memory, not via index
  ```
- **OR predicates** do not trigger index union scans:
  ```cypher
  MATCH (n:Person) WHERE n.age = 30 OR n.age = 40 RETURN n
  -- Falls back to full label scan + filter (even if age is indexed)
  ```
- **String predicates** (`CONTAINS`, `STARTS WITH`, `ENDS WITH`) do not use indexes

To verify which scan your query uses, always prefix with `EXPLAIN`.

### How does the query planner choose between possible plans?

The graph-native planner follows this pipeline:

1. **Parse** the Cypher AST (cached for repeated queries)
2. **Extract** a `PatternGraph` from the MATCH clause — nodes, edges, labels, directions
3. **Enumerate** candidate plans: for each pattern node as starting point, BFS through the pattern graph building a logical plan tree. At each edge, `choose_direction()` compares `estimate_expand_out` vs `estimate_expand_in` to pick the cheaper traversal direction
4. **Optimize** each candidate: predicate pushdown (move Filter below Expand when safe) and ExpandInto insertion (when both endpoints already bound)
5. **Score** each candidate via `estimate_plan_cost()` using GraphCatalog triple-level stats
6. **Select** the cheapest plan
7. **Translate** to physical operators via `logical_to_physical()` (direction reversal: Logical Reverse → Physical Incoming)
8. **Cache** the plan with generation-based invalidation

```cypher
MATCH (a:Person)-[:KNOWS]->(b:Person)
WHERE a.name = 'Alice'
RETURN b.name
ORDER BY b.name
LIMIT 10
-- Plan: IndexScan(Person.name='Alice') → Expand(KNOWS) → Project(b.name) → Sort(b.name) → Limit(10)
```

EXPLAIN shows diagnostics including candidates evaluated and chosen plan cost. The planner reorders joins automatically — query text order does not affect plan quality.

### What is the graph-native planner and how does it differ from the legacy planner?

Since v0.6.1, Samyama has a **graph-native cost-based optimizer** (ADR-015) that follows the same fundamental approach as mature systems like PostgreSQL:

1. **Enumerate** candidate plans — one per starting node in the MATCH pattern, with BFS traversal through the pattern graph
2. **Estimate** the cost of each plan using the multiplicative cardinality model and GraphCatalog triple-level statistics
3. **Optimize** each candidate with predicate pushdown and ExpandInto insertion
4. **Compare** all candidates and select the lowest-cost plan (up to 64 evaluated)

**Key differences from the legacy planner:**

| Aspect | Legacy Planner | Graph-Native Planner |
| :--- | :--- | :--- |
| Starting point | Always leftmost node in AST | Evaluates ALL pattern nodes |
| Direction | Always follows AST direction | Chooses cheapest direction per edge |
| ExpandInto | Not available | O(log d) edge existence check |
| Cost model | Heuristic (no numeric costs) | Multiplicative cardinality estimation |
| Plan candidates | 1 (single greedy plan) | Up to 64 per query |
| Statistics | Batch (GraphStatistics) | Incremental (GraphCatalog) |
| Predicate pushdown | Basic | Cost-aware, below Expand nodes |

Example — the graph-native planner considers multiple plans for a 3-way join:
```cypher
MATCH (a:Person)-[:KNOWS]->(b:Person)-[:WORKS_AT]->(c:Company)
WHERE a.age > 25 AND c.size > 1000
RETURN a.name, c.name

-- Plan A (start a): LabelScan(Person) → Filter(age>25) → Expand(KNOWS) → Expand(WORKS_AT) → Filter(size>1000)
-- Plan B (start c): LabelScan(Company) → Filter(size>1000) → ReverseExpand(WORKS_AT) → ReverseExpand(KNOWS) → Filter(age>25)
-- Plan C (start b): LabelScan(Person) → Expand(KNOWS, Reverse) → Expand(WORKS_AT) → Filter(age>25, size>1000)
-- Planner estimates cost of each via catalog stats, picks cheapest
```

The **ExpandInto** operator is a key graph-native optimization. When both endpoints of an edge are already bound, instead of scanning all neighbors (O(degree)), it checks edge existence via binary search on sorted adjacency lists (O(log degree)):
```cypher
-- Triangle pattern: a→b, b→c, a→c
MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person), (a)-[:KNOWS]->(c)
-- Plan: LabelScan(a) → Expand(a→b) → Expand(b→c) → ExpandInto(a→c)
-- ExpandInto checks if edge exists between already-bound a and c
```

**Picasso visualization** (available in samyama-insight) helps analyze CBO behavior by generating **plan diagrams** — color-coded maps showing which plan the optimizer selects at each point in the selectivity/parameter space. These visualizations reveal:
- **Plan switches**: Where the optimizer changes its preferred plan
- **Cost cliffs**: Sudden spikes in estimated cost at plan boundaries
- **Nervous regions**: Areas where small selectivity changes cause frequent plan switches
- **Robust plans**: Plans that perform well across a wide range of selectivities

The graph-native planner is enabled via `PlannerConfig { graph_native: true }` and falls back gracefully to the legacy planner for unsupported patterns (e.g., variable-length paths).

### What are "plan cliffs" and does Samyama have them?

A **plan cliff** occurs when a small change in data distribution causes the optimizer to switch to a dramatically different (and often worse) plan.

Example in a hypothetical CBO:
```
Selectivity of WHERE age > $threshold:
  threshold=95 → IndexScan  (fast, 5% of data)   → 2ms
  threshold=94 → IndexScan  (fast, 6% of data)   → 2.4ms
  threshold=93 → LabelScan! (slow, full table)    → 200ms  ← CLIFF!
```

The optimizer switches from index scan to full scan at a threshold, causing a 100x latency spike. Picasso visualizes these as sudden color changes in plan diagrams or sharp spikes in 3D cost surface plots.

Since v0.6.1, Samyama's graph-native planner evaluates multiple candidate plans per query. Plan cliffs are possible (e.g., switching starting point or direction as data distribution shifts). samyama-insight's Picasso tool visualizes these by sweeping parameter or pattern space and coloring cells by chosen plan, revealing plan switches and cost cliffs.

### Can I evaluate alternative plans for the same query (Foreign Plan Costing)?

**Yes, partially.** The graph-native planner stores `PlanDiagnostics` for each query, accessible via EXPLAIN:

```
EXPLAIN MATCH (p:Person)-[:WORKS_AT]->(c:Company) RETURN p, c

Planner diagnostics:
  Candidates evaluated: 2
  Chosen plan cost: 1000.0
  Alternatives:
    Plan starting from p: cost 1000.0 ← selected
    Plan starting from c: cost 1000.0
```

samyama-insight's Picasso page extends this further — sweeping parameter ranges and showing which plan wins at each point in the selectivity space. Full FPC-style "force a specific plan and measure sub-optimality" is on the roadmap.

### Can I visualize and compare execution plans (Plan Diffing)?

`EXPLAIN` outputs a textual operator tree, which can be compared manually between different queries:

```cypher
-- Query A:
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Output: IndexScanOperator(Person.name = 'Alice') → ProjectOperator

-- Query B:
EXPLAIN MATCH (n:Person) WHERE n.age > 25 RETURN n
-- Output: NodeScanOperator(Person) → FilterOperator(age > 25) → ProjectOperator

-- Manual diff: Query A uses IndexScan, Query B uses NodeScan + Filter
-- → Create an index on :Person(age) to improve Query B
```

There is no built-in plan diffing tool that automatically highlights differences between two plans. Plan diffing, plan diagram generation, and graphical plan visualization are on the roadmap.

### Is there plan caching or AST caching?

**Yes, since v0.6.0.** Samyama caches both parsed ASTs and execution plans, keyed by query string hash. Repeated queries skip parsing and planning entirely:

```cypher
-- First execution: parse + plan + execute
MATCH (n:Person) WHERE n.name = 'Alice' RETURN n    -- cold: ~40ms

-- Subsequent executions: cache hit, execute only
MATCH (n:Person) WHERE n.name = 'Alice' RETURN n    -- warm: ~2ms (cache hit)
```

The plan cache significantly reduces warm-query latency. LDBC benchmarks show high cache hit rates (e.g., 63 hits vs 21 misses on the SNB Interactive workload).

**Prepared statements** (`PREPARE`/`EXECUTE` syntax) are on the roadmap for explicit cache management.

### What is predicate pushdown, and does Samyama do it?

**Predicate pushdown** moves filter conditions as close to the data source as possible — filtering early reduces the number of records flowing through the rest of the plan.

Since v0.6.0, Samyama performs **full predicate pushdown** across paths and MATCH clauses:
- **Index pushdown**: When a WHERE predicate matches an indexed property, the `IndexScanOperator` applies the filter during the scan itself
- **Label filtering**: `NodeScanOperator` only scans nodes with the specified label, not all nodes
- **Cross-scope pushdown** (v0.6.0): WHERE predicates are scoped across paths and MATCH clauses, filtering as early as possible

```cypher
-- Index pushdown (index on :Person(name)):
MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
-- Plan: IndexScan(name='Alice')  ← filter is INSIDE the scan operator

-- Cross-scope pushdown (v0.6.0):
MATCH (a:Person)-[:KNOWS]->(b:Person)
WHERE b.age > 30
RETURN a.name, b.name
-- Plan: NodeScan(Person) → Expand(KNOWS) → Filter(b.age > 30) [pushed to earliest point]
```

Not yet implemented:
- Predicates on **aggregation results** (HAVING-style) are not pushed below the aggregation
- **Edge predicates** are not pushed into the `ExpandOperator`

### Can I force a specific execution plan or provide optimizer hints?

**Not yet.** Samyama does not currently support:
- `USING INDEX` directives (Neo4j-style)
- `USING SCAN` to force a label scan
- `USING JOIN ON` to force a specific join variable
- Query hints or optimizer directives of any kind

The only way to influence plan selection today is:

```cypher
-- 1. Create indexes so the planner automatically uses them:
CREATE INDEX ON :Person(name)
CREATE INDEX ON :Person(age)

-- 2. Reorder MATCH clauses (put most selective first):
-- Slow (scans all 1M persons first):
MATCH (a:Person), (b:Department {name: 'Engineering'}) ...
-- Fast (scans 1 department first):
MATCH (b:Department {name: 'Engineering'}), (a:Person) ...

-- 3. Use EXPLAIN to verify the plan:
EXPLAIN MATCH (n:Person) WHERE n.name = 'Alice' RETURN n
```

Optimizer hints and plan forcing are planned for a future release.

### What is the query optimizer roadmap?

The optimizer roadmap, roughly in priority order:

| Feature | Impact | Status |
| :--- | :--- | :---: |
| AST caching | Eliminate re-parsing (~22ms savings) | **Done (v0.6.0)** |
| Plan memoization | Eliminate re-planning (~18ms savings) | **Done (v0.6.0)** |
| Parameterized queries (`$param`) | Enable plan reuse across parameter values | **Done (v0.6.0)** |
| `PROFILE` (runtime statistics) | Actual rows, timing per operator | **Done (v0.6.0)** |
| `DROP INDEX` / `SHOW INDEXES` | Index lifecycle management | **Done (v0.6.0)** |
| Composite indexes | Multi-property indexes | **Done (v0.6.0)** |
| AND-chain index selection | Use best index for multi-predicate WHERE | **Done (v0.6.0)** |
| Predicate pushdown across scopes | Reduce intermediate result sizes | **Done (v0.6.0)** |
| Cost-based plan selection | Compare alternative plans by estimated cost | **Done (v0.6.0)** |
| Join reordering | Pick optimal join order based on cardinalities | **Done (v0.6.0)** |
| Early LIMIT propagation | Push LIMIT down to reduce work | **Done (v0.6.0)** |
| Index intersection | Combine multiple index scans | Planned |
| `USING INDEX` / `USING SCAN` hints | User-controlled plan forcing | Planned |
| Histogram-based statistics | Better selectivity estimates for skewed data | Planned |
| Adaptive query execution | Re-plan mid-execution if estimates are wrong | Research |

### How many physical operators does Samyama have?

**42 physical operators** organized into these categories:

| Category | Operators | Count |
| :--- | :--- | :---: |
| **Scan & Traverse** | NodeScanOperator, ExpandOperator, ExpandIntoOperator, IndexScanOperator, VectorSearchOperator, NodeByIdOperator, ShortestPathOperator | 7 |
| **Relational** | FilterOperator, ProjectOperator, JoinOperator, LeftOuterJoinOperator, CartesianProductOperator | 5 |
| **Aggregation** | AggregateOperator, UnwindOperator, ForeachOperator | 3 |
| **Sort & Limit** | SortOperator, LimitOperator, SkipOperator, WithBarrierOperator | 4 |
| **Write** | CreateNodeOperator, CreateEdgeOperator, CreateNodesAndEdgesOperator, MatchCreateEdgeOperator, MatchMergeEdgeOperator, DeleteOperator, SetPropertyOperator, RemovePropertyOperator, MergeOperator | 9 |
| **Schema/DDL** | CreateIndexOperator, CreateVectorIndexOperator, CompositeCreateIndexOperator, CreateConstraintOperator, DropIndexOperator, ShowIndexesOperator, ShowConstraintsOperator, ShowLabelsOperator, ShowRelationshipTypesOperator, ShowPropertyKeysOperator, SchemaVisualizationOperator | 11 |
| **Special** | SingleRowOperator, AlgorithmOperator | 2 |
| **Navigation** | ShortestPathOperator | 1 |

All operators implement the Volcano iterator model (lazy, pull-based) with late materialization (`Value::NodeRef` instead of full node clones).

### How many index types does Samyama have?

**6 distinct index types:**

| Index | Storage | Use Case | Complexity |
| :--- | :--- | :--- | :---: |
| **PropertyIndex** | B-Tree (`BTreeMap<PropertyValue, HashSet<NodeId>>`) | Point lookups and range scans on (label, property) | O(log n) |
| **VectorIndex** | HNSW (Hierarchical Navigable Small World) | Approximate nearest neighbor search | O(log n) |
| **LabelIndex** | `HashMap<Label, HashSet<NodeId>>` | Fast node lookup by label | O(1) |
| **EdgeTypeIndex** | `HashMap<EdgeType, HashSet<EdgeId>>` | Fast edge lookup by type | O(1) |
| **SortedAdjacencyLists** | Vec-of-Vec + FrozenAdjacency (CSR) | Neighbor traversal, `edge_between()` binary search | O(log d) |
| **ColumnStore** | Columnar property storage | Vectorized property reads for late materialization | O(1) |

Additionally:
- **Composite indexes** create individual PropertyIndex entries per property in the list
- **Unique constraints** are enforced via PropertyIndex with uniqueness validation on insert
- **GraphCatalog** maintains triple-level statistics (not an index, but used for cost-based planning)

---

## Graph Algorithms

### What algorithms are available?

13 algorithms in the `samyama-graph-algorithms` crate:

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
use samyama_sdk::AlgorithmClient;

let config = PageRankConfig { damping: 0.85, iterations: 20, tolerance: 1e-6 };
let scores = client.page_rank(config, "Person", "KNOWS").await?;
for (node_id, score) in &scores {
    println!("Node {}: {:.4}", node_id, score);
}
```

### How do I find shortest paths?

Using Dijkstra for weighted shortest paths:
```cypher
CALL algo.dijkstra({
  source_label: 'City', source_property: 'name', source_value: 'Mumbai',
  target_label: 'City', target_property: 'name', target_value: 'Delhi',
  edge_type: 'ROAD', weight_property: 'distance'
})
YIELD path, cost
```

Using BFS for unweighted shortest paths:
```cypher
CALL algo.bfs({
  source_label: 'Person', source_property: 'name', source_value: 'Alice',
  edge_type: 'KNOWS'
})
YIELD node, depth
```

### What is the CSR format and why is it used?

**Compressed Sparse Row (CSR)** is a cache-efficient array-based representation of a graph. Algorithms project from `GraphStore` into CSR for OLAP workloads because sequential memory access patterns allow CPU prefetching with ~100% accuracy.

Example — a graph with 4 nodes and 5 edges in CSR:
```
Adjacency:  0→1, 0→2, 1→2, 2→3, 3→0

out_offsets:  [0, 2, 3, 4, 5]   ← node i's edges start at out_offsets[i]
out_targets:  [1, 2, 2, 3, 0]   ← target node IDs, packed contiguously
weights:      [1.0, 1.0, ...]   ← optional edge weights

To iterate node 0's neighbors: out_targets[0..2] = [1, 2]
To iterate node 1's neighbors: out_targets[2..3] = [2]
```

This layout is ~10x faster than `HashMap<NodeId, Vec<NodeId>>` for iterative algorithms because it eliminates pointer chasing and hash lookups. See the [Analytical Power](./analytical_power.md) chapter.

### Does PCA support auto-selection of the solver?

Yes. `PcaSolver::Auto` selects Randomized SVD when `n > 500` and `k < 0.8 * min(n, d)`, otherwise falls back to Power Iteration.

Example via Cypher:
```cypher
CALL algo.pca({
  label: 'Document',
  properties: ['feature1', 'feature2', 'feature3', 'feature4'],
  components: 2,
  solver: 'auto'
})
YIELD node, components
```

Via Rust SDK:
```rust
let config = PcaConfig { components: 2, solver: PcaSolver::Auto };
let results = client.pca(config, "Document", &["feature1", "feature2", "feature3"]).await?;
```

---

## Vector Search & AI

### What distance metrics are supported?

Three metrics: **Cosine**, **L2 (Euclidean)**, and **Dot Product**.

Example — choosing the right metric:
```cypher
-- Cosine: best for text embeddings (direction matters, not magnitude)
CREATE VECTOR INDEX FOR (d:Document) ON (d.embedding) OPTIONS {dimensions: 768, similarity: 'cosine'}

-- L2: best for spatial data (absolute distance matters)
CREATE VECTOR INDEX FOR (p:Point) ON (p.coords) OPTIONS {dimensions: 3, similarity: 'l2'}

-- Dot Product: best for pre-normalized embeddings
CREATE VECTOR INDEX FOR (i:Item) ON (i.features) OPTIONS {dimensions: 128, similarity: 'dot_product'}
```

### What is Graph RAG?

Graph RAG combines vector search with graph traversal in a single query. Instead of retrieving vectors and filtering in the application layer, Samyama applies graph filters *inside* the execution engine.

Example — find documents similar to a query, but only from a specific author's department:
```cypher
MATCH (a:Author {name: 'Alice'})-[:WORKS_IN]->(dept:Department)
MATCH (d:Document)-[:AUTHORED_BY]->(colleague)-[:WORKS_IN]->(dept)
CALL db.index.vector.queryNodes('Document', 'embedding', $query_vector, 10)
YIELD node, score
WHERE node = d
RETURN d.title, score, colleague.name
ORDER BY score DESC
```

This prevents the "filter-out-all-results" problem where a pure vector search returns documents from irrelevant departments. See [AI & Vector Search](./ai_vector_search.md).

### How do I generate embeddings? Why is Mock the default?

Samyama **indexes and searches** vectors but does not bundle an embedding model. The default `Mock` provider generates random vectors — this is deliberate to keep the binary small (~30MB savings), avoid mandatory model downloads, and let you choose the embedding model that fits your domain.

**For real embeddings, choose based on your stack:**

| Stack | Provider | Setup |
| :--- | :--- | :--- |
| Python | `sentence-transformers` | `pip install sentence-transformers` — best model selection, easiest path |
| Rust | `ort` crate (ONNX Runtime) | Export model to ONNX, load with `ort::Session` — fastest, no Python |
| Any language | OpenAI API | HTTP call to `/v1/embeddings` — simplest, pay-per-use |
| Any language (local) | Ollama | `ollama pull nomic-embed-text` — free, private, runs anywhere |

**Python example with sentence-transformers:**
```python
from samyama import SamyamaClient
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2")  # 384-dim
client = SamyamaClient.embedded()
client.create_vector_index("Document", "embedding", 384, "cosine")

embedding = model.encode("Graph databases unify structure and search").tolist()
client.add_vector("Document", "embedding", node_id, embedding)
```

See [AI & Vector Search — Embedding Providers](./ai_vector_search.md#embedding-providers) for complete examples across all providers.

### What is Agentic Enrichment (GAK)?

**Generation-Augmented Knowledge (GAK)** is the inverse of RAG. Instead of using the database to help an LLM, the database uses an LLM to help build itself.

Example flow:
```
1. Event:    New node created: (:Company {name: 'Acme Corp'})
2. Trigger:  AgentRuntime detects missing properties (industry, revenue, CEO)
3. LLM Call: "What industry is Acme Corp in? Who is the CEO?"
4. Result:   SET n.industry = 'Manufacturing', n.revenue = 5000000
             CREATE (n)-[:LED_BY]->(:Person {name: 'Jane Smith', role: 'CEO'})
5. Safety:   Schema validation + destructive query rejection before commit
```

See [Agentic Enrichment](./agentic_enrichment.md).

### What LLM providers are supported for NLQ?

The `NLQClient` supports: **OpenAI**, **Google Gemini**, **Ollama** (local), **Anthropic** (Claude API), **Claude Code**, and **Azure OpenAI**. A **Mock** provider is also available for testing.

Example — natural language to Cypher:
```rust
let pipeline = NLQPipeline::new(NLQConfig {
    enabled: true,
    provider: LLMProvider::OpenAI,
    model: "gpt-4o".to_string(),
    api_key: Some(env::var("OPENAI_API_KEY")?),
    api_base_url: None,
    system_prompt: None,
})?;

let cypher = pipeline.text_to_cypher(
    "Who are Alice's friends that work at Google?",
    &schema_summary
).await?;
// Returns: MATCH (a:Person {name: 'Alice'})-[:KNOWS]->(f:Person)-[:WORKS_AT]->(c:Company {name: 'Google'}) RETURN f.name
```

Supported providers: `LLMProvider::OpenAI`, `Ollama`, `Gemini`, `Anthropic`, `ClaudeCode`, `AzureOpenAI`, `Mock` (for testing).

The pipeline uses a **whitelist** safety check — only queries starting with `MATCH`, `RETURN`, `UNWIND`, `CALL`, or `WITH` are allowed through, preventing accidental mutations from LLM-generated Cypher.

---

## Optimization

### How many solvers are available?

22 metaheuristic solvers in the `samyama-optimization` crate:
- **Metaphor-less**: Jaya, QOJAYA, Rao (1-3), TLBO, ITLBO, GOTLBO
- **Swarm/Evolutionary**: PSO, DE, GA, GWO, ABC, BAT, Cuckoo, Firefly, FPA
- **Physics-based**: GSA, SA, HS, BMR, BWR
- **Multi-objective**: NSGA-II, MOTLBO

### How do I run an optimization solver?

Via Cypher:
```cypher
-- Single-objective: minimize supply chain cost
CALL algo.or.solve({
  solver: 'jaya',
  dimensions: 5,
  bounds: [[0, 100], [0, 100], [0, 100], [0, 100], [0, 100]],
  objective: 'minimize',
  fitness_function: 'supply_chain_cost',
  iterations: 1000,
  population: 50
})
YIELD solution, fitness

-- Multi-objective: Pareto-optimal trade-offs
CALL algo.or.solve({
  solver: 'nsga2',
  dimensions: 3,
  bounds: [[0, 1], [0, 1], [0, 1]],
  objectives: ['minimize_cost', 'maximize_quality'],
  population: 100,
  generations: 200
})
YIELD pareto_front
```

### Are the optimization solvers open-source or enterprise-only?

All 22 solvers are in the **open-source** `samyama-optimization` crate. Enterprise adds GPU-accelerated constraint evaluation for large-scale problems.

### How do I choose the right solver?

| Scenario | Recommended Solver | Why |
| :--- | :--- | :--- |
| Simple optimization, no tuning | **Jaya** | Parameter-free, good baseline |
| Constraints with penalty functions | **PSO** or **GWO** | Good constraint handling |
| Multiple conflicting objectives | **NSGA-II** | Constrained Dominance Principle, Pareto front |
| High-dimensional search space | **DE** | Good for 10+ dimensions |
| Need global optimum, avoid local minima | **SA** (Simulated Annealing) | Probabilistic escape from local minima |
| Teaching/learning-inspired | **TLBO** | No algorithm-specific parameters |

---

## Performance & Scaling

### What are the latest benchmark numbers?

On Mac Mini M4 (16GB RAM), v0.6.0:

| Benchmark | CPU | GPU |
| :--- | :---: | :---: |
| **Node Ingestion** | 255K/s | 412K/s |
| **Edge Ingestion** | 4.2M/s | 5.2M/s |
| **Cypher OLTP (1M nodes)** | 115K QPS | — |
| **PageRank (1M nodes)** | 92ms | 11ms (8.2x) |
| **Vector Search (10K, 128d)** | 15K QPS | — |

### When should I use GPU acceleration?

GPU acceleration is beneficial for graphs with **> 100,000 nodes**. Below this threshold, CPU-GPU memory transfer overhead dominates.

Example — PageRank speedup at different scales:
```
10K nodes:   CPU 0.6ms vs GPU 9.3ms  → GPU is SLOWER (0.06x)
100K nodes:  CPU 8.2ms vs GPU 3.1ms  → GPU wins (2.6x faster)
1M nodes:    CPU 92ms  vs GPU 11ms   → GPU wins big (8.2x faster)
```

For PCA specifically, the threshold is 50,000 nodes and > 32 dimensions.

### Has Samyama been validated against industry benchmarks?

Yes. Samyama achieved **28/28 (100%)** on the LDBC Graphalytics benchmark suite across 6 algorithms (BFS, PageRank, WCC, CDLP, LCC, SSSP) on both XS and S-size datasets.

```bash
# Run the validation yourself:
cargo bench --bench graphalytics_benchmark -- --all
```

S-size datasets include cit-Patents (3.8M vertices), datagen-7_5-fb (633K vertices, 68M edges), and wiki-Talk (2.4M vertices). See [Performance & Benchmarks](./performance_benchmarks.md#ldbc-graphalytics-validation).

### What is the bottleneck in query execution?

At 1M nodes, the bottleneck is the **language frontend** (parsing: 54%, planning: 44%), not execution (2%):

```
Component          Time      % of total
─────────────────────────────────────────
Parse (Pest)       ~22ms     54%
Plan (AST→Ops)     ~18ms     44%
Execute (iterate)  <1ms       2%  ← actual graph work is sub-millisecond!
```

As of v0.6.0, a **plan cache** memoizes compiled execution plans for repeated queries, eliminating the parsing and planning overhead on warm queries. Parameterized queries (`$param`) further improve cache hit rates by separating query structure from literal values.

### Where do the Neo4j and Memgraph comparison numbers come from?

Table 10 in the [arxiv paper (2603.08036)](https://arxiv.org/abs/2603.08036) compares Samyama against Neo4j 5.x and Memgraph 2.x. Here are the sources for each competitor number:

**1-Hop Query Latency** — Memgraph ~1.1 ms, Neo4j ~28 ms:
From Memgraph's official benchmark (Expansion 1 query: Memgraph 1.09 ms, Neo4j 27.96 ms).
- Source: [Memgraph vs. Neo4j: A Performance Comparison](https://memgraph.com/blog/memgraph-vs-neo4j-performance-benchmark-comparison)

**Node Ingestion** — Neo4j ~26K/s, Memgraph ~295K/s:
From Memgraph's write speed analysis — Neo4j took 3.8s to create 100K nodes (~26K/s); Memgraph took ~400ms for 100K nodes (~250K/s).
- Source: [Memgraph or Neo4j: Analyzing Write Speed Performance](https://memgraph.com/blog/memgraph-or-neo4j-analyzing-write-speed-performance)

**Memory (1M nodes)** — Neo4j ~1,200 MB, Memgraph ~600 MB:
Neo4j's JVM heap sizing recommendations (heap + page cache overhead for graph workloads); Memgraph's C++ in-memory architecture characteristics.
- Source: [Neo4j Memory Configuration](https://neo4j.com/docs/operations-manual/current/performance/memory-configuration/)
- Source: [Memgraph vs Neo4j in 2025](https://medium.com/decoded-by-datacast/memgraph-vs-neo4j-in-2025-real-time-speed-or-battle-tested-ecosystem-66b4c34b117d)

**GC Pauses** — Neo4j 10-100 ms, Samyama/Memgraph 0 ms:
Neo4j's GC tuning documentation describes old-generation garbage collection pauses; Samyama (Rust) and Memgraph (C++) have no garbage collector.
- Source: [Neo4j GC Tuning](https://neo4j.com/docs/operations-manual/current/performance/gc-tuning/)

**Additional resources:**
- [Memgraph BenchGraph](https://memgraph.com/benchgraph) — interactive benchmark comparison tool
- [Memgraph White Paper: Performance Benchmark](https://memgraph.com/white-paper/performance-benchmark-graph-databases)

> **Note:** The memory numbers (~1,200 MB for Neo4j, ~600 MB for Memgraph at 1M nodes) are estimates based on architecture characteristics rather than a single published benchmark at exactly 1M nodes. The ingestion and latency numbers come from Memgraph's published benchmarks, which were conducted on their hardware and configuration. Samyama numbers are measured on Mac Mini M4 (16 GB RAM). As stated in the paper: *"Direct comparison is approximate due to different hardware, datasets, and query optimization levels."*

---

## Architecture Deep Dive

### Is Samyama ACID-compliant or eventually consistent?

Samyama provides **local ACID** guarantees for single-node deployments:

- **Atomicity**: Each write query (CREATE, DELETE, SET, MERGE) executes as an atomic `WriteBatch` via RocksDB. Either all changes commit or none do.
- **Consistency**: Unique constraints (when defined) are enforced before commit. Schema integrity is maintained across labels, edges, and properties.
- **Isolation**: The in-memory `GraphStore` uses a `RwLock` — multiple concurrent readers with exclusive writer access. Queries see a consistent snapshot.
- **Durability**: The Write-Ahead Log (WAL) persists every mutation before acknowledgement. On crash recovery, uncommitted WAL entries are replayed.

In a **Raft cluster** (Enterprise), writes go through consensus — a write is acknowledged only after a majority of nodes have persisted the log entry. This provides strong consistency (linearizable writes) at the cost of write latency. There is no "eventually consistent" mode.

Interactive multi-statement transactions (`BEGIN...COMMIT`) are on the roadmap. Today, each Cypher statement is an implicit transaction.

### Is Samyama multi-master? How does Raft synchronization work?

No. Samyama uses **single-leader** Raft consensus (via the `openraft` crate):

- **One leader** accepts all write requests and replicates them to followers.
- **Followers** can serve read queries (read replicas) for horizontal read scaling.
- If the leader fails, a new leader is automatically elected (typically within 1–2 seconds).

This is not a multi-master architecture. Multi-master would require conflict resolution (CRDTs, last-write-wins, etc.), which adds complexity and weakens consistency guarantees. Single-leader Raft gives us strong consistency without conflict resolution overhead.

```
Client Write ──► Leader ──► Follower 1 (ack)
                       └──► Follower 2 (ack)
                       └──► majority acked → commit → respond to client
```

### Does Samyama use the RocksDB C/C++ library or a Rust port?

Samyama uses **`rust-rocksdb`**, which is a Rust binding to the original C++ RocksDB library from Meta (Facebook). It is NOT a Rust rewrite — it links against the actual C++ RocksDB via FFI (Foreign Function Interface). This means:

- We get the battle-tested, production-proven RocksDB storage engine (used by Meta, CockroachDB, TiKV, etc.)
- The Rust binding provides safe, idiomatic Rust APIs over the C++ core
- Performance is identical to native RocksDB — no overhead from the binding layer

RocksDB handles compaction, compression (LZ4/Zstd), bloom filters, and sorted string tables (SSTs). Samyama uses RocksDB column families for multi-tenancy isolation.

### How does concurrency work?

Samyama uses a **readers-writer lock** (`tokio::sync::RwLock`) at the `GraphStore` level:

- **Reads** (MATCH queries): Multiple readers can execute concurrently. Each reader acquires a shared read lock.
- **Writes** (CREATE, DELETE, SET, MERGE): A writer acquires an exclusive lock. No reads or other writes proceed while a write is in progress.
- **RESP server**: The Tokio async runtime handles thousands of concurrent connections. Read queries are processed concurrently; write queries are serialized.

This model is simple and correct. For read-heavy workloads (typical for graph databases), it provides excellent throughput since reads never block each other. Write throughput is limited to one writer at a time, but individual writes are fast (sub-millisecond for most mutations).

Future work includes finer-grained concurrency (per-partition or MVCC-based), but the current model handles production workloads well because graph queries spend most time in traversal (reading), not mutation.

### Are you using SIMD for graph traversal?

Not currently in explicit SIMD intrinsics, but we benefit from **auto-vectorization** by the LLVM backend (Rust compiles via LLVM). The `--release` build enables `-O3` optimizations which include:

- Auto-vectorized array operations in adjacency list scanning
- SIMD-friendly memory layouts in the CSR (Compressed Sparse Row) representation used by graph algorithms
- Cache-line-aligned data structures for traversal hot paths

For GPU acceleration (Enterprise), we use **WGSL compute shaders** via `wgpu` — this is massively parallel computation (thousands of GPU threads), which is a different paradigm from CPU SIMD. GPU shaders handle PageRank, CDLP, LCC, Triangle Counting, and PCA on large graphs (>100K nodes).

Explicit CPU SIMD intrinsics (e.g., for batch property filtering or distance calculations) are on the roadmap but not yet implemented.

### How does multi-tenancy work internally? Is there database-level isolation?

Yes, tenants get **storage-level isolation** via RocksDB Column Families:

- Each tenant gets its own **Column Family** in a single RocksDB instance. Column families are logically separate key-value namespaces — they have independent memtables, SST files, and compaction schedules.
- One tenant's heavy writes or compaction do **not** affect other tenants' read/write performance.
- **Per-tenant quotas** are enforced: `max_nodes`, `max_edges`, `max_memory_bytes`, `max_storage_bytes`, `max_connections`, and `max_query_time_ms`.

```
┌──────────── Single RocksDB Instance ────────────┐
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │  CF: acme   │  │ CF: globex  │  │ CF: ...  │ │
│  │  memtable   │  │  memtable   │  │          │ │
│  │  SST files  │  │  SST files  │  │          │ │
│  │  WAL        │  │  WAL        │  │          │ │
│  └─────────────┘  └─────────────┘  └──────────┘ │
└─────────────────────────────────────────────────┘
```

We chose a single RocksDB instance with column families over multiple RocksDB instances because:
1. **Lower resource overhead**: One set of background threads, one WAL, shared block cache
2. **Simpler operations**: One database to back up, monitor, and recover
3. **Proven at scale**: TiKV (TiDB's storage engine) uses the same column-family-per-region approach

If you need stronger isolation (separate processes, separate machines), the Raft cluster topology allows deploying dedicated nodes per tenant.

### How does embedding work? Is it a .so file or a Rust library?

Both options are available:

1. **Rust library (primary)**: Add `samyama-sdk` as a Cargo dependency. The `EmbeddedClient` runs the full engine in-process — no server, no network, no serialization overhead.

   ```toml
   [dependencies]
   samyama-sdk = "0.6"
   ```

   ```rust
   let client = EmbeddedClient::new();
   client.query("default", "CREATE (n:Person {name: 'Alice'})").await?;
   ```

2. **Python binding (PyO3)**: The Python SDK compiles to a native `.so` / `.dylib` shared library via PyO3. Install with `pip install samyama` (or `maturin develop` from source). No Rust toolchain needed at runtime.

   ```python
   from samyama import SamyamaClient
   client = SamyamaClient.embedded()
   result = client.query("default", "MATCH (n) RETURN count(n)")
   ```

3. **C FFI (planned)**: A C-compatible shared library (`.so` / `.dll`) for embedding from any language with FFI support (Go, Java, C#, etc.) is on the roadmap.

For production services, most users run Samyama as a **standalone server** (RESP on :6379, HTTP on :8080) and connect via the Rust, Python, or TypeScript SDK using the `RemoteClient`.

---

## Distributed Deployment & High Availability

### Does Samyama support replication?

Yes. Samyama implements **Raft consensus** (via the `openraft` Rust crate) for distributed replication. All write operations (CREATE, SET, DELETE, MERGE) are replicated to followers before being committed.

**How it works:**
1. Client sends a write to the Raft leader
2. Leader appends to its local log (uncommitted)
3. Leader sends `AppendEntries` to followers in parallel
4. Once a quorum (majority) acknowledges, the entry is committed
5. Leader applies to the graph store and returns success
6. Followers apply in the next heartbeat cycle

**Configuration:** 500ms heartbeat, 1.5–3s election timeout, log compaction after 5000 entries.

### How does a node failure get handled?

| Scenario | Behavior | Downtime |
|----------|----------|----------|
| **Follower fails** (1 of 3) | Quorum still holds (2/2), writes continue | None |
| **Leader fails** | Election triggered, new leader elected | 150–300ms |
| **Network partition** | Majority partition continues; minority rejects writes | Auto-heals on reconnection |

**Recovery:** When a failed node comes back online, it receives heartbeats from the current leader, requests missing log entries, catches up, and rejoins the cluster. No manual intervention needed.

**Data safety:** A Raft entry is committed only after replication to a majority. Even if the leader crashes immediately after committing, at least one other node has the data.

### How does tenant persistence and restore work?

Each tenant's data is persisted to **RocksDB** using column families (one per tenant). The write path is:

1. **Write-Ahead Log (WAL)** — sequential log for durability
2. **RocksDB** — indexed storage with tenant-prefixed keys
3. **In-memory graph** — the live GraphStore

On restart, `PersistenceManager::recover(tenant)` scans all nodes and edges from RocksDB and rebuilds the in-memory adjacency lists.

**Snapshots (`.sgsnap`)** provide an additional backup mechanism:
- Export: `POST /api/snapshot/export` → gzip-compressed JSON-lines file
- Import: `POST /api/snapshot/import` → ID remapping allows importing into non-empty stores
- Use cases: disaster recovery, tenant migration, version-controlled deployments

### How does this work in a distributed deployment?

In a Raft cluster:
- **All nodes hold a full copy** of every tenant's data (full replication, not partitioned)
- The leader processes writes and replicates via Raft log entries
- Followers can serve read queries (if configured for read replicas)
- Snapshot and WAL are per-node; Raft log is the source of truth for consistency

**Tenant-level sharding** is implemented: a routing layer maps each tenant to a specific Raft cluster. Different tenants can be served by different clusters, providing logical isolation.

```
Tenant A → Raft Cluster 1 (nodes 1, 2, 3)
Tenant B → Raft Cluster 2 (nodes 4, 5, 6)
Tenant C → Raft Cluster 1 (same cluster as A)
```

### What if a tenant needs 1 billion nodes? Isn't sharding necessary?

Yes. Today, Samyama's graph store is **in-memory**, so a single graph is limited by available RAM on one node. Practical limits:

| Nodes | Edges | Approx. RAM |
|------:|------:|------------|
| 100K | 1M | ~500 MB |
| 1M | 10M | ~5 GB |
| 8M | 28M | ~33 GB |
| 100M | 500M | ~150 GB |
| 1B | 5B | ~1.5 TB |

For **1 billion nodes**, you would need either a very large machine (1.5+ TB RAM) or **graph-level sharding** — partitioning a single graph across multiple nodes.

**Current status:** Graph-level sharding is **designed but not yet implemented** (ADR-009). The approach uses graph-aware partitioning (METIS min-cut algorithm) to minimize cross-partition edges, with scatter-gather distributed query execution via Arrow Flight RPC.

**Why not yet?** It's a research-level problem with very high complexity. The current Raft replication handles the majority of production use cases. Graph-level sharding will be implemented when customer demand justifies the engineering investment.

**Workaround today:** For very large graphs, use a machine with sufficient RAM (e.g., AWS `r6i.24xlarge` with 768 GB, or `x2idn.32xlarge` with 2 TB). The in-memory architecture means queries are extremely fast on these machines.

### What are the recommended cluster sizes?

| Cluster | Quorum | Fault Tolerance | Write Latency |
|---------|--------|-----------------|---------------|
| 1 node | 1 | None | ~1.2ms |
| 3 nodes | 2 | 1 failure | ~2.8ms |
| 5 nodes | 3 | 2 failures | ~3.5ms |

**Recommendation:** 3 nodes for most deployments (balances availability and latency). 5 nodes for critical workloads requiring tolerance of 2 simultaneous failures.

---

## Enterprise & Operations

### How does licensing work?

Enterprise uses **JET (JSON Enablement Token)**—an Ed25519-signed token containing org, edition, features, expiry, and machine fingerprint. 30-day grace period after expiry.

```bash
# Check license status:
redis-cli ADMIN.LICENSE

# Set license file:
SAMYAMA_LICENSE_FILE=/path/to/samyama.license cargo run --release --features gpu
```

See [Enterprise Edition](./samyama_enterprise.md#5-licensing--governance).

### How do I create a backup?

```bash
# Full snapshot
redis-cli ADMIN.BACKUP CREATE

# List all backups
redis-cli ADMIN.BACKUP LIST

# Verify integrity of backup #5
redis-cli ADMIN.BACKUP VERIFY 5

# Restore from backup
redis-cli ADMIN.BACKUP RESTORE 5
```

### What is Point-in-Time Recovery (PITR)?

PITR replays archived WAL entries against a snapshot to restore the database to an exact moment.

Example scenario:
```
10:30:00  Backup snapshot taken
10:30:04  Normal writes happening
10:30:05  Accidental: DELETE (n:Customer) WHERE n.region = 'APAC'   ← oops!
10:30:06  More writes

# Restore to 10:30:04 (before the accidental delete):
redis-cli ADMIN.PITR RESTORE "2026-03-04T10:30:04.000000"
# All APAC customers are back, writes after 10:30:04 are lost
```

### How does multi-tenancy work?

Each tenant gets a dedicated RocksDB Column Family with per-tenant resource quotas (memory, storage, query time). Compaction is independent per tenant—one tenant's write-heavy workload won't affect others.

Example — querying within a specific tenant:
```bash
# Create a graph in tenant "acme"
redis-cli GRAPH.QUERY acme "CREATE (n:User {name: 'Alice'})"

# Query within that tenant (isolated from other tenants)
redis-cli GRAPH.QUERY acme "MATCH (n:User) RETURN n.name"

# Different tenant, different data
redis-cli GRAPH.QUERY globex "MATCH (n:User) RETURN n.name"  -- returns different results
```

See [Observability & Multi-tenancy](./observability_multi_tenancy.md).

---

## RDF & SPARQL

### What RDF serialization formats are supported?

| Format | Read | Write | Example |
| :--- | :---: | :---: | :--- |
| Turtle (.ttl) | ✅ | ✅ | `@prefix ex: <http://example.org/> . ex:Alice a ex:Person .` |
| N-Triples (.nt) | ✅ | ✅ | `<http://example.org/Alice> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://example.org/Person> .` |
| RDF/XML (.rdf) | ✅ | ✅ | `<rdf:Description rdf:about="http://example.org/Alice">` |
| JSON-LD (.jsonld) | ❌ | ✅ | `{"@id": "http://example.org/Alice", "@type": "Person"}` |

### Is SPARQL fully implemented?

SPARQL parser infrastructure is in place (via the `spargebra` crate), but query execution is not yet operational. The focus is on the OpenCypher engine.

Example of what will be supported:
```sparql
PREFIX ex: <http://example.org/>
SELECT ?name ?age
WHERE {
  ?person a ex:Person .
  ?person ex:name ?name .
  ?person ex:age ?age .
  FILTER (?age > 25)
}
ORDER BY ?name
```

See [RDF & SPARQL](./rdf_sparql.md).

### Can I use RDF and property graph data together?

A mapping framework (`MappingConfig`) is defined for converting between RDF triples and property graph nodes/edges. Automatic bidirectional conversion is on the roadmap.

Example of the conceptual mapping:
```
RDF Triple:  <ex:Alice>  <ex:knows>  <ex:Bob>
                  ↕              ↕           ↕
Property Graph:  (:Person {uri: 'ex:Alice'}) -[:knows]-> (:Person {uri: 'ex:Bob'})
```

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
use samyama_sdk::{EmbeddedClient, SamyamaClient};

let client = EmbeddedClient::new();

// Write data
client.query("default", "CREATE (n:Person {name: 'Alice', age: 30})").await?;
client.query("default", "CREATE (n:Person {name: 'Bob', age: 25})").await?;

// Query data
let result = client.query("default", "MATCH (n:Person) WHERE n.age > 28 RETURN n.name").await?;
println!("{:?}", result.rows);  // [["Alice"]]
```

### How do I use the CLI?

```bash
# Single query
samyama-cli query "MATCH (n:Person) RETURN n.name, n.age" --format table

# Output:
# +-------+-----+
# | n.name| n.age|
# +-------+-----+
# | Alice |  30  |
# | Bob   |  25  |
# +-------+-----+

# Interactive REPL
samyama-cli shell
samyama> MATCH (n) RETURN count(n)
samyama> CREATE (n:City {name: 'Mumbai', population: 20000000})

# Server status
samyama-cli status --format json

# Health check
samyama-cli ping
```

### Does the Python SDK support algorithms directly?

Yes (v0.6.0+). The Python SDK provides **direct method-level algorithm access** in embedded mode, in addition to Cypher `CALL algo.*` queries:

```python
from samyama import SamyamaClient

# Embedded mode (no server required)
client = SamyamaClient.embedded()

# Create data
client.query("default", "CREATE (a:Person {name: 'Alice'})-[:KNOWS]->(b:Person {name: 'Bob'})")

# Direct algorithm methods (embedded mode only)
scores = client.page_rank("Person", "KNOWS", damping=0.85, iterations=20)
components = client.wcc("Person", "KNOWS")
distances = client.bfs("Person", "KNOWS", start_node_id=0)
shortest = client.dijkstra("Person", "KNOWS", source_id=0, target_id=1, weight_property="weight")

# Also available: scc(), pca(), triangle_count()

# Or via Cypher (works in both embedded and remote mode)
result = client.query("default", """
    CALL algo.pagerank({label: 'Person', edge_type: 'KNOWS', iterations: 20})
    YIELD node, score
""")
```

### How do I use the TypeScript SDK?

```typescript
import { SamyamaClient } from 'samyama-sdk';

const client = SamyamaClient.connectHttp('http://localhost:8080');

// Query
const result = await client.query('default', 'MATCH (n:Person) RETURN n.name');
console.log(result.rows);

// Create data
await client.query('default', `
  CREATE (a:Person {name: 'Alice'})-[:KNOWS]->(b:Person {name: 'Bob'})
`);
```

---

## Project & Commercial

### What is Samyama's motivation and long-term vision?

Samyama was born from the observation that existing graph databases force users to choose between **performance** (C++/Rust in-memory engines), **features** (Cypher, vector search, NLQ, graph algorithms), and **operational simplicity** (easy deployment, Redis protocol compatibility). We believe a modern graph database should deliver all three.

The name "Samyama" comes from Sanskrit — it means "integration" or "bringing together." The database integrates property graphs, vector search, natural language queries, graph algorithms, and constrained optimization into a single engine.

Long-term, Samyama aims to be the **converged graph + AI database** — where graph structure, vector embeddings, and LLM-powered queries work together natively, not as bolted-on features.

### How do you plan to maintain this over 6–8 years?

Three pillars:

1. **Rust as a foundation**: Rust's memory safety, zero-cost abstractions, and absence of garbage collection give us a codebase that is inherently more maintainable than C++ (no memory bugs) and more performant than JVM-based alternatives (no GC pauses). The compiler catches entire classes of bugs at compile time.

2. **Open-core model**: The Community Edition (Apache 2.0) ensures the core engine always has community scrutiny and contributions. Enterprise features (monitoring, backup, GPU, audit) are layered on top — they don't fork the core. This means maintenance effort focuses on one engine, not two.

3. **Revenue-funded engineering**: The Enterprise tier funds dedicated engineering. We're not dependent on VC funding cycles. The pricing model (data-scale tiers, not per-seat) ensures revenue grows with customer success.

We also invest heavily in automated quality: 250+ unit tests, 10 benchmark suites, LDBC Graphalytics validation (100% pass rate), and LDBC SNB Interactive/BI benchmarks run on every release.

### What features are Enterprise-only vs. open source?

The core principle: **Enterprise gates operations, not functionality.** The full query engine, all algorithms, vector search, NLQ, persistence, and multi-tenancy are in the open-source Community Edition. Enterprise adds:

| Enterprise-Only Feature | Why Enterprise |
| :--- | :--- |
| GPU acceleration (wgpu shaders) | Hardware-specific, driver dependencies |
| Prometheus metrics / health checks | Production monitoring |
| Backup & restore (full/incremental/PITR) | Data protection SLA |
| Audit logging | Compliance (SOC2, GDPR) |
| Enhanced Raft (HTTP/2 transport, snapshot streaming) | Production HA |
| ADMIN commands (CONFIG, STATS, TENANTS) | Operational control |

### How is the Enterprise edition priced?

Samyama uses a **data-scale + cluster-size** pricing model — not per-seat, not per-CPU, not per-query. Pricing is transparent and published:

| Tier | Price | Data Limit | Cluster | Support |
| :--- | :--- | :--- | :--- | :--- |
| **Community** | Free | Unlimited | 1 node | GitHub community |
| **Pro** | $499/mo ($4,990/yr) | 10M nodes | Up to 3 nodes | Email, 48h SLA |
| **Enterprise** | $2,499/mo ($24,990/yr) | 100M nodes | Unlimited | 24/7, 4h Sev1 SLA |
| **Dedicated Cloud** | Contact sales | Unlimited | Unlimited | Named TAM, 1h Sev1 SLA |

Annual commitment saves 17%. Multi-year (3-year) saves 30%.

We deliberately avoid per-CPU/per-core licensing — customers shouldn't worry about hardware choices. Price scales with the value delivered (data size, operational maturity), not with infrastructure decisions.

### Do you provide support? What does it look like?

| Tier | Support Level | Response Time |
| :--- | :--- | :--- |
| Community | GitHub Issues, community forums | Best-effort |
| Pro | Email support | 48h for general, 24h for Sev1 |
| Enterprise | 24/7 support, phone escalation | 4h for Sev1, 8h for Sev2 |
| Dedicated | Named Technical Account Manager | 1h for Sev1, custom SLA |

Add-ons available: dedicated support engineer (+$2,000/mo), premium SLA upgrade (+$500/mo), custom integration/consulting ($250/hr).

### Is the pricing recurring or one-time? Per-CPU?

**Recurring** — monthly or annual subscription. Annual prepay saves 17%.

We explicitly avoid per-CPU/per-core licensing. The pricing model is based on **data scale** (node count) and **cluster size** (number of HA nodes). Customers can run on any hardware without license implications — whether it's a 4-core laptop or a 128-core server.

### Do you offer OEM licensing?

Yes. For partners who embed Samyama within their own product or manage it on behalf of their clients, we offer **OEM / Embedded licensing** with:

- **White-label deployment**: No Samyama branding visible to end customers
- **Volume-based pricing**: Per-deployment or per-end-customer pricing rather than per-instance
- **Redistribution rights**: Bundle Samyama binaries within your product installer
- **Dedicated integration support**: Engineering assistance for embedding and customization

OEM licensing is structured as a custom annual agreement. Contact sales for terms that match your deployment model (SaaS platform, managed service, on-prem appliance, etc.).
