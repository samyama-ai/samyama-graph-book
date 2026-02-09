# Performance & Benchmarks

Samyama is designed for "Mechanical Sympathy"—aligning the software's data structures with the physical reality of modern CPU caches and SSDs.

## The v0.5.0 Benchmark Suite

After implementing CSR, Vectorized Execution, and Columnar Storage, we achieved the following results on commodity hardware:

### Ingestion (The "Write" Story)
*   **Nodes**: 363,000 / sec
*   **Edges**: 1.51 Million / sec

This high throughput is achieved by decoupling the write path. Writes are acknowledged once they hit the **Write-Ahead Log (WAL)**, while indexing (B-Tree and HNSW) happens asynchronously in background threads.

### Vector Search (The "AI" Story)
*   **Latency**: 1.33ms (Avg)
*   **Throughput**: 752 Queries Per Second
*   **Accuracy**: 98% recall on 10k vectors

By using the **HNSW** algorithm, we provide semantic search capabilities that are as fast as a traditional property lookup.

## The Power of Late Materialization

One of the biggest performance wins in Samyama was the transition to **Late Materialization**.

In early versions, our query engine would "hydrate" a full `Node` object (cloning all its properties) as soon as it was matched. In a 2-hop traversal, this led to massive memory allocation and CPU cycles spent cloning data that might never be returned.

**The Fix**:
Operators now pass around lightweight `NodeRef`s (just a `u64` ID). We only "materialize" the properties at the very last step (the `RETURN` clause) or when they are explicitly needed for a `WHERE` filter.

**The Impact**:
*   **1-Hop Query**: 164ms → 41ms (**4x faster**)
*   **2-Hop Query**: 1.22s → 259ms (**4.7x faster**)

## The Last Bottleneck: Parsing

As shown in our profiling, the **Execution** of a query now takes less than **1ms**. The remaining ~40ms is spent in the **Parser** and **Planner**. 

Our next architectural step is **Query AST Caching**. By caching the results of the `pest` parser, we expect to bring the total latency of repeated queries down to **~15ms**, making Samyama one of the fastest graph engines in the industry.
