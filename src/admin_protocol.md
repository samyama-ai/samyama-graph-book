# Administrative Protocol

Samyama Enterprise introduces a dedicated **Administrative Protocol** implemented via the `ADMIN.*` RESP command set. This allows database administrators to control and monitor the server using standard Redis clients without resorting to separate APIs or CLI tools.

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

## Backup & Recovery

The `ADMIN.BACKUP` suite provides high-level control over the **BackupEngine**:

*   **`ADMIN.BACKUP CREATE`**: Triggers an immediate, synchronous snapshot of the database.
*   **`ADMIN.BACKUP LIST`**: Lists all available backups, their IDs, and timestamps.
*   **`ADMIN.BACKUP VERIFY [id]`**: Performs a checksum verification of a specific backup's data files.
*   **`ADMIN.BACKUP RESTORE [id]`**: Restores the database to a previous state (requires a restart to finalize).
*   **`ADMIN.BACKUP DELETE [id]`**: Manually removes a backup file and its associated metadata.

## Governance & Licensing

Every `ADMIN.*` call is logged to the **Audit Trail**. The system also uses these commands to interact with the **LicenseManager**:

*   **`ADMIN.LICENSE`**: Returns the details of the currently active license, including the expiry date and enabled features (e.g., `gpu`, `monitoring`, `backup`).

By integrating these controls into the RESP protocol, Samyama allows teams to build automated operational dashboards using their existing Redis-compatible tools and libraries.

