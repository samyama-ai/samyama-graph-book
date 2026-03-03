# Predictive Power (GNNs)

> **Status: Planned** — The features described in this chapter are on the Samyama roadmap and are **not yet implemented**. This chapter outlines the design vision for future GNN integration.

While traditional graph algorithms like PageRank tell you about the *importance* of a node, **Graph Neural Networks (GNNs)** would allow the database to make *predictions* about the future.

Samyama's philosophy on GNNs is clear: **Focus on Inference, not Training.**

## The Problem: Data Gravity
Training a GNN model (using frameworks like PyTorch Geometric or DGL) requires massive compute power and specialized hardware. However, once a model is trained, moving the entire graph to a Python environment every time you need a prediction is slow and expensive. This is "Data Gravity."

## The Planned Solution: In-Database Inference

The planned approach is to implement an inference engine based on **ONNX Runtime** (`ort`).

### How it will work:
1.  **Export**: Train your GNN in Python (where the data science ecosystem is best) and export it to the standard **ONNX** format.
2.  **Upload**: Upload the model to Samyama.
3.  **Execute**: Run predictions directly in Cypher queries.

```cypher
// Future: Predict the fraud risk for a person based on their connections
CALL algo.gnn.predict('fraud_model_v1', 'Person')
YIELD node, score
SET node.fraud_score = score
```

## Planned: GraphSAGE Aggregators

A future addition would be native **GraphSAGE-style Aggregators** for "Zero-Config" intelligence.

Instead of an external model, these aggregators would leverage the existing **Vector Search (HNSW)** infrastructure to compute new node embeddings by aggregating the vectors of neighbors (mean, max, or LSTM pooling).

This would allow the database to act as a **Dynamic Feature Store**, where embeddings are updated in real-time as the graph evolves, providing a predictive layer that most graph databases offer only through external tooling.
