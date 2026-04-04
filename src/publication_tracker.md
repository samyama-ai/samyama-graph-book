# Publication Tracker

*Updated: 2026-04-04*

## All Papers

| # | Title | Venue / Target | arxiv | Status | Deadline | File |
|---|-------|---------------|-------|--------|----------|------|
| 1 | Samyama: Unified Graph-Vector Database | **arxiv** (preprint) → VLDB 2027 | [2603.08036](https://arxiv.org/abs/2603.08036) v2 | Published. **v3 in preparation** (1B-edge results) | Anytime | `research/arxiv/samyama.tex` |
| 3 | Knowledge Graphs for Industrial Asset Operations | **NeurIPS 2026 E&D** | Not yet | Draft ready, IBM alignment pending | **May 6, 2026** | `research/arxiv/paper3_industrial_kg.tex` |
| 4 | Open Biomedical Knowledge Graphs at Scale | **arxiv** (preprint) → VLDB/ICDE 2027 | [2603.15080](https://arxiv.org/abs/2603.15080) v1 | Published. v2 ready (Drug Interactions KG, BiomedQA 98%) | Anytime | `research/arxiv/paper4_biomedical_kg.tex` |
| 5 | Federated Biomedical KGs [Demo] | **GRADES-NDA @ SIGMOD 2026** | — | Submitted (CMT3 #23) | Notification **Apr 13** | `research/arxiv/paper5_grades_nda_2026.tex` |
| 6 | MCP Tools vs Text-to-Cypher | **aiDM @ SIGMOD 2026** | — | Submitted (EasyChair #2) | Notification **Apr 24** | `research/arxiv/paper6_aidm_2026.tex` |
| 7 | Billion-Edge KG Federation on Commodity Hardware | **arxiv** (preprint) → VLDB 2027 | Not yet | **In preparation** | — | `research/arxiv/paper7_billion_edge.tex` |
| — | VLDB 2027 Systems Paper | **VLDB 2027 Industry Track** | — | In preparation (extends Paper 1) | ~Apr 2027 (rolling) | `research/vldb/samyama-vldb.tex` |

## Key Dates

| Date | Event |
|------|-------|
| **2026-04-13** | GRADES-NDA notification (Paper 5) |
| **2026-04-24** | aiDM notification (Paper 6) |
| 2026-04-26 | GRADES-NDA camera-ready (if accepted) |
| **2026-05-04** | aiDM camera-ready (if accepted) |
| **2026-05-06** | NeurIPS E&D full paper deadline (Paper 3) |
| 2026-05-31 | aiDM workshop @ SIGMOD Bengaluru |
| 2026-06-05 | GRADES-NDA workshop @ SIGMOD Bengaluru |
| 2026-09-24 | NeurIPS E&D notification |
| ~2026-11 | SIGMOD 2027 Demo Track deadline (Picasso+++) |
| ~2027-04 | VLDB 2027 rolling deadline |

## Benchmarks Referenced in Papers

| Benchmark | Papers | Results | Hardware |
|-----------|--------|---------|----------|
| LDBC SNB Interactive (21/21) | 1, VLDB | All pass, SF1 | Mac Mini M4 |
| LDBC Graphalytics (28/28) | 1, VLDB | All pass, XS-S | Mac Mini M4 |
| LDBC FinBench (40/40) | 1, VLDB | All pass | Mac Mini M4 |
| AssetOpsBench (139 scenarios) | 3, 6 | MCP 99%, T2C 83%, GPT-4 65% | Mac Mini M4 |
| BiomedQA (40 questions) | 4, 5, 6 | MCP 98%, T2C 85%, GPT-4o 75% | AWS g4dn.4xlarge |
| Biomedical 100-query (74M nodes, 1B edges) | **7**, VLDB | 96/100 pass | AWS r6a.8xlarge |
| Public Health 40-query (305K nodes) | **7** | 40/40 pass | MacBook Pro |
| Cricket 100-query (37K nodes) | 1 | 87/100 | Mac Mini M4 |
