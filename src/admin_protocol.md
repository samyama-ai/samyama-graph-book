# Administrative Protocol

Efficiently managing a distributed database cluster requires a specialized set of commands that go beyond data querying. Samyama Enterprise introduces the `ADMIN` command family, accessible via the standard RESP protocol.

## Server Management

These commands allow operators to inspect the internal state of a Samyama node without leaving their terminal.

*   **`ADMIN.STATUS`**: Returns high-level health indicators, including server uptime, total query count, active connection count, and memory usage.
*   **`ADMIN.METRICS`**: Dumps the complete internal metrics registry as a JSON object. This is useful for ad-hoc debugging or custom monitoring integration.
*   **`ADMIN.CONFIG GET/SET`**: Allows for dynamic reconfiguration of the server without a restart. You can adjust the `slow_query_threshold`, memory quotas, or log levels on the fly.

## Tenant Governance

In a multi-tenant environment, the `ADMIN.TENANTS` command is critical. It provides a detailed breakdown of resource consumption across the cluster:

| Field | Description |
| :--- | :--- |
| **Tenant ID** | The unique namespace of the tenant. |
| **Node Count** | Number of nodes in this tenant's graph. |
| **Storage (MB)** | Disk space consumed in RocksDB. |
| **QPS** | Current queries per second. |
| **Quota Status** | Shows if the tenant is approaching their memory or storage limits. |

## Performance Introspection

The `ADMIN.SLOWLOG` command tracks queries that exceed the execution time threshold. Unlike general logging, this persists in a high-performance ring buffer for quick retrieval.

```bash
# Retrieve the last 10 slow queries
redis-cli ADMIN.SLOWLOG 10
```

This protocol ensures that Samyama is not a "black box," but a transparent and controllable part of the enterprise infrastructure.
