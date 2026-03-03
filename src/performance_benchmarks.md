# Performance & Benchmarks

Samyama is designed for "Mechanical Sympathy"—aligning software data structures with the physical reality of modern CPU caches and high-speed NVMe storage.

## Recent Benchmark Results (Mac Mini M4, 2026-02-26)

All benchmarks run on Mac Mini M4, 16GB RAM, macOS. Comparison between the Community (CPU-only) and Enterprise (GPU-accelerated via `wgpu`) builds.

### Ingestion Throughput

Samyama achieves industry-leading ingestion rates on commodity hardware:

| Operation | CPU-Only (ops/sec) | GPU-Enabled (ops/sec) |
| :--- | :---: | :---: |
| **Node Ingestion** | 255,120 | **412,036** |
| **Edge Ingestion** | 4,211,342 | **5,242,096** |

*Note: Edge ingestion is significantly faster because it primarily involves appending to adjacency lists and updating the WAL.*

## GPU Acceleration: The Crossover Point

A key finding in the v0.5.12 benchmarks is the impact of memory transfer overhead on GPU acceleration.

| Algorithm | Scale (Nodes) | CPU Compute | GPU (inc. Transfer) | Speedup |
| :--- | :---: | :---: | :---: | :---: |
| **PageRank** | 10,000 | **0.6 ms** | 9.3 ms | 0.06x (Slowdown) |
| **PageRank** | 100,000 | 8.2 ms | **3.1 ms** | **2.6x** |
| **PageRank** | 1,000,000 | 92.4 ms | **11.2 ms** | **8.2x** |

**Conclusion**: For subgraphs smaller than 100,000 nodes, the CPU remains faster. Once the scale exceeds this "crossover point," the GPU parallelism overcomes the memory transfer cost, leading to massive speedups.

## Vector Search (HNSW, k=10)

Vector search utilizes `hnsw_rs` (CPU) for graph traversal. GPU acceleration in Enterprise is used for batch re-ranking after retrieval.

| Metric (10K vectors, 128-dim) | CPU-Only | GPU Build |
| :--- | :---: | :---: |
| **Cosine distance QPS** | **15,872/s** | 11,311/s |
| **L2 distance QPS** | **15,014/s** | 10,429/s |
| **Search 50K vectors** | **10,446 QPS** | 9,428 QPS |

*Note: The slight slowdown in the GPU build for small vector searches is due to the initialization overhead of the GPU context.*

## The Power of Late Materialization

One of our most impactful architectural choices remains **Late Materialization**. 

### Latency Impact (1M nodes)
| Query Type | Latency (Before) | Latency (After) | Improvement |
| :--- | :---: | :---: | :---: |
| **1-Hop Traversal** | 164.11 ms | **41.00 ms** | **4.0x** |
| **2-Hop Traversal** | 1,220.00 ms | **259.00 ms** | **4.7x** |

## Bottleneck Analysis

Profiling our query engine reveals a shift in where time is spent:

| Component | Time | % of 1-Hop |
| :--- | :--- | :--- |
| **Parse (Pest grammar)** | ~22ms | 54% |
| **Plan (AST → Operators)** | ~18ms | 44% |
| **Execute (Iteration)** | **<1ms** | **2%** |

**Conclusion**: The actual execution of the graph traversal is sub-millisecond. The remaining overhead is in the language frontend (parsing and planning). Our roadmap includes **AST Caching** and **Plan Memoization** to bring warm-query latency down to the ~10ms range.

> **Note**: These timings reflect cold-start conditions (first query execution). Subsequent queries benefit from OS-level page cache and instruction cache warmth, reducing total latency significantly.