# Query Optimization (Explain & Profile)

As queries grow in complexity—involving multiple hops, filters, and vector searches—it becomes impossible to optimize performance by guessing. Samyama provides two powerful tools for query introspection: `EXPLAIN` and `PROFILE`.

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

## PROFILE: Runtime Statistics

While `EXPLAIN` shows the *intent*, `PROFILE` shows the *reality*. It executes the query and collects timing and row-count data for every single operator in the tree.

```cypher
PROFILE MATCH (n:Person)-[:KNOWS]->(m:Person) 
WHERE n.age > 30 
RETURN m.name
```

**Output**:
```text
+----------------------------+----------------+-------------+-----------+
| Operator                   | Estimated Rows | Actual Rows | Time (ms) |
+----------------------------+----------------+-------------+-----------+
| ProjectOperator            |             50 |          47 |      0.12 |
|   FilterOperator           |             50 |          47 |      0.35 |
|     ExpandOperator         |            500 |         312 |      1.80 |
|       NodeScanOperator     |            100 |         100 |      0.45 |
+----------------------------+----------------+-------------+-----------+

Total rows returned: 47
Total execution time: 2.72 ms
```

### Key Performance Indicators (KPIs)
*   **Time (ms)**: Identifies which operator is the bottleneck. In multi-hop queries, the `ExpandOperator` is often the most expensive.
*   **Actual Rows**: If this is much larger than "Estimated Rows," it suggests that the cost-based optimizer needs better statistics to make better decisions.
*   **Late Materialization Savings**: In the `ProjectOperator`, profiling shows the time spent fetching properties from disk/memory, highlighting the efficiency of our columnar storage.

By using these tools, developers can fine-tune their Cypher queries to achieve sub-millisecond latencies even on massive graphs.
