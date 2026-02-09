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

## Zero-Copy Serialization

Traditional serialization (JSON, Protobuf) requires "deserializing" data into memory objects before they can be used. This is a massive overhead for a database.

Samyama uses **Cap'n Proto** and **Apache Arrow**. 
*   **Cap'n Proto**: Provides true zero-copy access. We cast a pointer to a memory-mapped file directly into a Rust struct. Deserialization time is effectively **0μs**.
*   **Apache Arrow**: Used for property storage. By storing properties in a columnar format (all "ages" together, all "salaries" together), we enable SIMD instructions to process multiple values in a single CPU cycle.

## Tokio: The Async Heart

Concurrency in Samyama is managed by **Tokio**, a work-stealing async runtime. 
Unlike "thread-per-core" models (like Glommio), Tokio's work-stealing approach prevents "starvation"—if one thread is stuck on a heavy calculation, other threads can "steal" tasks from its queue to keep the CPU utilized at 100%. This is critical for handling thousands of concurrent query connections without a massive increase in latency.
