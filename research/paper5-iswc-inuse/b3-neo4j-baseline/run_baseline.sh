#!/usr/bin/env bash
# B3 — Samyama vs Neo4j head-to-head runner.
# Run inside b3-neo4j-baseline/ directory on the AWS VM.

set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
QUERIES="$DIR/b3_subset_queries.csv"
OUT="$DIR/results.csv"
SAMYAMA_BIN="${SAMYAMA_BIN:-$HOME/samyama-graph/target/release/examples/b3_runner}"
SAMYAMA_OUT="$DIR/samyama_results.csv"
NEO4J_USER="${NEO4J_USER:-neo4j}"
NEO4J_PASS="${NEO4J_PASS:-samyama-baseline}"

if [ ! -x "$SAMYAMA_BIN" ]; then
  echo "ERROR: $SAMYAMA_BIN not built" >&2
  exit 1
fi
if ! command -v cypher-shell >/dev/null 2>&1; then
  echo "ERROR: cypher-shell not found in PATH" >&2
  exit 1
fi

# ── Samyama side ──
echo "[run] Samyama subset run..."
"$SAMYAMA_BIN" \
    --snapshots "$HOME/data/pathways.sgsnap,$HOME/data/druginteractions.sgsnap,$HOME/data/clinical-trials.sgsnap" \
    --queries "$QUERIES" \
    --csv "$SAMYAMA_OUT" \
    --warm 1 --runs 3

# ── Neo4j side ──
echo "[run] Neo4j subset run..."
NEO4J_OUT="$DIR/neo4j_results.csv"
echo "id,kg,system,latency_ms,row_count,status" > "$NEO4J_OUT"

# Read queries with python to handle CSV quoting properly
export QUERIES NEO4J_USER NEO4J_PASS
python3 <<'PYEOF' >> "$NEO4J_OUT"
import csv, subprocess, time, os, sys

queries_path = os.environ.get('QUERIES')
neo4j_user = os.environ.get('NEO4J_USER', 'neo4j')
neo4j_pass = os.environ.get('NEO4J_PASS', 'samyama-baseline')

with open(queries_path) as f:
    reader = csv.DictReader(f)
    for row in reader:
        qid = row['id']
        kg = row['kg']
        cypher = row['cypher']

        # Warm-up (discard)
        try:
            subprocess.run(
                ['cypher-shell', '-u', neo4j_user, '-p', neo4j_pass, '--format', 'plain', cypher],
                capture_output=True, timeout=120, check=False
            )
        except subprocess.TimeoutExpired:
            pass

        latencies = []
        rows = 0
        status = 'pass'
        for i in range(3):
            start = time.perf_counter()
            try:
                result = subprocess.run(
                    ['cypher-shell', '-u', neo4j_user, '-p', neo4j_pass, '--format', 'plain', cypher],
                    capture_output=True, text=True, timeout=120, check=False
                )
            except subprocess.TimeoutExpired:
                latencies.append(120000.0)
                status = 'timeout'
                break

            dt_ms = (time.perf_counter() - start) * 1000
            latencies.append(dt_ms)

            if result.returncode != 0:
                status = 'error'
                break
            if i == 0:
                # Count output lines minus header
                lines = result.stdout.strip().split('\n')
                rows = max(0, len(lines) - 1)

        if status == 'pass' and rows == 0:
            status = 'empty'

        latencies.sort()
        median = latencies[len(latencies) // 2] if latencies else -1
        # CSV-safe error message
        err_safe = status.replace(',', ';').replace('\n', ' ')
        print(f"{qid},{kg},neo4j,{median:.3f},{rows},{err_safe}")
        sys.stdout.flush()
PYEOF

# ── Combine into results.csv ──
echo "id,kg,system,latency_ms,row_count,status" > "$OUT"
tail -n +2 "$SAMYAMA_OUT" >> "$OUT"
tail -n +2 "$NEO4J_OUT" >> "$OUT"

echo "[run] Done. Combined results in $OUT"
echo "[run] Summary:"
awk -F, 'NR>1 { c[$3]++; if ($6=="pass") p[$3]++; sum[$3]+=$4 }
         END { for (s in c) printf("  %-10s pass=%d/%d  total_median=%.0fms  avg=%.1fms\n",
                                    s, p[s], c[s], sum[s], sum[s]/c[s]) }' "$OUT"
