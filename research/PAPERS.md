# Samyama Research Papers — Tracker

## arXiv Papers

| # | Title | arxiv ID | Date | Status | File |
|---|-------|----------|------|--------|------|
| 1 | Samyama: A Unified Graph-Vector Database with In-Database Optimization, Agentic Enrichment, and Hardware Acceleration | [2603.08036](https://arxiv.org/abs/2603.08036) | 2026-03-09 (v1), 2026-03-10 (v2) | Published | `arxiv/samyama.tex` |
| 3 | Knowledge Graphs as the Missing Data Layer for LLM-Based Industrial Asset Operations | — | — | Draft ready, not yet submitted | `arxiv/paper3_industrial_kg.tex` |
| 4 | Open Biomedical Knowledge Graphs at Scale: Construction, Federation, and AI Agent Access | [2603.15080](https://arxiv.org/abs/2603.15080) | 2026-03-17 (v1) | Published. v2 (adds Drug Interactions KG + BiomedQA) ready to replace | `arxiv/paper4_biomedical_kg.tex` |

## SIGMOD/PODS 2026 Workshop Papers (Bengaluru, India)

| # | Workshop | Title | Submission ID | Submitted | Deadline | Notification | Status | File |
|---|----------|-------|---------------|-----------|----------|-------------|--------|------|
| 5 | GRADES-NDA (June 5) | [Demo] Federated Biomedical Knowledge Graphs: Graph-Native Storage, Planning, and AI-Agent Integration | Paper 23 (CMT3) | 2026-03-16 | 2026-03-17 | 2026-04-13 | Submitted | `arxiv/paper5_grades_nda_2026.tex` |
| 6 | aiDM (May 31) | Domain-Specific MCP Tools vs. Generic Text-to-Cypher: How Graph Databases Become the Data Layer for AI Agents | Submission 2 (EasyChair) | 2026-03-17 | 2026-03-30 | 2026-04-24 | Submitted | `arxiv/paper6_aidm_2026.tex` |

## Key Dates

| Date | Event |
|------|-------|
| 2026-04-13 | GRADES-NDA notification |
| 2026-04-24 | aiDM notification |
| 2026-04-26 | GRADES-NDA camera-ready (if accepted) |
| 2026-05-04 | aiDM camera-ready (if accepted) |
| 2026-05-31 | aiDM workshop (SIGMOD, Bengaluru) |
| 2026-06-05 | GRADES-NDA workshop (SIGMOD, Bengaluru) |

## Benchmarks Cited

| Benchmark | Paper(s) | Results | Hardware |
|-----------|----------|---------|----------|
| AssetOpsBench (IBM 139 + Custom 40) | Papers 3, 6 | MCP 99%, Text-to-Cypher 83%, GPT-4 65% | Mac Mini M4 |
| BiomedQA (40 pharmacology questions) | Papers 4, 5, 6 | MCP 98% (39/40), Text-to-Cypher 0%, GPT-4o 75% | AWS g4dn.4xlarge (62GB, A10G) |

## Notes

- **Paper 4 v2**: Tarball ready (`paper4-biomedical-kg-arxiv-v2.tar.gz`). Adds Drug Interactions KG, BiomedQA benchmark, AWS VM evaluation. Replace on arxiv when processing error clears.
- **Paper 3**: Not yet on arxiv. Could submit independently or fold into paper 4.
- **Paper 5 (GRADES-NDA)**: Anonymous version submitted. Updated PDF with corrected citations should be re-uploaded to CMT3.
- **Paper 6 (aiDM)**: Anonymous version submitted. Self-citation anonymized for double-blind.
- **Citation audit**: Papers 5 and 6 had hallucinated citations fixed (2026-03-17). Key fixes: Bio2RDF author/year, AssetOpsBench arxiv ID, DIN-SQL/Spider year corrections.
