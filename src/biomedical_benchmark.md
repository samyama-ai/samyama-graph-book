# Biomedical Knowledge Graph Benchmark

**100 queries. 4 knowledge graphs. 74 million nodes. 1 billion edges. One query language.**

Samyama's biomedical benchmark demonstrates real-world cross-knowledge-graph queries across the largest open biomedical dataset we know of — unified in a single queryable graph on commodity hardware.

## The Dataset

| Knowledge Graph | Source | Nodes | Edges | Key Entities |
|---|---|---|---|---|
| **PubMed/MEDLINE** | NLM | 66.2M | 1.04B | Article, Author, MeSHTerm, Chemical, Journal, Grant |
| **Clinical Trials** | AACT/ClinicalTrials.gov | 7.8M | 27M | ClinicalTrial, Intervention, AdverseEvent, Site, Outcome, Sponsor, Condition, Drug |
| **Pathways** | Reactome | 119K | 835K | Protein, Pathway, Complex, Reaction, GOTerm |
| **Drug Interactions** | DrugBank + ChEMBL + SIDER + DGIdb | 245K | 388K | Drug, Gene, SideEffect, Indication, AdverseEvent, Bioactivity |
| **NCT Bridge** | AACT study_references | — | 1M+ | REFERENCED_IN (Article → ClinicalTrial) |
| **Total** | | **74.3M** | **1.07B** | |

## Results Summary

**100 queries executed. 86 returned data. 12 returned empty (correct for the specific filter). 2 timed out (300s limit on full-corpus aggregations).**

| Category | Queries | Pass | Empty | Error | Avg Time |
|---|---|---|---|---|---|
| PubMed | 35 | 31 | 3 | 1 | 15.5s |
| Clinical Trials | 20 | 19 | 1 | 0 | 40.0s |
| Pathways | 15 | 11 | 4 | 0 | 2.1s |
| Drug Interactions | 15 | 11 | 3 | 1 | 16.0s |
| Cross-KG | 15 | 14 | 0 | 1 | 33.5s |
| **Total** | **100** | **86** | **12** | **2** | |

## Infrastructure

- **Instance:** r6a.8xlarge (32 vCPU, 256 GB RAM, AMD EPYC)
- **Cost:** ~$2.50 (AWS spot, ap-south-1)
- **Import time:** 31 minutes from v2 snapshots
- **NCT bridge:** 1,018,483 REFERENCED_IN edges created in 109 seconds
- **Index creation:** 10 indexes in ~320 seconds

---

## PubMed Queries (35)

### Point Lookups

| ID | Query | Time | Rows | Result |
|---|---|---|---|---|
| PM01 | Article PMID=12345678 | 19.6s | 1 | "Denpasar Declaration on Population and Development" (1994) |
| PM02 | Article PMID=25000000 | 1.3s | 1 | "How to measure technology assessment: an introduction" |
| PM03 | Article PMID=35000000 | 1.3s | 1 | "Hypusinated EIF5A as a feasible drug target..." (2022) |
| PM04 | Article PMID=1 (oldest) | 1.3s | 1 | "Formate assay in body fluids: application in methanol poisoning" |

### 1-Hop Traversals

| ID | Query | Time | Rows | Result |
|---|---|---|---|---|
| PM06 | Article → Authors | 13.3s | 1 | Arie Hasman |
| PM07 | Article → MeSH terms | 2.4s | 6 | Attitude of Health Personnel, Consumer Behavior, Health Information Systems, Medical Informatics, Technology Assessment |
| PM09 | Article → Journal | 1.3s | 1 | Studies in health technology and informatics |
| PM11 | Author → Articles (reverse) | 1.3s | 10 | Arie Hasman's publications |
| PM12 | MeSH → Articles | 2.0s | 10 | Articles annotated with "Neoplasms" |
| PM13 | Chemical → Articles | 1.4s | 10 | Articles mentioning "Aspirin" |
| PM14 | Journal → Articles | 1.4s | 10 | Articles in "Nature" |
| PM17 | Articles citing a specific article | 1.3s | 1 | Citation found |

### Multi-Hop Analytics

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| PM15 | Co-authors of an article | 1.3s | 10 | Co-author network for PMID 25000000 |
| PM19 | MeSH co-occurrence (Neoplasms) | 17.5s | 10 | **Humans (513,845)**, Female (138,966), Animals (127,482) |
| PM20 | MeSH co-occurrence (Diabetes) | 6.2s | 10 | **Humans (139,986)** |
| PM21 | Chemical co-occurrence (Aspirin) | 2.3s | 10 | **Platelet Aggregation Inhibitors (12,722)** |
| PM22 | Author collaboration network | 1.3s | 10 | Jan Talmon (10 co-authored papers) |

### Aggregations

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| PM23 | Top authors (Smith*) | 32.1s | 10 | Smith Giri (233 papers) |
| PM24 | Most cited articles | 42.7s | 10 | PMID 20000334 (461 citations) |
| PM25 | ML publication trend | 8.4s | 18 | 2020: 4,974 papers |
| PM26 | Top cancer journals | 5.3s | 10 | **Cancer (6,059 articles)** |
| PM27 | Cancer funding agencies | 3.9s | 10 | **NCI NIH HHS (46,137 papers)** |
| PM29 | Diabetes funding agencies | 8.7s | 10 | **NIDDK NIH HHS (5,123 papers)** |
| PM30 | Most published journals | 6.0s | 10 | **Nature (140,152 articles)** |
| PM31 | Chemical mentions in Nature | 2.3s | 10 | **DNA (3,726 mentions)** |
| PM32 | MeSH terms for NCI articles | 63.7s | 10 | **Humans (438,053)** |
| PM35 | ML prolific authors | 5.4s | 10 | Wei Wang (149 papers) |

---

## Clinical Trials Queries (20)

### Sample Queries

| ID | Query | Time | Rows | Result |
|---|---|---|---|---|
| CT01 | Trial interventions | 2.2s | 10 | NCT05524376 → no intervention, NCT03092076 → Ticagrelor |
| CT02 | Trial adverse events | 1.6s | 10 | NCT02028182 → Pruritus, NCT03790111 → Nausea |
| CT03 | Trial sites | 1.6s | 10 | Switzerland, Canada, China, Denmark |
| CT05 | Trial sponsors | 1.6s | 10 | Sun Yat-Sen Memorial Hospital |
| CT06 | Trial conditions | 1.6s | 10 | Sepsis |

### Aggregations

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| CT08 | Trials per country | 15.0s | 15 | **United States (190,879 trials)** |
| CT09 | Most common interventions | 10.1s | 15 | **Placebo (41,155 trials)** |
| CT10 | Most common adverse events | 16.3s | 15 | **Headache (28,130 trials)** |
| CT11 | Most studied conditions | 8.2s | 15 | **Healthy (10,898 trials)** |
| CT12 | Top sponsors | 7.1s | 10 | Assiut University (4,547 trials) |

### Complex Queries

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| CT13 | Cancer trial interventions | 159s | 10 | **Placebo (1,597)** |
| CT14 | Diabetes trial adverse events | 150s | 10 | **Headache (970)** |
| CT16 | Condition → Intervention → AE chain | 120s | 10 | Hypertension → Placebo → Headache (116) |
| CT17 | Cancer trial sponsors | 163s | 10 | **National Cancer Institute (1,320)** |
| CT20 | Multi-arm trials with AE | 142s | 10 | NCT01682876 (4 arms) → Nausea |

---

## Pathways Queries (15)

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| PW01 | Protein interactions | 9.7s | 10 | IGKV2D-28 → IGHV3-11, IL17A |
| PW03 | Insulin pathways | 1.4s | 9 | Insulin effects on Xylulose-5-Phosphate synthesis |
| PW04 | Protein lookup (TP53) | 1.2s | 1 | TP53 found |
| PW05 | Largest pathways | 1.8s | 10 | **Signal Transduction (2,614 proteins)**, Disease (2,575), Immune System (2,330) |
| PW06 | Most connected proteins | 1.7s | 10 | **TP53 (571 interactions)** — the "guardian of the genome" |
| PW08 | GO term annotations | 1.4s | 10 | IGKV2D-28 → adaptive immune response |
| PW11 | Pathway hierarchy | 1.4s | 10 | 2-LTR circle formation → Integration of provirus |
| PW14 | Immune system proteins | 1.3s | 20 | Full list |
| PW15 | Protein interaction depth 2 | 1.3s | 10 | 2-hop interaction network from IGKV2D-28 |

---

## Drug Interactions Queries (15)

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| DI01 | Drug side effects | 1.3s | 10 | Bivalirudin → Abdominal pain, Anaemia |
| DI02 | Drug-gene interactions | 1.3s | 10 | Cetuximab → gene targets |
| DI03 | Drug indications | 1.3s | 10 | Bivalirudin → Haemorrhage |
| DI04 | Drug adverse events | 1.3s | 10 | Cetuximab → adverse events |
| DI06 | Drugs with most side effects | 1.4s | 10 | **Pregabalin (839 side effects)** |
| DI07 | Most common side effects | 1.5s | 10 | **Nausea (985 drugs)** |
| DI08 | Drugs sharing gene targets | 1.3s | 10 | Cetuximab ↔ Erythropoietin (shared gene) |
| DI09 | Drugs for diabetes | 1.4s | 10 | Desmopressin → Diabetes insipidus |
| DI13 | Drug indications + side effects | 103s | 10 | Bivalirudin: Haemorrhage (indication) + Abdominal pain (side effect) |

---

## Cross-Knowledge-Graph Queries (15)

These traverse `REFERENCED_IN` edges connecting 747,505 PubMed articles to clinical trials via PMID↔NCT ID mapping from AACT study_references.

### The Headline Results

```cypher
-- XK02: What drugs are tested in cancer research trials?
-- Spans: MeSH → Article → ClinicalTrial → Intervention (3 KGs)
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

**Time: 5.2s** — Pembrolizumab (Keytruda) is the most-tested non-placebo cancer drug.

---

```cypher
-- XK03: What drugs are tested in diabetes research trials?
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

**Time: 2.4s**

---

```cypher
-- XK04: What adverse events appear in heart disease trials?
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

**Time: 2.0s**

---

```cypher
-- XK06: What adverse events appear in Metformin-linked trials?
-- Spans: Chemical → Article → ClinicalTrial → AdverseEvent (4 entities)
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

**Time: 2.1s** — Diarrhoea is a known Metformin side effect, confirmed across PubMed + ClinicalTrials.gov.

---

### All Cross-KG Results

| ID | Query | Time | Rows | Top Result |
|---|---|---|---|---|
| XK01 | Article → Trial links | 39.8s | 10 | PMID 1 → NCT03260829 |
| XK02 | Cancer → Trial interventions | **5.2s** | 10 | Pembrolizumab (137 trials) |
| XK03 | Diabetes → Trial interventions | **2.4s** | 10 | Metformin (70 trials) |
| XK04 | Heart disease → Trial AE | **2.0s** | 10 | Headache (60 trials) |
| XK05 | Aspirin → Trials | **1.5s** | 10 | NCT00000491 "Aspirin MI study" |
| XK06 | Metformin → Trial AE | **2.1s** | 10 | Headache (215), Diarrhoea (185) |
| XK07 | Cancer trial sites | **3.8s** | 10 | US (4,062), China (1,170), France (827) |
| XK08 | NCI-funded → Interventions | **19.4s** | 10 | Placebo (933), Lab biomarker (614), Cyclophosphamide (517) |
| XK09 | NCT-linked count | 98.6s | 1 | **747,505 articles linked to trials** |
| XK11 | HIV → Trial sites | **11.6s** | 10 | US (2,384) |
| XK12 | Alzheimer → Interventions | **2.4s** | 10 | Placebo (345) |
| XK13 | NHLBI-funded → Trial AE | **18.3s** | 10 | Headache (643) |
| XK14 | Paclitaxel → Trial sponsors | **1.9s** | 10 | NCI (64 trials) |
| XK15 | Breast cancer → Outcomes | **4.0s** | 1 | 6,591 outcome measures |

---

## What These Results Mean

1. **Pembrolizumab dominates cancer trials** — The immunotherapy revolution is visible in the data. Across all PubMed articles annotated with "Neoplasms" that link to clinical trials, Keytruda appears in 137 trials, more than any classic chemotherapy agent.

2. **Metformin's GI side effects confirmed cross-database** — Diarrhoea ranks 4th in Metformin-linked trial adverse events (185 trials), consistent with clinical knowledge. This was found by traversing Chemical → Article → Trial → AdverseEvent — four entities across two databases.

3. **The US conducts 45% of global clinical trials** — 190,879 of ~420K total trials. China is second at 1,170 cancer-specific trials.

4. **Nature has 140,152 articles in PubMed** — making it the most-indexed journal. DNA is its most-mentioned chemical (3,726 articles).

5. **TP53 is the most connected protein** — 571 interaction partners in Reactome, confirming its role as the "guardian of the genome."

6. **NCI NIH funds 46,137 cancer research papers** — and those papers link to 933 placebo-controlled trials.

## Query Files

The full query catalog and results are available as CSV for automated benchmarking:

- [`pubmed-queries.csv`](data/benchmark/pubmed-queries.csv) — 35 PubMed queries
- [`clinical-trials-queries.csv`](data/benchmark/clinical-trials-queries.csv) — 20 Clinical Trials queries
- [`pathways-queries.csv`](data/benchmark/pathways-queries.csv) — 15 Pathways queries
- [`drug-interactions-queries.csv`](data/benchmark/drug-interactions-queries.csv) — 15 Drug Interactions queries
- [`cross-kg-queries.csv`](data/benchmark/cross-kg-queries.csv) — 15 Cross-KG queries
- [`verified-results.csv`](data/benchmark/verified-results.csv) — All 100 results with timings

## Reproducing

All knowledge graph snapshots and the benchmark runner are included in Samyama Graph Enterprise Edition. [Contact us](https://samyama.dev/contact) to access the pre-built snapshots and benchmark tooling.
