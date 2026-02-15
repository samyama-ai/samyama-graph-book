# Performance & Benchmarks

Samyama is designed for "Mechanical Sympathy"—aligning software data structures with the physical reality of modern CPU caches and high-speed NVMe storage.

## The v0.5.0 "Quantum Leap"

The v0.5.0 release introduced three foundational optimizations that moved Samyama from a prototype to a high-performance engine:
1.  **Compressed Sparse Row (CSR)**: For analytics.
2.  **Vectorized Execution**: For query processing.
3.  **Columnar Property Storage**: For efficient attribute access.

### Ingestion Throughput
By decoupling the write path and using an asynchronous indexing pipeline, Samyama achieves industry-leading ingestion rates on commodity hardware:

| Operation | Throughput (ops/sec) |
| :--- | :--- |
| **Node Ingestion** | **363,017** |
| **Edge Ingestion** | **1,511,803** |

*Note: Edge ingestion is significantly faster because it primarily involves appending to adjacency lists and updating the WAL.*

## The Power of Late Materialization

One of our most impactful architectural changes was the move to **Late Materialization**. 

In traditional graph engines, matching a node often triggers the "hydration" of that node—cloning all its properties into memory. In a multi-hop traversal, this leads to massive CPU and memory overhead for data that might never be returned to the user.

**Our Approach**: We pass around lightweight `NodeRef`s (just 64-bit IDs). We only "materialize" (fetch properties from the columnar store) at the very last step of the pipeline.

### Latency Impact
| Query Type | Latency (Before) | Latency (After) | Improvement |
| :--- | :--- | :--- | :--- |
| **1-Hop Traversal** | 164.11 ms | **41.00 ms** | **4.0x** |
| **2-Hop Traversal** | 1,220.00 ms | **259.00 ms** | **4.7x** |

## Bottleneck Analysis

Profiling our query engine reveals a shift in where time is spent:

| Component | Time | % of 1-Hop |
| :--- | :--- | :--- |
| **Parse (Pest grammar)** | ~22ms | 54% |
| **Plan (AST → Operators)** | ~18ms | 44% |
| **Execute (Iteration)** | **<1ms** | **2%** |

**Conclusion**: The actual execution of the graph traversal is now sub-millisecond. The remaining overhead is in the language frontend (parsing and planning). Our roadmap includes **AST Caching** and **Plan Memoization** to bring warm-query latency down to the ~10ms range.