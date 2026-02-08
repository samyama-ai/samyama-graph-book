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

## Execution Model: Volcano vs. Vectorization

Samyama implements a hybrid execution model.

### The Volcano Model (Iterator)
Historically, databases used the "Volcano" model. Each operator implements a `next()` method that returns a single tuple (or `Record`).

```rust
trait PhysicalOperator {
    fn next(&mut self, store: &GraphStore) -> Option<Record>;
}
```

*   **Pros**: Simple, composable, low memory footprint.
*   **Cons**: High CPU overhead due to virtual function calls per row.

### Vectorized Execution (The Samyama Way)
To achieve modern performance, especially for analytical workloads, Samyama implements **Vectorized Execution**. Instead of processing one row at a time, operators process **batches** (typically 1024 rows).

```rust
trait PhysicalOperator {
    // Classic fallback
    fn next(&mut self, store: &GraphStore) -> Option<Record>;

    // High-performance batch path
    fn next_batch(&mut self, store: &GraphStore, batch_size: usize) -> Option<RecordBatch>;
}
```

The `RecordBatch` utilizes Columnar storage principles (similar to Apache Arrow) where possible, allowing the CPU to use SIMD (Single Instruction, Multiple Data) instructions to process data faster.

For example, the `NodeScanOperator` in Samyama retrieves a block of 1024 `NodeId`s at once, rather than iterating one by one. This reduces the instruction cache misses and function call overhead by nearly 3 orders of magnitude.

## The Operator Library

Samyama includes a rich library of physical operators:
*   **`NodeScan`**: Scans all nodes or uses a Label index.
*   **`IndexScan`**: Uses a B-Tree property index for fast lookups (e.g., `WHERE n.id = 1`).
*   **`VectorSearch`**: A specialized operator that queries the HNSW index for semantic similarity.
*   **`Expand`**: The core graph traversal operator. It takes a node and "expands" it to its neighbors via the adjacency list.
*   **`Filter`**: Applies boolean logic to batches.
*   **`Project`**: Selects and renames fields.
*   **`Aggregate`**: Performs `GROUP BY`, `COUNT`, `SUM`, etc.
