# Public Health Knowledge Graph Benchmark

**40 queries. 2 knowledge graphs. 305K nodes. 305K edges. Cross-KG federation with health system capacity data.**

The public health benchmark demonstrates Samyama's ability to load, query, and cross-correlate population health determinants with health system capacity data — answering questions from "Why are populations vulnerable?" to "What capacity exists to respond?"

## The Dataset

| Knowledge Graph | Source | Nodes | Edges | Key Entities |
|---|---|---|---|---|
| **Health Determinants** | World Bank WDI + WHO Air Quality + WHO Water/Sanitation | 285,635 | 285,628 | Country, Region, SocioeconomicIndicator, EnvironmentalFactor, NutritionIndicator, DemographicProfile, WaterResource |
| **Health Systems** | WHO SPAR v2 + WHO NHWA (workforce) | 19,661 | 19,428 | Country, EmergencyResponse, HealthWorkforce |
| **Total** | | **305,296** | **305,056** | |

**Data coverage:**
- **211 countries** with World Bank indicators across 5 categories (1990–2024)
- **233 countries** with IHR SPAR v2 capacity scores + health workforce density (2020–2023)
- **80 curated WDI indicators**: socioeconomic (16), environmental (10), nutrition (10), demographic (15), water (10)
- **1,880 country-year PM2.5** air quality records from WHO GHO
- **47,531 water/sanitation** records (safely managed + basic water/sanitation)
- **11,008 health workforce** density records (physicians, nurses, dentists, pharmacists)
- **15 IHR capacities**: legislation, coordination, financing, laboratory, surveillance, human resources, emergency management, health services, IPC, risk communication, points of entry, zoonotic, food safety, chemical, radiation

## Results Summary

**40 queries executed. 40 returned data. 0 empty. 0 errors.**

| Category | Queries | Pass | Empty | Error | Median (ms) |
|---|---|---|---|---|---|
| Health Determinants | 20 | 20 | 0 | 0 | 27.4 |
| Health Systems | 10 | 10 | 0 | 0 | 12.2 |
| Cross-KG / Cross-Indicator | 10 | 10 | 0 | 0 | 190.7 |
| **Total** | **40** | **40** | **0** | **0** | **15.1** |

## Performance

**Infrastructure:** MacBook Pro M-series, single process, in-memory graph loaded from .sgsnap snapshots.

| Metric | Value |
|---|---|
| Snapshot import (Health Determinants) | 1.6s (239K nodes, 240K edges) |
| Snapshot import (Health Systems) | 0.1s (8.7K nodes, 8.4K edges) |
| Point lookups | 1.3–4.2 ms |
| Single-hop traversals | 1.8–24.7 ms |
| Aggregation scans | 10.6–133.5 ms |
| Cross-indicator joins | 105–478 ms |
| All 40 queries total | ~3.6s |

## Query Categories

### Health Determinants (HD01–HD20)

Point lookups, indicator traversals, cross-category analysis, and regional aggregations over World Bank WDI data.

| ID | Name | Time (ms) | Rows |
|---|---|---|---|
| HD01 | Country by ISO code | 4.2 | 2 |
| HD02 | Country by name | 1.9 | 2 |
| HD03 | All regions | 1.3 | 7 |
| HD04 | Countries in a region | 18.1 | 6 |
| HD05 | GNI per capita for India (latest) | 2.2 | 1 |
| HD06 | India poverty rate trend | 2.2 | 5 |
| HD07 | PM2.5 air pollution for India | 1.9 | 5 |
| HD08 | Energy use per capita top 10 | 56.2 | 10 |
| HD09 | Stunting prevalence Nigeria | 2.0 | 5 |
| HD10 | Countries with high stunting (>30%) | 36.7 | 8 |
| HD11 | Population top 10 countries | 133.5 | 10 |
| HD12 | Life expectancy Brazil trend | 2.5 | 10 |
| HD13 | Infant mortality worst countries | 119.9 | 10 |
| HD14 | Water stress high countries | 53.6 | 10 |
| HD15 | Safe drinking water lowest | 59.6 | 10 |
| HD16 | India all indicators for 2022 | 2.3 | 11 |
| HD17 | India environmental profile | 1.9 | 4 |
| HD18 | Poverty vs life expectancy | 478.1 | 10 |
| HD19 | Health expenditure vs infant mortality | 350.9 | 10 |
| HD20 | Regional average GNI per capita | 238.2 | 7 |

### Health Systems (HS01–HS10)

IHR SPAR capacity queries — country profiles, rankings, gaps, and trends.

| ID | Name | Time (ms) | Rows |
|---|---|---|---|
| HS01 | Country by ISO code | 1.8 | 2 |
| HS02 | SPAR scores for India | 11.6 | 14 |
| HS03 | SPAR scores for Nigeria | 11.4 | 14 |
| HS04 | Top 10 by surveillance capacity | 10.8 | 10 |
| HS05 | Countries with lowest lab capacity | 11.2 | 10 |
| HS06 | Average SPAR score per country | 12.2 | 10 |
| HS07 | Countries with lowest avg SPAR | 10.6 | 10 |
| HS08 | India SPAR trend over years | 16.0 | 4 |
| HS09 | Risk communication capacity gap (<40) | 12.7 | 10 |
| HS10 | Count countries per SPAR year | 18.0 | 4 |

### Cross-KG / Cross-Indicator (PH01–PH10)

Queries spanning multiple indicator categories or joining determinants with health system capacity data.

| ID | Name | Time (ms) | Rows |
|---|---|---|---|
| PH01 | India vulnerability + SPAR capacity | 11.9 | 14 |
| PH02 | High poverty countries SPAR scores | 105.2 | 20 |
| PH03 | PM2.5 vs surveillance capacity | 66.3 | 5 |
| PH04 | Water stress + health expenditure | 274.6 | 10 |
| PH05 | Stunting + infant mortality correlation | 315.6 | 10 |
| PH06 | Urbanization vs life expectancy | 404.6 | 10 |
| PH07 | Under-5 mortality + safe water access | 309.8 | 10 |
| PH08 | Low income full profile + SPAR | 106.1 | 20 |
| PH09 | Health expenditure vs infant mortality | 348.5 | 10 |
| PH10 | Nigeria full determinants profile | 2.0 | 8 |

## Sample Query Results

### PH02: High poverty countries — do they have health capacity?

```cypher
MATCH (c1:Country)-[:HAS_INDICATOR]->(pov:SocioeconomicIndicator)
WHERE pov.indicator_code = 'SI.POV.DDAY' AND pov.value > 20
WITH c1.iso_code AS iso, pov.value AS poverty
ORDER BY poverty DESC LIMIT 5
MATCH (e:EmergencyResponse)-[:CAPACITY_FOR]->(c2:Country)
WHERE c2.iso_code = iso AND e.year = 2023
RETURN c2.name, poverty, e.capacity_code, e.score
ORDER BY poverty DESC
```

This query identifies countries with >20% extreme poverty and correlates with their IHR emergency preparedness scores — answering "Are the most vulnerable populations in countries with the least health system capacity?"

### PH07: Under-5 mortality + safe water access

```cypher
MATCH (c:Country)-[:DEMOGRAPHIC_OF]->(d:DemographicProfile)
WHERE d.indicator_code = 'SH.DYN.MORT' AND d.year = 2022
WITH c, d.value AS u5_mortality
MATCH (c)-[:WATER_RESOURCE_OF]->(w:WaterResource)
WHERE w.indicator_code = 'SH.H2O.SMDW.ZS' AND w.year = 2022
RETURN c.name, u5_mortality, w.value AS safe_water_pct
ORDER BY u5_mortality DESC LIMIT 10
```

Central African Republic tops both worst lists: 387 under-5 deaths per 1,000 and only 6.1% safely managed drinking water.

## 6-KG Federation Vision

These two KGs complete the **public health trifecta** alongside the existing Surveillance KG (217K nodes). Together with the biomedical trifecta (Pathways + Clinical Trials + Drug Interactions), Samyama now supports queries spanning **molecular biology to population health**:

```
PUBLIC HEALTH TRIFECTA              BIOMEDICAL TRIFECTA
Surveillance (217K)  ←──────────→  Clinical Trials (7.7M)
         ↓ Country.iso_code               ↑ Drug
Health Determinants (240K)         Drug Interactions (245K)
         ↓ Country.iso_code               ↑ Gene
Health Systems (8.7K) ←─────────→  Pathways (119K)
```

**Bridge property:** `Country.iso_code` (ISO 3166-1 alpha-3) links all public health KGs. Cross-trifecta bridges use `Disease.icd_code`, `Drug.drugbank_id`, and `Pathogen → Gene` mappings.

## Data Files

| File | Description |
|---|---|
| [`health-determinants-queries.csv`](data/benchmark/health-determinants-queries.csv) | 20 Health Determinants queries |
| [`health-systems-queries.csv`](data/benchmark/health-systems-queries.csv) | 10 Health Systems queries |
| [`public-health-cross-kg-queries.csv`](data/benchmark/public-health-cross-kg-queries.csv) | 10 Cross-KG queries |
| [`public-health-results.csv`](data/benchmark/public-health-results.csv) | All 40 query results with timing |

## Snapshots

Available for download:

| Snapshot | Size | Source |
|---|---|---|
| `health-determinants.sgsnap` | 6.5 MB | [GitHub Release kg-snapshots-v6](https://github.com/samyama-ai/samyama-graph/releases/tag/kg-snapshots-v6) |
| `health-systems.sgsnap` | 0.5 MB | [GitHub Release kg-snapshots-v6](https://github.com/samyama-ai/samyama-graph/releases/tag/kg-snapshots-v6) |
| Also on S3 | | `s3://samyama-data/snapshots/` |
