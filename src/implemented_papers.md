# Implemented Research Papers Index

Samyama Graph Database is built on the foundations of cutting-edge computer science research. Below is an index of the major research papers, algorithms, and architectural models implemented directly within the core engine and its specialized crates.

## Core System Architecture
*   **Vectorized Execution & Volcano Iterator Model**
    *   *Paper:* "Volcano - An Extensible and Parallel Query Evaluation System" (Graefe, 1994)
    *   *Implementation:* `src/query/executor/mod.rs` (Hybrid Vectorized Iterator)
*   **Distributed Consensus (High Availability)**
    *   *Paper:* "In Search of an Understandable Consensus Algorithm" (Ongaro & Ousterhout, 2014)
    *   *Implementation:* `src/raft/` via the `openraft` framework.
*   **Vector Search (AI Native)**
    *   *Paper:* "Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs" (Malkov & Yashunin, 2018)
    *   *Implementation:* `src/vector/` via the `hnsw_rs` crate.

## Graph Analytics (`samyama-graph-algorithms`)
*   **PageRank**
    *   *Paper:* "The PageRank Citation Ranking: Bringing Order to the Web" (Page et al., 1999)
*   **Community Detection via Label Propagation (CDLP)**
    *   *Paper:* "Near linear time algorithm to detect community structures in large-scale networks" (Raghavan et al., 2007)
*   **Strongly Connected Components (SCC)**
    *   *Algorithm:* Tarjan's strongly connected components algorithm (Tarjan, 1972) / Kosaraju's Algorithm.
*   **Minimum Spanning Tree**
    *   *Algorithm:* Prim's Algorithm (Prim, 1957)

## Metaheuristic Optimization (`samyama-optimization`)
The engine natively supports an exhaustive suite of Operation Research (OR) and Optimization algorithms:
*   **Jaya Algorithm & QOJAYA**
    *   *Paper:* "Jaya: A simple and new optimization algorithm for solving constrained and unconstrained optimization problems" (R. Venkata Rao, 2016)
*   **Rao Algorithms (Rao-1, Rao-2, Rao-3)**
    *   *Paper:* "Rao algorithms: Three metaphor-less simple algorithms for solving optimization problems" (R. Venkata Rao, 2020)
*   **TLBO & Variants (ITLBO, GOTLBO, MOTLBO)**
    *   *Paper:* "Teaching–learning-based optimization: A novel method for constrained mechanical design optimization problems" (R. Venkata Rao et al., 2011)
*   **Particle Swarm Optimization (PSO)**
    *   *Paper:* "Particle swarm optimization" (Kennedy & Eberhart, 1995)
*   **Differential Evolution (DE)**
    *   *Paper:* "Differential Evolution – A Simple and Efficient Heuristic for global Optimization over Continuous Spaces" (Storn & Price, 1997)
*   **Grey Wolf Optimizer (GWO)**
    *   *Paper:* "Grey Wolf Optimizer" (Mirjalili et al., 2014)
*   **Artificial Bee Colony (ABC)**
    *   *Paper:* "An Idea Based On Honey Bee Swarm for Numerical Optimization" (Karaboga, 2005)
*   **NSGA-II (Multi-Objective)**
    *   *Paper:* "A fast and elitist multiobjective genetic algorithm: NSGA-II" (Deb et al., 2002)

*(Additional Swarm & Physics-based solvers implemented: BAT, Cuckoo Search, Firefly, FPA, GSA, SA, HS, BMR, BWR)*

## Hardware Acceleration (`samyama-gpu`)
*   **Parallel Graph Algorithms on GPU**
    *   *Implementation:* WGSL compute shaders for PageRank, Triangle Counting, CDLP, and LCC targeting WebGPU (Metal, Vulkan, DX12).
