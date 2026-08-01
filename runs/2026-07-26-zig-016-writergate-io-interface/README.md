# Zig 0.16 "Writergate" / I/O as an Interface — zig 0.16.0

📝 Post (KO): https://var.gg/ko/blog/zig-016-writergate-io-interface
🗓 Run: 2026-07-26 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I compiled four tiny programs on zig 0.16.0 and watched them pass or fail."*
> This directory is that run — the four sources, the harness, and the deterministic verdicts —
> so you don't have to take the claim on faith. `git clone` and `./run.sh` reproduces it.

## What this verifies

Zig 0.16.0 (released 2026-04-14) completed the standard-library I/O redesign that began in
0.15.1 — nicknamed **"Writergate"** and finished as **"I/O as an Interface"**. The interesting,
falsifiable parts are: the exact shape of the new `std.Io` write path, the *silent* footgun when
you forget to flush, and which 0.15 idioms were removed outright. Each is a **deterministic**
compile pass/fail or stdout byte count — same source + pinned compiler → same verdict.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json` / `probe-result.json`.
Claims sourced from the release notes are listed separately as *cited, not measured* — the post
marks them the same way.

### Firsthand (measured on zig 0.16.0, Windows x86_64 Threaded backend)

| Claim in the post | Evidence | Value |
|---|---|---|
| The canonical 0.16 write (`std.Io.File.stdout().writer(io,&buf)` → `interface.print` → `interface.flush`, with a Juicy Main injecting `init.io`) compiles, runs, and prints | `hello_flush.zig` → `probe-result.json.with_flush` | `"hello, writergate"`, **17 bytes** |
| The **same** program with only `flush()` removed prints **nothing** — the new writer is buffered by default and drops output on exit | `hello_noflush.zig` → `probe-result.json.without_flush` | `""`, **0 bytes** |
| Old `std.io.getStdOut()` fails at the **namespace** step — lowercase `std.io` is gone (renamed `std.Io`) | `old_api.zig` → `probe-result.json.old_api_error` | compile error: `has no member named 'io'` |
| `std.Thread.Pool` was **removed** (replaced by `std.Io` async primitives) — Writergate is about async, not cosmetics | `threadpool.zig` → `probe-result.json.thread_pool_error` | compile error: `has no member named 'Pool'` |

The flush footgun is the headline: **17 bytes vs 0 bytes**, one line of difference.

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| 0.16.0 was an ~8-month release: 244 contributors, 1,183 commits | [Zig 0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html) |
| `std.Io` targets colorless async over threaded + evented backends (Linux io_uring, macOS GCD) | Zig 0.16.0 release notes |
| `std.Io.async` / `std.Io.Group` exist in the std source | observed in the pinned 0.16.0 toolchain (io.zig) |

### Explicitly NOT verified

The Linux **io_uring** and macOS **GCD** evented backends did **not** run in this harness — all
four probes ran on the Windows x86_64 **Threaded** backend only. Their performance and behavior
are cited from the release notes, never presented as firsthand. Real async throughput and the
0.15→0.16 migration scale are qualitative/cited, not measured. This is a compile+stdout probe,
**not a speed benchmark** — the result is machine-independent.

## Environment

Windows 11 x86_64 · native zig **0.16.0** (no Docker) · `builtin.zig_version` confirmed 0.16.0.
Hardware is irrelevant here — this is compiler behavior + symbol presence, not timing.

## Reproduce

```bash
./run.sh          # fetch pinned zig 0.16.0 → probe.sh compiles the four programs
# or, if you already have it:
ZIG=/path/to/zig-0.16.0/zig ./run.sh
```

Then compare the regenerated `probe-result.gen.json` against the committed `probe-result.json`.

## Raw data

None discarded. This run has no large artifacts. The 97 MB pinned zig toolchain was received,
executed, and deleted per firsthand cleanup; `run.sh` re-fetches the same pinned 0.16.0 to
reproduce. The deterministic evidence — `probe-result.json` — is committed. See `checksums.txt`
for integrity hashes of the committed harness + evidence.

## Files

| File | What it is |
|---|---|
| `hello_flush.zig` | Canonical 0.16 stdout write, **with** `interface.flush()`. |
| `hello_noflush.zig` | Identical but **without** `flush()` — the buffered-output footgun. |
| `old_api.zig` | The 0.15 idiom `std.io.getStdOut()` — must fail to compile. |
| `threadpool.zig` | `std.Thread.Pool` — must fail to compile (removed for `std.Io` async). |
| `probe.sh` | The harness. Compiles all four, records byte counts + compile errors. |
| `probe-result.json` | Raw probe output (byte counts + the two compile errors). Deterministic. |
| `results.json` | Claim-facing summary: behaviors, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, retention policy. |
| `run.sh` | Reproduction: fetch pinned zig 0.16.0, run `probe.sh`. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
