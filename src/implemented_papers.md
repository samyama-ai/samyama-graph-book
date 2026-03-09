# Index of Implemented Research Papers

Samyama Graph Database is built on the foundations of cutting-edge computer science research. Below is a comprehensive index of the research papers, algorithms, data structures, and standards implemented directly within the core engine and its specialized crates.

---

## Core System Architecture

### Query Execution
*   **Volcano Iterator Model**
    *   *Paper:* "Volcano — An Extensible and Parallel Query Evaluation System" (Graefe, 1994)
    *   *Implementation:* `src/query/executor/operator.rs` — 35 physical operators using pull-based `next_batch()` with vectorized `RecordBatch` processing (batch size 1,024)
    *   *Key insight:* Lazy evaluation avoids materializing intermediate results; each operator pulls only what downstream needs

*   **Late Materialization**
    *   *Paper:* "Column-Stores vs. Row-Stores: How Different Are They Really?" (Abadi et al., 2008)
    *   *Implementation:* `src/query/executor/operator.rs` — Scan operators produce `Value::NodeRef(id)` instead of full node clones; properties resolved on-demand at `ProjectOperator`
    *   *Result:* 4.0x improvement on 1-hop traversals, 4.7x on 2-hop traversals

*   **PEG Parsing (Parsing Expression Grammars)**
    *   *Paper:* "Parsing Expression Grammars: A Recognition-Based Syntactic Foundation" (Ford, 2004)
    *   *Implementation:* `src/query/cypher.pest` — Pest PEG parser for OpenCypher with atomic keyword rules for word boundary enforcement

### Storage Engine
*   **Log-Structured Merge Trees (LSM-Tree)**
    *   *Paper:* "The Log-Structured Merge-Tree (LSM-Tree)" (O'Neil et al., 1996)
    *   *Implementation:* `src/persistence/storage.rs` — RocksDB with LZ4/Zstd compression, Column Families for multi-tenant isolation

*   **Write-Ahead Logging (WAL)**
    *   *Paper:* "ARIES: A Transaction Recovery Method Supporting Fine-Granularity Locking and Partial Rollbacks" (Mohan et al., 1992)
    *   *Implementation:* `src/persistence/wal.rs` — Sequential WAL with fsync for Raft log, async for state machine

### Concurrency Control
*   **Multi-Version Concurrency Control (MVCC)**
    *   *Paper:* "Concurrency Control in Distributed Database Systems" (Bernstein & Goodman, 1981)
    *   *Implementation:* `src/graph/store.rs` — Versioned arena with `Vec<Vec<T>>` version chains enabling Snapshot Isolation without read locks

### Distributed Consensus
*   **Raft Consensus Algorithm**
    *   *Paper:* "In Search of an Understandable Consensus Algorithm" (Ongaro & Ousterhout, 2014)
    *   *Implementation:* `src/raft/` via the `openraft` framework — Leader election, log replication, quorum commits, CP trade-off
    *   *Enterprise:* HTTP/2 transport, TLS encryption, snapshot streaming, cluster metrics

### Serialization
*   **Bincode (Binary Encoding)**
    *   *Library:* `bincode` crate — Compact binary serialization for `StoredNode`/`StoredEdge` structs in RocksDB
    *   *Benefit:* Nanosecond deserialization, no field name overhead, serde integration

---

## Vector Search & AI

*   **HNSW (Hierarchical Navigable Small World)**
    *   *Paper:* "Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs" (Malkov & Yashunin, 2018)
    *   *Implementation:* `src/vector/` via the `hnsw_rs` crate — Cosine, L2, and Dot Product metrics; 15K+ QPS on 128-dim vectors
    *   *Integration:* `VectorSearchOperator` in query pipeline enables Graph RAG (combined vector + graph traversal)

---

## Graph Analytics (`samyama-graph-algorithms`)

### Centrality & Importance
*   **PageRank**
    *   *Paper:* "The PageRank Citation Ranking: Bringing Order to the Web" (Page, Brin, Motwani & Winograd, 1999)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/pagerank.rs` — Iterative power method with configurable damping factor, dangling node redistribution, convergence tolerance
    *   *Validation:* LDBC Graphalytics 5/5 (XS + S datasets including cit-Patents 3.8M vertices)

*   **Local Clustering Coefficient (LCC)**
    *   *Paper:* "Collective dynamics of 'small-world' networks" (Watts & Strogatz, 1998)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/lcc.rs` — Both directed and undirected variants; measures neighborhood connectivity
    *   *Validation:* LDBC Graphalytics 5/5

### Community Detection & Connectivity
*   **Community Detection via Label Propagation (CDLP)**
    *   *Paper:* "Near linear time algorithm to detect community structures in large-scale networks" (Raghavan, Albert & Kumara, 2007)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/cdlp.rs` — Iterative neighbor voting with configurable max iterations
    *   *Validation:* LDBC Graphalytics 5/5

*   **Weakly Connected Components (WCC)**
    *   *Algorithm:* Union-Find with path compression and union by rank
    *   *Implementation:* `crates/samyama-graph-algorithms/src/community.rs` — O(n * α(n)) near-linear time
    *   *Validation:* LDBC Graphalytics 5/5

*   **Strongly Connected Components (SCC)**
    *   *Algorithm:* Tarjan's Algorithm (Tarjan, 1972)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/community.rs` — Single DFS pass with lowlink tracking

*   **Triangle Counting**
    *   *Algorithm:* Node-iterator method with sorted adjacency intersection
    *   *Implementation:* `crates/samyama-graph-algorithms/src/topology.rs` — Used for social cohesion analysis and network clustering metrics

### Pathfinding & Network Flow
*   **Breadth-First Search (BFS)**
    *   *Algorithm:* Level-synchronous BFS (Moore, 1959)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/pathfinding.rs` — Standard BFS + all shortest paths variant
    *   *Validation:* LDBC Graphalytics 5/5

*   **Dijkstra's Shortest Path**
    *   *Paper:* "A note on two problems in connexion with graphs" (Dijkstra, 1959)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/pathfinding.rs` — Binary heap priority queue; also used for SSSP in LDBC validation
    *   *Validation:* LDBC Graphalytics SSSP 3/3

*   **Edmonds-Karp Maximum Flow**
    *   *Paper:* "Theoretical Improvements in Algorithmic Efficiency for Network Flow Problems" (Edmonds & Karp, 1972)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/flow.rs` — BFS-based augmenting path selection; O(VE²) complexity

*   **Prim's Minimum Spanning Tree**
    *   *Algorithm:* Prim's Algorithm (Prim, 1957)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/mst.rs` — Greedy MST construction with priority queue

### Statistical & Dimensionality Reduction
*   **PCA — Randomized SVD**
    *   *Paper:* "Finding structure with randomness: Probabilistic algorithms for constructing approximate matrix decompositions" (Halko, Martinsson & Tropp, 2011)
    *   *Implementation:* `crates/samyama-graph-algorithms/src/pca.rs` — Gaussian random projection → power iterations → QR factorization → small SVD; O(n·d·k) complexity
    *   *Auto-selection:* `PcaSolver::Auto` uses Randomized SVD for n > 500 nodes

*   **PCA — Power Iteration (Deflation)**
    *   *Algorithm:* Classical power iteration with Gram-Schmidt re-orthogonalization
    *   *Implementation:* `crates/samyama-graph-algorithms/src/pca.rs` — Legacy solver, `PcaResult` includes `transform()` and `transform_one()` for projection

---

## Metaheuristic Optimization (`samyama-optimization`)

The engine natively supports 22 state-of-the-art optimization algorithms, all implemented in `crates/samyama-optimization/src/algorithms/`:

### Metaphor-Less Algorithms
*   **Jaya Algorithm**
    *   *Paper:* "Jaya: A simple and new optimization algorithm for solving constrained and unconstrained optimization problems" (R. Venkata Rao, 2016)
    *   *Key property:* Parameter-free—requires no algorithm-specific tuning

*   **Quasi-Oppositional Jaya (QOJAYA)**
    *   *Paper:* "Quasi-oppositional based Jaya algorithm" (derived from Rao, 2016)
    *   *Enhancement:* Opposition-based initialization improves convergence speed

*   **Rao Algorithms (Rao-1, Rao-2, Rao-3)**
    *   *Paper:* "Rao algorithms: Three metaphor-less simple algorithms for solving optimization problems" (R. Venkata Rao, 2020)
    *   *Key property:* Three progressively complex variants; all metaphor-free

*   **TLBO (Teaching-Learning-Based Optimization)**
    *   *Paper:* "Teaching–learning-based optimization: A novel method for constrained mechanical design optimization problems" (R. Venkata Rao, Savsani & Vakharia, 2011)

*   **ITLBO (Improved TLBO)**
    *   *Enhancement:* Adaptive learning factor and improved selection mechanisms

*   **GOTLBO (Group-Optimized TLBO)**
    *   *Enhancement:* Group-based teaching phase with oppositional learning

### Swarm & Evolutionary Algorithms
*   **Particle Swarm Optimization (PSO)**
    *   *Paper:* "Particle swarm optimization" (Kennedy & Eberhart, 1995)

*   **Differential Evolution (DE)**
    *   *Paper:* "Differential Evolution – A Simple and Efficient Heuristic for global Optimization over Continuous Spaces" (Storn & Price, 1997)

*   **Genetic Algorithm (GA)**
    *   *Paper:* "Adaptation in Natural and Artificial Systems" (Holland, 1975)

*   **Grey Wolf Optimizer (GWO)**
    *   *Paper:* "Grey Wolf Optimizer" (Mirjalili, Mirjalili & Lewis, 2014)

*   **Artificial Bee Colony (ABC)**
    *   *Paper:* "An Idea Based On Honey Bee Swarm for Numerical Optimization" (Karaboga, 2005)

*   **Bat Algorithm**
    *   *Paper:* "A New Metaheuristic Bat-Inspired Algorithm" (Yang, 2010)

*   **Cuckoo Search**
    *   *Paper:* "Cuckoo Search via Lévy Flights" (Yang & Deb, 2009)

*   **Firefly Algorithm**
    *   *Paper:* "Firefly Algorithms for Multimodal Optimization" (Yang, 2009)

*   **Flower Pollination Algorithm (FPA)**
    *   *Paper:* "Flower Pollination Algorithm for Global Optimization" (Yang, 2012)

### Physics-Based Algorithms
*   **Gravitational Search Algorithm (GSA)**
    *   *Paper:* "GSA: A Gravitational Search Algorithm" (Rashedi, Nezamabadi-pour & Saryazdi, 2009)

*   **Simulated Annealing (SA)**
    *   *Paper:* "Optimization by Simulated Annealing" (Kirkpatrick, Gelatt & Vecchi, 1983)

*   **Harmony Search (HS)**
    *   *Paper:* "A New Heuristic Optimization Algorithm: Harmony Search" (Geem, Kim & Loganathan, 2001)

*   **BMR & BWR**
    *   Specialized reinforcement-based solvers for constrained search spaces

### Multi-Objective Algorithms
*   **NSGA-II (Non-dominated Sorting Genetic Algorithm II)**
    *   *Paper:* "A fast and elitist multiobjective genetic algorithm: NSGA-II" (Deb, Pratap, Agarwal & Meyarivan, 2002)
    *   *Enhancement:* Constrained Dominance Principle for feasibility-first selection

*   **MOTLBO (Multi-Objective TLBO)**
    *   *Paper:* Multi-objective extension of TLBO (derived from Rao et al., 2011)
    *   *Feature:* Pareto front discovery with crowding distance for diversity preservation

---

## RDF & Semantic Web Standards

*   **RDF (Resource Description Framework)**
    *   *Standard:* W3C RDF 1.1 Concepts and Abstract Syntax (2014)
    *   *Implementation:* `src/rdf/` — Triple/Quad storage with SPO/POS/OSP indices via `oxrdf` crate

*   **Turtle (Terse RDF Triple Language)**
    *   *Standard:* W3C RDF 1.1 Turtle (2014)
    *   *Implementation:* `src/rdf/serialization/turtle.rs` via `rio_turtle`

*   **SPARQL 1.1**
    *   *Standard:* W3C SPARQL 1.1 Query Language (2013)
    *   *Implementation:* `src/sparql/` — Parser infrastructure via `spargebra`; query execution in development

---

## Hardware Acceleration (`samyama-gpu`)

*   **Parallel Graph Algorithms on GPU**
    *   *Implementation:* 8+ WGSL compute shaders targeting WebGPU (Metal, Vulkan, DX12)
    *   *Algorithms:* PageRank, Triangle Counting, CDLP, LCC, PCA
    *   *Operators:* SUM aggregation (parallel reduction), ORDER BY (bitonic sort)
    *   *Vector:* Cosine distance, inner product (batch re-ranking)

*   **GPU PCA (Fused Power Iteration)**
    *   *Implementation:* Five WGSL shaders: `pca_mean`, `pca_center`, `pca_covariance` (tiled, 64-sample tiles), `pca_power_iter`, `pca_power_iter_norm` (fused mat-vec + parallel norm + normalize in single dispatch)
    *   *Threshold:* `MIN_GPU_PCA = 50,000` nodes, `d > 32` dimensions

*   **Bitonic Sort**
    *   *Paper:* "Sorting networks and their applications" (Batcher, 1968)
    *   *Implementation:* `crates/samyama-gpu/src/shaders/bitonic_sort.wgsl` — GPU argsort for ORDER BY on >10K result sets

---

## Benchmark Validation

*   **LDBC Graphalytics**
    *   *Standard:* "The LDBC Graphalytics Benchmark" (Iosup et al., 2016)
    *   *Result:* 28/28 tests passed (100%) across BFS, PageRank, WCC, CDLP, LCC, SSSP on XS and S-size datasets
    *   *Datasets:* example-directed, example-undirected, cit-Patents (3.8M vertices), datagen-7_5-fb (633K vertices, 68M edges), wiki-Talk (2.4M vertices)
