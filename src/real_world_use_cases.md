# Real-world Use Cases

Samyama is not just a research project; it is designed to solve complex, real-world problems. We include several fully functional demos in the `examples/` directory of the repository.

Here are three key scenarios where Samyama shines.

## 1. Banking: Fraud Detection
**Source**: `examples/banking_demo.rs`

Financial fraud often involves complex networks of transactions that traditional SQL databases struggle to uncover.

**The Scenario**: A money laundering ring moves illicit funds through a series of "mule" accounts to hide the origin, eventually depositing it back into a clean account. This creates a cycle.

**The Solution**:
We model the data as:
*   **Nodes**: `Account`
*   **Edges**: `TRANSFER` (with properties `amount`, `date`)

**The Query**:
```cypher
MATCH (a:Account)-[t1:TRANSFER]->(b:Account)-[t2:TRANSFER]->(c:Account)-[t3:TRANSFER]->(a)
WHERE t1.amount > 10000 
  AND t2.amount > 9000 
  AND t3.amount > 8000
RETURN a.id, b.id, c.id
```
This simple query instantly reveals circular transaction patterns that would require massive, slow `JOIN`s in SQL.

## 2. Supply Chain: Dependency Analysis
**Source**: `examples/supply_chain_demo.rs`

Modern supply chains are fragile. Knowing "who supplies my supplier" is critical for risk management.

**The Scenario**: A factory produces a "Car". It needs an "Engine", which needs "Pistons", which needs "Steel". If a strike hits the Steel mill, how does it affect Car production?

**The Solution**:
We use the **Graph Algorithms** module (specifically Breadth-First Search or custom traversal).

**The Logic**:
1.  Start at the "Steel Mill" node.
2.  Traverse all outgoing `SUPPLIES` edges recursively.
3.  Identify all downstream `Factory` nodes.
4.  Calculate the "Risk Score" based on the dependency depth.

## 3. Knowledge Graph: Clinical Trials
**Source**: `examples/clinical_trials_demo.rs` + `examples/graph_rag_demo.rs`

Medical research is unstructured. Trials, drugs, and conditions are buried in text documents.

**The Scenario**: A researcher wants to find "Drugs used for Hypertension that have a mechanism similar to ACE inhibitors."

**The Solution (Graph RAG)**:
1.  **Ingest**: Load ClinicalTrials.gov data into Samyama.
2.  **Embed**: Use the "Auto-Embed" pipeline to turn the "Mechanism of Action" text into vectors.
3.  **Query**:
    *   **Vector Search**: Find drugs with description similar to "ACE inhibitor".
    *   **Graph Filter**: `MATCH (drug)-[:TREATS]->(c:Condition {name: 'Hypertension'})`.

## 4. Smart Manufacturing: Production Optimization
**Source**: `examples/smart_manufacturing_demo.rs`

In a modern factory, thousands of variables must be balanced: machine speed, energy cost, and maintenance schedules.

**The Solution**:
Samyama uses its built-in **Jaya** or **GWO** (Grey Wolf Optimizer) to adjust production rates across the graph. The objective is to maximize output while keeping total energy consumption below a specific threshold (the constraint).

## 5. Enterprise SOC: Threat Hunting
**Source**: `examples/enterprise_soc_demo.rs`

Security Operations Centers (SOC) deal with millions of events (logins, file access, network traffic).

**The Solution**:
By modeling logs as a graph, security analysts can run **Pathfinding** algorithms to trace the "Lateral Movement" of an attacker.
*   **Graph RAG**: Use vector search to find "unusual login behavior" semantically similar to known attack patterns.
*   **Graph Traversal**: Instantly find all machines accessed by that user in the last 24 hours.
