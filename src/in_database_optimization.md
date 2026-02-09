# In-Database Optimization (Metaheuristics)

Most graph databases stop at "Retrieval." They help you find data. Samyama goes a step further into **Prescription**. 

By integrating a suite of 15+ metaheuristic solvers directly into the engine via the `samyama-optimization` crate, we allow users to solve complex Operation Research (OR) problems where the graph *is* the model.

## What are Metaheuristics?

Unlike exact solvers (like CPLEX), metaheuristics are nature-inspired algorithms that search for "good enough" solutions in massive, complex search spaces where an exact answer is mathematically impossible to find in a reasonable time.

Samyama supports three main families:
1.  **Metaphor-less**: **Jaya**, **Rao (1, 2, 3)**, and **TLBO**. These are high-performance algorithms with very few parameters to tune.
2.  **Nature-Inspired**: **Grey Wolf Optimizer (GWO)**, **Particle Swarm (PSO)**, **Firefly**, and **Cuckoo Search**.
3.  **Multi-Objective**: **NSGA-II** and **MOTLBO** for solving problems with conflicting goals (e.g., "Minimize Cost" vs. "Maximize Safety").

## The Graph-to-Optimization Bridge

Samyama allows you to define an optimization problem using Cypher. The database maps node properties to decision variables and edges to constraints.

```cypher
// Optimize Factory production to minimize cost
CALL algo.or.solve({
  algorithm: 'Jaya',
  label: 'Factory',
  property: 'production_rate',
  min: 10.0,
  max: 100.0,
  cost_property: 'unit_cost',
  budget: 50000.0
}) 
YIELD fitness, variables
```

## Parallel Evolution

Optimization is computationally expensive. Samyama's engine evaluates entire "populations" of candidate solutions in parallel using **Rayon**. If you have a 32-core server, Samyama will evolve 32 potential solutions simultaneously, finding the optimal resource allocation in milliseconds where a Python-based solver would take seconds.

This unique integration makes Samyama the ideal choice for **Smart Manufacturing**, **Logistics**, and **Healthcare Management**.
