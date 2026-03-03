# Research Paper: Samyama Overview

We have published a comprehensive research paper detailing the architecture and performance of Samyama Graph.

**Title**: *Samyama: A Unified Distributed Graph-Vector Database with In-Database Optimization and Agentic Enrichment*

## Download PDF
You can download the professional PDF version of this paper (arXiv-ready) from our GitHub Releases:
[Download Samyama Paper PDF](https://github.com/samyama-ai/samyama-graph-book/releases/latest/download/samyama_paper.pdf)

---

## Paper Abstract
Modern data architectures are often fragmented, requiring separate systems for transactional graphs, vector embeddings, and analytical processing. We present **Samyama**, a high-performance, distributed graph-vector database written in Rust. Samyama unifies these workloads into a single engine by combining a RocksDB-backed persistent store with a versioned-arena MVCC model, a vectorized query executor, and a dedicated analytics engine using Compressed Sparse Row (CSR) structures. Notably, Samyama integrates 22 metaheuristic optimization solvers directly into its query language, utilizes **wgpu-based GPU hardware acceleration** for massive analytical workloads, and implements "Agentic Enrichment" for autonomous graph expansion. Our evaluation on v0.5.12 shows ingestion rates of 255K nodes/s (CPU) and 412K nodes/s (GPU-accelerated), with query latencies improved by 4.7x through late materialization, making it a robust foundation for next-generation AI applications.

---

## Implemented Research
For a comprehensive list of the specific academic algorithms, models, and architectures implemented directly within the Samyama codebase, please see the [Index of Implemented Papers](./implemented_papers.md).

---

## Visualizations
The paper includes several illustrations detailing the system's design:

### 1. Unified Engine Architecture
A high-level view of how the RESP protocol interacts with the Cypher parser, which in turn orchestrates the Vectorized Executor across the HNSW (Vector) and RocksDB (Graph) indices.
![Samyama Architecture](./images/architecture.svg)

### 2. The Optimization Frontier
A Pareto front chart illustrating how the NSGA-II solver identifies optimal trade-offs in multi-objective resource allocation directly on the graph.
![Pareto Front](./images/pareto_front.svg)

### 3. JIT Knowledge Graph Expansion
A sequence diagram showing the Agentic Enrichment loop: an event trigger initiates an LLM search which automatically creates new nodes and edges, "healing" the graph's missing knowledge.
![Agentic Loop](./images/agentic_loop.svg)
