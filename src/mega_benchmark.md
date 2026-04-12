# Mega Benchmark: 500 Queries Across 10 Knowledge Graphs

**500 queries. 10 knowledge graphs. 138 million nodes. 1.22 billion edges. One graph, one query language, one server.**

Samyama Graph Enterprise v1.0.0 runs the full 500-query mega benchmark across ten independently-sourced knowledge graphs loaded into a single federated graph — on a single commodity EC2 spot instance.

## Headline

**455 / 500 pass (91.0%)** — up from 414/500 (82.8%) on v0.8.0.

- **+41 queries passing** vs v0.8.0 baseline
- **Engine errors cut from 28 → 9** (−68%)
- **13 of 14** previously-failing `IS NOT NULL AND` queries now pass (Cypher three-valued logic fix, PR #188)
- **Zero regressions** — all 9 remaining errors are pre-existing timeout/query-bug categories
- Load time **37 min** (−43% vs v0.8's 65 min)

## The Dataset

| Knowledge Graph | Source | Nodes | Edges | Key Entities |
|---|---|---:|---:|---|
| **PubMed/MEDLINE** | NLM | 66.2M | 1.04B | Article, Author, MeSHTerm, Chemical, Journal, Grant |
| **Clinical Trials** | AACT/ClinicalTrials.gov | 7.8M | 27M | ClinicalTrial, Intervention, AdverseEvent, Site, Sponsor |
| **Pathways** | Reactome | 119K | 835K | Protein, Pathway, Complex, Reaction, GOTerm |
| **Drug Interactions** | DrugBank, ChEMBL, SIDER, DGIdb | 245K | 388K | Drug, Gene, SideEffect, Indication, Bioactivity |
| **FAERS** | FDA Adverse Events | 10.4M | 90M | AdverseEventCase, Reaction, Drug, Outcome |
| **UniProt** | EBI | 618K | 3.9M | Protein, Organism, GOTerm |
| **OMOP** | MIMIC-IV (115K patients) | 51.9M | 54M | Person, Visit, ConditionOccurrence, DrugExposure, Measurement |
| **Surveillance** | WHO SPAR | 217K | 241K | Country, CapacityIndicator |
| **Health Determinants** | World Bank + WHO | 286K | 286K | Country, SocioeconomicIndicator, EnvironmentalFactor |
| **Health Systems** | WHO | 20K | 19K | Country, HealthWorkforce, VaccineCoverage |
| **NCT Bridge** | AACT study_references | — | 747K | REFERENCED_IN (Article → ClinicalTrial) |
| **Total** | | **137.7M** | **1.22B** | |

## Results by Prefix

| Prefix | Knowledge Graph | Queries | Pass | Empty | Error | Rate |
|---|---|---:|---:|---:|---:|---:|
| PM | PubMed | 35 | 34 | 1 | 0 | 97.1% |
| CT | Clinical Trials | 20 | 19 | 1 | 0 | 95.0% |
| PW | Pathways | 15 | 15 | 0 | 0 | **100%** |
| DI | Drug Interactions | 15 | 14 | 1 | 0 | 93.3% |
| XK | Cross-KG joins | 15 | 15 | 0 | 0 | **100%** |
| HD | Health Determinants | 20 | 20 | 0 | 0 | **100%** |
| HS | Health Systems | 10 | 10 | 0 | 0 | **100%** |
| PH | Public Health (cross-KG) | 10 | 10 | 0 | 0 | **100%** |
| EX | Expanded (PubMed-heavy) | 60 | 56 | 1 | 3 | 93.3% |
| UP | UniProt | 25 | 25 | 0 | 0 | **100%** |
| FA | FAERS | 30 | 28 | 1 | 1 | 93.3% |
| OM | OMOP | 30 | 28 | 1 | 1 | 93.3% |
| MB | Mega Benchmark (multi-KG) | 215 | 181 | 30 | 4 | 84.2% |
| **Total** | | **500** | **455** | **36** | **9** | **91.0%** |

Six prefixes hit **100%** including all three cross-KG categories (XK, PH, and the public-health cross-KG set).

## The Cypher 3VL Fix

Fourteen queries in v0.8.0 errored on patterns like:

```cypher
MATCH (p:Protein)
WHERE p.gene_name IS NOT NULL AND p.gene_name CONTAINS "kinase"
RETURN p
```

Prior to v1.0.0, the `IS NOT NULL AND <bool>` combination failed type-checking because `NULL AND false` was not short-circuited per Cypher's three-valued logic spec. The fix (PR #188) implements proper three-valued logic for `AND`/`OR`:

| Query | v0.8.0 | v1.0.0 |
|---|---|---|
| UP11, UP13, UP14, UP22, UP23, UP24 | error | **pass** |
| MB060, MB117, MB157, MB158, MB159, MB160, MB182 | error | **pass** |
| MB153 | error | empty (data artifact, query runs clean) |

## Remaining 9 Errors

All 9 errors are **pre-existing v0.8 categories** — no new failure modes introduced in v1.0:

| Queries | Category |
|---|---|
| EX05, EX06, EX49, FA14, MB049, MB053, MB054, MB111 | Query timeout (>120s) on PubMed/FAERS full-scans |
| OM27 | `NOT requires boolean` — query-side null-guard bug |

The 8 timeouts are candidates for parallel-scan or query-rewrite fixes in v1.1.

## Infrastructure

| | |
|---|---|
| **Instance** | r7i.16xlarge (64 vCPU, 495 GB RAM) |
| **Region** | AWS ap-south-1 (Mumbai), spot pricing |
| **Disk** | 500 GB gp3 |
| **Peak memory** | ~299 GB (60% utilization) |
| **Load time** | 36.8 min (10 snapshots + NCT bridge + 43 indexes) |
| **Query runtime** | 32 min |
| **Total runtime** | 130 min |
| **Build** | SGE `main` @ 0a6fe7b (post PR #169 / #188) |

## Version Progression

| Version | Pass | Rate | Δ | Key Improvements |
|---|---:|---:|---:|---|
| v0.7.x | 383/500 | 76.6% | — | baseline |
| v0.8.0 | 414/500 | 82.8% | +31 | WITH push-down, DS-07c edge arena removal |
| **v1.0.0** | **455/500** | **91.0%** | **+41** | MVCC, Cypher 3VL, version GC, edge COW |

## Reproducing

```bash
# On r7i.16xlarge ap-south-1, AMI ami-0d219aaceb19e2c84
./target/release/examples/unified_benchmark \
  --pubmed-snap ~/snapshots/pubmed-v2.sgsnap \
  --ct-snap ~/snapshots/clinical-trials.sgsnap \
  --pw-snap ~/snapshots/pathways.sgsnap \
  --faers-snap ~/snapshots/faers-full.sgsnap \
  --uniprot-snap ~/snapshots/uniprot.sgsnap \
  --omop-snap ~/snapshots/omop-115k.sgsnap \
  --di-snap ~/snapshots/druginteractions.sgsnap \
  --surv-snap ~/snapshots/surveillance.sgsnap \
  --hd-snap ~/snapshots/health-determinants.sgsnap \
  --hs-snap ~/snapshots/health-systems.sgsnap \
  --study-refs ~/study_references.txt \
  --queries ~/benchmark-queries
```

Snapshots are public at `s3://samyama-data/snapshots/`. Query CSVs live in this repo under `src/data/benchmark/`. Raw run output: [`benchmark-v100-results.csv`](./data/benchmark/benchmark-v100-results.csv).

---

*Run: 2026-04-12. Instance stopped post-run.*
