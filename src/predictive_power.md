# Predictive Power (GNNs)

While traditional graph algorithms like PageRank tell you about the *importance* of a node, **Graph Neural Networks (GNNs)** allow the database to make *predictions* about the future.

Samyama's philosophy on GNNs is clear: **We focus on Inference, not Training.**

## The Problem: Data Gravity
Training a GNN model (using frameworks like PyTorch Geometric or DGL) requires massive compute power and specialized hardware. However, once a model is trained, moving the entire graph to a Python environment every time you need a prediction is slow and expensive. This is "Data Gravity."

## The Solution: In-Database Inference

Samyama implements an inference engine based on **ONNX Runtime** (`ort`). 

### How it works:
1.  **Export**: You train your GNN in Python (where the data science ecosystem is best) and export it to the standard **ONNX** format.
2.  **Upload**: You upload the model to Samyama.
3.  **Execute**: You run predictions directly in your Cypher queries.

```cypher
// Predict the fraud risk for a person based on their connections
CALL algo.gnn.predict('fraud_model_v1', 'Person') 
YIELD node, score
SET node.fraud_score = score
```

## GraphSAGE Aggregators

For users who want "Zero-Config" intelligence, we have implemented native **GraphSAGE-style Aggregators**. 

Instead of an external model, these aggregators leverage the existing **Vector Search (HNSW)** infrastructure. They compute a new node embedding by aggregating the vectors of its neighbors (mean, max, or LSTM pooling). 

This allows the database to act as a **Dynamic Feature Store**, where embeddings are updated in real-time as the graph evolves, providing a predictive layer that most graph databases lack.
