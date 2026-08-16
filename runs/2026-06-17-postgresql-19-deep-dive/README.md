# PostgreSQL 19 Beta 1 — capability & limit checks in a container

📝 Post (KO): https://var.gg/ko/blog/postgresql-19-deep-dive
🗓 Run: 2026-06-17 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ♻️ **backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran postgres:19beta1 in a throwaway container and checked what the
> headline features actually do — including where they stop."* This directory is that run —
> the method, the pinned image, and the accept/error observations — so you don't have to take
> the claim on faith. It is a **backfill**: the original container and SQL fixtures were
> removed per the finite-disk policy, so `run.sh` + `fixture/*.sql` are reconstructed from the
> recorded methodology. Because the findings are deterministic feature behaviors (a syntax
> accepts or errors, a command exists, a GUC has a fixed default), re-running against the same
> image should reproduce them. Production Cloud SQL was never touched.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json`. External docs are
separated out under *cited, not measured*.

### Firsthand (PostgreSQL 19beta1, in-container)

| Claim in the post | Evidence | Value |
|---|---|---|
| SQL/PGQ is real — `CREATE PROPERTY GRAPH` + `GRAPH_TABLE ... MATCH` parse and run, including a fixed 2-hop | `results.json` → `sql_pgq_fixed_length` · `fixture/01-sql-pgq.sql` | 1-hop + fixed 2-hop rows |
| …but **variable-length / quantified paths are unsupported** — arbitrary-depth reachability still needs a recursive CTE | `results.json` → `sql_pgq_quantifier_limit` | `quantifier -> ERROR` |
| Plan advice is **a load-time library** (`EXPLAIN (PLAN_ADVICE)`), not `CREATE EXTENSION` — and the secondary-source name is off | `results.json` → `plan_advice_library_and_extension` (`correction`) | `/* matched */` feedback |
| A separate **`pg_stash_advice` extension** stores `query_id → advice` for auto-apply (6 functions) | `results.json` → `plan_advice_library_and_extension` · `fixture/02-plan-advice.sql` | `demo\|12345\|JOIN_ORDER(d f)` |
| **REPACK is in core** (absorbs pg_repack), with a `CONCURRENTLY` option | `results.json` → `repack_in_core` · `fixture/03-repack.sql` | help text shows `CONCURRENTLY` |
| REPACK CONCURRENTLY **did not force `wal_level=logical`** here (ran at `replica`, no concurrent writer) | `results.json` → `repack_concurrently_wal_level` | 200k rows, 1082 pages |
| Parallel autovacuum is **opt-in** (`autovacuum_max_parallel_workers` default **0**) | `results.json` → `guc_defaults` · `fixture/04-guc.sql` | `0` |
| Async I/O defaults: `io_method=worker`, `io_max_concurrency=64` (restart to change) | `results.json` → `guc_defaults` | `worker` / `64` |

### Cited, not measured

- **AIO introduced in PG18** — only its default worker mode was confirmed on 19beta1 here.
- **Whether REPACK CONCURRENTLY uses logical decoding under live concurrent writes** — the
  report's mechanism claim was not driven with a concurrent writer in this run.
- **SQL/PGQ conformance breadth** beyond the fixed-length patterns tested.

## Environment

Windows 11 x64 host, Docker Desktop; PostgreSQL under test runs **inside** the container
`docker run --name pg19test postgres:19beta1` (Debian 19~beta1-1.pgdg13+1, gcc 14.2.0). This is
a capability/limit/default check, so host hardware does not change the accept/error outcomes.

> **Beta 1.** Syntax, library/extension names, the `EXPLAIN` option spelling, and GUC defaults
> **may change before GA**. Every finding is pinned to the `postgres:19beta1` image.

## Reproduce

```bash
./run.sh          # docker run postgres:19beta1 -> psql executes fixture/01..04
```

`run.sh` starts a throwaway container and runs the four SQL probes, showing the intentional
`element pattern quantifier is not supported` ERROR rather than aborting on it. Compare the
output against `results.json`.

## Raw data

**Backfill — nothing preserved from the original run.** The pulled image (`postgres:19beta1`)
and the container were removed after 2026-06-17 per the finite-disk policy, and no hashes were
captured at the time (this predates packaging). Rather than fabricate artifacts, the run ships
a **reconstructed** harness (`run.sh` + `fixture/*.sql`) built from `firsthand-benchmark.md`,
and states this openly. `results.json` holds the capabilities, limits, and two behavior
observations recorded on the day. `checksums.txt` hashes the committed harness for integrity.

## Files

| File | What it is |
|---|---|
| `run.sh` | Reconstructed harness: runs `postgres:19beta1` in Docker, executes the fixtures. |
| `fixture/01-sql-pgq.sql` | Property-graph queries + the quantifier limit. |
| `fixture/02-plan-advice.sql` | `pg_plan_advice` library + `pg_stash_advice` extension. |
| `fixture/03-repack.sql` | Core `REPACK` help + `CONCURRENTLY` on 200k rows. |
| `fixture/04-guc.sql` | Parallel-autovacuum + async-I/O GUC defaults. |
| `results.json` | Claim-facing summary: capabilities, behaviors, cited-not-measured, honest limits. |
| `manifest.json` | Environment, pinned image, `executed_by`, `backfilled`, retention policy. |
| `checksums.txt` | sha256 of the committed harness. |
