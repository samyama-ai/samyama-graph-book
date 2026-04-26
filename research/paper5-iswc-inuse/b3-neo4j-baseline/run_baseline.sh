#!/usr/bin/env bash
# B3 — Samyama vs Neo4j head-to-head runner
#
# Prerequisites on the AWS instance:
#   - Samyama built at ~/samyama-graph-enterprise/target/release/
#   - Neo4j 5.x Community installed and running on bolt://localhost:7687
#   - cypher-shell available in PATH
#   - PW + DI + CT snapshots in ~/data/{pathways,druginteractions,clinical-trials}.sgsnap
#   - This directory containing b3_subset_queries.csv
#
# Output: results.csv with columns id,kg,system,latency_ms,row_count,status

set -euo pipefail

QUERIES=$(dirname "$0")/b3_subset_queries.csv
OUT=$(dirname "$0")/results.csv
SAMYAMA_BIN=${SAMYAMA_BIN:-$HOME/samyama-graph-enterprise/target/release/examples/unified_benchmark}
NEO4J_USER=${NEO4J_USER:-neo4j}
NEO4J_PASS=${NEO4J_PASS:-samyama-baseline}

echo "id,kg,system,latency_ms,row_count,status" > "$OUT"

# --- Samyama: use unified_benchmark with --queries override pointing to subset ---
echo "[run] Samyama subset run..."
SAMYAMA_OUT=$(mktemp)
"$SAMYAMA_BIN" \
    --snapshots pathways,druginteractions,clinical-trials \
    --queries "$QUERIES" \
    --csv "$SAMYAMA_OUT" \
    --warm-runs 1 --measured-runs 3
# Expected output schema: id,name,kg,latency_us,row_count,status
awk -F, 'NR>1 { printf("%s,%s,samyama,%.3f,%s,%s\n", $1, $3, $4/1000, $5, $6) }' "$SAMYAMA_OUT" >> "$OUT"

# --- Neo4j: pipe each query through cypher-shell, time it, capture row count ---
echo "[run] Neo4j subset run..."
tail -n +2 "$QUERIES" | while IFS=, read -r id name kg category hops cypher_quoted; do
    # Strip surrounding quotes from cypher field
    cypher=$(echo "$cypher_quoted" | sed -E 's/^"//; s/"$//; s/""/"/g')

    # Warm-up run (discard)
    cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" --format plain "$cypher" > /dev/null 2>&1 || true

    # Timed runs — take median of 3
    latencies=()
    rows=0
    status="pass"
    for i in 1 2 3; do
        start=$(python3 -c 'import time; print(int(time.time()*1000))')
        out=$(cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASS" --format plain "$cypher" 2>&1) || status="error"
        end=$(python3 -c 'import time; print(int(time.time()*1000))')
        latencies+=($((end - start)))
        if [ $i -eq 1 ]; then
            rows=$(echo "$out" | wc -l | awk '{print $1 - 1}') # subtract header line
            [ "$rows" -lt 0 ] && rows=0
            [ "$rows" -eq 0 ] && [ "$status" = "pass" ] && status="empty"
        fi
    done
    median=$(printf '%s\n' "${latencies[@]}" | sort -n | awk 'NR==2')
    echo "$id,$kg,neo4j,$median,$rows,$status" >> "$OUT"
done

echo "[run] Done. Results in $OUT"
echo
echo "Summary:"
awk -F, 'NR>1 { c[$3]++; if ($6=="pass") p[$3]++; sum[$3]+=$4 }
         END { for (s in c) printf("  %-10s pass=%d/%d  median_total=%.0fms\n", s, p[s], c[s], sum[s]) }' "$OUT"
