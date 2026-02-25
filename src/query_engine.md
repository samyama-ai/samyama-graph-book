# The Query Engine

The heart of any database is its query engine. It translates the user's intent (expressed in a query language) into actionable operations on the data.

Samyama supports **OpenCypher**, the most widely adopted graph query language.

## From String to Plan

When a user sends a query like:
```cypher
MATCH (p:Person)-[:KNOWS]->(f:Person)
WHERE p.age > 30
RETURN f.name
```

It goes through three distinct stages:

### 1. Parsing (The `pest` Parser)
We use `pest`, a PEG (Parsing Expression Grammar) parser generator for Rust. The grammar is defined in `cypher.pest`.
The output is an Abstract Syntax Tree (AST) representing the query structure.

### 2. Logical Planning
The AST is converted into a **Logical Plan**. This is a tree of high-level operators like `Scan`, `Filter`, `Join`, and `Project`. At this stage, the engine doesn't care *how* the data is stored, only *what* needs to be done.

### 3. Physical Planning
The optimizer transforms the Logical Plan into a **Physical Plan**. This involves:
*   Choosing index scans over full scans.
*   Reordering joins for efficiency.
*   Selecting specific algorithms (e.g., `HashJoin` vs `NestedLoopJoin`).

![Samyama Architecture](./images/architecture.svg)

## Execution Model: Vectorized Processing

To achieve modern performance, especially for analytical workloads, Samyama implements **Vectorized Execution**. Instead of processing one row at a time (the "Volcano" model), operators process **batches** (typically 1024 rows).

```rust
pub struct RecordBatch {
    /// A column of NodeIds for the current 'node' variable
    pub nodes: Vec<NodeId>,
    /// Columnar property values mapped by name
    pub properties: HashMap<String, Column>,
    /// Number of rows in this batch
    pub len: usize,
}

trait PhysicalOperator {
    /// High-performance batch path
    fn next_batch(&mut self, store: &GraphStore, batch_size: usize) -> Option<RecordBatch>;
}
```

The `RecordBatch` utilizes Columnar storage principles. By passing around batches of data, the query engine can:
*   **Amortize Function Call Overhead**: Instead of calling `next()` 1,000,000 times, we call `next_batch()` 1,000 times.
*   **Utilize CPU Cache**: Data for a single column is processed in a tight loop, maximizing L1/L2 cache efficiency.
*   **SIMD Acceleration**: Operations like "Filter nodes where age > 30" can be performed across multiple values in a single CPU instruction (SIMD).

For example, the `NodeScanOperator` in Samyama retrieves a block of 1024 `NodeId`s at once, rather than iterating one by one. This reduces instruction cache misses and function call overhead by nearly 3 orders of magnitude.

## Late Materialization: The "Delayed Hydration" Strategy

One of Samyama's most impactful architectural choices is **Late Materialization**. 

In traditional graph engines, matching a node often triggers the "hydration" of that node—cloning all its properties into memory. In a multi-hop traversal (e.g., `(p)-[:KNOWS]->(f)-[:LIVES_IN]->(c)`), this leads to massive CPU and memory overhead for data that might never be returned to the user.

**Our Approach**: We pass around lightweight `NodeId`s within our `RecordBatch` columns. We only "materialize" (fetch properties from the columnar store) at the very last step of the pipeline (the `Project` or `Return` operator).

This strategy, combined with vectorized execution, allows Samyama to perform traversals at over **1.5 million edges/second** on a single thread.

## The Operator Library

Samyama includes a rich library of physical operators:
*   **`NodeScan`**: Scans all nodes or uses a Label index.
*   **`IndexScan`**: Uses a B-Tree property index for fast lookups (e.g., `WHERE n.id = 1`).
*   **`VectorSearch`**: A specialized operator that queries the HNSW index for semantic similarity.
*   **`Expand`**: The core graph traversal operator. It takes a node and "expands" it to its neighbors via the adjacency list.
*   **`Filter`**: Applies boolean logic to batches.
*   **`Project`**: Selects and renames fields.
*   **`Aggregate`**: Performs `GROUP BY`, `COUNT`, `SUM`, etc.
