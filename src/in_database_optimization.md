# In-Database Optimization (Metaheuristics)

Most graph databases stop at "Retrieval." They help you find data. Samyama goes a step further into **Prescription**. 

By integrating a suite of highly concurrent metaheuristic solvers directly into the engine via the `samyama-optimization` crate, we allow users to solve complex Operation Research (OR) problems where the graph *is* the model.

## Supported Solvers

Unlike exact solvers (like CPLEX), metaheuristics are nature-inspired algorithms that search for "good enough" solutions in massive, complex search spaces. The `samyama-optimization` crate implements an exhaustive list of state-of-the-art algorithms:

*   **Metaphor-less**: `Jaya`, `QOJAYA` (Quasi-Oppositional), `RAO` (Variants 1, 2, 3), `TLBO` (Teaching-Learning), `ITLBO` (Improved TLBO), `GOTLBO`.
*   **Swarm & Evolutionary**: `PSO` (Particle Swarm), `DE` (Differential Evolution), `GA` (Genetic Algorithms), `GWO` (Grey Wolf Optimizer), `ABC` (Artificial Bee Colony), `BAT`, `Cuckoo`, `Firefly`, `GSA` (Gravitational Search), `FPA` (Flower Pollination Algorithm).
*   **Physics-based & Other**: `SA` (Simulated Annealing), `HS` (Harmony Search), `BMR`, `BWR`.
*   **Multi-Objective**: `NSGA-II` and `MOTLBO` for determining Pareto frontiers when solving problems with conflicting goals (e.g., "Minimize Cost" vs. "Maximize Safety").

## Parallel Evolution: The Power of Rust

Metaheuristic algorithms are computationally intensive as they evaluate entire populations of candidate solutions. Samyama's engine handles this at the Rust level:
*   **Rayon Integration**: Evaluates all candidate solutions in a population in parallel across all CPU cores.
*   **SIMD Fitness**: Calculates the "fitness" of multiple solutions simultaneously.
*   **Zero-Copy Execution**: Solutions are directly evaluated against the in-memory `GraphStore` structures without intermediate mapping.


This unique integration makes Samyama the ideal choice for **Smart Manufacturing**, **Logistics**, and **Healthcare Management**.
