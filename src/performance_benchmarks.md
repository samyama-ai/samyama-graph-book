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

## Cypher Query Throughput (OLTP)

For transactional workloads, Samyama's index-driven execution delivers consistent sub-millisecond latencies:

| Graph Scale | Queries/sec | Avg Latency |
| :---: | :---: | :---: |
| **10,000 nodes** | 35,360 QPS | 0.028 ms |
| **100,000 nodes** | 116,373 QPS | 0.008 ms |
| **1,000,000 nodes** | 115,320 QPS | 0.008 ms |

*Index-driven lookups achieve O(1) or O(log n) access. QPS is measured with simple `MATCH ... WHERE ... RETURN` queries on indexed properties.*

These numbers demonstrate that Samyama scales almost linearly—throughput at 1M nodes is comparable to 100K because index-based access eliminates full scans.

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

## GPU at Scale: S-Size Datasets

On LDBC Graphalytics S-size datasets (millions of vertices), the GPU crossover becomes significant:

| Algorithm | Dataset | Vertices | Edges | CPU | GPU | Speedup |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **LCC** | cit-Patents | 3.8M | 16.5M | 9.6s | **4.7s** | **2.0x** |
| **CDLP** | cit-Patents | 3.8M | 16.5M | 9.5s | 11.1s | 0.85x |
| **PageRank** | datagen-7_5-fb | 633K | 68.4M | — | CPU fallback | — |

*Note: Extremely dense graphs (e.g., 68M edges on datagen-7_5-fb) trigger CPU fallback due to the 256MB GPU buffer limit on Apple Silicon. Dedicated GPUs with larger VRAM can handle these datasets.*

## LDBC Graphalytics Validation

Samyama has achieved **100% validation** against the LDBC Graphalytics benchmark suite—the industry standard for graph analytics correctness:

| Algorithm | XS Datasets (2) | S Datasets (3) | Total |
| :--- | :---: | :---: | :---: |
| BFS | ✅ 2/2 | ✅ 3/3 | 5/5 |
| PageRank | ✅ 2/2 | ✅ 3/3 | 5/5 |
| WCC | ✅ 2/2 | ✅ 3/3 | 5/5 |
| CDLP | ✅ 2/2 | ✅ 3/3 | 5/5 |
| LCC | ✅ 2/2 | ✅ 3/3 | 5/5 |
| SSSP | ✅ 2/2 | ✅ 1/1 | 3/3 |
| **Total** | **12/12** | **16/16** | **28/28** |

S-size datasets include cit-Patents (3.8M vertices), datagen-7_5-fb (633K vertices, 68M edges), and wiki-Talk (2.4M vertices). All results match LDBC reference outputs exactly.

> **Developer Tip:** Run the validation yourself with `cargo bench --bench graphalytics_benchmark`. LDBC datasets are available in `data/graphalytics/`.

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