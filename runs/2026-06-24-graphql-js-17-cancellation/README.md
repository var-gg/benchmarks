# GraphQL.js v16 vs v17 — cancellation, cleanup & observability

📝 Post (KO): https://var.gg/ko/blog/graphql-js-17-cancellation
🗓 Run: 2026-06-24 firsthand · re-executed 2026-08-08 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran v16 and v17 side by side and watched what abort() actually does."*
> This directory is that run — the harness, the pinned versions, and the raw event logs — so
> you don't have to take the claim on faith. `git clone` and `./run.sh` reproduces it.
>
> The original 2026-06-24 harness was deleted post-publish (finite-disk policy), but this is a
> pure-local Node benchmark and the host still runs the exact recorded Node build (v24.15.0),
> so the harness was re-authored from the recorded methodology and **genuinely re-executed** on
> 2026-08-08. `probe-result.json` is that re-run's real output, not a reconstruction — see
> `manifest.json.rerun_note`. Every contract below reproduced.

## Claim ↔ evidence

Both versions load in one process via npm aliases (`graphql-v16` = `graphql@16.14.2`,
`graphql-v17` = `graphql@17.0.1`). The evidence is the **contracts** — throw vs resolve, event
ordering, channel payloads — not milliseconds.

### Firsthand (measured — graphql 16.14.2 baseline vs 17.0.1 subject)

| Claim in the post | Evidence | Value |
|---|---|---|
| v16 **silently ignores** an `abortSignal`; both fields resolve and `info.getAbortSignal` doesn't exist | `probe-result.json` → `experiment1_cancel_ab.v16` | `resolved`, `getAbortSignal:undefined` |
| v17 `execute({abortSignal})` **throws `AbortedGraphQLExecutionError`** the instant abort fires | `probe-result.json` → `experiment1_cancel_ab.v17` | `threw AbortedGraphQLExecutionError` |
| v17 cancellation is **cooperative**: the executor stops waiting, but child work only stops if the resolver forwards `info.getAbortSignal()` | `experiment1_cancel_ab.v17.events` | `db:abort:coop` (cancelled) **and** `db:done:slow` fires after abort (orphan) |
| **Cancel ≠ rollback**: a mid-flight mutation still commits already-started writes; the caller only gets the error | `experiment2_cancel_not_rollback_v17` | `A:wrote` + `B:wrote` despite abort; `isAborted:true` |
| v17 exposes a **`diagnostics_channel` TracingChannel** surface with a rich per-field `resolve` payload | `experiment3_diagnostics_v17` | channels fired in order; resolve keys = `alias,args,fieldName,fieldPath,fieldType,isDefaultResolver,parentType` |
| On abort, v17 preserves the partial result via **`error.abortedResult`** and the reason via `error.cause` | `experiment4_partial_result_v17` | `cause='client gone'`, `abortedResult.data = {fast:'FAST', slow:null}` |

### Cited, not measured (flagged the same way in the post)

| Claim | Source |
|---|---|
| Tracing is zero-overhead with no subscribers (`shouldTrace` gates on `channel.hasSubscribers`) | graphql 17 `diagnostics.mjs` source — this run always had subscribers, so the no-subscriber cost was read, not timed |
| Whether a real DB driver honors an `AbortSignal` depends on the driver | the probe proves the propagation **mechanism** with a `setTimeout` fake DB; real-driver cooperation is a post caveat |
| `@defer` / `@stream` incremental delivery is a separate experimental surface | GraphQL.js v17 release notes — out of scope |

### Honestly not verified here

`graphql:validate` did **not** fire in this run because the probe calls `execute()` on a
pre-parsed document — validation is a separate stage. The full `parse → validate → execute`
chain shows up only through `graphql()`/the whole pipeline. Stated plainly rather than papered over.

## Environment

Windows 11 · Node **v24.15.0** · npm 11.12.1 · plain Node, single process, no network/DB/GPU.
Hardware is irrelevant — these are engine contracts, not throughput. The `309ms` (v16 full
resolve) vs `91ms` (v17 abort-throw) figures in `results.json.timings_context_only` are context, not evidence.

## Reproduce

```bash
./run.sh          # npm install (pinned 16.14.2 + 17.0.1) → node probe.mjs
```

Then compare the regenerated `probe-result.json` against the committed `results.json`.

## Files

| File | What it is |
|---|---|
| `probe.mjs` | The harness. Runs all four contracts against both versions in one process. |
| `package.json` | Pins both graphql versions via npm aliases. |
| `probe-result.json` | Raw probe output (event logs + contract outcomes). Deterministic ordering. |
| `results.json` | Claim-facing summary: behaviors, cited-vs-measured split, context-only timings. |
| `manifest.json` | Environment, versions, `executed_by`, `rerun_note`, retention policy. |
| `run.sh` | Reproduction entry point. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
