# VLDB 2026 Submission Plan

**Target**: PVLDB Vol. 19, May 1 2026 deadline (5 PM PT)
**Track**: Research Track (can be tagged [Experiment, Analysis & Benchmark] if we lead with benchmarks)
**Page limit**: 12 pages + unlimited references
**Template**: acmart.cls with PVLDB macros
**Review**: Single-blind (author names visible)

## Paper Strategy

The arxiv preprint (2603.08036) is a **systems paper** covering everything. For VLDB we need to **focus and deepen** rather than broaden.

### Option A: Systems Paper (Research Track)
**Title**: "Samyama: A Unified Graph-Vector Database with Cost-Based Query Planning and Late Materialization"

Focus on 3 core database contributions:
1. **Late materialization for property graphs** (NodeRef/EdgeRef) — 4x traversal speedup
2. **Graph-native cost-based planner** (ADR-015) — triple-level statistics, plan enumeration, direction reversal
3. **Hybrid CSR adjacency** — frozen tier + write buffer for memory-efficient bulk loading

De-emphasize: GPU, agentic enrichment, optimization solvers, RDF (mention as system features, don't evaluate deeply)

Add: LDBC SNB comparison, Cricket-100 benchmark, FinBench results

### Option B: Experiment/Analysis/Benchmark Paper
**Title**: "Evaluating Graph Database Performance on Biomedical Knowledge Graphs: From 8M to 80M Nodes [Experiment, Analysis & Benchmark]"

Focus on reproducible benchmarks:
1. LDBC SNB (21/21), BI (16/16), Graphalytics (12/12), FinBench (40/40)
2. Biomedical KG scale test: pathways → clinical trials → PubMed (80M nodes)
3. Cricket-100 real-world query benchmark
4. Comparison with Neo4j, Memgraph on standard workloads

### Recommendation: Option A

A systems paper is more impactful and leverages the unique contributions. The benchmarks support the systems claims.

## Outline (12 pages)

1. **Introduction** (1.5 pages)
   - Problem: fragmented graph+vector architectures
   - Key insight: late materialization + graph-native planning
   - Contributions (3 primary + engineering)

2. **Background & Related Work** (1 page)
   - Neo4j, Memgraph, Kuzu, DuckPGQ, TigerGraph
   - Late materialization in columnar DBs (Abadi et al.)
   - Graph query optimization (worst-case optimal joins, etc.)

3. **System Architecture** (1.5 pages)
   - Storage: RocksDB + arena allocation + hybrid CSR
   - Protocol: RESP + HTTP/REST
   - Multi-tenancy: column families + resource quotas

4. **Query Engine** (2 pages) — primary contribution
   - Pest-based OpenCypher parser (~90% coverage)
   - Volcano iterator model (35 physical operators)
   - Late materialization: NodeRef/EdgeRef design
   - Columnar property store for scan-heavy workloads

5. **Graph-Native Query Planner** (2 pages) — primary contribution
   - GraphCatalog: triple-level statistics (TriplePattern → TripleStats)
   - Plan enumeration: BFS from each start node
   - ExpandInto for bound-bound patterns
   - Direction reversal based on cardinality
   - Predicate pushdown, early LIMIT propagation
   - Plan cache with generation-based invalidation

6. **Hybrid CSR Storage** (1 page) — primary contribution
   - FrozenAdjacency (CSR) + Vec-of-Vec write buffer
   - Inter-phase compaction for bulk loading
   - Memory savings: 40M nodes in 128GB (PubMed benchmark)

7. **Evaluation** (2.5 pages)
   - 7.1 LDBC validation (SNB 21/21, BI 16/16, Graphalytics 12/12, FinBench 40/40)
   - 7.2 Late materialization ablation (1-hop, 2-hop, 3-hop)
   - 7.3 Planner effectiveness (plan comparison, cost accuracy)
   - 7.4 Scale: biomedical trifecta (7.9M nodes, 28M edges)
   - 7.5 Comparative: vs Neo4j, Memgraph on traversal/ingestion
   - 7.6 Cricket-100: real-world analytical queries (87/100)

8. **Conclusion & Future Work** (0.5 pages)

## New Content Needed

- [ ] PVLDB formatting (acmart.cls, two-column)
- [ ] Prof. Rao's feedback incorporated (tone, comparisons, ablation)
- [ ] Graph-native planner section (ADR-015, new since arxiv v2)
- [ ] Hybrid CSR section (DS-07, new since arxiv v2)
- [ ] Updated benchmark numbers (v0.6.1)
- [ ] Planner effectiveness evaluation (plan comparison screenshots)
- [ ] Architecture diagram updated for VLDB style

## Timeline

| Date | Milestone |
|------|-----------|
| Mar 27-28 | Outline + skeleton in VLDB template |
| Mar 29-31 | Sections 4-5 (query engine + planner — new content) |
| Apr 1-5 | Section 6 (hybrid CSR) + Section 7 (evaluation) |
| Apr 6-10 | Section 1-3 (intro, related work, architecture) |
| Apr 11-15 | Polish, figures, bibliography |
| Apr 16-20 | Internal review, revisions |
| Apr 21-25 | Final polish |
| Apr 28-30 | Camera-ready check, submit by May 1 |
