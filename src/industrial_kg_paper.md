# Research Paper: Knowledge Graphs for Industrial Operations

We have published a research paper evaluating knowledge graphs as the data layer for LLM-based industrial asset operations, building on the AssetOpsBench benchmark.

**Title**: *Knowledge Graphs as the Missing Data Layer for LLM-Based Industrial Asset Operations*

**Authors**: [Madhulatha Mandarapu](https://www.linkedin.com/in/madhulatha-mandarapu-72bb6b2a/) (madhulatha@samyama.ai), [Sandeep Kunkunuru](https://www.linkedin.com/in/sandeepkunkunuru/) (sandeep@samyama.ai)

March 2026 | [GitHub (assetops-kg)](https://github.com/samyama-ai/assetops-kg) | [IBM AssetOpsBench](https://github.com/IBM/AssetOpsBench)

**Keywords**: Knowledge Graphs, Large Language Models, Industrial Asset Operations, Benchmark, OpenCypher, Vector Search, Graph Algorithms.

---

## Download PDF

- [Paper PDF](https://github.com/samyama-ai/samyama-graph-book/releases/latest/download/paper3_industrial_kg.pdf) — arxiv-ready LaTeX version (12 pages)
- [arxiv Upload Bundle](https://github.com/samyama-ai/samyama-graph-book/releases/latest/download/paper3-industrial-kg-arxiv.tar.gz) — tex + bib for arxiv submission

---

## Abstract

LLM-based agents for industrial asset operations show promise but achieve limited accuracy when reasoning over flat document stores. The AssetOpsBench benchmark establishes that GPT-4 agents achieve 65% success on 139 industrial maintenance scenarios backed by CouchDB, YAML, and CSV data sources. AssetOpsBench evaluates LLM agent autonomy; we ask a complementary question: *how much does the data model behind the tools affect agent performance?*

Building on the same benchmark data and scenarios, we introduce a knowledge graph layer (781 nodes, 955 edges, 16 relationship types) and evaluate three architectures of increasing LLM involvement:

| Architecture | LLM Role | Pass Rate | Avg Latency |
| :--- | :--- | :--- | :--- |
| Deterministic + graph | None (pre-coded) | **99% (137/139)** | **63 ms** |
| LLM + graph via NLQ | Generates Cypher | 83% (115/139) | 5,874 ms |
| Baseline (tool-augmented LLM) | Does everything | ~65% (91/139) | not reported |

Our key finding is **inverted LLM usage**: instead of asking the LLM to reason over raw data (a broad, error-prone task), we ask it to generate structured queries from a typed schema — a narrow problem that plays to LLM strengths. The graph then executes deterministically.

---

## Thesis

For structured operational domains, the **data model is the primary bottleneck**. A knowledge graph with typed relationships enables both deterministic queries (for known patterns) and LLM-assisted queries (for novel questions), while document stores place the full data-reasoning burden on the LLM — a task where LLMs consistently struggle.

---

## Three Architectures

### Baseline: Tool-Augmented LLM (65%)

```
User question
  → LLM parses intent → LLM selects tool → Tool queries document store
    → LLM interprets raw results → LLM synthesizes answer
```

The LLM handles intent parsing, tool selection, argument crafting, data interpretation, and answer synthesis. GPT-4 achieves 65%. Failures cluster around counting, cross-document correlation, and relationship traversal — data operations rather than reasoning failures.

### NLQ: LLM Generates Queries (83%)

```
User question
  → LLM generates Cypher (given schema)
    → Graph executes deterministically
      → LLM synthesizes answer from structured results
```

We **invert** the LLM's role: instead of broad data reasoning, ask it to generate a Cypher query from a typed schema. This is code generation — a task LLMs excel at. The graph handles traversal, counting, and algorithms deterministically.

### Deterministic: No LLM (99%)

```
User question
  → Keyword routing → Cypher query → Structured response
```

Pre-coded handlers for known patterns. A software engineering solution — demonstrates the ceiling with the right data model. 63ms average latency, zero token cost.

---

## The Inverted LLM Pattern

The key insight: **schema-aware query generation outperforms free-form data reasoning** for any structured domain.

- **Architecture A** asks: "LLM, answer this question from this data" (broad, error-prone)
- **Architecture B** asks: "LLM, given this schema, write a Cypher query" (narrow, plays to strengths)

The same LLM, given a sharper problem scoped to its strengths, produces dramatically better results. Code generation is an LLM strength; data traversal, counting, and relationship reasoning are graph strengths. Each system does what it's good at.

---

## Knowledge Graph Schema

**781 nodes, 955 edges, 11 labels, 16 edge types**

Built from the AssetOpsBench data sources via an 8-step ETL pipeline:

```
Site ─[CONTAINS_LOCATION]→ Location ─[CONTAINS_EQUIPMENT]→ Equipment ─[HAS_SENSOR]→ Sensor
                                                              │
                                           DEPENDS_ON / SHARES_SYSTEM_WITH
                                                              │
FailureMode ─[MONITORS]→ Equipment ─[EXPERIENCED]→ FailureMode
WorkOrder ─[FOR_EQUIPMENT]→ Equipment
WorkOrder ─[ADDRESSES]→ FailureMode
Anomaly ─[TRIGGERED]→ WorkOrder
Event ─[FOR_EQUIPMENT]→ Equipment
```

Key additions over the baseline document model:
- **Equipment dependencies**: `DEPENDS_ON` and `SHARES_SYSTEM_WITH` edges enable cascade analysis
- **Failure mode embeddings**: 384-dim Sentence-BERT vectors in HNSW index enable similarity search
- **Unified event timeline**: 6,256 events with ISO timestamps enable temporal queries

---

## AssetOpsBench 139 Scenarios — Per-Type Results

| Type | Count | Deterministic | NLQ (GPT-4o) | Baseline (GPT-4) |
| :--- | :--- | :--- | :--- | :--- |
| IoT | 20 | **20/20 (100%)** | 17/20 (85%) | — |
| FMSR | 40 | **40/40 (100%)** | 37/40 (93%) | — |
| TSFM | 23 | **23/23 (100%)** | 21/23 (91%) | — |
| Multi | 20 | **20/20 (100%)** | 8/20 (40%) | — |
| WO | 36 | 34/36 (94%) | 32/36 (89%) | — |
| **Total** | **139** | **137/139 (99%)** | **115/139 (83%)** | **~91/139 (65%)** |

NLQ Multi stays at 40% because 12/20 scenarios require TSFM pipeline execution (forecasting, anomaly detection) that cannot be expressed as Cypher queries — a structural limitation.

---

## Custom 40 Scenarios — Graph-Native Capabilities

40 new scenarios extending the benchmark with graph-native capabilities:

| Category | Count | GPT-4o Avg | Samyama Avg | Delta |
| :--- | :--- | :--- | :--- | :--- |
| Failure similarity | 6 | 0.501 | **0.902** | +0.401 |
| Criticality analysis | 5 | 0.566 | **0.938** | +0.372 |
| Root cause analysis | 5 | 0.580 | **0.934** | +0.354 |
| Multi-hop dependency | 8 | 0.618 | **0.934** | +0.316 |
| Maintenance optimization | 5 | 0.634 | **0.931** | +0.297 |
| Cross-asset correlation | 6 | 0.638 | **0.929** | +0.291 |
| Temporal pattern | 5 | 0.679 | **0.923** | +0.244 |

Largest gains on **failure similarity** (+0.401) and **criticality analysis** (+0.372) — exactly where graph structure and vector search provide the most value. GPT-4o's 6 failures all require graph traversal, PageRank, or vector search that LLMs cannot perform from parametric knowledge alone.

---

## The Full Pipeline: LLMs at the Edges, Graph in the Middle

The query layer comparison above is only part of the story. The full industrial data pipeline has three layers:

1. **Data Ingestion** (software engineering): Structured data (90%+) → deterministic ETL. Unstructured data (maintenance logs, PDFs) → LLM-assisted entity extraction, resolution, classification.
2. **Data Model** (architecture decision): One-time choice between flat documents and knowledge graph.
3. **Query** (LLM optional): Deterministic handlers for known patterns; LLM-generated Cypher for novel questions.

LLMs appear at both **edges** — data preparation (unstructured → structured) and query generation (natural language → Cypher). The graph is the **stable center** that receives data from both deterministic and LLM-assisted ingestion, and serves both deterministic and LLM-generated queries.

In both cases, the LLM performs a **generation task** (structured output from unstructured input) — its strength. The graph handles **data operations** (storage, traversal, algorithms) — its strength. Neither component is asked to do what it's bad at.

---

## Scalability

| Dimension | Arch. A (LLM + docs) | Arch. B/C (graph ± LLM) |
| :--- | :--- | :--- |
| 10K queries/day | $300–500 (tokens) | $0 (deterministic) or ~$30 (NLQ) |
| Real-time streaming | Not supported | Graph updates + continuous queries |
| Multi-hop at 10K assets | LLM reasons across 10K docs | BFS traversal, O(\|E\|) |
| Latency per query | 5–11 seconds | 63 ms (det.) / ~6 s (NLQ) |

---

## Honest Caveats

1. **Deterministic vs. autonomous**: The 99% result compares pre-coded answers against an autonomous agent — fundamentally different tasks. The comparison illustrates the ceiling achievable with the right data model, not a claim of superior agent intelligence.
2. **Model mismatch**: The baseline used GPT-4; NLQ used GPT-4o. The +18pp gap is an upper bound. Same-model comparison pending.
3. **Clean data**: AssetOpsBench provides clean, structured data. Real-world messy data needs LLM-assisted preparation.
4. **Custom scenarios**: Designed to extend the benchmark with graph-native capabilities, not replace the original scenarios.
5. **Complementary research questions**: AssetOpsBench evaluates LLM agent autonomy. We evaluate data model impact. Both are valid; our results do not diminish the value of the original benchmark.

---

## Conclusion

Building on AssetOpsBench, we show that introducing a knowledge graph as the data layer improves LLM-based industrial operations at every level of LLM involvement. For structured operational domains, the data model is the primary bottleneck. The inverted LLM pattern (schema-aware query generation instead of free-form data reasoning) is generalizable to any structured domain.

---

## Implementation

- **Benchmark code**: [samyama-ai/assetops-kg](https://github.com/samyama-ai/assetops-kg)
- **Graph database**: [samyama-ai/samyama-graph](https://github.com/samyama-ai/samyama-graph)
- **Rust demo**: `cargo run --example industrial_kg_demo` (871 lines)
- **Python SDK**: `pip install samyama` ([PyPI](https://pypi.org/project/samyama/))
- **Community PR**: [AssetOpsBench PR #203](https://github.com/IBM/AssetOpsBench/pull/203) — 40 new graph-native scenarios contributed back to the benchmark
