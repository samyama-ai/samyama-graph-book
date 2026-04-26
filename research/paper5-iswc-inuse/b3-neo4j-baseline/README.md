# B3 — Neo4j Baseline Experiment

Head-to-head Samyama vs Neo4j Community Edition on a 55-query subset spanning Pathways + Drug Interactions + Clinical Trials KGs.

See [`paper5-b3-neo4j-baseline.md`](https://github.com/samyama-ai/samyama-cloud/blob/main/wiki/topics/paper5-b3-neo4j-baseline.md) (samyama-cloud wiki) for full plan.

## Files

| File | Purpose |
|------|---------|
| `b3_subset_queries.csv` | The 55 queries: 15 PW + 15 DI + 20 CT + HERO + 4 XK |
| `samyama_to_neo4j.rs` | Converter: read .sgsnap, emit Neo4j CSVs (place in `samyama-graph-enterprise/examples/`) |
| `launch-b3-vm.sh` | Local: launch r7i.2xlarge spot in ap-south-1 |
| `setup-b3.sh` | On-VM: install Neo4j, build Samyama, convert + import data, run benchmark |
| `run_baseline.sh` | On-VM: execute queries on both systems, write `results.csv` |

## Workflow

### 1. Pre-launch checks (local)
```
# Confirm AWS credentials
aws sts get-caller-identity --region ap-south-1

# Confirm SSH key exists
ls -la ~/.ssh/pem/graph.pem

# Confirm SG_ID (e.g., from past hero runs)
export SG_ID=sg-xxxxxxxxxxxx
```

### 2. Place the Rust converter in the engine repo
```
cp samyama_to_neo4j.rs ~/projects/Madhulatha-Sandeep/graph_ws/samyama-graph-enterprise/examples/
# (commit + push to gitea/github so the VM clone picks it up)
```

### 3. Launch
```
SG_ID=sg-xxx ./launch-b3-vm.sh
# Note the public IP it prints
```

### 4. SSH and run setup
```
ssh -i ~/.ssh/pem/graph.pem ubuntu@<PUB_IP>
# On VM:
curl -fsSL https://raw.githubusercontent.com/samyama-ai/samyama-graph-book/main/research/paper5-iswc-inuse/b3-neo4j-baseline/setup-b3.sh | bash
# Wait ~30-45 minutes
```

### 5. Pull results, terminate
```
# On VM:
aws s3 cp results.csv s3://samyama-snapshots/b3-results.csv

# Locally:
aws s3 cp s3://samyama-snapshots/b3-results.csv ./

# Terminate
aws ec2 terminate-instances --region ap-south-1 --instance-ids <INST>
```

### 6. Update paper Section 4 with results

Expected output schema (`results.csv`):
```
id,kg,system,latency_ms,row_count,status
PW01,PW,samyama,3.2,10,pass
PW01,PW,neo4j,5.7,10,pass
...
```

Aggregate into a single comparison table for the paper.

## Risks

- **Cypher dialect drift**: ~3-5 queries may need rewriting for Neo4j 5.x. The runner will mark them `error`; we fix and re-run that subset only.
- **Snapshot conversion bugs**: validate by running PW01 on both systems and checking row counts match.
- **Spot preemption**: setup-b3.sh re-runs are idempotent; CSVs cached in `~/neo4j-csvs/` survive a re-attach.

## Budget

~$5-10 total for r7i.2xlarge spot + EBS + S3 transfer over 2-4 hours.
