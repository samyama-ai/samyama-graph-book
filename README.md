# Building Samyama: The Architecture of a Modern Rust Graph Database

This repository contains the source code for the "Book as Code" project describing the internal architecture of **Samyama-Graph**.

It is written using `mdBook`.

## Building the Book

1.  **Install mdBook**:
    ```bash
    cargo install mdbook
    ```

2.  **Build**:
    ```bash
    mdbook build
    ```

3.  **Serve locally**:
    ```bash
    mdbook serve --open
    ```

## Content Structure

*   **Part I**: Core storage and memory management (RocksDB, MVCC).
*   **Part II**: Query processing and Algorithms (Volcano/Vectorized, CSR).
*   **Part III**: Distributed Systems and AI (Raft, HNSW).
*   **Part IV**: Real-world application.

## License

This book content is licensed under CC-BY-4.0.
The Samyama Graph code is licensed under Apache 2.0.
