# Preface

In the rapidly evolving landscape of data systems, we often find ourselves gluing together disparate technologies to build a complete platform. We use Redis for caching, Neo4j for graphs, Qdrant or Pinecone for vectors, and Spark for analytics. This fragmentation leads to "Frankenstein" architectures—complex, fragile, and hard to maintain.

**Samyama** (Sanskrit for "Integration" or "Binding together") was born from a desire to collapse this complexity.

Why can't a single engine handle the transactional integrity of a graph, the semantic power of vectors, and the raw speed of in-memory analytics? Why must we choose between the flexibility of Cypher and the performance of compiled code?

This book is the story of building **Samyama-Graph**, a modern, high-performance graph database written in Rust. It is not just a user manual; it is an architectural deep dive. We will peel back the layers to show you *how* it works—from the byte-level serialization in RocksDB to the lock-free concurrency of our MVCC engine, and up to the distributed consensus algorithms that keep it alive.

## Why Rust?

When building a database in the 2020s, the choice of language is pivotal. We chose Rust not just for its hype, but for its promise: **Fearless Concurrency**.

A graph database is, by definition, a pointer-chasing engine. It demands random memory access patterns that are notoriously hard to optimize and easy to mess up (hello, segmentation faults!). Rust's ownership model allowed us to implement complex memory management strategies—like Arena Allocation and localized reference counting—without the overhead of a Garbage Collector or the safety risks of C++.

## Who is this book for?

*   **System Architects** who want to understand the internals of a modern database.
*   **Rust Developers** curious about real-world patterns for FFI, concurrency, and distributed systems.
*   **Data Engineers** looking for a unified solution for their graph and AI workloads.

Let's begin the journey.
