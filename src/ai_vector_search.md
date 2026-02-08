# AI & Vector Search

The "Vector Database" hype train has led to many specialized tools (Pinecone, Weaviate). But a vector is just a property of a node. Separating vectors from the graph creates data silos.

Samyama treats Vectors as **First-Class Citizens**.

## The HNSW Index

We use the **Hierarchical Navigable Small World (HNSW)** algorithm (via the `hnsw_rs` crate) to index high-dimensional vectors.

*   **Storage**: Vectors are stored in a dedicated RocksDB column family.
*   **Indexing**: The HNSW graph is maintained in memory for millisecond-speed nearest neighbor search.

```rust
pub struct VectorIndex {
    dimensions: usize,
    metric: DistanceMetric, // Cosine, L2, or DotProduct
    hnsw: Hnsw<'static, f32, CosineDistance>,
}
```

## Graph RAG (Retrieval Augmented Generation)

The power of Samyama comes from combining Vector Search with Graph Traversal in a single query.

**Scenario**: You want to find legal precedents that are *semantically similar* to a case file AND *cited by* a specific judge.

Pure Vector DB:
1.  Query Vector DB -> Get top 100 docs.
2.  Filter in application -> Keep only those cited by Judge X.
3.  Problem: You might filter out all 100 docs!

Samyama (Graph RAG):
```cypher
// 1. Vector Search finds the entry points
CALL db.index.vector.queryNodes('Precedent', 'embedding', $query_vector, 100)
YIELD node, score

// 2. Graph Pattern filters them immediately
MATCH (node)<-[:CITED]-(j:Judge {name: 'Scalia'})

// 3. Return best matches
RETURN node.summary, score
ORDER BY score DESC LIMIT 5
```

This "Pre-filtering" or "Post-filtering" happens inside the engine, enabling highly efficient Retrieval-Augmented Generation workflows for LLMs.
