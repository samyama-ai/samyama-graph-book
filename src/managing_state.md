# Managing State (MVCC & Memory)

In a high-performance database, "State" is the enemy of speed. Managing it requires locks, and locks kill concurrency.

If User A is reading a graph to calculate the shortest path between two cities, and User B updates a road in the middle of that calculation, what should happen?
1.  **Locking**: User B waits until User A finishes. (Safe but slow).
2.  **Dirty Read**: User A sees the half-updated state and crashes. (Fast but broken).
3.  **MVCC**: User A sees the "old" version of the road, while User B writes the "new" version. Both proceed in parallel.

Samyama implements **Multi-Version Concurrency Control (MVCC)** using a specialized in-memory structure.

## The Data Structure: Versioned Arena

Most graph databases use pointer-heavy structures (`Box<Node>`, `Rc<RefCell<Node>>`). In Rust, this is often a performance trap due to cache misses and borrowing rules.

Samyama uses a **Versioned Arena** pattern.

```rust
pub struct GraphStore {
    /// Node storage: NodeId -> [Version1, Version2, ...]
    nodes: Vec<Vec<Node>>,
    
    /// Global transaction counter
    pub current_version: u64,
}
```

### 1. The ID is the Index
A `NodeId` in Samyama isn't a random UUID; it's a direct `u64` index into the `nodes` vector. `NodeId(5)` means "look at index 5 in the vector". This gives us **O(1)** access time without hashing.

### 2. The Version Chain
The inner vector `Vec<Node>` represents the history of that node.
*   Index 0: The oldest version.
*   Index N: The latest version.

When a write happens:
1.  We acquire a write lock on the specific node (or the whole structure, depending on the transaction scope).
2.  We **clone** the latest version.
3.  We apply the changes to the clone.
4.  We push the new version to the end of the list with `version = current_global_version + 1`.

## Snapshot Isolation

This structure enables **Snapshot Isolation**. When a query starts, it grabs the `current_version` (say, 100).

```rust
// Simplified logic
fn get_node_at_version(&self, id: NodeId, query_version: u64) -> Option<&Node> {
    let history = &self.nodes[id];
    
    // Iterate backwards to find the newest version <= query_version
    for node_version in history.iter().rev() {
        if node_version.version <= query_version {
            return Some(node_version);
        }
    }
    None
}
```

Even if a writer updates the node to version 101, 102, and 103 while the query is running, the query logic will simply skip them and return version 100.

## Memory Management & cleanup

"But wait," you ask, "won't memory explode if you keep every version forever?"

Yes. That's why we have **Garbage Collection (GC)**.
Samyama runs a background process that "prunes" versions that are:
1.  Older than the oldest active transaction.
2.  Persisted to RocksDB (for cold storage).

This architecture allows Samyama to serve heavy analytical queries (which might take seconds) simultaneously with high-throughput transactional writes (thousands per second) without them blocking each other.
