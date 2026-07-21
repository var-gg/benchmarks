# Wasmtime 46 WASI permissions — a read-only file, rewritten through a hard link

📝 Post (KO): https://var.gg/ko/blog/wasmtime-46-wasi-sandbox
🗓 Run: 2026-07-01 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I handed a WASI guest a directory whose file contents were read-only,
> and on Wasmtime 46.0.0 the guest rewrote a protected file anyway — by hard-linking it
> into a writable preopen. On 46.0.1 the same guest was refused."* This directory is that
> run: the host embedding, the guest programs, and the console transcripts.
> [GHSA-4ch3-9j33-3pmj](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-4ch3-9j33-3pmj).

⚠️ **Backfilled.** The experiments ran 2026-07-01; this directory was packaged 2026-07-22.
The host source and the transcripts are preserved verbatim. The two guest programs, the host
`Cargo.toml` and `run.sh` were **re-authored** from the run notes so a third party can re-run
the method — they are not byte-preserved originals. No hashes of the original binaries were
captured at run time. See `manifest.json → backfill_note`. Said plainly rather than dressed up.

## Claim ↔ evidence

### Firsthand (observed 2026-07-01 — transcripts in `observed-output.txt`)

| Claim in the post | Evidence | Value |
|---|---|---|
| A WASI guest has **no ambient authority** — without a preopen, a file that exists on disk does not exist to the guest | `observed-output.txt` → EXP-A, second transcript | `allowed.txt` → *No such file or directory (os error 44)* with no `--dir` |
| The preopen **is** the boundary: inside reads, `../` escape is a permission violation, absolute host paths are invisible | `observed-output.txt` → EXP-A, first transcript | `"allowed-content-123"` · `../secret.txt` → os error 63 · `/etc/hosts` → os error 44 |
| On **46.0.0**, a `FilePerms::READ` file is rewritten via a hard link into a `FilePerms::all()` preopen | `observed-output.txt` → EXP-C, 46.0.0 | step1 BLOCKED · step2 **LINKED** · step3 WROTE · step4 **`"MODIFIED-VIA-LINK"`** |
| On **46.0.1**, the link itself is refused and the protected original survives | `observed-output.txt` → EXP-C, 46.0.1 | step2 **BLOCKED** (os error 63) · step4 `"SECRET-readonly-original"` |
| **"The write succeeded" is not a security signal** — step 3 prints `WROTE` on both versions and means opposite things | same transcripts, step 3 vs step 4 | identical step-3 line, opposite step-4 content |

The decisive precondition is the preopen config, and it is deliberate:
`ro` = `DirPerms::all()` + `FilePerms::READ` — *you may tidy the directory, you may not rewrite
the files*. Give `ro` only `DirPerms::READ` and the link's source side is already refused, so
the bug cannot appear at all. The vulnerable configuration is the realistic one.

### Cited, not measured (flagged the same way in the post)

| Claim | Source |
|---|---|
| The vulnerable code checked directory-mutation permission only, never that file permissions matched; `rename` was affected the same way; symlinks were not | [GHSA-4ch3-9j33-3pmj](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-4ch3-9j33-3pmj) |
| The `wasmtime` CLI is unaffected because it always sets `FilePerms::all()` | Same advisory. Consistent with the CLI's `--dir` help text observed here (no read-only flag), but not independently read out of the source |
| Affected `<24.0.11`, `25.0.0–<36.0.12`, `37.0.0–<45.0.3`, `46.0.0` → patched `24.0.11 / 36.0.12 / 45.0.3 / 46.0.1`; CVSS 6.5 Moderate | Same advisory |
| WASI 0.3.0 ratified 2026-06-11; Wasmtime 46.0.0 is the first release with it on by default | [WASI 0.3 announcement](https://bytecodealliance.org/articles/WASI-0.3) + v46.0.0 release notes |

### Explicitly NOT verified

Only the **46.0.0 ↔ 46.0.1** boundary was executed — the 24.x / 36.x / 45.x branches are cited.
Only **`wasm32-wasip1`** (preview1); preview2/component guests were not run. Only **`hard_link`**;
`rename`, which the advisory names as the same class, was not exercised. Only **Windows 11** —
hard-link and rename semantics vary by host OS.

## Environment

Windows 11 (native, no WSL) · rustc 1.95 · target `wasm32-wasip1` · no Docker ·
`wasmtime 46.0.0 (423be7a4e 2026-06-22)` and `46.0.1 (823d1b8f2 2026-06-24)`, official release
binaries for the CLI experiment and exact crate pins (`=46.0.0` / `=46.0.1`) for the host.
Hardware is irrelevant — this is a permission-boundary check, not a timing benchmark.

## Reproduce

```bash
./run.sh          # toolchain check → EXP-A (CLI) → EXP-C (host built twice, 46.0.0 then 46.0.1)
```

`run.sh` downloads the two pinned wasmtime releases, builds both guests to `wasm32-wasip1`,
builds the embedding host once per pinned crate version, and runs each against a **fresh**
`ro/secret.txt`. Everything lands in a `.gitignore`d `work/`. Compare its output to
`observed-output.txt`.

Requires network (release downloads + crates.io) and a Rust toolchain. Note that the CVE cannot
be reproduced through the `wasmtime` CLI at all — the CLI grants every preopen full file
permissions, so there is no read-only side to bypass. You need the embedding host.

## Files

| File | What it is |
|---|---|
| `harness/host/src/main.rs` | The embedding host. **Preserved verbatim** from the original run — the two preopens with different `FilePerms` are the experiment. |
| `harness/host/Cargo.toml` | Exact crate pins; `run.sh` rewrites them to switch versions. Reconstructed. |
| `harness/guest_a.rs` | EXP-A guest: read inside the preopen, escape with `../`, read an absolute path. Reconstructed. |
| `harness/guest_cve.rs` | EXP-C guest: direct write → hard link → write through the link → read the original back. Reconstructed. |
| `run.sh` | Third-party entrypoint: fetch pinned runtimes, build, run both versions. |
| `observed-output.txt` | The original 2026-07-01 console transcripts, verbatim. The evidence. |
| `results.json` | Claim-facing summary: preconditions, behaviors, cited-vs-measured, not-verified. |
| `manifest.json` | Environment, versions, advisory metadata, `backfilled` provenance. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
