# Analytical Power (CSR & Algorithms)

Transactional queries (OLTP) usually touch a small subgraph: "Find Alice's friends."
Analytical queries (OLAP) touch the *entire* graph: "Rank every webpage by importance (PageRank)."

The pointer-chasing structure of a standard graph database (Adjacency Lists) is excellent for OLTP but suboptimal for OLAP due to cache misses.

Samyama solves this by introducing a dedicated **Analytics Engine** in the `samyama-graph-algorithms` crate. This crate is decoupled from the core storage engine, allowing it to iterate independently and even be used as a standalone library.

## The CSR (Compressed Sparse Row) Format

When you run an algorithm like PageRank or Weakly Connected Components, Samyama doesn't run it directly on the `GraphStore`. Instead, it "projects" the relevant subgraph into a highly optimized read-only structure called **CSR**.

A Graph $G=(V, E)$ in CSR format is represented by three contiguous arrays:
1.  **`out_offsets`**: Indices indicating where each node's neighbor list starts in the `out_targets` array.
2.  **`out_targets`**: A massive, flat array containing all neighbor `NodeId`s.
3.  **`weights`**: (Optional) Edge weights corresponding to the `out_targets` list.

```rust
pub struct GraphView {
    pub out_offsets: Vec<usize>,
    pub out_targets: Vec<NodeId>,
    pub weights: Vec<f32>,
}
```

### Why CSR?
*   **Memory Efficiency**: CSR eliminates the memory overhead of adjacency lists (which are `Vec<Vec<EdgeId>>` in the core engine). 
*   **Sequential Memory Access**: Iterating through a node's neighbors becomes a simple sequential scan of the `out_targets` array, which the CPU can prefetch with nearly 100% accuracy.
*   **Zero-Lock Parallelism**: Since the CSR structure is immutable once built, algorithms can scale across all available CPU cores using **Rayon** without a single mutex or atomic lock.

## The Algorithm Library

The `samyama-graph-algorithms` crate includes a wide range of standard and advanced graph algorithms, all implemented with CSR-based parallelism:

1.  **Centrality**:
    *   **PageRank**: For global importance rankings.
    *   **Eigenvector Centrality**: Identifying influential nodes in undirected graphs.

2.  **Community Detection**:
    *   **Weakly Connected Components (WCC)**: Identifying isolated clusters.
    *   **LCC (Local Clustering Coefficient)**: Measuring "tight-knitness" around nodes.

3.  **Pathfinding & Flow**:
    *   **BFS / DFS**: Standard breadth and depth first traversals.
    *   **Dijkstra / A\***: Shortest path algorithms with weighted support.
    *   **Max-Flow / Min-Cut**: Determining the maximum possible flow between two nodes.

## Zero-Copy Python Integration

The same CSR structure used in Rust is exposed to Python via the `samyama` client using **PyO3**. This allows data scientists to run PageRank on billions of edges in Rust and receive the results in a NumPy array or Pandas DataFrame without the massive overhead of data duplication.

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
