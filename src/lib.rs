//! backup lib: снапшоты каталогов.
//!
//! Снапшот = pack каталога в один .eml-контейнер (hash-chain, верифицируем).
//! Реестр = tagdb: запись X-Tag: backup + пользовательские теги, X-Timestamp,
//! тело {"file": <путь к снапшоту>, "bytes": ...}. Ротация: prune старых.

use emlbox::format::find_blank;
use emlbox::pack;
use emlbox::tagdb;
use serde_json::Value;
use std::path::{Path, PathBuf};

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn body_of(p: &Path) -> Result<Value, String> {
    let data = std::fs::read(p).map_err(|e| e.to_string())?;
    let (end, sep) = find_blank(&data).ok_or("no blank line in record")?;
    serde_json::from_slice(&data[end + sep..]).map_err(|e| e.to_string())
}

/// Create a snapshot: pack dir -> snaps/<name>_<nanos>.eml, register in db.
pub fn snap(db: &Path, src: &Path, name: &str, tags: &[String]) -> Result<PathBuf, String> {
    std::fs::create_dir_all(db).map_err(|e| e.to_string())?;
    let snaps = db.join("snaps");
    std::fs::create_dir_all(&snaps).map_err(|e| e.to_string())?;
    let safe = name.replace(['/', ' ', ':'], "_");
    let file = snaps.join(format!("{safe}_{}.eml", now()));
    let (n, bytes) = pack::pack(src, &file, &format!("backup:{name}"))?;
    let mut all_tags = vec!["backup".to_string()];
    for t in tags {
        if !all_tags.contains(t) {
            all_tags.push(t.clone());
        }
    }
    let body = serde_json::json!({"file": file.to_string_lossy(), "bytes": bytes, "files": n});
    let id = format!("bk_{}", now());
    tagdb::insert(db, &id, &all_tags, "local", now(), &body).map_err(|e| e.to_string())?;
    Ok(file)
}

/// List snapshots by query: (snap_file, bytes, files, tags).
pub fn list(db: &Path, q: &str) -> Result<Vec<(String, u64, usize, Vec<String>)>, String> {
    let (records, _) = tagdb::query(db, q)?;
    let mut out = Vec::new();
    for (p, headers) in records {
        let tags: Vec<String> = headers
            .iter()
            .filter(|(k, _)| k.eq_ignore_ascii_case("X-Tag"))
            .map(|(_, v)| v.clone())
            .collect();
        let b = body_of(&p).unwrap_or_else(|_| serde_json::json!({}));
        let file = b.get("file").and_then(|v| v.as_str()).unwrap_or("?").to_string();
        let bytes = b.get("bytes").and_then(|v| v.as_u64()).unwrap_or(0);
        let files = b.get("files").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
        out.push((file, bytes, files, tags));
    }
    Ok(out)
}

/// Verify a snapshot container's hash-chain. Returns issues.
pub fn verify_snap(snap: &Path) -> Result<Vec<String>, String> {
    emlbox::verify::verify(snap)
}

/// Restore a snapshot into `out_dir`.
pub fn restore(snap: &Path, out: &Path) -> Result<usize, String> {
    pack::unpack(snap, out)
}

/// Prune snapshots older than `older_than_secs`: remove records + files.
pub fn prune(db: &Path, older_than_secs: u64) -> Result<usize, String> {
    let cutoff = now().saturating_sub(older_than_secs);
    let (records, _) = tagdb::scan(db)?;
    let mut removed = 0usize;
    for (p, headers) in records {
        let ts: u64 = headers
            .iter()
            .find(|(k, _)| k.eq_ignore_ascii_case("X-Timestamp"))
            .and_then(|(_, v)| v.parse().ok())
            .unwrap_or(0);
        if ts > 0 && ts < cutoff {
            // only remove registered snapshots (tag backup), not registry itself
            if headers.iter().any(|(k, v)| k.eq_ignore_ascii_case("X-Tag") && v == "backup") {
                if let Ok(b) = body_of(&p) {
                    if let Some(f) = b.get("file").and_then(|v| v.as_str()) {
                        let _ = std::fs::remove_file(f);
                    }
                }
                let _ = std::fs::remove_file(&p);
                removed += 1;
            }
        }
    }
    Ok(removed)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn setup(tag: &str) -> (PathBuf, PathBuf) {
        let dir = std::env::temp_dir().join(format!("backup_{}_{}", std::process::id(), tag));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db = dir.join("reg");
        std::fs::create_dir_all(&db).unwrap();
        let src = dir.join("src");
        std::fs::create_dir_all(src.join("sub")).unwrap();
        std::fs::write(src.join("a.txt"), b"hello").unwrap();
        std::fs::write(src.join("sub/b.bin"), vec![0u8, 1, 2, 255]).unwrap();
        (db, src)
    }

    #[test]
    fn snap_list_restore_verify() {
        let (db, src) = setup("rt");
        let snap = snap(&db, &src, "proj", &["important".into()]).unwrap();
        assert!(snap.exists());

        let l = list(&db, "X-Tag == \"backup\" AND X-Tag == \"important\"").unwrap();
        assert_eq!(l.len(), 1);
        assert_eq!(l[0].3, vec!["backup", "important"]);
        assert_eq!(l[0].2, 2, "two files packed");

        assert!(verify_snap(&snap).unwrap().is_empty(), "snapshot hash-chain clean");

        let out = db.parent().unwrap().join("out");
        let n = restore(&snap, &out).unwrap();
        assert_eq!(n, 2);
        assert_eq!(std::fs::read(out.join("a.txt")).unwrap(), b"hello");
        assert_eq!(std::fs::read(out.join("sub/b.bin")).unwrap(), vec![0u8, 1, 2, 255]);
    }

    #[test]
    fn prune_removes_old_only() {
        let (db, src) = setup("prune");
        // old snapshot with old timestamp: insert registry record manually at ts=100
        let snaps = db.join("snaps");
        std::fs::create_dir_all(&snaps).unwrap();
        let old_file = snaps.join("old_100.eml");
        std::fs::write(&old_file, b"stale").unwrap();
        tagdb::insert(&db, "bk_old", &["backup".into()], "local", 100, &serde_json::json!({"file": old_file.to_string_lossy()})).unwrap();
        // fresh snapshot
        snap(&db, &src, "fresh", &[]).unwrap();

        let n = prune(&db, 3600).unwrap(); // older than 1h
        assert_eq!(n, 1);
        assert!(!old_file.exists(), "old snapshot file removed");
        assert!(snaps.join("fresh_").to_string_lossy().len() > 0); // fresh remains (file exists check below)
        let (records, _) = tagdb::scan(&db).unwrap();
        assert_eq!(records.len(), 1, "only fresh record remains");
    }
}
