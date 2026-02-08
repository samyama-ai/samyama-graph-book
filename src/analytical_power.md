# Analytical Power (CSR & Algorithms)

Transactional queries (OLTP) usually touch a small subgraph: "Find Alice's friends."
Analytical queries (OLAP) touch the *entire* graph: "Rank every webpage by importance (PageRank)."

The pointer-chasing structure of a standard graph database (Adjacency Lists) is excellent for OLTP but suboptimal for OLAP due to cache misses.

Samyama solves this by introducing a dedicated **Analytics Engine** in the `samyama-graph-algorithms` crate.

## The CSR (Compressed Sparse Row) Format

When you run an algorithm like PageRank or Betweenness Centrality, Samyama doesn't run it directly on the `GraphStore`. Instead, it projects the relevant subgraph into a highly optimized read-only structure called **CSR**.

A Graph $G=(V, E)$ is represented by three contiguous arrays:
1.  **`out_offsets`**: Indices indicating where each node's neighbor list starts.
2.  **`out_targets`**: A massive, flat array of all neighbor IDs.
3.  **`weights`**: (Optional) Edge weights corresponding to `out_targets`.

```rust
pub struct GraphView {
    pub out_offsets: Vec<usize>,
    pub out_targets: Vec<usize>,
    // ...
}
```

### Why CSR?
*   **Memory Compactness**: No overhead for pointers or objects. Just raw integers.
*   **Cache Locality**: Iterating neighbors is a sequential memory read, which CPUs love. PREFETCH instructions work perfectly here.
*   **Parallelism**: Since the structure is read-only, we can safely share it across Rayon threads without locks.

## The Algorithm Library

We have implemented standard graph algorithms optimized for this structure:

1.  **Centrality**:
    *   **PageRank**: The classic algorithm for node importance.
    *   **Eigenvector Centrality**: Similar to PageRank but for undirected graphs.

2.  **Community Detection**:
    *   **Weakly Connected Components (WCC)**: Finds isolated islands in the graph.
    *   **Louvain / Leiden**: (Planned) For detecting dense clusters.

3.  **Pathfinding**:
    *   **BFS / DFS**: Standard traversals.
    *   **Dijkstra / A\***: Shortest weighted paths.
    *   **Delta-Stepping**: A parallelized version of Dijkstra for large graphs.

## Python Bindings: Data Science Integration

We know that data scientists live in Python. We use **PyO3** to expose these Rust-optimized algorithms directly to Python.

The `GraphView` is zero-copy shared with Python where possible, or efficiently constructed.

```python
import samyama

# Connect to the DB
db = samyama.connect("localhost:6379")

# Run PageRank on the "Person" subgraph connected by "KNOWS"
# This runs in Rust at C++ speeds, but is called from Python!
scores = db.algo.page_rank(
    label="Person", 
    relationship="KNOWS", 
    damping_factor=0.85
)
```

This architecture allows Samyama to replace dedicated graph analytics frameworks like NetworkX (which is slow) or GraphFrames (which requires Spark), providing a single engine for storage and analysis.
