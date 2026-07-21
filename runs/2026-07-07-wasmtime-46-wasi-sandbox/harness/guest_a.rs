// EXP-A guest — does the guest have any authority it was not handed?
//
// Build:  rustc -O --target wasm32-wasip1 guest_a.rs -o guest_a.wasm
// Run:    wasmtime run --dir sandbox::/ guest_a.wasm     (one directory handed over)
//         wasmtime run guest_a.wasm                       (nothing handed over)
//
// Three probes: a file inside the preopen, a relative escape above it, and an
// absolute host path. Output labels are Korean, matching the original run's
// transcripts in observed-output.txt.
use std::fs;

fn main() {
    match fs::read_to_string("allowed.txt") {
        Ok(s) => println!("[OK]   preopen 안 allowed.txt 읽음: {:?}", s.trim()),
        Err(e) => println!("[ERR]  allowed.txt: {e}"),
    }

    match fs::read_to_string("../secret.txt") {
        Ok(s) => println!("[FAIL] 탈출 성공(../secret.txt): {:?}", s.trim()),
        Err(e) => println!("[OK]   탈출 차단(../secret.txt): {e}"),
    }

    match fs::read_to_string("/etc/hosts") {
        Ok(_) => println!("[FAIL] 절대경로 읽힘(/etc/hosts)"),
        Err(e) => println!("[OK]   절대경로 차단(/etc/hosts): {e}"),
    }
}
