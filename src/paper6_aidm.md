# Paper 6: MCP Tools vs Text-to-Cypher — aiDM @ SIGMOD 2026

**Title:** *Domain-Specific MCP Tools vs. Generic Text-to-Cypher: How Graph Databases Become the Data Layer for AI Agents*

**Venue:** aiDM Workshop at SIGMOD 2026, Bengaluru, India (May 31, 2026)

**Status:** Submitted (EasyChair Submission #2, 2026-03-17). Notification: **April 24, 2026**.

**Authors:** Madhulatha Mandarapu, Sandeep Kunkunuru

## Summary

Empirical comparison of three approaches for LLM access to knowledge graphs: (1) domain-specific MCP tools with Cypher templates, (2) generic text-to-Cypher via schema-aware prompting, and (3) raw LLM with no graph access. Evaluated on two benchmarks across biomedical and industrial domains.

## Key Results

| Approach | AssetOpsBench (139) | BiomedQA (40) |
|----------|---|---|
| MCP Tools | **99%** | **98%** |
| Text-to-Cypher (NLQ) | 83% | 85% |
| GPT-4/4o standalone | 65% | 75% |

The "inverted LLM" thesis: structured data + deterministic tools outperforms unstructured LLM reasoning on domain-specific factual questions.

## Files

- LaTeX: `research/arxiv/paper6_aidm_2026.tex`
- PDF: `research/arxiv/paper6_aidm_2026.pdf`
- Anonymous version: `research/arxiv/paper6_aidm_2026_anonymous.pdf`
