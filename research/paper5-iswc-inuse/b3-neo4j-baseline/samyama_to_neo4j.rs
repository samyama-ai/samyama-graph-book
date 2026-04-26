// Samyama → Neo4j CSV converter
// Place this file in samyama-graph-enterprise/examples/samyama_to_neo4j.rs
//
// Usage:
//   cargo run --release --example samyama_to_neo4j -- <snapshot.sgsnap> <output_dir>
//
// Output: nodes-<Label>.csv and rels-<TYPE>.csv files for neo4j-admin database import.

use samyama::snapshot::SnapshotImporter;
use samyama::{GraphStore, NodeId};
use std::collections::{BTreeMap, BTreeSet};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: {} <snapshot.sgsnap> <output_dir>", args[0]);
        std::process::exit(1);
    }
    let snap_path = &args[1];
    let out_dir = PathBuf::from(&args[2]);
    std::fs::create_dir_all(&out_dir)?;

    eprintln!("[convert] loading snapshot: {}", snap_path);
    let mut store = GraphStore::new();
    let importer = SnapshotImporter::new();
    importer.import_file(snap_path, &mut store, "default")?;
    eprintln!(
        "[convert] loaded {} nodes / {} edges",
        store.node_count(),
        store.edge_count()
    );

    // Group nodes by label, edges by type. For each label/type, collect
    // the union of property keys so the CSV header is complete.
    let mut nodes_by_label: BTreeMap<String, Vec<NodeId>> = BTreeMap::new();
    let mut node_props: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();

    for nid in store.all_node_ids() {
        let node = match store.get_node(nid) {
            Some(n) => n,
            None => continue,
        };
        let label = node
            .labels
            .iter()
            .next()
            .map(|l| l.as_str().to_string())
            .unwrap_or_else(|| "_NoLabel".to_string());
        nodes_by_label.entry(label.clone()).or_default().push(nid);
        let entry = node_props.entry(label).or_default();
        for key in node.properties.keys() {
            entry.insert(key.clone());
        }
    }

    // Write nodes-<Label>.csv
    for (label, ids) in &nodes_by_label {
        let path = out_dir.join(format!("nodes-{}.csv", label));
        let mut w = BufWriter::new(File::create(&path)?);
        let keys: Vec<&String> = node_props[label].iter().collect();

        // Header: nodeId:ID(<Label>),<key1>,<key2>,...,<labelN>:LABEL
        write!(w, "nodeId:ID({})", label)?;
        for k in &keys {
            write!(w, ",{}", k)?;
        }
        writeln!(w, ",:LABEL")?;

        for &nid in ids {
            let node = store.get_node(nid).unwrap();
            write!(w, "{}", nid.as_u64())?;
            for k in &keys {
                let cell = node
                    .properties
                    .get(*k)
                    .map(format_value)
                    .unwrap_or_default();
                write!(w, ",{}", csv_escape(&cell))?;
            }
            // Emit all labels separated by ;
            let labels: Vec<String> = node.labels.iter().map(|l| l.as_str().to_string()).collect();
            writeln!(w, ",{}", labels.join(";"))?;
        }
        eprintln!("[convert] wrote {} ({} rows)", path.display(), ids.len());
    }

    // Edges by type
    let mut edges_by_type: BTreeMap<String, Vec<(NodeId, NodeId, BTreeMap<String, String>)>> =
        BTreeMap::new();
    let mut edge_props: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();

    for nid in store.all_node_ids() {
        for (_eid, _src, tgt, etype) in store.get_outgoing_edge_targets(nid) {
            let etype_str = etype.as_str().to_string();
            // Properties on edges (if any) — currently empty for these KGs
            let props: BTreeMap<String, String> = BTreeMap::new();
            edges_by_type
                .entry(etype_str.clone())
                .or_default()
                .push((nid, tgt, props));
            edge_props.entry(etype_str).or_default();
        }
    }

    for (etype, edges) in &edges_by_type {
        let path = out_dir.join(format!("rels-{}.csv", etype));
        let mut w = BufWriter::new(File::create(&path)?);
        let keys: Vec<&String> = edge_props[etype].iter().collect();

        // Header — START/END use polymorphic ID space; the Label suffix is omitted
        // so any node ID matches. (neo4j-admin allows this if all node CSVs use the
        // same ID space.) For per-label ID spaces, we'd need separate :START_ID(L) headers.
        write!(w, ":START_ID,:END_ID,:TYPE")?;
        for k in &keys {
            write!(w, ",{}", k)?;
        }
        writeln!(w)?;

        for (src, tgt, props) in edges {
            write!(w, "{},{},{}", src.as_u64(), tgt.as_u64(), etype)?;
            for k in &keys {
                let v = props.get(*k).cloned().unwrap_or_default();
                write!(w, ",{}", csv_escape(&v))?;
            }
            writeln!(w)?;
        }
        eprintln!("[convert] wrote {} ({} rows)", path.display(), edges.len());
    }

    eprintln!("[convert] done");
    Ok(())
}

fn format_value(v: &samyama::PropertyValue) -> String {
    use samyama::PropertyValue::*;
    match v {
        String(s) => s.clone(),
        Integer(i) => i.to_string(),
        Float(f) => f.to_string(),
        Boolean(b) => b.to_string(),
        DateTime(d) => d.to_rfc3339(),
        Null => String::new(),
        Array(a) => a.iter().map(format_value).collect::<Vec<_>>().join(";"),
        Map(_) => String::new(), // skip nested maps
    }
}

fn csv_escape(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}
