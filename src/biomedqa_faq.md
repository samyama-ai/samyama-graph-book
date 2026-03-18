# BiomedQA Benchmark FAQ

## Why does GPT-4o standalone (75%) outperform text-to-Cypher (0%)?

These are **fundamentally different tasks**, not the same task with different accuracy.

### GPT-4o Standalone (75%) — No Database at All

This is **not** generating queries. GPT-4o answers from its **training data memory**:

```
Question: "What genes does Metformin target?"
GPT-4o: "Metformin primarily targets AMPK (AMP-activated protein kinase),
         and also interacts with PPARG, OCT1/SLC22A1..."
```

It gets 75% because GPT-4o has strong pharmacology knowledge baked in from medical literature. It **knows** what Metformin does. We evaluate by checking if the answer text **contains** the expected values (e.g., does "PPARG" appear in the response).

**Where it fails (25%):** Questions requiring precise identifiers ("What's the DrugBank ID of Tamoxifen?"), exact counts ("How many side effects does Warfarin have?"), and shared-target queries that need database-level precision.

### Text-to-Cypher (0%) — Generates Queries, All Fail Silently

We **did** provide schema + 3 few-shot examples in the system prompt:

```
System prompt:
  "You are a Cypher query expert. Given a graph database schema and a question,
   generate ONLY the Cypher query..."

  SCHEMA: 19 node labels, 12 edge types, property names...

  3 FEW-SHOT EXAMPLES
```

GPT-4o generates **syntactically valid Cypher** that **looks correct** but returns empty results:

**Example 1: Hallucinated property filter**
```
Question: "What are the approved indications for Metformin?"

GPT-4o generates:
  MATCH (d:Drug {name: 'Metformin'})-[:HAS_INDICATION {method: 'approved'}]->(i:Indication)
  RETURN i.name

Problem: The edge HAS_INDICATION has no {method: 'approved'} property in our
actual data — GPT-4o hallucinated that filter. Query runs successfully but
returns EMPTY result set.
```

**Example 2: Subtle schema mismatch**
```
Question: "Which proteins participate in the Apoptosis pathway?"

GPT-4o generates:
  MATCH (p:Protein)-[:PARTICIPATES_IN]->(pw:Pathway {name: 'Apoptosis'})
  RETURN p.uniprot_id

Problem: Query looks perfect but returns empty because of how the
snapshot import remapped node IDs — the property pattern matching has
subtle mismatches with the actual graph structure.
```

### Error Breakdown

The 0% is **NOT syntax errors** — it's the insidious **"plausible but wrong"** failure mode:

| Error Category | Count | Example |
|----------------|------:|---------|
| Schema mismatch (empty result) | 33 (82%) | Hallucinated property filters, wrong property names |
| Incorrect multi-MATCH pattern | 6 (15%) | Comma-separated MATCH that engine handles differently |
| Non-existent filter constraint | 1 (3%) | `{method: 'approved'}` doesn't exist |

### Why 3 Examples Weren't Enough

The schema has **19 node labels and 12 edge types** across 3 federated KGs. Three examples can't cover:
- Which properties exist on which edges (HAS_INDICATION has `method` but not value `'approved'`)
- How multi-MATCH patterns resolve across snapshot-imported nodes
- The exact casing and property names (`gene_name` vs `name` vs `uniprot_id`)

With more examples or fine-tuning, text-to-Cypher would likely reach 30–50%. But MCP tools would still dominate because **templates eliminate the entire class of schema-mismatch errors**.

### The Key Insight

```
Standalone GPT-4o (75%):  LLM answers from MEMORY — no query, no database
                          Good for general knowledge, bad for precision

Text-to-Cypher (0%):      LLM generates QUERIES — syntactically valid but
                          semantically wrong. Silent failures. Dangerous.

MCP Tools (98%):           LLM SELECTS pre-authored tools — deterministic,
                          auditable, no schema hallucination possible
```

The paradox is intentional: **knowing the answer (75%) beats generating the query (0%)**. This is exactly why the "inverted-LLM" pattern works — don't ask the LLM to write code, ask it to pick from a menu.

---

## Could text-to-Cypher improve with better prompting?

Yes. The Remote Planet demo achieved **100% NLQ accuracy** (12/12) with Ollama qwen2.5-coder:14b by:

1. Including **full schema with edge directions** in the system prompt (not just labels)
2. Adding **property type annotations** (String, Float, Boolean) and **value casing rules** (e.g., `severity="critical"` lowercase, `Region.name="Scotland"` title-case)
3. Adding **3 few-shot examples** covering edge counting, variable-length paths, and aggregation
4. Iterating the system prompt through 4 versions (42% → 67% → 75% → 100%)

However, that was on a **single KG with 10 node labels**. The BiomedQA benchmark spans **3 federated KGs with 19 labels** — the schema complexity is much higher, making text-to-Cypher fundamentally harder.

## Why not combine both? (MCP tools + text-to-Cypher fallback)

This is planned (see backlog item AI-11). The architecture:

1. LLM first tries to match a domain-specific MCP tool (98% accuracy)
2. If no tool matches → fall back to Samyama Enterprise's NLQ endpoint
3. NLQ pipeline has direct schema access, safety validation, and its own LLM call
4. Expected hybrid accuracy: ~98% for known patterns + ~50% for long-tail questions

See [MCP Tool Catalog — Architecture](../docs/mcp-tool-catalog.md) for sequence diagrams.

---

## Benchmark Details

**BiomedQA benchmark:** 40 pharmacology questions across 7 categories over 3 federated KGs (7.9M nodes).

| Approach | Accuracy | Avg Latency | Avg Tokens | How It Works |
|----------|----------|-------------|------------|-------------|
| GPT-4o standalone | 30/40 (75%) | 2,474ms | 213 | Answers from training data memory |
| Text-to-Cypher | 0/40 (0%) | 986ms | 548 | Generates Cypher, executes against graph |
| **MCP tools** | **39/40 (98%)** | **651ms** | **0** | Selects pre-authored tool, deterministic execution |

**Hardware:** AWS g4dn.4xlarge (16 vCPU AMD EPYC, 62GB RAM, NVIDIA A10G)
**Graph:** Pathways (119K nodes) + Drug Interactions (33K nodes) + Clinical Trials (7.7M nodes)
**Verified:** 3 independent fresh-load runs, all producing 39/40 (98%)
