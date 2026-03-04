# The Future of Graph DBs

We have built a strong foundation, but the journey is just beginning. As we look toward version 1.0 and beyond, several frontier technologies will define the next generation of Samyama.

## Recently Completed (v0.5.8 – v0.5.12)

Before looking ahead, here are major milestones recently delivered:

- **SDK Ecosystem**: Rust SDK (`SamyamaClient` trait, `EmbeddedClient`, `RemoteClient`), Python SDK (PyO3), TypeScript SDK, and CLI — all domain examples migrated to use SDK.
- **RDF & SPARQL Foundation**: RDF data model with `oxrdf`, triple store with SPO/POS/OSP indices, Turtle/N-Triples/RDF-XML serialization, SPARQL parser infrastructure.
- **PCA Algorithm**: Randomized SVD (Halko-Martinsson-Tropp) and Power Iteration solvers in the `samyama-graph-algorithms` crate, with GPU-accelerated PCA in Enterprise.
- **OpenAPI Specification**: Formal API documentation at `api/openapi.yaml`.
- **WITH Projection Barrier**: Full `WITH` clause support for query pipelining.
- **EXPLAIN with Graph Statistics**: Cost-based query plan visualization with label counts, edge type counts, and property selectivity.

## 1. Time-Travel Queries (Temporal Graphs)
Data is not static; it flows. Current graph databases only show the *current* state.

We plan to expose our internal MVCC versions to the user.
**Goal**: Allow queries like:
```cypher
MATCH (p:Person)-[:KNOWS]->(f:Person)
WHERE p.name = 'Alice'
AT TIME '2023-01-01' -- Query the graph as it looked last year
RETURN f.name
```
This is invaluable for auditing, debugging, and historical analysis.

## 2. Graph-Level Sharding
Currently, we shard by **Tenant**. This is perfect for SaaS but limits the size of a *single* graph to one machine's capacity (vertical scaling).

**The Challenge**: Partitioning a single graph across multiple machines is the "Holy Grail" of graph databases. It introduces the "Min-Cut" problem (minimizing edges that cross machines) to reduce network latency.

**The Plan**: We are investigating **METIS** and streaming partitioning algorithms to intelligently distribute nodes based on community structure, ensuring that "friends stay together" on the same physical server.

## 3. Distributed Query Execution (Scatter-Gather)
To complement Graph-Level Sharding, the query engine must evolve from a single-node vectorized iterator to a distributed execution framework.
*   **Query Coordinator**: Will partition the physical plan into sub-plans.
*   **Workers**: Execute local traversals.
*   **Shuffle/Exchange Operators**: Pass intermediate `RecordBatch` streams across the network using Arrow Flight RPC.

## 4. PROFILE (Runtime Statistics)
While `EXPLAIN` shows the *plan*, `PROFILE` will show the *reality*—executing the query and collecting actual row counts and operator-level timing. This will complement cost-based optimization with empirical feedback.

## 5. Native Graph Neural Networks (GNNs)
While we currently support powerful vector search (HNSW) and metaheuristic optimization, the next step in "predictive power" is natively training and serving Graph Neural Networks directly within the database.
*   **Goal**: Run `CALL algo.gnn.predict_link('Person', 'KNOWS')` without exporting data to Python and PyTorch Geometric.

## Full Backlog

The items above are highlights. The complete prioritized backlog with ~100 items across 13 categories is maintained in `samyama-cloud/docs/BACKLOG.md`. Key backlog IDs referenced in this chapter:

| Topic | Backlog IDs |
|-------|-------------|
| Temporal queries | HA-04 |
| Graph-level sharding | HA-05 |
| Distributed query execution | HA-06 |
| PROFILE runtime stats | QE-02 |
| GNN inference | AI-04, AI-05 |
| Query planner improvements | QP-01 through QP-10 |
| Cypher completeness gaps | CY-01 through CY-10 |

## Conclusion

Samyama started as a question: "Can we do better?"
The answer, we believe, is "Yes."

By fusing the transactional integrity of RocksDB, the safety of Rust, the massive parallelism of GPU compute shaders, and the semantic power of AI, we are building a database engine for the next decade of intelligent applications.

Thank you for exploring the architecture of Samyama with us.
