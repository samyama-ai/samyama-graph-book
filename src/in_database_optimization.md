# In-Database Optimization (Metaheuristics)

Most graph databases stop at "Retrieval." They help you find data. Samyama goes a step further into **Prescription**. 

By integrating a suite of highly concurrent metaheuristic solvers directly into the engine via the `samyama-optimization` crate, we allow users to solve complex Operation Research (OR) problems where the graph *is* the model.

## Supported Solvers

Unlike exact solvers (like CPLEX), metaheuristics are nature-inspired algorithms that search for "good enough" solutions in massive, complex search spaces. The `samyama-optimization` crate implements an exhaustive list of state-of-the-art algorithms:

*   **Metaphor-less**: `Jaya`, `QOJAYA` (Quasi-Oppositional), `RAO` (Variants 1, 2, 3), `TLBO` (Teaching-Learning), `ITLBO` (Improved TLBO), `GOTLBO`.
*   **Swarm & Evolutionary**: `PSO` (Particle Swarm), `DE` (Differential Evolution), `GA` (Genetic Algorithms), `GWO` (Grey Wolf Optimizer), `ABC` (Artificial Bee Colony), `BAT`, `Cuckoo`, `Firefly`, `GSA` (Gravitational Search), `FPA` (Flower Pollination Algorithm).
*   **Physics-based & Other**: `SA` (Simulated Annealing), `HS` (Harmony Search), `BMR`, `BWR`.
*   **Multi-Objective**: `NSGA-II` and `MOTLBO` for determining Pareto frontiers when solving problems with conflicting goals (e.g., "Minimize Cost" vs. "Maximize Safety").

## The Graph-to-Optimization Bridge

Samyama allows you to define an optimization problem directly using Cypher. The database seamlessly maps node properties to decision variables and edges to constraints.

```cypher
// Example: Optimize Factory production using Particle Swarm Optimization
CALL algo.or.solve({
  algorithm: 'PSO',
  label: 'Factory',
  property: 'production_rate',
  min: 10.0,
  max: 100.0,
  cost_property: 'unit_cost',
  budget: 50000.0,
  population_size: 50,
  iterations: 200
}) 
YIELD fitness, variables
```

> **Developer Tip:** You can explore the raw performance of these native solvers by running the optimization benchmarks: `cargo bench --bench graph_optimization_benchmark`. This benchmarks algorithms like PSO and Jaya running concurrently via Rayon.

## Parallel Evolution: The Power of Rust

Metaheuristic algorithms are computationally intensive as they evaluate entire populations of candidate solutions. Samyama's engine handles this at the Rust level:
*   **Rayon Integration**: Evaluates all candidate solutions in a population in parallel across all CPU cores.
*   **SIMD Fitness**: Calculates the "fitness" of multiple solutions simultaneously.
*   **Zero-Copy Execution**: Solutions are directly evaluated against the in-memory `GraphStore` structures without intermediate mapping.

This unique integration makes Samyama the ideal choice for **Smart Manufacturing**, **Logistics**, and **Healthcare Management**.
