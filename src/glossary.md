# Glossary

Key terms and concepts used throughout this book, organized alphabetically.

---

**Adjacency List**
: A graph representation where each node stores a list of its outgoing and incoming edge IDs. Used in `GraphStore` for fast neighbor lookups. O(1) access to a node's neighbors.

**Agentic Enrichment**
: See *GAK*.

**Arena Allocation**
: A memory management pattern where objects are allocated in contiguous blocks rather than scattered heap allocations. Samyama uses a versioned arena (`Vec<Vec<T>>`) for nodes and edges, giving cache-friendly sequential memory access.

**AST (Abstract Syntax Tree)**
: The intermediate tree representation produced by the Pest parser after parsing a Cypher query string. Transformed by the `QueryPlanner` into a physical execution plan.

**Bincode**
: A Rust-specific binary serialization format used for RocksDB value encoding. Faster than JSON or Protobuf for Rust-to-Rust communication. Used to serialize `StoredNode` and `StoredEdge` structs.

**CAP Theorem**
: States that a distributed system can provide only two of three guarantees: Consistency, Availability, Partition Tolerance. Samyama chooses CP (Consistency + Partition Tolerance) via Raft.

**CDLP (Community Detection via Label Propagation)**
: A graph algorithm where each node adopts the most frequent label among its neighbors. Converges to natural community boundaries. LDBC Graphalytics standard.

**Column Family**
: A RocksDB feature that logically partitions data. Samyama uses column families for tenant isolation (separate compaction, backup, and key namespaces per tenant).

**ColumnStore**
: Samyama's columnar property storage. Stores all values of a given property (e.g., all "ages") in a contiguous array, enabling cache-efficient analytical queries and late materialization.

**Cost-Based Optimizer (CBO)**
: The query planning component that uses `GraphStatistics` (label counts, edge counts, property selectivity) to choose between execution strategies (e.g., IndexScan vs. NodeScan).

**CSR (Compressed Sparse Row)**
: A compact, read-only graph representation using three arrays (`out_offsets`, `out_targets`, `weights`). Used for OLAP algorithm execution because sequential memory access enables CPU prefetching.

**Cypher**
: A declarative graph query language originally created by Neo4j. Samyama supports ~90% of the OpenCypher specification.

**EdgeId**
: A `u64` integer serving as a direct index into the edge storage arena. Like `NodeId`, this gives O(1) access without hashing.

**Embedded Mode**
: Running the Samyama engine in-process (no server) via `EmbeddedClient`. Zero network overhead, full access to algorithms, vector search, and persistence APIs.

**EXPLAIN**
: A Cypher prefix that returns the physical execution plan without executing the query. Shows operator tree, estimated row counts, and graph statistics.

**GAK (Generation-Augmented Knowledge)**
: Samyama's paradigm where the database uses LLMs to autonomously discover and create missing data, inverting the traditional RAG pattern. The database actively builds its own knowledge graph.

**GraphStatistics**
: Runtime statistics maintained by `GraphStore`: label counts, edge type counts, average degree, and property stats (null fraction, distinct count, selectivity). Used by the cost-based optimizer.

**GraphStore**
: The core in-memory storage structure. Contains versioned arenas for nodes/edges, adjacency lists, column stores, vector indices, and property indices.

**GraphView**
: The CSR representation of a projected subgraph, used as input to all algorithms in `samyama-graph-algorithms`. Immutable once built, enabling zero-lock parallel processing.

**HNSW (Hierarchical Navigable Small World)**
: An approximate nearest neighbor search algorithm for vector indexing. Provides logarithmic search complexity with high recall. Implemented via the `hnsw_rs` crate.

**JET (JSON Enablement Token)**
: The Enterprise license format: `base64(header).base64(payload).base64(signature)` with Ed25519 signing. Contains org, features, expiry, and machine fingerprint.

**Label**
: A string tag on a node that categorizes it (e.g., `Person`, `Account`). Nodes can have multiple labels. Labels are indexed for fast scanning.

**Late Materialization**
: An optimization where scan operators produce `Value::NodeRef(id)` references instead of full node clones. Properties are resolved on-demand only at the `ProjectOperator`, reducing memory bandwidth by 4-5x.

**LDBC Graphalytics**
: The industry-standard benchmark suite for graph analytics correctness and performance. Samyama passes 28/28 tests across 6 algorithms on XS and S-size datasets.

**LSM-Tree (Log-Structured Merge-Tree)**
: The storage engine architecture used by RocksDB. Converts random writes into sequential appends, optimizing for write-heavy workloads like graph databases.

**Mechanical Sympathy**
: Designing software to align with hardware characteristics (CPU caches, memory access patterns, SIMD lanes). A core design principle throughout Samyama.

**Metaheuristic**
: A nature-inspired optimization algorithm that searches for "good enough" solutions in complex spaces. Samyama implements 22 metaheuristics (Jaya, PSO, DE, GWO, NSGA-II, etc.).

**MVCC (Multi-Version Concurrency Control)**
: A concurrency technique where readers see a consistent snapshot while writers create new versions. Samyama implements MVCC via version chains in the node/edge arenas.

**NodeId**
: A `u64` integer serving as a direct index into the versioned node arena (`Vec<Vec<Node>>`). This eliminates hash lookups, giving O(1) access with cache-friendly contiguous memory.

**NodeRef**
: A lightweight `Value::NodeRef(NodeId)` used in late materialization. Carries only the ID, not the full node data. Properties are resolved lazily via `resolve_property()`.

**NLQ (Natural Language Query)**
: The pipeline that converts natural language questions to Cypher queries using LLMs. Supports OpenAI, Gemini, Ollama, and Claude providers.

**NSGA-II (Non-dominated Sorting Genetic Algorithm II)**
: A multi-objective optimization algorithm that finds Pareto-optimal solutions. Used with the Constrained Dominance Principle for feasible-first selection.

**OpenCypher**
: The open standard for the Cypher query language, maintained by the openCypher project. Samyama implements ~90% of the specification.

**Pareto Front**
: The set of solutions where no objective can be improved without worsening another. NSGA-II and MOTLBO return Pareto fronts for multi-objective optimization.

**PCA (Principal Component Analysis)**
: A dimensionality reduction technique that projects high-dimensional data onto principal components. Samyama implements Randomized SVD (Halko et al.) and Power Iteration solvers.

**PEG (Parsing Expression Grammar)**
: A formal grammar type that uses ordered choice (tries alternatives left-to-right). Samyama's Cypher parser uses the Pest PEG library.

**PhysicalOperator**
: The trait implemented by all 35 execution operators. Each operator processes `RecordBatch`es in a pull-based Volcano model.

**PITR (Point-in-Time Recovery)**
: Enterprise feature that restores the database to an exact timestamp by replaying WAL entries against a snapshot.

**PROFILE**
: A planned Cypher prefix (not yet implemented) that will execute the query and return actual row counts and timing per operator, complementing EXPLAIN.

**PropertyValue**
: The union type for node/edge properties: `String`, `Integer`, `Float`, `Boolean`, `DateTime`, `Array`, `Map`, or `Null`.

**Raft**
: A consensus algorithm for distributed systems. Ensures all nodes agree on the log order. Samyama uses the `openraft` crate for leader election, log replication, and quorum commits.

**Rayon**
: A Rust parallel computing library used for data-parallel algorithm execution. Enables zero-overhead parallel iteration over CSR arrays.

**RDF (Resource Description Framework)**
: A W3C standard for representing knowledge as subject-predicate-object triples. Samyama supports RDF with SPO/POS/OSP indexing and Turtle/N-Triples/RDF-XML serialization.

**RecordBatch**
: The internal data structure passed between operators in the Volcano model. Contains columns of `Value`s and supports batch processing of 1,024 records at a time.

**RESP (Redis Serialization Protocol)**
: The wire protocol used by Redis clients. Samyama implements RESP3 for backward compatibility with the Redis ecosystem.

**RocksDB**
: An embedded key-value store based on LSM-Trees, originally forked from LevelDB by Facebook. Samyama uses it for persistent storage with Column Families for multi-tenancy.

**Selectivity**
: The fraction of rows that satisfy a filter predicate. Low selectivity (e.g., 0.01 = 1%) means the filter is highly selective, favoring index scans.

**Snapshot Isolation**
: A concurrency level where each query sees a consistent point-in-time view of the database, regardless of concurrent writes. Achieved via MVCC version chains.

**SPARQL**
: The W3C standard query language for RDF data. Parser infrastructure is in place via `spargebra`; query execution is in development.

**Volcano Model**
: A query execution model where operators form a tree and data flows bottom-up via `next_batch()` calls. Each operator pulls from its children on demand (lazy evaluation).

**WAL (Write-Ahead Log)**
: A sequential log where all mutations are written before being applied to the main storage. Ensures durability: if the process crashes, uncommitted changes can be replayed.

**wgpu**
: The Rust implementation of the WebGPU API. Used in Samyama Enterprise for GPU-accelerated graph algorithms via WGSL compute shaders targeting Metal, Vulkan, and DX12.

**WGSL (WebGPU Shading Language)**
: The shader language for WebGPU compute kernels. Samyama Enterprise uses WGSL shaders for PageRank, CDLP, LCC, Triangle Counting, PCA, and vector distance operations.
