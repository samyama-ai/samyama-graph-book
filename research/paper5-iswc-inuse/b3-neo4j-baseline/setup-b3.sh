#!/usr/bin/env bash
# Setup script — runs on the AWS VM after launch.
# Builds Samyama OSS, downloads PW+DI+CT snapshots from S3,
# converts to CSVs, installs Neo4j 5.x, imports CSVs, runs the baseline.

set -euo pipefail

cd "$HOME"
export PATH="$HOME/.cargo/bin:$PATH"

# ── 1. Clone OSS Samyama (public, no key needed) and the book repo ──
[ -d samyama-graph ] || git clone https://github.com/samyama-ai/samyama-graph.git
[ -d samyama-graph-book ] || git clone https://github.com/samyama-ai/samyama-graph-book.git
( cd samyama-graph && git pull --ff-only )
( cd samyama-graph-book && git pull --ff-only )

# ── 2. Install Neo4j Community 5.x and JDK 17 ──
if ! command -v cypher-shell >/dev/null 2>&1; then
  echo "[setup] Installing Neo4j 5 + OpenJDK 17..."
  sudo apt-get update -qq
  sudo apt-get install -y openjdk-17-jdk wget gnupg curl
  wget -qO- https://debian.neo4j.com/neotechnology.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/neo4j.gpg
  echo 'deb [signed-by=/usr/share/keyrings/neo4j.gpg] https://debian.neo4j.com stable 5' | sudo tee /etc/apt/sources.list.d/neo4j.list
  sudo apt-get update -qq
  sudo apt-get install -y neo4j
fi

sudo systemctl stop neo4j || true
# Tune for ~8M nodes — r7i.2xlarge has 64GB RAM, give Neo4j plenty
sudo sed -i 's/^#\?server.memory.heap.max_size=.*/server.memory.heap.max_size=24G/' /etc/neo4j/neo4j.conf
sudo sed -i 's/^#\?server.memory.heap.initial_size=.*/server.memory.heap.initial_size=24G/' /etc/neo4j/neo4j.conf
sudo sed -i 's/^#\?server.memory.pagecache.size=.*/server.memory.pagecache.size=16G/' /etc/neo4j/neo4j.conf
sudo neo4j-admin dbms set-initial-password samyama-baseline 2>/dev/null || true

# ── 3. Download snapshots from S3 ──
mkdir -p ~/data
echo "[setup] Downloading PW + DI + CT snapshots..."
for f in pathways druginteractions clinical-trials; do
  [ -f ~/data/${f}.sgsnap ] || aws s3 cp s3://samyama-data/snapshots/${f}.sgsnap ~/data/${f}.sgsnap
done

# ── 4. Build Samyama (OSS) ──
echo "[setup] Building Samyama OSS examples..."
cd ~/samyama-graph
cargo build --release --example samyama_to_neo4j 2>&1 | tail -3

# ── 5. Convert each snapshot → Neo4j CSV ──
# Each snapshot uses its own NodeId space starting from 1; merging them into
# a single Neo4j graph would collide. Apply per-KG ID offsets.
echo "[setup] Converting snapshots..."
mkdir -p ~/neo4j-csvs
declare -A OFFSETS=( [pathways]=0 [druginteractions]=10000000 [clinical-trials]=20000000 )
for kg in pathways druginteractions clinical-trials; do
  out=~/neo4j-csvs/${kg}
  rm -rf "$out"  # force regenerate with offsets
  mkdir -p "$out"
  ~/samyama-graph/target/release/examples/samyama_to_neo4j ~/data/${kg}.sgsnap "$out" "${OFFSETS[$kg]}" 2>&1 | tail -3
done
# Make CSVs readable by neo4j user
chmod 755 /home/ubuntu /home/ubuntu/neo4j-csvs
find /home/ubuntu/neo4j-csvs -type d -exec chmod 755 {} \;
find /home/ubuntu/neo4j-csvs -type f -exec chmod 644 {} \;

# ── 6. Import into Neo4j (single merged DB for the comparison) ──
sudo systemctl stop neo4j
NODE_ARGS=$(find ~/neo4j-csvs -name 'nodes-*.csv' | sed 's|^|--nodes=|' | xargs)
REL_ARGS=$(find ~/neo4j-csvs -name 'rels-*.csv' | sed 's|^|--relationships=|' | xargs)
echo "[setup] Running neo4j-admin import..."
sudo -u neo4j neo4j-admin database import full neo4j \
    --overwrite-destination=true \
    --skip-bad-relationships=true \
    --skip-duplicate-nodes=true \
    --id-type=INTEGER \
    --report-file=/var/lib/neo4j/import.report \
    $NODE_ARGS $REL_ARGS 2>&1 | tail -25

sudo systemctl start neo4j
echo "[setup] Waiting for Neo4j..."
for _ in $(seq 1 60); do
  cypher-shell -u neo4j -p samyama-baseline "RETURN 1" >/dev/null 2>&1 && break
  sleep 2
done

# ── 7. Create indexes (parity with Samyama) ──
echo "[setup] Creating Neo4j indexes..."
cypher-shell -u neo4j -p samyama-baseline <<'EOF' 2>&1 | tail -3
CREATE INDEX drug_name IF NOT EXISTS FOR (d:Drug) ON (d.name);
CREATE INDEX gene_name IF NOT EXISTS FOR (g:Gene) ON (g.gene_name);
CREATE INDEX gene_label_name IF NOT EXISTS FOR (g:Gene) ON (g.name);
CREATE INDEX protein_gene_name IF NOT EXISTS FOR (p:Protein) ON (p.gene_name);
CREATE INDEX protein_name IF NOT EXISTS FOR (p:Protein) ON (p.name);
CREATE INDEX protein_uniprot IF NOT EXISTS FOR (p:Protein) ON (p.uniprot_id);
CREATE INDEX pathway_name IF NOT EXISTS FOR (p:Pathway) ON (p.name);
CREATE INDEX trial_nct IF NOT EXISTS FOR (t:ClinicalTrial) ON (t.nct_id);
CREATE INDEX intervention_name IF NOT EXISTS FOR (i:Intervention) ON (i.name);
CREATE INDEX condition_name IF NOT EXISTS FOR (c:Condition) ON (c.name);
CREATE INDEX se_name IF NOT EXISTS FOR (s:SideEffect) ON (s.name);
EOF
sleep 5  # wait for index population

# ── 8. Run baseline ──
cd ~/samyama-graph-book/research/paper5-iswc-inuse/b3-neo4j-baseline
./run_baseline.sh

echo "[setup] Done. Results: $(pwd)/results.csv"
echo "[setup] Upload to S3:"
echo "  aws s3 cp results.csv s3://samyama-data/b3-neo4j-baseline/results.csv"
