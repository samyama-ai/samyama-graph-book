# Ecosystem Architecture & Dependency Graph

This chapter maps the full Samyama ecosystem: repositories, modules, features, and knowledge graph projects — with dependency graphs showing how everything connects.

---

## 1. Repository Map

The Samyama ecosystem spans 7 repositories.

```mermaid
graph LR
    subgraph Public ["Public (GitHub)"]
        SG["samyama-graph<br/>(OSS engine)"]
        SGB["samyama-graph-book<br/>(documentation)"]
        CKG["cricket-kg"]
        CTKG["clinicaltrials-kg"]
    end

    subgraph Private ["Private"]
        SGE["samyama-graph-enterprise"]
        SC["samyama-cloud<br/>(deploy, backlog, workflow)"]
        SI["samyama-insight<br/>(React frontend)"]
        AOKG["assetops-kg"]
    end

    SG -->|"sync via PR"| SGE
    SG -->|"Python SDK"| CKG
    SG -->|"Python SDK"| CTKG
    SG -->|"Python SDK"| AOKG
    SG -->|"TS SDK"| SI
    SGE -->|"deploy scripts"| SC
    SGB -.->|"documents"| SG
    SGB -.->|"documents"| SGE

    style SG fill:#4a9eff,stroke:#333,color:#fff
    style SGE fill:#ff6b6b,stroke:#333,color:#fff
    style SI fill:#51cf66,stroke:#333,color:#fff
    style SC fill:#ffd43b,stroke:#333
    style CKG fill:#b197fc,stroke:#333,color:#fff
    style CTKG fill:#b197fc,stroke:#333,color:#fff
    style AOKG fill:#b197fc,stroke:#333,color:#fff
```

| Repository | Visibility | Purpose |
|---|---|---|
| `samyama-graph` | Public | Rust graph DB engine (OSS) |
| `samyama-graph-enterprise` | Private | Enterprise features (GPU, monitoring, backup, licensing) |
| `samyama-graph-book` | Public | mdBook documentation + research papers |
| `samyama-insight` | Private | React + Vite frontend (schema explorer, query console, visualizer) |
| `samyama-cloud` | Private | Deployment configs, backlog, workflow |
| `cricket-kg` | Public | Cricket knowledge graph (Cricsheet data) |
| `clinicaltrials-kg` | Public | Clinical trials KG (ClinicalTrials.gov / AACT data) |
| `assetops-kg` | Private | Asset operations KG (industrial IoT data) |

---

## 2. samyama-graph Module Architecture

The OSS engine is organized into 7 core modules, 3 workspace crates, and 3 SDK packages.

```mermaid
graph TB
    subgraph "SDK Layer"
        PYSDK["sdk/python<br/>samyama (PyO3)"]
        MCP["sdk/python<br/>samyama_mcp"]
        TSSDK["sdk/typescript<br/>samyama-sdk"]
    end

    subgraph "Crates"
        SDK["crates/samyama-sdk<br/>EmbeddedClient + RemoteClient"]
        ALGO["crates/samyama-graph-algorithms<br/>PageRank, WCC, SCC, BFS, etc."]
        OPT["crates/samyama-optimization<br/>15 metaheuristic solvers"]
    end

    subgraph CLI
        CLIRS["cli/<br/>query, status, shell"]
    end

    subgraph "Core Engine (src/)"
        QUERY["query/<br/>parser (Pest) + planner + executor"]
        GRAPH["graph/<br/>store, node, edge, property, catalog"]
        PROTO["protocol/<br/>RESP server + HTTP API"]
        PERSIST["persistence/<br/>RocksDB, WAL, tenant"]
        RAFT["raft/<br/>openraft consensus"]
        NLQ["nlq/<br/>text-to-Cypher (multi-provider)"]
        AGENT["agent/<br/>GAK runtime + tools"]
        VECTOR["vector/<br/>HNSW index"]
        SHARD["sharding/<br/>tenant-level routing"]
    end

    %% SDK dependencies
    PYSDK --> SDK
    MCP --> PYSDK
    TSSDK -->|"HTTP fetch"| PROTO
    CLIRS --> SDK

    %% Crate dependencies
    SDK --> QUERY
    SDK --> GRAPH
    SDK --> PERSIST
    SDK --> ALGO
    SDK --> OPT
    SDK --> NLQ
    SDK --> AGENT
    SDK --> VECTOR

    %% Core module dependencies
    QUERY --> GRAPH
    PROTO --> QUERY
    PROTO --> GRAPH
    PERSIST --> GRAPH
    RAFT --> PERSIST
    NLQ --> QUERY
    AGENT --> NLQ
    VECTOR --> GRAPH
    SHARD --> PERSIST
    ALGO --> GRAPH

    style QUERY fill:#4a9eff,stroke:#333,color:#fff
    style GRAPH fill:#51cf66,stroke:#333,color:#fff
    style PROTO fill:#ffd43b,stroke:#333
    style SDK fill:#ff6b6b,stroke:#333,color:#fff
    style MCP fill:#b197fc,stroke:#333,color:#fff
    style PYSDK fill:#b197fc,stroke:#333,color:#fff
```

### Module Responsibilities

| Module | Key Types | Entry Points |
|---|---|---|
| `graph/` | `GraphStore`, `Node`, `Edge`, `PropertyValue`, `GraphCatalog` | In-memory storage, O(1) lookups, sorted adjacency lists |
| `query/` | `QueryExecutor`, `MutQueryExecutor`, `PhysicalOperator` | Pest parser → AST → logical plan → physical plan → Volcano iterator |
| `protocol/` | `RespServer`, `HttpServer`, `CommandHandler` | RESP on :6379, HTTP on :8080 |
| `persistence/` | `StorageEngine`, `WAL`, `TenantManager` | RocksDB column families, per-tenant isolation |
| `raft/` | `RaftNode`, `GraphStateMachine`, `ClusterManager` | openraft-based leader election + log replication |
| `nlq/` | `NLQPipeline`, `NLQClient`, `LLMProvider` | text → schema-aware prompt → LLM → Cypher extraction |
| `agent/` | `AgentRuntime`, `Tool` trait, `AgentConfig` | GAK: query gap → enrichment prompt → LLM → Cypher → ingest |
| `vector/` | `HnswIndex`, `VectorSearch` | HNSW with cosine/L2/inner-product, bincode persistence |
| `crates/samyama-sdk` | `SamyamaClient`, `EmbeddedClient`, `RemoteClient` | Async trait with extension traits (AlgorithmClient, VectorClient) |
| `crates/samyama-graph-algorithms` | `GraphView` (CSR), PageRank, WCC, SCC, BFS, Dijkstra | Build CSR projection → run algorithm → return results |
| `crates/samyama-optimization` | `Solver` trait, GA, PSO, SA, ACO, etc. | 15 solvers with `or.solve()` Cypher procedure |
| `sdk/python/samyama` | `SamyamaClient` (PyO3) | `.embedded()` / `.connect(url)` factory methods |
| `sdk/python/samyama_mcp` | `SamyamaMCPServer`, generators, schema discovery | Auto-generate MCP tools from graph schema |
| `sdk/typescript` | `SamyamaClient` class | Pure TS with `fetch`, `.connectHttp()` factory |

---

## 3. Enterprise Feature Layering (OSS → SGE)

```mermaid
graph TB
    subgraph OSS ["samyama-graph (OSS — Apache 2.0)"]
        QE["Query Engine<br/>~90% OpenCypher"]
        PS["Persistence<br/>RocksDB + WAL"]
        MT["Multi-Tenancy"]
        VS["Vector Search<br/>HNSW"]
        GA["Graph Algorithms<br/>PageRank, WCC, BFS..."]
        NQ["NLQ<br/>text-to-Cypher"]
        HV["HTTP Visualizer"]
        RF["Raft Consensus<br/>(basic)"]
        MO["Metaheuristic<br/>Optimization"]
        RDF["RDF / SPARQL<br/>(infrastructure)"]
    end

    subgraph SGE ["samyama-graph-enterprise (Proprietary)"]
        MON["Prometheus /metrics"]
        HC["Health Checks"]
        BK["Backup & Restore<br/>(PITR)"]
        AU["Audit Trail"]
        SQ["Slow Query Log"]
        ADM["ADMIN.* Commands"]
        ERF["Enhanced Raft<br/>(HTTP transport)"]
        GPU["GPU Acceleration<br/>(wgpu shaders)"]
        LIC["JET Licensing<br/>(Ed25519 signed)"]
    end

    SGE -->|"inherits all of"| OSS

    GPU -->|"accelerates"| GA
    GPU -->|"accelerates"| VS
    MON -->|"observes"| QE
    BK -->|"snapshots"| PS
    AU -->|"logs"| QE
    LIC -->|"gates"| SGE

    style OSS fill:#e8f5e9,stroke:#2e7d32
    style SGE fill:#fce4ec,stroke:#c62828
```

### Feature Availability Matrix

| Feature | Community (OSS) | Enterprise |
|---|---|---|
| OpenCypher query engine | ✅ | ✅ |
| Persistence (RocksDB + WAL) | ✅ | ✅ |
| Multi-tenancy | ✅ | ✅ |
| Vector search (HNSW) | ✅ | ✅ |
| Graph algorithms (11 algos) | ✅ | ✅ |
| NLQ (text-to-Cypher) | ✅ | ✅ |
| Raft consensus (basic) | ✅ | ✅ |
| Metaheuristic optimization | ✅ | ✅ |
| MCP server generation | ✅ | ✅ |
| Prometheus /metrics | ❌ | ✅ |
| Backup & restore (PITR) | ❌ | ✅ |
| Audit trail | ❌ | ✅ |
| ADMIN.* commands | ❌ | ✅ |
| GPU acceleration (wgpu) | ❌ | ✅ |
| Enhanced Raft (HTTP transport) | ❌ | ✅ |

---

## 4. Knowledge Graph Projects

All KG projects share the same stack: Python SDK → samyama-mcp-serve → custom config.

```mermaid
graph TB
    subgraph Engine ["Samyama Engine"]
        SG["samyama-graph<br/>(Rust)"]
        PYSDK["samyama<br/>(Python SDK / PyO3)"]
        MCPSERVE["samyama_mcp<br/>(MCP serve)"]
    end

    subgraph KGs ["Knowledge Graph Projects"]
        subgraph CKG ["cricket-kg"]
            CETL["etl/loader.py<br/>(Cricsheet JSON)"]
            CMCP["mcp_server/<br/>config.yaml (12 custom)"]
            CTEST["tests/<br/>25 MCP tests"]
        end

        subgraph CTKG ["clinicaltrials-kg"]
            CTETL["etl/loader.py<br/>(API or AACT flat files)"]
            CTMCP["mcp_server/<br/>16 tools (hand-written)"]
            CTAACT["etl/aact_loader.py<br/>(500K+ studies)"]
        end

        subgraph AOKG ["assetops-kg"]
            AOETL["etl/loader.py"]
            AOMCP["mcp_server/<br/>9 tools"]
        end
    end

    SG --> PYSDK
    PYSDK --> MCPSERVE
    MCPSERVE --> CMCP
    MCPSERVE -.->|"SK-14: migrate"| CTMCP
    MCPSERVE -.->|"SK-15: migrate"| AOMCP
    PYSDK --> CETL
    PYSDK --> CTETL
    PYSDK --> CTAACT
    PYSDK --> AOETL

    style SG fill:#4a9eff,stroke:#333,color:#fff
    style MCPSERVE fill:#b197fc,stroke:#333,color:#fff
    style CKG fill:#d0f0c0,stroke:#2e7d32
    style CTKG fill:#ffe0b2,stroke:#e65100
    style AOKG fill:#e1bee7,stroke:#6a1b9a
```

### KG Schema Summary

| KG | Node Labels | Edge Types | Data Source | Data Volume |
|---|---|---|---|---|
| cricket-kg | 6 (Player, Match, Team, Venue, Tournament, Season) | 12 | Cricsheet JSON | ~100-500 matches |
| clinicaltrials-kg | 15 (ClinicalTrial, Condition, Intervention, Sponsor, Site, ...) | 25 | ClinicalTrials.gov API or AACT flat files | ~500K+ studies |
| assetops-kg | 8 (Asset, Component, FailureMode, MaintenanceRecord, ...) | 11 | Industrial IoT data | Domain-specific |

---

## 5. Feature Dependency Graph (Backlog)

The complete feature dependency chain across all backlog items. Green = done, blue = in progress, white = planned.

```mermaid
graph TB
    subgraph "Query Engine (Done ✅)"
        QE01["QE-01<br/>Parameterized $param"]
        QE02["QE-02<br/>PROFILE stats"]
        QE03["QE-03<br/>shortestPath()"]
        QE07["QE-07<br/>CALL procedures"]
    end

    subgraph "Cypher Completeness (Done ✅)"
        CY01["CY-01<br/>collect(DISTINCT)"]
        CY02["CY-02<br/>datetime args"]
        CY04["CY-04<br/>Named paths"]
        CY05["CY-05<br/>Path functions"]
    end

    subgraph "Planner / Optimizer (Done ✅)"
        QP01["QP-01 Predicate pushdown"]
        QP02["QP-02 Cost-based"]
        QP05["QP-05 Plan cache"]
        QP11["QP-11 Graph-native enum"]
        QP12["QP-12 Triple stats"]
        QP13["QP-13 ExpandInto"]
        QP14["QP-14 Direction reversal"]
        QP15["QP-15 Logical plan IR"]
    end

    subgraph "Planner (Planned)"
        QP06["QP-06<br/>Histogram stats"]
        QP09["QP-09<br/>Operator fusion"]
        QP10["QP-10<br/>Adaptive exec"]
    end

    subgraph "Indexes (Done ✅)"
        IX01["IX-01..06<br/>DROP/SHOW/Composite/Unique"]
    end

    subgraph "Indexes (Planned)"
        IX07["IX-07<br/>Full-text index"]
        IX08["IX-08<br/>OR union scans"]
    end

    subgraph "Performance (Done ✅)"
        PF01["PF-01 CSR"]
        PF04["PF-04 Late materialization"]
        PF06["PF-06 AST cache"]
    end

    subgraph "Performance (Planned)"
        PF07["PF-07<br/>MVCC"]
        PF09["PF-09<br/>WCO joins"]
        PF10["PF-10<br/>Parallel exec"]
    end

    subgraph "Data Structures (Done ✅)"
        DS01["DS-01 Triple stats"]
        DS02["DS-02 Sorted adjacency"]
    end

    subgraph "Data Structures (Planned)"
        DS03["DS-03<br/>Type-partitioned adj"]
    end

    subgraph "SDK / MCP (Done ✅)"
        SK01["SK-01..06<br/>Rust/Python/TS SDK + CLI"]
        SK09["SK-09 npm publish"]
        SK10["SK-10 EXPLAIN/PROFILE"]
        SK11["SK-11 Schema/Stats"]
        SK12["SK-12<br/>samyama-mcp-serve"]
        SK13["SK-13<br/>cricket-kg MCP"]
    end

    subgraph "SDK (Planned)"
        SK14["SK-14<br/>clinicaltrials MCP"]
        SK15["SK-15<br/>assetops MCP"]
    end

    subgraph "HA (Done ✅)"
        HA01["HA-01 Raft"]
        HA02["HA-02 Sharding"]
        HA03["HA-03 Vector persist"]
    end

    subgraph "HA (Planned)"
        HA04["HA-04<br/>Temporal queries"]
        HA05["HA-05<br/>Graph sharding"]
        HA06["HA-06<br/>Distributed exec"]
    end

    subgraph "AI (Done ✅)"
        AI01["AI-01 GAK runtime"]
        AI02["AI-02 NLQ"]
        AI03["AI-03 Auto-embed"]
    end

    subgraph "AI / JIT KG (Planned)"
        AI07["AI-07<br/>Enterprise connectors"]
        AI08["AI-08<br/>Demand-driven agent"]
        AI09["AI-09<br/>Text-to-SQL bridge"]
        AI10["AI-10<br/>JIT KG demo"]
    end

    subgraph "GPU (Done ✅)"
        GP01["GP-01..10<br/>PageRank, CDLP, LCC,<br/>PCA, triangles, vectors,<br/>aggregates, sort"]
    end

    subgraph "Benchmarks (Done ✅)"
        BM01["BM-01..03<br/>Graphalytics, SNB, FinBench"]
    end

    subgraph "Benchmarks (Planned)"
        BM04["BM-04<br/>SF10 scale"]
        BM05["BM-05<br/>SNB BI tuning"]
        BM07["BM-07<br/>Comparative bench"]
    end

    subgraph "Visualizer (Done ✅)"
        VZ01["VZ-01..05<br/>Plan DAG, PROFILE,<br/>Stats, Console, Features"]
        VZ07["VZ-07..10<br/>Schema, CSV/JSON Import, E2E"]
    end

    subgraph "KG Projects"
        KG01["KG-01<br/>AACT full loader<br/>(in progress)"]
    end

    %% Dependencies
    CY01 & CY02 & QE03 & CY04 --> BM05
    CY04 --> CY05
    PF06 --> QP05
    QP01 & QP02 --> BM04
    PF07 --> HA04
    DS02 --> PF09
    HA05 --> HA06
    QE01 --> QP11
    QP12 --> QP11
    DS02 --> QP13
    QP14 --> QP11
    QP15 --> QP11
    SK09 --> VZ01
    SK10 --> VZ01
    SK11 --> VZ07
    QE07 --> VZ07
    SK12 --> SK13
    SK12 --> SK14
    SK12 --> SK15

    %% JIT KG chain
    AI01 --> AI07
    AI02 --> AI07
    SK12 --> AI07
    AI02 --> AI09
    AI07 --> AI08
    AI09 --> AI08
    AI08 --> AI10

    %% KG-01
    IX01 --> KG01

    %% Benchmark deps
    BM07 -.-> BM05

    style QE01 fill:#51cf66,stroke:#333,color:#fff
    style QE02 fill:#51cf66,stroke:#333,color:#fff
    style QE03 fill:#51cf66,stroke:#333,color:#fff
    style QE07 fill:#51cf66,stroke:#333,color:#fff
    style CY01 fill:#51cf66,stroke:#333,color:#fff
    style CY02 fill:#51cf66,stroke:#333,color:#fff
    style CY04 fill:#51cf66,stroke:#333,color:#fff
    style CY05 fill:#51cf66,stroke:#333,color:#fff
    style QP01 fill:#51cf66,stroke:#333,color:#fff
    style QP02 fill:#51cf66,stroke:#333,color:#fff
    style QP05 fill:#51cf66,stroke:#333,color:#fff
    style QP11 fill:#51cf66,stroke:#333,color:#fff
    style QP12 fill:#51cf66,stroke:#333,color:#fff
    style QP13 fill:#51cf66,stroke:#333,color:#fff
    style QP14 fill:#51cf66,stroke:#333,color:#fff
    style QP15 fill:#51cf66,stroke:#333,color:#fff
    style IX01 fill:#51cf66,stroke:#333,color:#fff
    style PF01 fill:#51cf66,stroke:#333,color:#fff
    style PF04 fill:#51cf66,stroke:#333,color:#fff
    style PF06 fill:#51cf66,stroke:#333,color:#fff
    style DS01 fill:#51cf66,stroke:#333,color:#fff
    style DS02 fill:#51cf66,stroke:#333,color:#fff
    style SK01 fill:#51cf66,stroke:#333,color:#fff
    style SK09 fill:#51cf66,stroke:#333,color:#fff
    style SK10 fill:#51cf66,stroke:#333,color:#fff
    style SK11 fill:#51cf66,stroke:#333,color:#fff
    style SK12 fill:#51cf66,stroke:#333,color:#fff
    style SK13 fill:#51cf66,stroke:#333,color:#fff
    style HA01 fill:#51cf66,stroke:#333,color:#fff
    style HA02 fill:#51cf66,stroke:#333,color:#fff
    style HA03 fill:#51cf66,stroke:#333,color:#fff
    style AI01 fill:#51cf66,stroke:#333,color:#fff
    style AI02 fill:#51cf66,stroke:#333,color:#fff
    style AI03 fill:#51cf66,stroke:#333,color:#fff
    style GP01 fill:#51cf66,stroke:#333,color:#fff
    style BM01 fill:#51cf66,stroke:#333,color:#fff
    style VZ01 fill:#51cf66,stroke:#333,color:#fff
    style VZ07 fill:#51cf66,stroke:#333,color:#fff
    style KG01 fill:#4a9eff,stroke:#333,color:#fff
    style AI07 fill:#fff,stroke:#333
    style AI08 fill:#fff,stroke:#333
    style AI09 fill:#fff,stroke:#333
    style AI10 fill:#fff,stroke:#333
```

---

## 6. Data Flow: Query → Enrichment → Response

This diagram shows the runtime data flow for a JIT KG query, incorporating the planned AI-07..AI-10 features.

```mermaid
sequenceDiagram
    participant U as User / Agent
    participant MCP as MCP Server
    participant NLQ as NLQ Pipeline
    participant QE as Query Engine
    participant GS as GraphStore
    participant AG as GAK Agent
    participant SRC as Enterprise Source<br/>(OneDrive / OLTP)

    U->>MCP: Natural language question
    MCP->>NLQ: text_to_cypher(question, schema)
    NLQ->>QE: MATCH (n:Person)-[:AUTHORED]->(d:Document)...
    QE->>GS: Execute query
    GS-->>QE: 0 results (gap detected)
    QE-->>MCP: Empty result set

    Note over MCP,AG: AI-08: Demand-driven enrichment triggers

    MCP->>AG: process_trigger(gap_context)
    AG->>SRC: AI-07: Pull from OneDrive (documents)
    SRC-->>AG: Document metadata + content
    AG->>NLQ: Extract entities (LLM)
    NLQ-->>AG: Cypher: CREATE (p:Person)..., CREATE (d:Document)...
    AG->>QE: Execute enrichment Cypher
    QE->>GS: MERGE nodes + edges

    AG->>SRC: AI-09: text-to-SQL (OLTP database)
    SRC-->>AG: Relational rows
    AG->>NLQ: Transform to graph entities (LLM)
    NLQ-->>AG: Cypher: CREATE (proj:Project)...
    AG->>QE: Execute enrichment Cypher
    QE->>GS: MERGE nodes + edges

    Note over MCP,GS: Graph enriched — re-execute original query

    MCP->>QE: Re-execute original Cypher
    QE->>GS: Execute query
    GS-->>QE: Results (populated)
    QE-->>MCP: Result set
    MCP-->>U: Answer with graph context
```

---

## 7. Deployment Architecture

```mermaid
graph TB
    subgraph "Samyama Server"
        SGE_BIN["samyama-graph<br/>(release binary)"]
        ROCKS["RocksDB<br/>(persistent storage)"]
        SI_DIST["samyama-insight<br/>(static dist/)"]
    end

    subgraph "Developer Workflow"
        SG_DEV["samyama-graph<br/>(cargo build)"]
        PY_DEV["Python SDK<br/>(maturin develop)"]
        KG_DEV["KG projects<br/>(python -m etl.loader)"]
    end

    subgraph "External Services"
        LLM["LLM Provider<br/>(OpenAI / Claude / Ollama)"]
    end

    SGE_BIN -->|":6379 RESP"| ROCKS
    SGE_BIN -->|":8080 HTTP"| SI_DIST
    SG_DEV -->|"sync via PR"| SGE_BIN
    SG_DEV --> PY_DEV --> KG_DEV
    SGE_BIN -->|"NLQ / GAK"| LLM

    style SGE_BIN fill:#ff6b6b,stroke:#333,color:#fff
    style SG_DEV fill:#4a9eff,stroke:#333,color:#fff
```

---

## 8. Version Sync Points

All packages must stay version-aligned. These are the 13 files that must be updated together on a version bump (Step 0.5 in the workflow):

```mermaid
graph LR
    V["Version<br/>v0.6.0"]

    V --> CT["Cargo.toml<br/>(root)"]
    V --> CLI["cli/Cargo.toml"]
    V --> SDKRS["crates/samyama-sdk/<br/>Cargo.toml"]
    V --> OPTC["crates/samyama-optimization/<br/>Cargo.toml"]
    V --> ALGOC["crates/samyama-graph-algorithms/<br/>Cargo.toml"]
    V --> PYC["sdk/python/Cargo.toml"]
    V --> PYP["sdk/python/pyproject.toml"]
    V --> TSP["sdk/typescript/package.json"]
    V --> TSL["sdk/typescript/package-lock.json"]
    V --> API["api/openapi.yaml"]
    V --> LIB["src/lib.rs<br/>(test_version)"]
    V --> CMD["CLAUDE.md"]

    style V fill:#ffd43b,stroke:#333
```

---

## 9. Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Language** | Rust (2021 edition) | Core engine, persistence, protocol |
| **Parser** | Pest (PEG) | OpenCypher grammar → AST |
| **Storage** | RocksDB | Persistent key-value with column families |
| **Consensus** | openraft | Raft leader election + log replication |
| **Vector Index** | Custom HNSW | Approximate nearest neighbor search |
| **GPU** | wgpu + WGSL shaders | GPU-accelerated algorithms (enterprise) |
| **Python SDK** | PyO3 0.22 + maturin | Rust → Python FFI binding |
| **MCP Framework** | FastMCP v2 | Model Context Protocol stdio server |
| **TypeScript SDK** | Pure TS + fetch | HTTP client for browser/Node.js |
| **Frontend** | React + Vite + shadcn/ui | Interactive dashboard (samyama-insight) |
| **E2E Testing** | Playwright | Browser-based end-to-end tests |
| **Benchmarks** | Criterion | Rust micro-benchmarks (10 suites) |
| **CI/CD** | GitHub Actions | Automated builds, tests, sync |
| **Licensing** | Ed25519 (JET tokens) | Cryptographic feature gating |
| **LLM Integration** | OpenAI, Claude, Gemini, Ollama | NLQ + Agentic enrichment |
