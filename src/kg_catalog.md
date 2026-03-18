# Knowledge Graph Catalog

Samyama ships with pre-built knowledge graphs spanning sports, biomedicine, and industrial operations. Each KG is available as a portable `.sgsnap` snapshot that loads in seconds, and comes with an MCP server for AI agent integration.

---

## Catalog Overview

```mermaid
graph TB
    subgraph "Biomedical Trifecta"
        PKG["🧬 Pathways KG<br/>119K nodes · 835K edges"]
        CTKG["💊 Clinical Trials KG<br/>7.7M nodes · 27M edges"]
        DIKG["💉 Drug Interactions KG<br/>33K nodes · 192K edges"]
    end

    subgraph "Public Health Trifecta (planned)"
        DSKG["🦠 Disease Surveillance KG<br/>~500K nodes (in progress)"]
        HDKG["📊 Health Determinants KG<br/>~1M nodes (planned)"]
        HSKG["🏥 Health Systems KG<br/>~500K nodes (planned)"]
    end

    subgraph "Sports"
        CKG["🏏 Cricket KG<br/>36K nodes · 1.4M edges"]
    end

    subgraph "Industrial"
        AOKG["🏭 AssetOps KG<br/>781 nodes · 955 edges"]
    end

    PKG -.->|"Gene · Protein"| DIKG
    DIKG -.->|"Drug · Intervention"| CTKG
    DSKG -.->|"Disease · Condition"| CTKG
    DSKG -.->|"Drug · AMR"| DIKG
    DSKG -.->|"Region"| HDKG
    DSKG -.->|"Region"| HSKG

    style CKG fill:#3b82f6,stroke:#333,color:#fff
    style PKG fill:#10b981,stroke:#333,color:#fff
    style CTKG fill:#8b5cf6,stroke:#333,color:#fff
    style DIKG fill:#ec4899,stroke:#333,color:#fff
    style AOKG fill:#f59e0b,stroke:#333,color:#fff
    style DSKG fill:#06b6d4,stroke:#333,color:#fff
    style HDKG fill:#84cc16,stroke:#333,color:#fff
    style HSKG fill:#f97316,stroke:#333,color:#fff
```

| KG | Nodes | Edges | Labels | Edge Types | Snapshot | Source | Status |
|----|------:|------:|-------:|-----------:|---------|--------|--------|
| [Cricket KG](#cricket-kg) | 36,619 | 1,392,017 | 6 | 12 | 21 MB | Cricsheet | Live |
| [Pathways KG](#pathways-kg) | 118,686 | 834,785 | 5 | 9 | 9 MB | Reactome, STRING, GO, WikiPathways, UniProt | Live |
| [Clinical Trials KG](#clinical-trials-kg) | 7,774,446 | 26,973,997 | 15 | 25 | 711 MB | ClinicalTrials.gov, MeSH, RxNorm, OpenFDA, PubMed | Live |
| [Drug Interactions KG](#drug-interactions-kg) | 32,726 | 191,970 | 4 | 3 | 1.9 MB | DrugBank CC0, DGIdb, SIDER | Live |
| [AssetOps KG](#assetops-kg) | 781 | 955 | 8 | 10 | < 1 MB | Synthetic (AssetOpsBench) | Live |
| [Disease Surveillance KG](#disease-surveillance-kg) | ~60K | ~120K | 7 | 7 | TBD | WHO GHO, WUENIC | In progress |
| Health Determinants KG | ~1M | ~2M | 6 | 4 | TBD | World Bank, UNICEF, WHO | Planned |
| Health Systems KG | ~500K | ~800K | 6 | 5 | TBD | WHO SPAR, GAVI, Global Fund | Planned |

### Cross-KG Federation

The **biomedical trifecta** (Pathways + Clinical Trials + Drug Interactions) enables queries spanning molecular biology, translational medicine, and pharmacogenomics. Evaluated on the BiomedQA benchmark: **39/40 (98%) accuracy** with MCP tools vs 0% for text-to-Cypher.

The **public health trifecta** (Disease Surveillance + Health Determinants + Health Systems) will enable queries from disease outbreaks to population vulnerability to health system capacity. Bridges to the biomedical trifecta via Disease/Condition and Drug/AMR connections.

---

## Cricket KG

> 21K international cricket matches from [Cricsheet](https://cricsheet.org/) — ball-by-ball data spanning T20, ODI, and Test formats.

[![Cricket KG Demo](https://github.com/samyama-ai/samyama-graph/releases/download/kg-snapshots-v2/simulation-preview.gif)](https://github.com/samyama-ai/samyama-graph/releases/download/kg-snapshots-v2/samyama-cricket-demo.mp4)

*Click for full demo (1:56) — Dashboard, Cypher Queries, and Graph Simulation*

### Schema

```mermaid
graph LR
    Player -->|BATTED_IN| Match
    Player -->|BOWLED_IN| Match
    Player -->|DISMISSED| Player
    Player -->|FIELDED_DISMISSAL| Player
    Player -->|PLAYED_FOR| Team
    Player -->|PLAYER_OF_MATCH| Match
    Team -->|COMPETED_IN| Match
    Team -->|WON| Match
    Team -->|WON_TOSS| Match
    Match -->|HOSTED_AT| Venue
    Match -->|IN_SEASON| Season
    Match -->|PART_OF| Tournament

    style Player fill:#3b82f6,stroke:#333,color:#fff
    style Match fill:#8b5cf6,stroke:#333,color:#fff
    style Team fill:#ef4444,stroke:#333,color:#fff
    style Venue fill:#f59e0b,stroke:#333,color:#fff
    style Tournament fill:#10b981,stroke:#333,color:#fff
    style Season fill:#ec4899,stroke:#333,color:#fff
```

| Label | Count | Key Properties |
|-------|------:|----------------|
| Match | 21,324 | date, match_type, season, winner |
| Player | 12,933 | name |
| Tournament | 1,053 | name |
| Venue | 877 | name, city |
| Team | 383 | name |
| Season | 49 | name |

### Example Queries

```cypher
-- Top 10 run scorers across all formats
MATCH (p:Player)-[b:BATTED_IN]->(m:Match)
RETURN p.name AS player, sum(b.runs) AS total_runs
ORDER BY total_runs DESC LIMIT 10

-- Bowler-batsman rivalries
MATCH (bowler:Player)-[d:DISMISSED]->(victim:Player)
RETURN bowler.name, victim.name, count(d) AS times
ORDER BY times DESC LIMIT 10

-- Venue-team affinity (home advantage)
MATCH (t:Team)-[:WON]->(m:Match)-[:HOSTED_AT]->(v:Venue)
WITH t, v, count(m) AS wins WHERE wins >= 5
RETURN t.name, v.name, wins ORDER BY wins DESC LIMIT 15
```

**Repository:** [samyama-ai/cricket-kg](https://github.com/samyama-ai/cricket-kg)
**Snapshot:** [kg-snapshots-v1](https://github.com/samyama-ai/samyama-graph/releases/tag/kg-snapshots-v1) (`cricket.sgsnap`, 21 MB)

---

## Pathways KG

> Biological pathways knowledge graph combining 5 open-license data sources — Reactome, STRING, Gene Ontology, WikiPathways, and UniProt. Human-only (organism 9606).

[![Pathways KG Demo](https://github.com/samyama-ai/samyama-graph/releases/download/kg-snapshots-v3/pathways-preview.gif)](https://github.com/samyama-ai/samyama-graph/releases/download/kg-snapshots-v3/samyama-pathways-demo.mp4)

*Click for full demo (2:06) — Dashboard, Cypher Queries, and Graph Simulation*

### Schema

```mermaid
graph LR
    Protein -->|PARTICIPATES_IN| Pathway
    Protein -->|CATALYZES| Reaction
    Protein -->|COMPONENT_OF| Complex
    Protein -->|ANNOTATED_WITH| GOTerm
    Protein -->|INTERACTS_WITH| Protein
    Pathway -->|CHILD_OF| Pathway
    GOTerm -->|IS_A| GOTerm
    GOTerm -->|PART_OF| GOTerm
    GOTerm -->|REGULATES| GOTerm

    style Protein fill:#3b82f6,stroke:#333,color:#fff
    style Pathway fill:#10b981,stroke:#333,color:#fff
    style GOTerm fill:#8b5cf6,stroke:#333,color:#fff
    style Reaction fill:#f59e0b,stroke:#333,color:#fff
    style Complex fill:#ef4444,stroke:#333,color:#fff
```

| Label | Count | Key Properties |
|-------|------:|----------------|
| GOTerm | 51,897 | go_id, name, namespace, definition |
| Protein | 37,990 | uniprot_id, name, gene_name |
| Complex | 15,963 | reactome_id, name |
| Reaction | 9,988 | reactome_id, name |
| Pathway | 2,848 | reactome_id, name, source |

| Edge Type | Count | Description |
|-----------|------:|-------------|
| ANNOTATED_WITH | 265,492 | Protein → GO term annotation |
| INTERACTS_WITH | 227,818 | Protein-protein interaction (STRING, score ≥ 700) |
| PARTICIPATES_IN | 140,153 | Protein → Pathway membership |
| CATALYZES | 121,365 | Protein → Reaction catalysis |
| IS_A | 58,799 | GO term hierarchy |
| COMPONENT_OF | 8,186 | Protein → Complex membership |
| PART_OF | 7,122 | GO term part-of relation |
| REGULATES | 2,986 | GO term regulation |
| CHILD_OF | 2,864 | Pathway hierarchy |

**Repository:** [samyama-ai/pathways-kg](https://github.com/samyama-ai/pathways-kg)
**Snapshot:** [kg-snapshots-v3](https://github.com/samyama-ai/samyama-graph/releases/tag/kg-snapshots-v3) (`pathways.sgsnap`, 9 MB)

---

## Clinical Trials KG

> 575K+ clinical studies from [ClinicalTrials.gov](https://clinicaltrials.gov/) enriched with MeSH disease hierarchy, RxNorm drug normalization, ATC drug classification, OpenFDA adverse events, and PubMed publications.

### Schema

```mermaid
graph LR
    ClinicalTrial -->|STUDIES| Condition
    ClinicalTrial -->|TESTS| Intervention
    ClinicalTrial -->|HAS_ARM| ArmGroup
    ClinicalTrial -->|MEASURES| Outcome
    ClinicalTrial -->|SPONSORED_BY| Sponsor
    ClinicalTrial -->|CONDUCTED_AT| Site
    ClinicalTrial -->|REPORTED| AdverseEvent
    ClinicalTrial -->|PUBLISHED_IN| Publication
    ArmGroup -->|USES| Intervention
    Intervention -->|CODED_AS_DRUG| Drug
    Condition -->|CODED_AS_MESH| MeSHDescriptor
    Drug -->|TARGETS| Protein
    Drug -->|CLASSIFIED_AS| DrugClass
    Drug -->|TREATS| Condition
    Gene -->|ENCODES| Protein
    Gene -->|ASSOCIATED_WITH| Condition
    MeSHDescriptor -->|BROADER_THAN| MeSHDescriptor

    style ClinicalTrial fill:#8b5cf6,stroke:#333,color:#fff
    style Condition fill:#ef4444,stroke:#333,color:#fff
    style Intervention fill:#3b82f6,stroke:#333,color:#fff
    style Drug fill:#10b981,stroke:#333,color:#fff
    style Protein fill:#f59e0b,stroke:#333,color:#fff
    style Gene fill:#ec4899,stroke:#333,color:#fff
    style MeSHDescriptor fill:#06b6d4,stroke:#333,color:#fff
    style Publication fill:#84cc16,stroke:#333,color:#fff
```

| Label | Key Properties | Source |
|-------|----------------|--------|
| ClinicalTrial | nct_id, title, phase, overall_status, enrollment | ClinicalTrials.gov |
| Condition | name, mesh_id, icd10_code | ClinicalTrials.gov |
| Intervention | name, type (DRUG/DEVICE/...), rxnorm_cui | ClinicalTrials.gov |
| Drug | rxnorm_cui, name, drugbank_id | RxNorm |
| Protein | uniprot_id, name, function | UniProt |
| Gene | gene_id, symbol, name | Linked ontologies |
| MeSHDescriptor | descriptor_id, name, tree_numbers | MeSH (NLM) |
| Sponsor | name, class (INDUSTRY/NIH/...) | ClinicalTrials.gov |
| Site | facility, city, country, latitude, longitude | ClinicalTrials.gov |
| Publication | pmid, title, journal, doi | PubMed |
| AdverseEvent | term, organ_system, is_serious | OpenFDA |
| ArmGroup | label, type (EXPERIMENTAL/...) | ClinicalTrials.gov |
| Outcome | measure, time_frame, type | ClinicalTrials.gov |
| DrugClass | atc_code, name, level | ATC |
| LabTest | loinc_code, name | LOINC |

**Repository:** [samyama-ai/clinicaltrials-kg](https://github.com/samyama-ai/clinicaltrials-kg) (private)
**Snapshot:** [kg-snapshots-v1](https://github.com/samyama-ai/samyama-graph/releases/tag/kg-snapshots-v1) (`clinical-trials.sgsnap`, 711 MB)

---

## Drug Interactions KG

> Drug-gene interactions, side effects, and indications from 3 open pharmacology databases. Bridges to Pathways KG (via gene name) and Clinical Trials KG (via drug name/DrugBank ID).

### Schema

```mermaid
graph LR
    Drug -->|INTERACTS_WITH_GENE| Gene
    Drug -->|HAS_SIDE_EFFECT| SideEffect
    Drug -->|HAS_INDICATION| Indication

    style Drug fill:#ec4899,stroke:#333,color:#fff
    style Gene fill:#3b82f6,stroke:#333,color:#fff
    style SideEffect fill:#ef4444,stroke:#333,color:#fff
    style Indication fill:#10b981,stroke:#333,color:#fff
```

| Label | Count | Key Properties |
|-------|------:|----------------|
| Drug | 19,842 | drugbank_id, name, cas_number |
| Gene | 4,182 | gene_name |
| SideEffect | 5,858 | meddra_id, name |
| Indication | 2,844 | meddra_id, name |

| Edge Type | Count | Description |
|-----------|------:|-------------|
| INTERACTS_WITH_GENE | 38,033 | Drug-gene interaction (with interaction_type) |
| HAS_SIDE_EFFECT | 139,193 | Drug side effect from SIDER |
| HAS_INDICATION | 14,744 | Drug indication from SIDER |

### Performance

- **Rust native loader**: 32,726 nodes + 191,970 edges in **928ms**
- **Snapshot**: 1.9 MB (`druginteractions.sgsnap`)
- **BiomedQA benchmark**: 39/40 (98%) accuracy with MCP tools

### Sources

| Source | License | Content |
|--------|---------|---------|
| DrugBank CC0 | CC0 | 19,842 drug vocabulary + 52,154 synonym mappings |
| DGIdb | Open | 38,033 drug-gene interactions from 4,182 genes |
| SIDER | CC-BY-SA | 139,193 side effect + 14,744 indication edges |

**Repository:** [samyama-ai/druginteractions-kg](https://github.com/samyama-ai/druginteractions-kg) (private)
**Rust loader:** `examples/druginteractions_loader.rs` in samyama-graph
**Snapshot:** `druginteractions.sgsnap` (1.9 MB)

---

## Disease Surveillance KG (In Progress)

> WHO Global Health Observatory data — disease case/death counts, vaccine coverage, and health indicators across 234 countries.

### Schema

```mermaid
graph LR
    Country -->|IN_REGION| Region
    Country -->|REPORTED| DiseaseReport
    DiseaseReport -->|REPORT_OF| Disease
    Country -->|HAS_COVERAGE| VaccineCoverage
    Country -->|HAS_INDICATOR| HealthIndicator

    style Country fill:#06b6d4,stroke:#333,color:#fff
    style Region fill:#84cc16,stroke:#333,color:#fff
    style Disease fill:#ef4444,stroke:#333,color:#fff
    style DiseaseReport fill:#8b5cf6,stroke:#333,color:#fff
    style VaccineCoverage fill:#f59e0b,stroke:#333,color:#fff
    style HealthIndicator fill:#ec4899,stroke:#333,color:#fff
```

| Label | Est. Count | Source |
|-------|--------:|--------|
| Country | 234 | WHO GHO |
| Region | 6 | WHO regions (AFR, AMR, SEAR, EUR, EMR, WPR) |
| Disease | 15+ | Cholera, Malaria, TB, HIV, Meningitis, etc. |
| DiseaseReport | ~49K | Annual case/death counts per country per disease |
| VaccineCoverage | ~10K | DTP3, MCV1, BCG, Polio3 coverage per country per year |
| HealthIndicator | ~164K | Life expectancy, infant mortality, sanitation, water |

**Status:** Data downloaded (223K records from WHO GHO API), Python loader tested (14/14 tests pass), Rust loader pending.
**Data sources:** WHO GHO OData API (30 indicators across infectious diseases, vaccines, and health metrics)

---

## AssetOps KG

> Synthetic industrial operations graph from the [AssetOpsBench](https://github.com/samyama-ai/AssetOpsBench) benchmark. Models assets, sensors, maintenance schedules, and failure modes for industrial IoT.

| Label | Count | Examples |
|-------|------:|---------|
| Asset | ~200 | Pumps, compressors, turbines |
| Sensor | ~150 | Temperature, vibration, pressure |
| WorkOrder | ~100 | Maintenance tasks |
| FailureMode | ~80 | Bearing failure, seal leak |
| Component | ~100 | Bearings, seals, impellers |
| Location | ~50 | Plants, areas, units |
| Operator | ~50 | Maintenance technicians |
| Schedule | ~50 | Maintenance windows |

**Repository:** [samyama-ai/assetops-kg](https://github.com/samyama-ai/assetops-kg) (private)

---

## Quick Start — Loading Any Snapshot

All snapshots follow the same load pattern:

```bash
# 1. Start Samyama Graph (v0.6.1+)
./target/release/samyama --demo social

# 2. Create a tenant
curl -X POST http://localhost:8080/api/tenants \
  -H 'Content-Type: application/json' \
  -d '{"id":"TENANT_ID","name":"TENANT_NAME"}'

# 3. Import snapshot into the tenant
curl -X POST http://localhost:8080/api/tenants/TENANT_ID/snapshot/import \
  -F "file=@snapshot.sgsnap"

# 4. Query
curl -X POST http://localhost:8080/api/query \
  -H 'Content-Type: application/json' \
  -d '{"query":"MATCH (n) RETURN labels(n), count(n)","graph":"TENANT_ID"}'

# 5. Explore in Insight
cd samyama-insight && npm run dev
# → http://localhost:5173 (select tenant from dropdown)
# → http://localhost:5173/simulation/TENANT_ID
```

> **Note:** Use `/api/tenants/:id/snapshot/import` (tenant-specific endpoint), NOT `/api/snapshot/import`. The generic endpoint always loads into the default tenant.
