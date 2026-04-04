# Samyama Research Papers — Tracker

*Updated: 2026-04-04*

## arxiv Preprints

| # | Title | arxiv ID | Status | File |
|---|-------|----------|--------|------|
| 1 | Samyama: A Unified Graph-Vector Database with In-Database Optimization, Agentic Enrichment, and Hardware Acceleration | [2603.08036](https://arxiv.org/abs/2603.08036) v2 | Published. **v3 in preparation** — add 1B-edge results, WCO joins, parallel algorithms, public health KGs | `arxiv/samyama.tex` |
| 4 | Open Biomedical Knowledge Graphs at Scale: Construction, Federation, and AI Agent Access | [2603.15080](https://arxiv.org/abs/2603.15080) v1 | Published. v2 ready (Drug Interactions 5-source, BiomedQA 98%/85%/75%) | `arxiv/paper4_biomedical_kg.tex` |
| 7 | Scaling Knowledge Graph Federation to One Billion Edges on Commodity Hardware | — | **In preparation.** 74M nodes, 1B edges, 6-KG federation, 140 queries, $2.50 cost | `arxiv/paper7_billion_edge.tex` (TBD) |

## SIGMOD 2026 Workshop Papers (Bengaluru, India)

| # | Workshop | Title | Submission | Notification | Status | File |
|---|----------|-------|------------|-------------|--------|------|
| 5 | GRADES-NDA (Jun 5) | [Demo] Federated Biomedical Knowledge Graphs | CMT3 #23 | **Apr 13** | Submitted | `arxiv/paper5_grades_nda_2026.tex` |
| 6 | aiDM (May 31) | Domain-Specific MCP Tools vs. Generic Text-to-Cypher | EasyChair #2 | **Apr 24** | Submitted (needs re-upload with updated numbers) | `arxiv/paper6_aidm_2026.tex` |

## Conference Targets (Full Papers)

| # | Venue | Title | Deadline | Status | File |
|---|-------|-------|----------|--------|------|
| 3 | **NeurIPS 2026 E&D** | Knowledge Graphs for Industrial Asset Operations (AssetOpsBench) | **May 6, 2026** | Draft ready, IBM alignment pending | `arxiv/paper3_industrial_kg.tex` |
| — | **VLDB 2027 Industry** | Samyama: Unified Graph-Vector Database (extends Paper 1) | ~Apr 2027 (rolling) | In preparation (62KB draft) | `vldb/samyama-vldb.tex` |

## Key Dates

| Date | Event |
|------|-------|
| **2026-04-13** | GRADES-NDA notification (Paper 5) |
| **2026-04-24** | aiDM notification (Paper 6) |
| 2026-04-26 | GRADES-NDA camera-ready |
| **2026-05-04** | NeurIPS E&D abstract deadline (Paper 3) |
| **2026-05-06** | NeurIPS E&D full paper deadline (Paper 3) |
| 2026-05-31 | aiDM workshop @ SIGMOD Bengaluru |
| 2026-06-05 | GRADES-NDA workshop @ SIGMOD Bengaluru |
| 2026-09-24 | NeurIPS E&D notification |
| ~2026-11 | SIGMOD 2027 Demo Track deadline |
| ~2027-04 | VLDB 2027 Industry Track |

## Paper 1 → arxiv v3: What to Add

Current v2 was written at v0.6.0. New results since then:

| Addition | Section | Impact |
|----------|---------|--------|
| 1B-edge biomedical trifecta (74M nodes, $2.50) | Evaluation | 10x scale increase |
| WCO TrieJoin for cyclic patterns (triangles, cliques) | Query Engine | New algorithmic contribution |
| Rayon parallel graph algorithms | Algorithms | Performance improvement |
| Edge stub memory optimization (24GB savings) | Storage | Engineering contribution |
| Public health KG trifecta (305K nodes, 40/40 queries) | KG Catalog | New domain |
| 6-KG federation architecture | Federation | Unique story |
| v0.7.0 version bump (2003 tests, 87.8% coverage) | Throughout | Credibility |

## Paper 7: Standalone arxiv Preprint

**Title:** Scaling Knowledge Graph Federation to One Billion Edges on Commodity Hardware

**Thesis:** Open-source graph database + open data sources + commodity hardware = billion-edge cross-domain knowledge graph federation accessible to any research group.

**Key numbers:** 74.3M nodes, 1.07B edges, 8 KGs, 140 benchmark queries, 136/140 pass, $2.50 AWS spot cost.

**Outline:** See `src/paper7_billion_edge_federation.md` in samyama-graph-book.

## Benchmarks

| Benchmark | Papers | Final Results | Hardware |
|-----------|--------|---------------|----------|
| LDBC SNB Interactive (21/21) | 1, VLDB | All pass, SF1 | Mac Mini M4 |
| LDBC Graphalytics (28/28) | 1, VLDB | All pass, XS-S | Mac Mini M4 |
| LDBC FinBench (40/40) | 1, VLDB | All pass | Mac Mini M4 |
| AssetOpsBench (139 scenarios) | 3, 6 | MCP 99%, T2C 83%, GPT-4 65% | Mac Mini M4 |
| BiomedQA (40 questions) | 4, 5, 6 | MCP 98%, T2C 85%, GPT-4o 75% | AWS g4dn.4xlarge |
| **Biomedical 100-query** (74M nodes, 1B edges) | **7**, VLDB | 96/100 pass | AWS r6a.8xlarge |
| **Public Health 40-query** (305K nodes) | **7** | 40/40 pass | MacBook Pro |
| Cricket 100-query (37K nodes) | 1 | 87/100 | Mac Mini M4 |

## Notes

- **Paper 4 v2**: Drug Interactions KG added, BiomedQA numbers corrected. Tarball ready. Upload when arxiv processing clears.
- **Paper 6 (aiDM)**: Anonymous version needs re-upload to EasyChair with updated BiomedQA numbers + error categorization table.
- **Paper 5 (GRADES-NDA)**: Some old BiomedQA numbers remain. Update if possible before notification.
- **Paper 3 (NeurIPS)**: Requires Croissant metadata, HuggingFace/Kaggle hosting, OpenReview profile. IBM co-authorship pending.
- **Citation audit**: Papers 5/6 had hallucinated citations fixed (2026-03-17).
