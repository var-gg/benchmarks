# Node.js 26 — Temporal (default global) vs legacy Date — v26.4.0

📝 Post (KO): https://var.gg/ko/blog/nodejs-26-temporal-default · (EN): https://var.gg/en/blog/nodejs-26-temporal-default
🗓 Run: 2026-06-29 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran it on Node 26.4.0 — Temporal is a global with no flag, and here's
> exactly how it differs from `Date`."* This directory is that run: the harness (`exp.mjs`),
> the pinned build, and the raw output. `git clone` and `./run.sh` reproduces it.

> **Honesty note (backfill).** The post published 2026-06-30 from a firsthand run on
> 2026-06-29; the original throwaway harness was not kept, only the recorded notes. `exp.mjs`
> here is a faithful reconstruction that was **re-run on a fresh, official Node v26.4.0** while
> packaging — `probe-result.json` is that genuine fresh output, and every value matches the
> 2026-06-29 record. These are deterministic language behaviors on a pinned build, so this is
> reproducible, not transcribed. See `manifest.json.backfill_note`.

## Claim ↔ evidence

Every **firsthand** claim maps to a field in `results.json` / `probe-result.json`. Claims from
external references (release dates, LTS cadence) are listed separately as *cited, not measured* —
the post marks them the same way.

### Firsthand (measured on Node 26.4.0)

| Claim in the post | Evidence | Value |
|---|---|---|
| `Temporal` is a top-level global with **no flag** | `probe-result.json.temporal_global` | `true` |
| `Date` months are **0-based**, `Temporal` months **1-based** | `.month_indexing` | arg `6` → "July"; `month:7` → `2026-07-29` |
| `Date.setMonth` **mutates in place**; `PlainDate.add` returns a **new** value | `.mutability` | `2026-07-29`→`2026-08-29` (same obj) vs original preserved |
| Across DST spring-forward, **calendar `+1 day` (12:00)** ≠ **physical `+24h` (13:00)**; legacy ms math is DST-blind (13:00) | `.dst` | `12` vs `13` vs `13` |
| Jan 31 **+ 1 month**: `Date` rolls to **Mar 03**, Temporal **constrains to Feb 28**, `reject` **throws** | `.month_end_overflow` | `2026-03-03` / `2026-02-28` / `RangeError` |
| `new Date('2026-06-29')` = UTC midnight; `'2026/06/29'` = **local** midnight; `PlainDate` is **tz-free** | `.parsing` | epochs differ; `PlainDate` `2026-06-29` |
| The **four Temporal types** all present | `.types_present` | Instant/PlainDate/PlainDateTime/ZonedDateTime → `true` |
| V8 14.6 extras: `Map.getOrInsert`, `getOrInsertComputed`, `Iterator.concat` | `.v8_146` | 3 / 3 `true` |
| Node 26 **removes** `http…writeHeader` and `_stream_wrap` | `.removals` | removed / `MODULE_NOT_FOUND` |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Node 26.0.0 released 2026-05-05; latest 26.x = v26.4.0 (2026-06-24) | [nodejs.org](https://nodejs.org/en/blog/release/v26.0.0) |
| Temporal default global via nodejs/node #61806 | [release tag](https://github.com/nodejs/node/releases/tag/v26.0.0) |
| LTS in 2026-10; Node 27+ annual-major (April), all LTS | [InfoQ](https://www.infoq.com/news/2026/06/nodejs-release-changes/) |
| Drops Python 3.9 build support, needs GCC 13.2+, `--experimental-transform-types` removed | Node 26 changelog |

### Explicitly NOT verified

Only run on Windows x64. Temporal/`Date` behavior is platform-independent by spec, but the
harness was not executed on Linux/macOS here (`run.sh` supports all three). The LTS timeline and
release-cadence claims are documentation facts, not harness observations.

## Environment

Windows 11 · official portable **Node v26.4.0** (V8 14.6.202.34-node.21, undici 8.5.0, uv 1.52.1,
`NODE_MODULE_VERSION` 147) · no network, no deps. This is a behavior check, not a timing benchmark —
hardware is irrelevant. `probe-result.json` reports `tz "(unset)"` because the harness TZ export
did not reach the Windows `node.exe` child; the system clock is Asia/Seoul, so the two parsing rows
still resolved against KST. On POSIX, `run.sh`'s `export TZ=Asia/Seoul` propagates normally.

## Reproduce

```bash
./run.sh    # downloads pinned node v26.4.0 into ./.node, runs exp.mjs
```

Then compare the regenerated `probe-result.json` against `results.json`. On a UTC-only machine the
slash-vs-ISO parsing rows coincide — that's why `run.sh` pins `TZ=Asia/Seoul`.

## Raw data

None discarded. The run produces no large artifacts. The downloaded node binary (~120 MB extracted)
is **not** committed — `run.sh` re-fetches the pinned official build into `./.node` (gitignored).
The deterministic evidence — `probe-result.json` — is committed. Integrity hashes are in
`checksums.txt`.

## Files

| File | What it is |
|---|---|
| `exp.mjs` | The harness. Pure Node stdlib (ESM), no deps. Runs all nine checks, writes `probe-result.json`. |
| `probe-result.json` | Raw harness output (behavior matrix + reported runtime versions). Deterministic. |
| `results.json` | Claim-facing summary: behaviors verified + cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, backfill note, retention policy. |
| `run.sh` | Reproduction (fetches pinned v26.4.0 per-OS). |
| `checksums.txt` | sha256 of the committed harness + evidence. |
