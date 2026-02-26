# Technology Choices (The "Why")

Building a database is an exercise in trade-offs. In this chapter, we explore the specific technology choices that define Samyama and why we chose them over popular alternatives.

## Rust vs. The World

Why not C++? Why not Go? 

As documented in our internal benchmarks, Rust provides a unique combination of **Memory Safety** and **Zero-Cost Abstractions**. 

### The Performance Gap
In a 2-hop traversal benchmark on 1 million nodes:
*   **Rust**: 12ms (with 450MB RAM)
*   **Go**: 45ms (with 850MB RAM + GC Pauses)
*   **Java**: 38ms (with 1200MB RAM + GC Pauses)

The "Cautionary Tale of InfluxDB" served as a warning to us. Originally written in Go, the InfluxDB team eventually rewrote their core query engine in Rust to eliminate unpredictable garbage collection pauses that were impacting P99 latencies. We chose to start with Rust to avoid that "technical debt" from day one.

## RocksDB vs. B-Trees

We chose an **LSM-Tree** (RocksDB) over a **B-Tree** (LMDB). 

Graph workloads are naturally write-heavy—every relationship creation involves multiple index updates. B-Trees suffer from "Write Amplification," where changing a few bytes requires rewriting entire pages. RocksDB turns these random writes into sequential appends, allowing Samyama to sustain over **350,000 node writes per second**, significantly outperforming LMDB in write-heavy scenarios.

## Optimized Serialization: Bincode

Traditional serialization formats like JSON or Protobuf introduce significant overhead. For a performance-first database like Samyama, we needed a format that could serialize and deserialize data with minimal CPU cycles.

We chose **Bincode**.

Bincode is a compact, binary serialization format specifically optimized for Rust-to-Rust communication. It effectively takes the memory layout of a Rust struct and dumps it to disk. 
*   **Speed**: Deserializing a `StoredNode` from RocksDB takes nanoseconds.
*   **Compactness**: No field names or metadata overhead; only the raw values are stored.
*   **Safety**: Integrated with `serde`, it ensures that even if the disk format is corrupted, the database won't crash on invalid memory access.

## Mechanical Sympathy: Custom Columnar Storage

For property-heavy analytical queries, even Bincode is too slow because it still requires "hydrating" a full node object. To solve this, Samyama uses a custom **Columnar Property Storage** for high-performance property access.

By storing properties in a columnar format (e.g., all "ages" together), we achieve **Mechanical Sympathy**:
1.  **Cache Locality**: The CPU can prefetch thousands of values at once into the L1 cache.
2.  **SIMD Integration**: Using the `packed_simd` or `std::simd` (nightly) crates, we can process 8, 16, or 32 values in a single CPU cycle.
3.  **Late Materialization**: We avoid fetching properties from disk until the very last stage of a query, reducing I/O and CPU overhead by orders of magnitude.

## Hardware Acceleration: Why wgpu?

When deciding how to add GPU acceleration to Samyama, we evaluated several options including CUDA, OpenCL, and Vulkan. We ultimately chose **wgpu**, the Rust implementation of the WebGPU API.

### The Portability Advantage
Unlike CUDA (limited to NVIDIA) or OpenCL (which can be temperamental across platforms), **wgpu** offers a common abstraction layer that targets the most performant native API of the host system:
*   **Metal** on macOS and iOS.
*   **Vulkan** on Linux and Android.
*   **DirectX 12** on Windows.

### Native Performance with WGSL
By writing our compute shaders in **WGSL** (WebGPU Shading Language), we can offload intensive graph algorithms like PageRank and community detection to the GPU's thousands of cores. This allows Samyama to remain "Hardware Agnostic" while still delivering hardware-native performance on any modern cloud instance or local machine with a GPU.

## Samyama vs. The Giants: A Comparison

How does Samyama compare to industry leaders like Neo4j (the veteran) and RedisGraph (the high-performance alternative)?

| Feature | Neo4j | RedisGraph | Samyama |
| :--- | :--- | :--- | :--- |
| **Language** | Java (JVM) | C (Redis Module) | **Rust (Native)** |
| **Storage Model** | Pointer-heavy (Adjacency) | Sparse Matrices (GraphBLAS) | **Hybrid (MVCC + CSR + Columnar)** |
| **Execution** | Interpreted/JIT | Matrix Math | **Vectorized (SIMD-Accelerated)** |
| **Vector Search** | Bolt-on (Index) | ❌ | **Native (HNSW)** |
| **Optimization** | ❌ | ❌ | **Built-in (Metaheuristics)** |
| **Memory Management** | GC-Heavy | Fixed (Redis) | **Zero-Pause (Arena/RAII)** |

### Why Samyama Wins on Modern Hardware
*   **Neo4j** suffers from the "GC Tax"—large heaps lead to long garbage collection pauses. Its pointer-heavy structure is also prone to cache misses during multi-hop traversals.
*   **RedisGraph** is fast but its dependence on GraphBLAS (Matrix Math) makes it less flexible for complex property-based Cypher queries. It also lacks native AI/Vector capabilities.
*   **Samyama** represents a "Third Way": The flexibility of a property graph, the speed of native Rust, and the analytical power of a dedicated CSR-based engine. By focusing on **Mechanical Sympathy** (aligning with CPU cache/SIMD), Samyama delivers 10x the performance with 1/4 the memory footprint of traditional engines.
