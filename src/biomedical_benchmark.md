# Biomedical Knowledge Graph Benchmark

Samyama's biomedical benchmark demonstrates cross-knowledge-graph queries across 74 million nodes and 1.07 billion edges — four real-world datasets unified in a single queryable graph.

## The Trifecta + DrugBank

| Knowledge Graph | Source | Nodes | Edges | Labels | Edge Types |
|---|---|---|---|---|---|
| **PubMed/MEDLINE** | NLM | 66.2M | 1.04B | Article, Author, MeSHTerm, Chemical, Journal, Grant | AUTHORED_BY, ANNOTATED_WITH, MENTIONS_CHEMICAL, PUBLISHED_IN, CITES, FUNDED_BY |
| **Clinical Trials** | AACT/ClinicalTrials.gov | 7.8M | 27M | ClinicalTrial, Intervention, AdverseEvent, Site, Outcome, Sponsor, Condition | TESTS, REPORTED, CONDUCTED_AT, MEASURES, SPONSORED_BY, STUDIES |
| **Pathways** | Reactome | 119K | 835K | Protein, Pathway, Complex, Reaction, GOTerm | INTERACTS_WITH, PARTICIPATES_IN, CATALYZES, REGULATES, COMPONENT_OF |
| **Drug Interactions** | DrugBank | 33K | 189K | Drug, Gene, SideEffect, Indication | HAS_SIDE_EFFECT, INTERACTS_WITH_GENE, HAS_INDICATION |
| **NCT Bridge** | AACT study_references | — | 1M+ | — | REFERENCED_IN (Article → ClinicalTrial) |
| **Total** | | **74.1M** | **1.07B** | | |

## Infrastructure

- **Instance:** r6a.8xlarge (32 vCPU, 256 GB RAM, AMD EPYC)
- **Cost:** ~$2.50 (AWS spot)
- **Import time:** 31 minutes from v2 snapshots
- **NCT bridge:** 1,018,483 edges created in 109 seconds

## Query Categories

### Point Lookups (PubMed)

```cypher
-- PM01: Find an article by PMID
MATCH (a:Article) WHERE a.pmid = '12345678'
RETURN a.pmid, a.title, a.pub_year
```
**Result:** "Denpasar Declaration on Population and Development" (1994) — **19.2s**

```cypher
-- PM02: Another article lookup
MATCH (a:Article) WHERE a.pmid = '25000000'
RETURN a.pmid, a.title
```
**Result:** "How to measure technology assessment: an introduction" — **1.4s**

### 1-Hop Traversals (PubMed)

```cypher
-- PM06: Who wrote this article?
MATCH (a:Article)-[:AUTHORED_BY]->(au:Author)
WHERE a.pmid = '25000000'
RETURN au.name
```
**Result:** Arie Hasman — **1.4s**

```cypher
-- PM07: What is this article about?
MATCH (a:Article)-[:ANNOTATED_WITH]->(m:MeSHTerm)
WHERE a.pmid = '25000000'
RETURN m.name
```
**Result:** Medical Informatics, Technology Assessment, Health Information Systems, Consumer Behavior, Attitude of Health Personnel — **1.4s** (6 rows)

```cypher
-- PM09: Where was this published?
MATCH (a:Article)-[:PUBLISHED_IN]->(j:Journal)
WHERE a.pmid = '25000000'
RETURN j.title
```
**Result:** Studies in health technology and informatics — **1.4s**

### Multi-Hop Analytics (PubMed)

```cypher
-- PM19: What topics co-occur with cancer research?
MATCH (m1:MeSHTerm)<-[:ANNOTATED_WITH]-(a:Article)-[:ANNOTATED_WITH]->(m2:MeSHTerm)
WHERE m1.name = 'Neoplasms' AND m1 <> m2
RETURN m2.name, count(a) AS cnt ORDER BY cnt DESC LIMIT 10
```
**Result:** Humans (513,845), Female (138,966), Animals (127,482), Male (117,695), Middle Aged (72,280) — **19s** across 1B edges

### Clinical Trials

```cypher
-- CT01: What drugs are being tested?
MATCH (t:ClinicalTrial)-[:TESTS]->(i:Intervention)
RETURN t.nct_id, i.name LIMIT 10
```
**Result:** NCT03092076→Ticagrelor, NCT03391063→Polyamide — **1.9s**

```cypher
-- CT02: What adverse events are reported?
MATCH (t:ClinicalTrial)-[:REPORTED]->(ae:AdverseEvent)
RETURN t.nct_id, ae.term LIMIT 10
```
**Result:** NCT02028182→Pruritus, NCT03790111→Nausea, Hypertension, Fatigue — **1.6s**

### Pathways (Reactome)

```cypher
-- PW05: Largest biological pathways
MATCH (prot:Protein)-[:PARTICIPATES_IN]->(p:Pathway)
RETURN p.name, count(prot) AS proteins ORDER BY proteins DESC LIMIT 10
```
**Result:** Signal Transduction (2,614), Disease (2,575), Immune System (2,330), Metabolism (2,216) — **1.9s**

### Drug Interactions (DrugBank)

```cypher
-- DI01: What are the side effects of Bivalirudin?
MATCH (d:Drug)-[:HAS_SIDE_EFFECT]->(se:SideEffect)
RETURN d.name, se.name LIMIT 10
```
**Result:** Bivalirudin → Abdominal pain, Anaemia, Anxiety, Atrial fibrillation — **1.4s**

---

## Cross-Knowledge-Graph Queries

These queries traverse `REFERENCED_IN` edges connecting PubMed articles to clinical trials via PMID↔NCT ID mapping.

### What drugs are tested in cancer research trials?

```cypher
-- XK02: MeSH → Article → Trial → Intervention (3 KGs)
MATCH (m:MeSHTerm)<-[:ANNOTATED_WITH]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:TESTS]->(i:Intervention)
WHERE m.name = 'Neoplasms'
RETURN i.name, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Intervention | Trials |
|---|---|
| Placebo | 521 |
| **Pembrolizumab** | **137** |
| Carboplatin | 106 |
| Paclitaxel | 106 |
| Cyclophosphamide | 98 |

**Time: 29s** — Pembrolizumab (Keytruda) is the most-tested non-placebo cancer drug.

### What drugs are tested in diabetes research trials?

```cypher
-- XK03: Same pattern, different disease
MATCH (m:MeSHTerm)<-[:ANNOTATED_WITH]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:TESTS]->(i:Intervention)
WHERE m.name = 'Diabetes Mellitus'
RETURN i.name, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Intervention | Trials |
|---|---|
| Placebo | 324 |
| **Metformin** | **70** |
| Usual care | 50 |
| Insulin | 25 |
| Exercise | 23 |

**Time: 3.5s** — Metformin dominates diabetes trials. Exercise appears as a non-drug intervention.

### What adverse events appear in heart disease trials?

```cypher
-- XK04: MeSH → Article → Trial → AdverseEvent
MATCH (m:MeSHTerm)<-[:ANNOTATED_WITH]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:REPORTED]->(ae:AdverseEvent)
WHERE m.name = 'Heart Diseases'
RETURN ae.term, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Adverse Event | Trials |
|---|---|
| Headache | 60 |
| Nausea | 56 |
| Syncope | 51 |
| Pneumonia | 49 |

**Time: 2.1s**

### Which trials reference articles about Aspirin?

```cypher
-- XK05: Chemical → Article → Trial
MATCH (c:Chemical)<-[:MENTIONS_CHEMICAL]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)
WHERE c.name = 'Aspirin'
RETURN t.nct_id, a.title LIMIT 10
```

**Result:** NCT00000491 "An intervention study—the aspirin myocardial infarction study" — **1.5s**

### What adverse events appear in Metformin-linked trials?

```cypher
-- XK06: Chemical → Article → Trial → AdverseEvent (4 entities)
MATCH (c:Chemical)<-[:MENTIONS_CHEMICAL]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:REPORTED]->(ae:AdverseEvent)
WHERE c.name = 'Metformin'
RETURN ae.term, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Adverse Event | Trials |
|---|---|
| Headache | 215 |
| Nausea | 207 |
| Nasopharyngitis | 186 |
| **Diarrhoea** | **185** |
| Vomiting | 157 |

**Time: 2.1s** — Diarrhoea is a known Metformin side effect, confirmed by traversing PubMed→ClinicalTrials.gov.

### Where are cancer trials conducted?

```cypher
-- XK07: MeSH → Article → Trial → Site
MATCH (m:MeSHTerm)<-[:ANNOTATED_WITH]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:CONDUCTED_AT]->(s:Site)
WHERE m.name = 'Neoplasms'
RETURN s.country, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Country | Trials |
|---|---|
| **United States** | **4,062** |
| China | 1,170 |
| France | 827 |
| Canada | 786 |
| Italy | 760 |

**Time: 14s**

### What drugs does NCI fund?

```cypher
-- XK08: Grant → Article → Trial → Intervention (4 entities)
MATCH (g:Grant)<-[:FUNDED_BY]-(a:Article)
      -[:REFERENCED_IN]->(t:ClinicalTrial)-[:TESTS]->(i:Intervention)
WHERE g.agency = 'NCI NIH HHS'
RETURN i.name, count(DISTINCT t) AS trials ORDER BY trials DESC LIMIT 10
```

| Intervention | NCI-funded Trials |
|---|---|
| Placebo | 933 |
| **Laboratory biomarker analysis** | **614** |
| Cyclophosphamide | 517 |
| Radiation therapy | 362 |
| Carboplatin | 338 |

**Time: 20s** — Lab biomarker analysis is the second most common "intervention" in NCI trials, reflecting the emphasis on precision medicine.

### How many articles link to trials?

```cypher
-- XK09: Count cross-KG links
MATCH (a:Article)-[:REFERENCED_IN]->(t:ClinicalTrial)
RETURN count(DISTINCT a)
```

**Result: 747,505 articles** — **99s**

---

## Performance Summary

| Query Type | Count | Avg Time | Range |
|---|---|---|---|
| Point lookups | 2 | 10.3s | 1.4-19.2s |
| 1-hop traversals | 6 | 1.5s | 1.3-1.9s |
| Multi-hop PubMed | 1 | 19s | 19s |
| Clinical Trials | 3 | 1.7s | 1.4-1.9s |
| Pathways | 2 | 1.7s | 1.4-1.9s |
| Drug Interactions | 2 | 1.5s | 1.3-1.5s |
| Cross-KG (targeted) | 8 | 9.1s | 1.5-29.4s |
| Cross-KG (count) | 1 | 99s | 99s |
| **Total verified** | **25** | | |

## Query Files

The full query catalog is in CSV format for automated benchmarking:

- [`pubmed-queries.csv`](data/benchmark/pubmed-queries.csv) — 35 PubMed queries
- [`clinical-trials-queries.csv`](data/benchmark/clinical-trials-queries.csv) — 20 Clinical Trials queries
- [`pathways-queries.csv`](data/benchmark/pathways-queries.csv) — 15 Pathways queries
- [`drug-interactions-queries.csv`](data/benchmark/drug-interactions-queries.csv) — 10 Drug Interactions queries
- [`cross-kg-queries.csv`](data/benchmark/cross-kg-queries.csv) — 15 Cross-KG queries
- [`verified-results.csv`](data/benchmark/verified-results.csv) — Results from verified queries with timings

## Reproducing

All knowledge graph snapshots and the benchmark runner are included in Samyama Graph Enterprise Edition. [Contact us](https://samyama.dev/contact) to access the pre-built snapshots and benchmark tooling.
