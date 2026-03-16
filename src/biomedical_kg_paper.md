# Research Paper: Open Biomedical Knowledge Graphs at Scale

We have published a research paper on constructing, federating, and querying biomedical knowledge graphs with Samyama.

**Title**: *Open Biomedical Knowledge Graphs at Scale: Construction, Federation, and AI Agent Access with Samyama Graph Database*

**Authors**: [Madhulatha Mandarapu](https://www.linkedin.com/in/madhulatha-mandarapu-72bb6b2a/) (madhulatha@samyama.ai), [Sandeep Kunkunuru](https://www.linkedin.com/in/sandeepkunkunuru/) (sandeep@samyama.ai)

March 2026 | [Pathways KG](https://github.com/samyama-ai/pathways-kg) | [Clinical Trials KG](https://github.com/samyama-ai/clinicaltrials-kg)

**Keywords**: Knowledge Graphs, Biomedical Data Integration, Graph Databases, Cross-KG Federation, Model Context Protocol, Clinical Trials, Biological Pathways, OpenCypher.

---

## Download PDF

- [Paper PDF](https://github.com/samyama-ai/samyama-graph-book/releases/latest/download/paper4_biomedical_kg.pdf) — arxiv-ready LaTeX version (10 pages)

---

## Abstract

Biomedical knowledge is fragmented across siloed databases — Reactome for pathways, STRING for protein interactions, Gene Ontology for functional annotations, ClinicalTrials.gov for study registries, and dozens more. We present two open-source biomedical knowledge graphs — **Pathways KG** (118,686 nodes, 834,785 edges from 5 sources) and **Clinical Trials KG** (7,711,965 nodes, 27,069,085 edges from 5 sources) — built on Samyama, a high-performance graph database written in Rust.

Our contributions are threefold:

1. **Reproducible KG construction** — ETL pipelines for two large-scale KGs using a common pattern: download, parse, deduplicate, batch-load via Cypher, and export as portable `.sgsnap` snapshots.

2. **Cross-KG federation** — loading both snapshots into a single graph tenant enables property-based joins across datasets, answering questions like "Which biological pathways are disrupted by drugs currently in Phase 3 trials for breast cancer?"

3. **Schema-driven MCP server generation** — each KG automatically exposes typed tools for LLM agents via the Model Context Protocol, enabling natural-language access without manual tool authoring.

The combined federated graph (7.83M nodes, 27.9M edges) loads in under 3 minutes on commodity hardware.

---

## Key Results

| Metric | Pathways KG | Clinical Trials KG | Combined |
|--------|------------:|-------------------:|---------:|
| Nodes | 118,686 | 7,711,965 | 7,830,651 |
| Edges | 834,785 | 27,069,085 | 27,903,870 |
| Labels | 5 | 15 | 20 |
| Edge types | 9 | 25 | 34 |
| Data sources | 5 | 5 | 10 |
| Snapshot size | 9 MB | 711 MB | 720 MB |
| Import time | < 5 s | ~90 s | ~95 s |

### Cross-KG Federation Query Patterns

| Pattern | Traversal | Latency |
|---------|-----------|---------|
| Drug → Pathway | Trial → Drug → Protein → Pathway | 2.5 s |
| Drug → GO Process | Trial → Drug → Protein → GOTerm | 1.8 s |
| Drug → PPI Network | Drug → Protein target → INTERACTS_WITH | 1.2 s |
| Disease → Pathway | Gene → Disease + Gene → Protein → Pathway | 1.8 s |
| Adverse Event → Pathway | Trial → AE → Drug → Protein → Pathway | 3.2 s |
