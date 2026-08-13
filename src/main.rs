//! backup CLI — снапшоты каталогов в .eml с теговым реестром.
//!
//!   backup init <db>
//!   backup snap <db> <path> --name N [--tag T]...
//!   backup list <db> [query]     (default: X-Tag == "backup")
//!   backup verify <db> <snap-file>
//!   backup restore <db> <snap-file> <out-dir>
//!   backup prune <db> --older-than SECS

use std::path::PathBuf;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let code = match args.get(1).map(|s| s.as_str()) {
        Some("init") => match args.get(2) {
            Some(db) => match std::fs::create_dir_all(db) {
                Ok(()) => {
                    println!("init {}", db);
                    0
                }
                Err(e) => err(&e.to_string()),
            },
            None => err("init: need db dir"),
        },
        Some("snap") => cmd_snap(&args[2..]),
        Some("list") => cmd_list(&args[2..]),
        Some("verify") => cmd_verify(&args[2..]),
        Some("restore") => cmd_restore(&args[2..]),
        Some("prune") => cmd_prune(&args[2..]),
        _ => {
            eprintln!("backup: см. usage в шапке исходника");
            2
        }
    };
    std::process::exit(code);
}

fn flag<'a>(a: &'a [String], name: &str) -> Option<&'a String> {
    a.iter().position(|x| x == name).and_then(|i| a.get(i + 1))
}

fn cmd_snap(a: &[String]) -> i32 {
    let db = match a.get(0).map(PathBuf::from) {
        Some(p) => p,
        None => return err("snap: need db"),
    };
    let src = match a.get(1).map(PathBuf::from) {
        Some(p) => p,
        None => return err("snap: need path"),
    };
    let name = flag(a, "--name").cloned().unwrap_or_else(|| "snap".to_string());
    let mut tags = Vec::new();
    let mut i = 2;
    while i < a.len() {
        if a[i] == "--tag" {
            if let Some(t) = a.get(i + 1) {
                tags.push(t.clone());
                i += 2;
                continue;
            }
        }
        i += 1;
    }
    match backup::snap(&db, &src, &name, &tags) {
        Ok(f) => {
            println!("snapshot: {}", f.display());
            0
        }
        Err(e) => err(&e),
    }
}

fn cmd_list(a: &[String]) -> i32 {
    let db = match a.get(0).map(PathBuf::from) {
        Some(p) => p,
        None => return err("list: need db"),
    };
    let q = a.get(1).cloned().unwrap_or_else(|| "X-Tag == \"backup\"".to_string());
    match backup::list(&db, &q) {
        Ok(items) => {
            for (file, bytes, files, tags) in &items {
                println!("  {}  [{}]  {} B, {} files", file, tags.join(","), bytes, files);
            }
            println!("{} snapshot(s)", items.len());
            0
        }
        Err(e) => err(&e),
    }
}

fn cmd_verify(a: &[String]) -> i32 {
    let _db = match a.get(0).map(PathBuf::from) {
        Some(p) => p,
        None => return err("verify: need db"),
    };
    let snap = match a.get(1).map(PathBuf::from) {
        Some(p) => p,
        None => return err("verify: need snap-file"),
    };
    match backup::verify_snap(&snap) {
        Ok(issues) => {
            if issues.is_empty() {
                println!("OK: {}", snap.display());
                0
            } else {
                for i in &issues {
                    println!("BROKEN: {i}");
                }
                1
            }
        }
        Err(e) => err(&e),
    }
}

fn cmd_restore(a: &[String]) -> i32 {
    let _db = match a.get(0).map(PathBuf::from) {
        Some(p) => p,
        None => return err("restore: need db"),
    };
    let snap = match a.get(1).map(PathBuf::from) {
        Some(p) => p,
        None => return err("restore: need snap-file"),
    };
    let out = match a.get(2).map(PathBuf::from) {
        Some(p) => p,
        None => return err("restore: need out-dir"),
    };
    match backup::restore(&snap, &out) {
        Ok(n) => {
            println!("restored {n} file(s) -> {}", out.display());
            0
        }
        Err(e) => err(&e),
    }
}

fn cmd_prune(a: &[String]) -> i32 {
    let db = match a.get(0).map(PathBuf::from) {
        Some(p) => p,
        None => return err("prune: need db"),
    };
    let secs: u64 = flag(a, "--older-than").and_then(|s| s.parse().ok()).unwrap_or(7 * 86400);
    match backup::prune(&db, secs) {
        Ok(n) => {
            println!("pruned {n} snapshot(s)");
            0
        }
        Err(e) => err(&e),
    }
}

fn err(e: &str) -> i32 {
    eprintln!("backup: {e}");
    1
}
