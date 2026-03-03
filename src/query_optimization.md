# Query Optimization (Explain)

As queries grow in complexity—involving multiple hops, filters, and vector searches—it becomes impossible to optimize performance by guessing. Samyama provides `EXPLAIN` for query introspection.

## EXPLAIN: Visualizing the Plan

The `EXPLAIN` prefix tells the engine to parse and plan the query, but **not** execute it. It returns the operator tree that the physical executor will follow.

```cypher
EXPLAIN MATCH (n:Person)-[:KNOWS]->(m:Person) 
WHERE n.age > 30 
RETURN m.name
```

**Output**:
```text
+----------------------------------+----------------+
| Operator                         | Estimated Rows |
+----------------------------------+----------------+
| ProjectOperator (m.name)         |             50 |
|   FilterOperator (n.age > 30)    |             50 |
|     ExpandOperator (-[:KNOWS]->) |            500 |
|       NodeScanOperator (:Person) |            100 |
+----------------------------------+----------------+
```

This is invaluable for verifying that the optimizer is correctly choosing indices (e.g., using an `IndexScan` instead of a `NodeScan`) and that joins are happening in the expected order.

## Future: PROFILE (Runtime Statistics)

> **Status: Planned** — `PROFILE` is on the roadmap but not yet implemented. Currently, only `EXPLAIN` is available.

A future `PROFILE` command would execute the query and collect timing and row-count data for every operator in the tree. This would complement `EXPLAIN` by showing the *reality* alongside the *intent*, enabling developers to identify bottlenecks at the operator level.

By using `EXPLAIN` today, developers can already fine-tune their Cypher queries by understanding the operator tree, cost estimates, and index selection decisions.
