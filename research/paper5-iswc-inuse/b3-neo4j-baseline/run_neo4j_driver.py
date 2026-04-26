#!/usr/bin/env python3
# Re-run Neo4j queries via the official Python driver — one persistent
# connection, no per-query JVM startup. Replaces the cypher-shell-based
# Neo4j run in run_baseline.sh for fair comparison.

import csv, sys, time
from neo4j import GraphDatabase

QUERIES = '/home/ubuntu/samyama-graph-book/research/paper5-iswc-inuse/b3-neo4j-baseline/b3_subset_queries.csv'
OUT = '/home/ubuntu/samyama-graph-book/research/paper5-iswc-inuse/b3-neo4j-baseline/neo4j_driver_results.csv'

driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "samyama-baseline"))

with driver.session(database="neo4j") as sess, open(OUT, 'w', newline='') as out_f:
    w = csv.writer(out_f)
    w.writerow(['id', 'kg', 'system', 'latency_ms', 'row_count', 'status'])
    with open(QUERIES) as f:
        for row in csv.DictReader(f):
            qid, kg, cypher = row['id'], row['kg'], row['cypher']

            # Warm-up
            try:
                list(sess.run(cypher))
            except Exception:
                pass

            latencies, rows, status = [], 0, 'pass'
            for i in range(3):
                start = time.perf_counter()
                try:
                    result = sess.run(cypher)
                    records = list(result)  # consume
                    dt_ms = (time.perf_counter() - start) * 1000
                    latencies.append(dt_ms)
                    if i == 0:
                        rows = len(records)
                except Exception as e:
                    latencies.append(-1.0)
                    status = f"error:{str(e)[:80]}".replace(',', ';').replace('\n', ' ')
                    break

            if status == 'pass' and rows == 0:
                status = 'empty'
            latencies = [x for x in latencies if x > 0]
            median = sorted(latencies)[len(latencies)//2] if latencies else -1
            w.writerow([qid, kg, 'neo4j', f"{median:.3f}", rows, status])
            print(f"{qid:6s} {kg:<4s} {median:8.2f}ms rows={rows:3d} {status}", flush=True)

driver.close()
print(f"\nWrote {OUT}")
