# VLDB Paper Formatting TODOs

## Table Overflow Issues (Critical — from PDF inspection)

1. **Pages 8-9: Tables 5, 6, 7, 8 all collide** — too many [!htbp] tables in evaluation section
   - Fix: Merge Table 5 (late-mat ablation) + Table 7 (throughput) into one "Performance Summary" table
   - Fix: Convert Table 6 (planner costs) to inline text — worked example already covers the numbers
   - Fix: Table 8 (PubMed memory) should be `table*` (full width) since it has 4 columns + bold

2. **Page 10: Tables 10 + 11 overlap** — AssetOpsBench + Cricket
   - Fix: Merge into one "Real-World Workloads" table

3. **Page 6: Table 2 (CSR memory)** — already converted to inline text ✓

## Total tables: 11 → target 7
- Keep: Table 1 (feature comparison), Table 3 (KG catalog), Table 4 (LDBC), Table 8 (PubMed memory), Table 9 (comparison)
- Merge: Tables 5+7 → "Performance", Tables 10+11 → "Workloads"
- Remove: Table 2 (CSR memory → inline) ✓, Table 6 (planner → inline)

## LDBC Language (Fixed)
- Changed "LDBC validation" → "LDBC-compatible self-validation" ✓
- Changed "LDBC validated" → "LDBC-compatible" ✓

## Other Formatting
- [ ] Check all `\ref{}` cross-references still work after table renumbering
- [ ] Ensure figures don't overlap with tables
- [ ] Balance last page columns (`\balance` already present)
- [ ] Check abstract word count (≤ 300 words for VLDB)
