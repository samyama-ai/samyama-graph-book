---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
---

# Samyama Graph Database
## A Unified Distributed Graph-Vector Engine

Built in Rust. Powered by Mechanical Sympathy.

---

## The Fragmentation Problem
Modern data architectures force developers to use multiple databases:
1. **Neo4j** for Graph Traversals (OLTP)
2. **Pinecone/Weaviate** for Vector Search
3. **Spark/GraphX** for Analytics (OLAP)
4. **Python/Gurobi** for Operations Research

*Result:* Data silos, high latency, and massive ETL pipelines.

---

## The Samyama Solution
A single, high-performance binary that unifies:
- **Property Graph Engine** (OpenCypher & RESP)
- **Vector Search** (Native HNSW)
- **Analytics Engine** (Compressed Sparse Row)
- **In-Database Optimization** (20+ Metaheuristic Solvers)

---

## Core Architecture: Mechanical Sympathy
We abandoned pointer-heavy `Box<Node>` designs for cache-friendly structures:
- **Versioned Arena**: `NodeId` is a contiguous `u64` index (O(1) lookups).
- **Columnar Storage**: Properties are stored as contiguous arrays for SIMD acceleration.
- **Vectorized Execution**: The Volcano iterator processes batches of 1,024 nodes at a time.
- **Late Materialization**: We pass lightweight IDs, fetching properties only at the final step.

*Result:* 1-hop traversal drops from 164ms to 41ms.

---

## In-Database Optimization
Stop moving data to Python to solve Operations Research problems. Samyama brings the solver to the data.

```cypher
CALL algo.or.solve({
  algorithm: 'PSO',
  label: 'Factory',
  property: 'production_rate',
  cost_property: 'unit_cost',
  budget: 50000.0,
  population_size: 50
}) YIELD fitness, variables
```
**20+ algorithms** implemented natively in Rust via Rayon (Jaya, Rao, PSO, DE, NSGA-II).

---

## Agentic Enrichment (GAK)
Beyond Retrieval-Augmented Generation (RAG). Introducing **Generation-Augmented Knowledge**.

- **Autonomous Healing**: When a query hits a missing node, an Event Trigger fires.
- **Tool Use**: The internal `AgentRuntime` queries the Web or internal documents.
- **Mutation**: The LLM constructs structured JSON, and the engine automatically generates Cypher `CREATE` commands to fill the knowledge gap in real-time.

---

## Samyama Enterprise Edition
Built for mission-critical, high-availability deployments.

- **Hardware Acceleration**: WGSL compute shaders via `wgpu` targeting Metal, Vulkan, and DX12. Massively parallel PageRank, CDLP, and LCC.
- **Advanced HA**: HTTP/2 Raft transport, automatic snapshot streaming, and role tracking.
- **Point-in-Time Recovery**: Full and incremental RocksDB backups.
- **Observability**: Prometheus metrics, health probes, audit trails, and `ADMIN.*` RESP commands.

---

## Performance Benchmarks (Mac Mini M4)

| Operation / Query | CPU-Only | GPU-Accelerated |
| :--- | :--- | :--- |
| **Node Ingestion** | 255K / sec | **412K / sec** |
| **Edge Ingestion** | 4.2M / sec | **5.2M / sec** |
| **PageRank (1M Nodes)** | 92.4 ms | **11.2 ms (8.2x)** |
| **Vector Search (10K)**| 15K QPS | GPU Batch Re-ranking |

*(GPU crossover threshold is ~100k nodes where parallelism beats memory transfer overhead)*

---

## Summary
Samyama is not just a database; it is an active knowledge partner.

- **Open Source Core**: High performance, zero GC pauses, developer-friendly.
- **Enterprise Ready**: GPU-accelerated, highly observable, and durable.

*https://x.com/Samyama_AI*
