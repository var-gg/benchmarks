# MCP 2026-07-28 spec "goes stateless" — verified against schema.json

📝 Post (KO): https://var.gg/ko/blog/mcp-2026-spec-stateless-core
🗓 Run: 2026-07-29 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims the 2026-07-28 MCP spec **drops the initialize handshake and per-session
> state** — you can now put a server behind a plain round-robin load balancer. Instead of
> re-narrating the changelog, this run checks that claim against the protocol's **own
> machine-readable `schema.json`**: it diffs the previous stable revision (`2025-11-25`)
> against the `2026-07-28` release-candidate draft and asserts, symbol by symbol, that the
> JSON-RPC types the changelog says were **removed** are gone and the ones it says were
> **added** are present. `git clone` + `./run.sh` reproduces it.

## What is checked

`probe.py` loads two published schemas and compares their top-level `$defs` (the set of
JSON-RPC message types the protocol defines):

- `schema/2025-11-25/schema.json` — the previous **stable** protocol revision. **145** `$defs`.
- `schema/draft/schema.json` — the **2026-07-28 release-candidate** line. **154** `$defs` (snapshot 2026-07-27).

Each of 20 assertions ties a specific changelog claim to a concrete symbol expected to appear
in exactly one of the two revisions. **20 / 20 passed.**

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a symbol in `probe-result.json`. Claims sourced
from the blog/changelog prose are listed separately as *cited, not measured*.

### Firsthand (schema `$defs` membership — deterministic)

| Claim in the post | Evidence | Value |
|---|---|---|
| The **initialize handshake is removed** (statelessness, SEP-2575) | `probe-result.json` → `InitializeRequest`, `InitializedNotification` | present at 2025-11-25, **absent** in draft |
| **`ping` is removed** | `probe-result.json` → `PingRequest` | present → **absent** |
| **`logging/setLevel` is removed** (logLevel moves to per-request `_meta`) | `probe-result.json` → `SetLevelRequest` | present → **absent** |
| **`resources/subscribe` is replaced by `subscriptions/listen`** | `probe-result.json` → `SubscribeRequest` (gone), `SubscriptionsListenRequest` (new) | absent ← / → present |
| **Server-initiated requests are replaced by MRTR** (SEP-2322) | `probe-result.json` → `ServerRequest` (gone), `InputRequiredResult` + `ResultType` (new) | absent ← / → present |
| **Tasks move out of core into an extension** (SEP-2663) | `probe-result.json` → `Task`, `CreateTaskResult`, `ListTasksRequest`, `GetTaskRequest` | all present → **absent** |
| **`server/discover` is added** for up-front version negotiation (SEP-2575) | `probe-result.json` → `DiscoverRequest`, `DiscoverResult` | absent → **present** |
| **Cacheable results** (`ttlMs` / `cacheScope`) are added (SEP-2549) | `probe-result.json` → `CacheableResult` | absent → **present** |
| **New explicit error types** for version/header mismatch (SEP-2575 / SEP-2243) | `probe-result.json` → `UnsupportedProtocolVersionError`, `HeaderMismatchError` | absent → **present** |
| Net symbol count grew **145 → 154** across the revision | `probe-result.json` → `compared` | 145 → 154 (`removed_defs` 32, `added_defs` 41) |

Full symbol lists: `probe-result.json` → `removed_defs` (32) / `added_defs` (41).

### Cited, not measured (the post flags these the same way)

| Claim | Source |
|---|---|
| The RC locked 2026-05-21 and published 2026-07-28 | [MCP blog: 2026-07-28 RC](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/) |
| Per-SEP rationale (SEP-2575 / 2322 / 2663 / 2549 / 2243) | [MCP draft changelog](https://modelcontextprotocol.io/specification/draft/changelog) |

### Explicitly NOT verified

- **Runtime interop.** Schema presence/absence is not behavior. `InitializeRequest` is gone
  from the schema — that real servers/SDKs actually interoperate *handshake-free end-to-end*
  is **not** exercised here (SDK Tier-1 support is cited).
- **Auth hardening** (RFC 9207 `iss` validation), **MCP Apps sandbox iframe**, and
  **deprecation-window governance** are confirmed to exist in the doc/schema only — runtime
  not exercised.
- **Performance.** "Runs behind a round-robin LB" and `tools/list` caching are the spec's
  design intent, cited — no load was measured.

## Honest limit — the draft is a moving target

`schema/draft/schema.json` is **mutable**: it kept changing until the 2026-07-28 publish, and
afterward `draft` advances to the next revision. The committed `probe-result.json` is the
**2026-07-27 snapshot**. Re-running `./run.sh` fetches whatever `draft` is *now*, so the
draft-axis symbols may differ — `git diff -- probe-result.json` shows that drift, which is
part of the finding. The `2025-11-25` axis is frozen and reproduces exactly.

## Environment

Windows 11 x64 · native (no Docker) · Python 3.11 · stdlib only (`urllib` + `json`). Hardware
is irrelevant — this observes schema symbol membership, not timing.

## Reproduce

```bash
./run.sh                       # fetches both schemas, runs the 20 assertions
git diff -- probe-result.json  # deltas vs the committed 2026-07-27 snapshot (draft drift is expected)
```

## Raw data

The two schema snapshots (174 KB + 180 KB) are **not committed** — they exceed the repo's
100 KB per-run budget and the draft is mutable. The deterministic evidence —
`probe-result.json` (20/20 assertion matrix + full `removed_defs`/`added_defs`) — is committed.
`run.sh` re-fetches the schemas. See `checksums.txt` for integrity hashes.

## Files

| File | What it is |
|---|---|
| `probe.py` | The harness. Fetches both schemas and asserts 20 changelog-claim ↔ `$defs`-symbol mappings. Pure stdlib. |
| `probe-result.json` | Committed evidence: the 20-assertion matrix + `removed_defs` (32) / `added_defs` (41). 2026-07-27 snapshot. |
| `results.json` | Claim-facing summary: removed/added groupings, not-measured axes, cited-vs-measured split, drift note. |
| `manifest.json` | Environment, compared revisions, `executed_by`, retention policy. |
| `run.sh` | Reproduction entry point (fetch → probe → diff instructions). |
| `checksums.txt` | sha256 of the committed harness + evidence. |
