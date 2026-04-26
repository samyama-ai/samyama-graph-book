#!/usr/bin/env bash
# Setup script — runs on the AWS VM after launch.
# Installs Neo4j 5.x, downloads PW+DI+CT snapshots, builds Samyama,
# converts to CSVs, imports into Neo4j, and runs the baseline.

set -euo pipefail

cd "$HOME"

# 1. Install Neo4j Community 5.x
if ! command -v cypher-shell >/dev/null 2>&1; then
    echo "[setup] Installing Neo4j Community 5.x..."
    sudo wget -O /usr/share/keyrings/neo4j.gpg https://debian.neo4j.com/neotechnology.gpg.key
    echo 'deb [signed-by=/usr/share/keyrings/neo4j.gpg] https://debian.neo4j.com stable 5' | sudo tee /etc/apt/sources.list.d/neo4j.list
    sudo apt-get update -qq
    sudo apt-get install -y neo4j openjdk-17-jdk
fi

# Increase Neo4j heap and pagecache for the ~8M node graph
sudo sed -i 's/^#server.memory.heap.max_size=.*/server.memory.heap.max_size=16G/' /etc/neo4j/neo4j.conf
sudo sed -i 's/^#server.memory.pagecache.size=.*/server.memory.pagecache.size=8G/' /etc/neo4j/neo4j.conf
# Set initial password
sudo systemctl stop neo4j
sudo neo4j-admin dbms set-initial-password samyama-baseline || true

# 2. Download snapshots from S3 (assumes S3 bucket per OPS-GUIDE)
mkdir -p ~/data
echo "[setup] Downloading snapshots from S3..."
aws s3 cp s3://samyama-snapshots/pathways.sgsnap ~/data/pathways.sgsnap
aws s3 cp s3://samyama-snapshots/druginteractions.sgsnap ~/data/druginteractions.sgsnap
aws s3 cp s3://samyama-snapshots/clinical-trials.sgsnap ~/data/clinical-trials.sgsnap

# 3. Build Samyama (assumes repos cloned via deploy keys)
if [ ! -d "$HOME/samyama-graph-enterprise" ]; then
    echo "[setup] ERROR: clone samyama-graph-enterprise first (deploy key required)"
    exit 1
fi
cd ~/samyama-graph-enterprise
export PATH="$HOME/.cargo/bin:$PATH"
cargo build --release --example unified_benchmark
cargo build --release --example samyama_to_neo4j

# 4. Convert each snapshot to Neo4j CSVs
echo "[setup] Converting snapshots to Neo4j CSVs..."
mkdir -p ~/neo4j-csvs
for kg in pathways druginteractions clinical-trials; do
    ./target/release/examples/samyama_to_neo4j ~/data/${kg}.sgsnap ~/neo4j-csvs/${kg}/
done

# 5. Import into Neo4j (merge all into single database)
# neo4j-admin database import full requires Neo4j stopped
sudo systemctl stop neo4j
sudo -u neo4j neo4j-admin database import full neo4j \
    --overwrite-destination=true \
    --skip-bad-relationships=true \
    --skip-duplicate-nodes=true \
    $(find ~/neo4j-csvs -name 'nodes-*.csv' | sed 's/^/--nodes=/') \
    $(find ~/neo4j-csvs -name 'rels-*.csv' | sed 's/^/--relationships=/')

sudo systemctl start neo4j
echo "[setup] Waiting for Neo4j to come up..."
for _ in $(seq 1 30); do
    cypher-shell -u neo4j -p samyama-baseline "RETURN 1" >/dev/null 2>&1 && break
    sleep 2
done

# 6. Create indexes (parity with Samyama)
echo "[setup] Creating Neo4j indexes..."
cypher-shell -u neo4j -p samyama-baseline <<'EOF'
CREATE INDEX drug_name IF NOT EXISTS FOR (d:Drug) ON (d.name);
CREATE INDEX gene_name IF NOT EXISTS FOR (g:Gene) ON (g.gene_name);
CREATE INDEX gene_label_name IF NOT EXISTS FOR (g:Gene) ON (g.name);
CREATE INDEX protein_gene_name IF NOT EXISTS FOR (p:Protein) ON (p.gene_name);
CREATE INDEX protein_uniprot IF NOT EXISTS FOR (p:Protein) ON (p.uniprot_id);
CREATE INDEX pathway_name IF NOT EXISTS FOR (p:Pathway) ON (p.name);
CREATE INDEX trial_nct IF NOT EXISTS FOR (t:ClinicalTrial) ON (t.nct_id);
CREATE INDEX intervention_name IF NOT EXISTS FOR (i:Intervention) ON (i.name);
CREATE INDEX condition_name IF NOT EXISTS FOR (c:Condition) ON (c.name);
EOF

# 7. Run the baseline
cd ~
git clone https://github.com/samyama-ai/samyama-graph-book.git
cd samyama-graph-book/research/paper5-iswc-inuse/b3-neo4j-baseline
./run_baseline.sh

echo "[setup] Done. Results in $(pwd)/results.csv"
echo "[setup] Upload to S3: aws s3 cp results.csv s3://samyama-snapshots/b3-results.csv"
