# Samyama Enterprise Edition

While the Community Edition (OSS) provides the high-performance core engine, the **Samyama Enterprise Edition** is designed for mission-critical production environments that require 24/7 availability, robust data protection, and deep operational visibility.

## The Production Gap

Moving a database from a developer's laptop to a production cluster involves solving three major challenges:
1.  **Observability**: Knowing the health of the system before users complain.
2.  **Durability**: Guaranteeing that data can be recovered even after catastrophic hardware failure.
3.  **Governance**: Enforcing quotas and auditing every change for compliance.

Samyama Enterprise addresses these through a set of exclusive, production-hardened modules.

## Enterprise-Only Capabilities

### 1. Monitoring & Observability Stack
Full-stack visibility via a native Prometheus export endpoint and an internal audit trail.
*   **Metrics**: Over 200 real-time counters and histograms (P50/P95/P99 latencies).
*   **Health Checks**: `/health/live` and `/health/ready` endpoints for Kubernetes orchestration.
*   **Slow Query Log**: Automatically captures queries exceeding a configurable threshold (default 100ms) for retroactive optimization.

### 2. Advanced Data Protection
Beyond the standard Write-Ahead Log (WAL), Enterprise includes a dedicated Backup & Recovery engine.
*   **Point-in-Time Recovery (PITR)**: Restore the database to any specific microsecond in the past.
*   **Incremental Backups**: Minimize storage costs and network bandwidth by only backing up changed data blocks.

### 3. Enhanced High Availability
While the OSS version includes basic Raft consensus, the Enterprise edition features a production-hardened transport layer.
*   **HTTP Inter-node RPC**: Uses encrypted HTTP/2 for all cluster communication.
*   **Snapshot Recovery**: Automatically synchronizes new or lagging nodes by streaming compressed database snapshots.

## Feature Comparison

| Feature | Community (OSS) | Enterprise |
| :--- | :---: | :---: |
| **Core Engine** | ✅ | ✅ |
| **OpenCypher** | ✅ | ✅ |
| **Vector Search** | ✅ | ✅ |
| **Backup & Restore** | ❌ | ✅ |
| **Prometheus Metrics** | ❌ | ✅ |
| **Audit Trail** | ❌ | ✅ |
| **Kubernetes Ready** | ❌ | ✅ |
| **24/7 Support** | ❌ | ✅ |

Samyama Enterprise ensures that your data layer is the strongest link in your application stack.
