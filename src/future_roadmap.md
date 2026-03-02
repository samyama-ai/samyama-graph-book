# The Future of Graph DBs

We have built a strong foundation, but the journey is just beginning. As we look toward version 1.0 and beyond, several frontier technologies will define the next generation of Samyama.

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

## 4. Native Graph Neural Networks (GNNs)
While we currently support powerful vector search (HNSW) and metaheuristic optimization, the next step in "predictive power" is natively training and serving Graph Neural Networks directly within the database.
*   **Goal**: Run `CALL algo.gnn.predict_link('Person', 'KNOWS')` without exporting data to Python and PyTorch Geometric.

## Conclusion

Samyama started as a question: "Can we do better?"
The answer, we believe, is "Yes."

By fusing the transactional integrity of RocksDB, the safety of Rust, the massive parallelism of GPU compute shaders, and the semantic power of AI, we are building a database engine for the next decade of intelligent applications.

Thank you for exploring the architecture of Samyama with us.
