# Observability & Multi-tenancy

A database in production is a living organism. To keep it healthy, we need to see inside it, and to keep it secure, we need to isolate its users.

## Multi-tenancy: Namespace Isolation

Samyama is "Multi-tenant by Design." We don't just put everyone's data in one big bucket; we use **Namespace Isolation**.

### Logical Separation with RocksDB
We leverage RocksDB's **Column Families** (CF) for this. Each tenant is assigned their own CF.
*   **Isolation**: Tenant A's keyspace is physically and logically distinct from Tenant B's.
*   **Maintenance**: Compaction (the background cleanup process) happens per-tenant. If Tenant A is doing heavy writes, it won't trigger a slow compaction for Tenant B.
*   **Backup**: We can snapshot and restore individual tenants without affecting others.

### Resource Quotas
To prevent the "Noisy Neighbor" problem, Samyama enforces strict resource quotas per tenant:
*   **Memory Quota**: Max RAM for the in-memory graph.
*   **Storage Quota**: Max disk space in RocksDB.
*   **Query Time**: Max duration for a single Cypher query (to prevent "queries from hell" from locking the CPU).

## Observability: The Three Pillars

We follow the industry-standard observability stack: **Prometheus**, **OpenTelemetry (OTEL)**, and **Structured Logging**.

### 1. Metrics (Prometheus)
Samyama exports hundreds of metrics in the Prometheus format. 
*   **QPS**: Queries per second (Read vs. Write).
*   **Latency Histograms**: P50, P95, and P99 response times.
*   **Cache Hit Rates**: How often we are hitting the in-memory graph versus going to RocksDB.

### 2. Tracing (OpenTelemetry)
For complex, distributed queries, metrics aren't enough. We need to know *where* the time was spent.
Using the `tracing` crate in Rust, we generate distributed traces that can be visualized in **Jaeger** or **Grafana Tempo**. You can see exactly how many milliseconds were spent parsing the query, planning it, and executing it on different nodes in the cluster.

### 3. Structured Logging
Gone are the days of parsing text logs. Samyama emits **JSON logs**.
```json
{
  "timestamp": "2026-02-08T10:30:45Z",
  "level": "INFO",
  "query": "MATCH (n) RETURN n",
  "duration_ms": 12,
  "tenant": "acme_corp"
}
```
This allows for easy ingestion into ELK (Elasticsearch, Logstash, Kibana) or Loki for powerful log aggregation and searching.

By combining strong tenant isolation with deep observability, Samyama provides an "Enterprise-Ready" experience that allows operators to run massive multi-user clusters with confidence.
