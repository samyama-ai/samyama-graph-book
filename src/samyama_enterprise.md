# Samyama Enterprise Edition

While the Community Edition (OSS) provides the high-performance core engine, the **Samyama Enterprise Edition** is designed for mission-critical production environments that require hardware acceleration, 24/7 availability, robust data protection, and deep operational visibility.

## The Production Gap

Moving a database from a developer's laptop to a production cluster involves solving three major challenges:
1.  **Observability**: Knowing the health of the system before users complain.
2.  **Durability**: Guaranteeing that data can be recovered even after catastrophic hardware failure.
3.  **Hardware Acceleration**: Utilizing modern GPUs for massive graph analytical workloads.

## Feature Matrix

| Category | Feature | Community (OSS) | Enterprise |
| :--- | :--- | :---: | :---: |
| **Core Engine** | Property Graph (nodes, edges, labels, 7 property types) | ✅ | ✅ |
| | OpenCypher Query Engine (~90% coverage) | ✅ | ✅ |
| | RESP Protocol (Redis-compatible) | ✅ | ✅ |
| | ACID Transactions (local) | ✅ | ✅ |
| **Persistence** | RocksDB Storage (LZ4/Zstd compression) | ✅ | ✅ |
| | Write-Ahead Log (WAL) | ✅ | ✅ |
| | Multi-Tenancy (namespace isolation, quotas) | ✅ | ✅ |
| | **Backup & Restore (Full/Incremental)** | ❌ | ✅ |
| | **Point-in-Time Recovery (PITR)** | ❌ | ✅ |
| | **Scheduled Backups & Retention Policies** | ❌ | ✅ |
| **Monitoring** | Logging (tracing crate) | ✅ | ✅ |
| | **Prometheus Metrics (`/metrics`)** | ❌ | ✅ |
| | **Health Checks (`/health/live`, `/health/ready`)** | ❌ | ✅ |
| | **Slow Query Log & Audit Trail** | ❌ | ✅ |
| | **ADMIN.* RESP Commands** | ❌ | ✅ |
| **High Availability** | Raft Consensus (openraft) | Basic | Enhanced |
| | **HTTP Raft Transport (inter-node RPC)** | ❌ | ✅ |
| | **Raft Metrics & Snapshot Recovery** | ❌ | ✅ |
| **Advanced** | Vector Search (HNSW) | ✅ | ✅ |
| | RDF/SPARQL 1.1 Support | ✅ | ✅ |
| | Graph Algorithms (PageRank, BFS, community detection) | ✅ | ✅ |
| | Natural Language Query (LLM text-to-Cypher) | ✅ | ✅ |
| | **GPU Acceleration (wgpu)** | ❌ | ✅ |

## 1. Hardware Acceleration (wgpu)

Samyama Enterprise includes hardware-accelerated compute via the `samyama-gpu` crate. Built on **wgpu**, it provides cross-platform acceleration (Metal on macOS, Vulkan on Linux, DX12 on Windows).

*   **GPU Algorithms**: PageRank, CDLP (Label Propagation), LCC (Clustering Coefficient), Triangle Counting, and PCA (Principal Component Analysis) are implemented as WGSL compute shaders.
*   **Vector Distance**: Optimized cosine distance and inner product shaders for batch re-ranking after HNSW retrieval.
*   **Query Operators**: Parallel reduction for `SUM` aggregations and bitonic sort for `ORDER BY` on large result sets (>10,000 rows).

> **Mechanical Sympathy Note**: The engine uses a `MIN_GPU_NODES` threshold (default 1,000). For PCA specifically, the threshold is higher (`MIN_GPU_PCA = 50,000` nodes and `d > 32` dimensions) due to the additional overhead of covariance matrix computation. For smaller subgraphs, the CPU remains faster due to memory transfer overhead. The GPU parallelism dominates once the graph scale exceeds ~100,000 nodes.

### GPU PCA Shaders

PCA on the GPU uses five specialized WGSL compute shaders:
1. **`pca_mean.wgsl`**: Parallel mean computation across feature columns.
2. **`pca_center.wgsl`**: Mean-centering the data matrix.
3. **`pca_covariance.wgsl`**: Tiled covariance matrix computation (processes 64 samples per tile for cache efficiency).
4. **`pca_power_iter.wgsl`**: Power iteration for eigenvector extraction.
5. **`pca_power_iter_norm.wgsl`**: Fused power iteration with in-GPU normalization—computes matrix-vector multiply, parallel reduction for the norm, and normalization in a single dispatch, avoiding costly CPU↔GPU synchronization per iteration.

## 2. Monitoring & Observability

Enterprise provides a full-stack observability suite:
*   **Prometheus `/metrics`**: Over 200 real-time counters and histograms (queries/sec, P99 latency, connection counts).
*   **Health API**: JSON-based health status (`/api/health`) with dedicated Kubernetes liveness/readiness probes.
*   **Audit Trail**: Cryptographically secure logs of every administrative action and data modification for compliance (GDPR, SOC2).

## 3. Data Protection (Backup & Recovery)

The Enterprise persistence layer (`src/persistence/backup.rs`) moves beyond the WAL:
*   **Incremental Backups**: WAL-based delta backups minimize storage costs.
*   **Point-in-Time Recovery (PITR)**: Restore the database to a specific backup ID, WAL sequence, or microsecond timestamp.
*   **Retention Policies**: Automated cleanup based on backup age or total count.

## 4. Enhanced High Availability

The Enterprise edition features a production-hardened Raft implementation (+850 lines of code over OSS):
*   **HTTP Transport**: Inter-node communication uses encrypted HTTP/2 (Axum-based) instead of simulated local pipes.
*   **Snapshot Recovery**: Automatically synchronizes lagging nodes by streaming compressed database snapshots.
*   **Role Tracking**: Advanced metrics for leader election, quorum health, and log replication lag.

## 5. Licensing & Governance

Enterprise features are gated via an Ed25519-signed **JET (JSON Enablement Token)**.

### Token Format

```
base64(header).base64(payload).base64(signature)
```

The payload contains: `id`, `org`, `email`, `edition`, `features[]`, `max_nodes`, `max_cluster_nodes`, `issued_at`, `expires_at`, and machine `fingerprint`.

### License Hardening

The Enterprise licensing system includes multiple layers of protection:

| Protection | Mechanism |
| :--- | :--- |
| **Public Key Embedding** | Ed25519 public key compiled into the binary via `build.rs` (release builds only) |
| **Machine Fingerprint** | SHA-256 hash of hostname + primary MAC address binds license to specific hardware |
| **Clock Drift Protection** | Persisted timestamp tracking with 1-hour tolerance prevents system clock manipulation |
| **Usage Enforcement** | Node count checked before every `CREATE` at both RESP and HTTP layers |
| **Revocation List** | Ed25519-signed `revocation.jet` checked at startup; revoked licenses immediately disabled |
| **Telemetry** | Optional anonymous heartbeat reporting license health (opt-out via `SAMYAMA_TELEMETRY=off`) |

*   **Grace Period**: 30-day operation after license expiry with warning logs. On day 31, enterprise features are disabled but the core engine continues operating.
*   **Governance**: Use `ADMIN.TENANTS` to monitor per-tenant resource usage and enforce strict memory/storage quotas in multi-tenant environments.
