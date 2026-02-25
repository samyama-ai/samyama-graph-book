# In-Database Optimization (Metaheuristics)

Most graph databases stop at "Retrieval." They help you find data. Samyama goes a step further into **Prescription**. 

By integrating a suite of 20+ metaheuristic solvers directly into the engine via the `samyama-optimization` crate, we allow users to solve complex Operation Research (OR) problems where the graph *is* the model.

## What are Metaheuristics?

Unlike exact solvers (like CPLEX), metaheuristics are nature-inspired algorithms that search for "good enough" solutions in massive, complex search spaces where an exact answer is mathematically impossible to find in a reasonable time.

Samyama supports three main families of solvers:
1.  **Metaphor-less**: **Jaya**, **Rao-1**, **Rao-2**, **Rao-3**, and **TLBO**. These are high-performance algorithms with very few parameters to tune. Our implementation follows the corrected standard formulas for all Rao variants.
2.  **Nature-Inspired (Swarm & Bio)**: **Particle Swarm Optimization (PSO)**, **Differential Evolution (DE)**, **Grey Wolf (GWO)**, **Firefly**, and **Cuckoo Search**.
3.  **Multi-Objective**: **NSGA-II** and **MOTLBO** for solving problems with conflicting goals (e.g., "Minimize Cost" vs. "Maximize Safety").

![Pareto Front](./images/pareto_front.svg)

## The Graph-to-Optimization Bridge

Samyama allows you to define an optimization problem using Cypher. The database maps node properties to decision variables and edges to constraints.

```cypher
// Optimize Factory production using Particle Swarm Optimization
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

## Parallel Evolution: The Power of Rust

Metaheuristic algorithms are computationally intensive as they evaluate entire populations of candidate solutions. Samyama's engine handles this at the Rust level:
*   **Rayon Integration**: Evaluates all candidate solutions in a population in parallel across all CPU cores.
*   **SIMD Fitness**: Calculates the "fitness" of multiple solutions simultaneously.
*   **Low-Level Memory**: We avoid the overhead of heavy object allocation for each solution, using raw contiguous buffers instead.

If you have a 32-core server, Samyama will evolve 32 potential solutions simultaneously, finding an optimal resource allocation in milliseconds where a Python-based solver would take seconds.

This unique integration makes Samyama the ideal choice for **Smart Manufacturing**, **Logistics**, and **Healthcare Management**.
