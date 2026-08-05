# Microsoft Coreutils for Windows 2026.6.16 — dialect dispatch & cross-tool behavior

📝 Post (KO): https://var.gg/ko/blog/coreutils-for-windows
🗓 Run: 2026-06-26 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ⚠️ **backfilled** (see `manifest.json`)
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I installed Microsoft Coreutils on native Windows and ran grep/find/sort
> against System32, PowerShell, and Git Bash."* This directory is that experiment — the
> fixtures, the harness, and the observed behavior matrix — so you don't have to take the
> claims on faith. On Windows + Git Bash, `./run.sh` reproduces it against pinned
> **Coreutils 2026.6.16**.

## Backfill honesty

This run directory was authored on 2026-08-06 from the firsthand notes taken during the
original 2026-06-26 experiment. The original ad-hoc scripts and the downloaded binary were
removed by the post-publish cleanup policy, so `run.sh`/`probe.sh` here are a **reconstructed**
harness that recreates the exact fixtures and re-runs the same commands against the pinned
binary. `results.json` records the 2026-06-26 observations; the harness lets you re-confirm
them. Nothing here is a fabricated measurement — where something was reported by Microsoft docs
rather than measured, it is split out as *cited, not measured*.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to an entry in `results.json.behaviors_verified`
and a step in `probe.sh`.

### Firsthand (observed on Coreutils 2026.6.16, native Windows 11)

| Claim in the post | Evidence | Value |
|---|---|---|
| One multi-call binary picks **DOS vs Unix dialect from argument shape** (`find /C` vs `find -type f`, `sort /R` vs `sort -n`) | `results.json` → `dual_dispatch_shim` + `probe.sh` | confirmed |
| coreutils `find` (tree walk) and System32 `find.exe` (in-file search) are **semantically opposite**; GNU-style args mis-parse on System32 find | `dual`… → `find_semantic_collision` | confirmed |
| The binary does its **own Windows-CRT argv globbing**, which breaks `find -name *.txt` unless quoted — and quote-survival differs cmd vs PowerShell | `argv_wildcard_globbing` | confirmed |
| Numeric sort splits three ways; only coreutils `sort -n` is truly numeric | `numeric_sort_three_way` | 2,9,10,30,100 vs 10,100,2,30,9 |
| coreutils sort is **locale-aware and `LC_ALL=C` does not force byte order** — the CI `LC_ALL=C sort` determinism trick may not hold | `locale_collation_trap` | confirmed via `od` bytes |
| Line endings handled differently per tool: **grep strips `\r`, sort preserves `\r\n`**; `wc -c` exposes the 30-vs-26 byte delta | `crlf_handling_divergence` | 30B / 26B |
| grep 0.1.0 does **ERE (`-E`) and PCRE (`-P`)** but has no LANG/localization yet | `grep_regex_modes` | match / match |

### Cited, not measured (flagged the same way in the post)

| Claim | Why not measured |
|---|---|
| uutils GNU test-suite compat (0.8.0 ~94.7%, 0.9.0 ~90.6%) | a **Linux** figure, not Windows end-to-end |
| install = hardlinks + PowerShell-profile + registry settings | unattended run used argv0 **shim copies** (behavior-equivalent) and did not install |

### Approximate, explicitly NOT a claim

A single warm run on a 600k-line / 28.6MB file put coreutils and Git Bash in the **same order
of magnitude** (grep ~109ms vs ~67ms; sort ~135ms vs ~130ms). Timing is hardware/cache
dependent and is **not committed as a benchmark number** — the post makes no performance-win
claim. Regenerate with `WITH_BIG=1 ./run.sh` if you want to see it locally.

## Environment

Windows 11 Pro 26200 (ko-KR) · native `cmd.exe` + PowerShell + Git Bash, no Docker ·
Microsoft Coreutils **2026.6.16** (uutils 0.8.0, grep 0.1.0).

## Reproduce

```bash
# Git Bash on Windows:
./run.sh                 # obtain pinned coreutils → build argv0 shims → fixtures → probe
WITH_BIG=1 ./run.sh      # also generate the 28MB perf fixture (optional)
```

`run.sh` finds `coreutils.exe` on PATH, or downloads the pinned portable zip if you set
`COREUTILS_ZIP_URL` (confirm the exact `2026.6.16` x64 asset on the microsoft/coreutils
releases page). Then compare `probe-output.txt` against `results.json`.

## Files

| File | What it is |
|---|---|
| `fixtures.sh` | Recreates the byte-exact CRLF/LF/nums/case fixtures (asserts 30B/26B). |
| `probe.sh` | The harness. Runs coreutils vs System32/PowerShell/Git Bash and prints a labelled transcript. |
| `run.sh` | Obtains the pinned binary, builds argv0 shims, runs fixtures + probe. |
| `results.json` | Claim-facing behavior matrix + cited-vs-measured split + honest limits. |
| `manifest.json` | Environment, versions, `executed_by`, `backfilled`, retention policy. |
| `checksums.txt` | sha256 of the committed harness + evidence. |

Fixtures, shims, and `probe-output.txt` are `.gitignore`d — regenerable, and committing the
CRLF fixtures would let git mangle the very bytes under test.
