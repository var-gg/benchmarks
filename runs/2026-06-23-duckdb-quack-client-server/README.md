# DuckDB quack — the in-process OLAP engine turned client-server

📝 Post (KO): https://var.gg/ko/blog/duckdb-quack-client-server
🗓 Run: 2026-06-23 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ♻️ **backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I stood up a `quack_serve` server, attached to it from a second DuckDB,
> and probed what the client-server session actually supports."* This directory is that run —
> the harness, the environment, and the observed behavior matrix — so you don't have to take
> the claims on faith. `git clone` and `./run.sh` reproduces the capability outcomes on the
> pinned DuckDB build.

## Backfill honesty

This run executed on **2026-06-23** against **DuckDB v1.5.3 (Variegata)** + the **quack** core
extension on a single Windows machine over loopback. Its harness (the SQL scripts + the
`quack_serve` invocation) lived in a gitignored `tmp/` dir and was deleted after publish per
the finite-disk firsthand policy. The harness committed here (`server.sql` + `client.sql` +
`concurrent_writers.sh` + `run.sh`) is **reconstructed** from the run's recorded methodology so
a third party can reproduce the capability claims. `results.json` holds the qualitative
behavior matrix **observed on 2026-06-23**; re-running reproduces the same pass/fail and
exact-error outcomes. The Section 5 latency numbers are machine-dependent context, never an
evidence claim.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a row in `results.json`.

### Firsthand (observed on DuckDB v1.5.3 + quack, loopback)

| Claim in the post | Evidence | Value |
|---|---|---|
| After `ATTACH`, the client reads remote tables transparently | `results.json` → `1_basic_roundtrip` | hello 2 rows · big `count(*)` = 1,000,000 |
| Auth is a shared token: valid attaches, **wrong token / no secret fail with distinct errors** | `results.json` → `2_auth` | `Authentication failed` / `Could not find a Quack authentication token` |
| The remote write surface is **append + DDL**, not arbitrary mutation: `INSERT`/`CREATE`/`DROP`/`SELECT` work but **direct `UPDATE`/`DELETE` fail** | `results.json` → `3_remote_write_surface` | `Binder Error: Can only update/delete base table` |
| `UPDATE`/`DELETE` aren't impossible — only the direct grammar is un-wired; **`remote.query('… RETURNING *')` works server-side** | `results.json` → `3b_update_delete_serverside_workaround` | matches quack issue #176 |
| A remote **`BEGIN; INSERT; ROLLBACK` leaves the row in place** — the rollback is not propagated | `results.json` → `3c_transaction_rollback_not_propagated` | before 0 → after 1 · matches issue #173 |
| Two **separate processes** appending concurrently both commit, no row loss / lockout | `results.json` → `4_concurrent_writers` | +10,000 rows (A 5000 / B 5000) |
| Killing the server surfaces a **connect error immediately**, not a silent hang | `results.json` → `6_server_failure` | `Could not connect to server` IO Error |

The headline finding: quack turns the in-process OLAP DuckDB into a **client-server pair where
both ends are DuckDB**, but in v1.5.3 the "multiplayer" story is bounded — concurrent append
and DDL yes, direct remote `UPDATE`/`DELETE` and propagated `ROLLBACK` no.

### Cited, not measured (flagged in the post too)

| Claim | Source |
|---|---|
| quack is "~3.5× faster than Arrow Flight" | official quack materials; a different-wire-protocol comparison — no Arrow Flight baseline was run here. The absolute cost of leaving in-process zero-copy (0ms → 0.5–1s over loopback) is what Section 5 shows. |
| Stable release target is v2.0 (2026-09) | project roadmap at time of writing; v1.5.3 is beta. |

This is the honest limit: this run verifies the **client-server capability surface** on one
loopback machine, not multi-host throughput or the Arrow Flight comparison.

## Environment

Windows 11 · DuckDB **v1.5.3 (Variegata)**, amd64 CLI · quack core extension (autoload) ·
single machine, loopback. Hardware is irrelevant to the pass/fail matrix; Section 5 latency is
context only.

**Windows trap:** `localhost` binds to IPv6 `::1`, so an IPv4 `127.0.0.1:9494` port probe is a
false negative. The client resolves `quack:localhost` the same way and works anyway.

## Reproduce

```bash
./run.sh   # boots server.sql → runs client.sql probes → concurrent_writers.sh
```

Requires the DuckDB v1.5.3 CLI on PATH. `INSTALL quack` fetches the extension from the network
once. Then compare the output against `results.json`.

## Files

| File | What it is |
|---|---|
| `server.sql` | Boots the quack server with seed tables (`hello`, `big`, `t`, `upd_probe`, `tx_probe`). |
| `client.sql` | The capability probes: auth, round-trip, remote DML/DDL surface, server-side `UPDATE`, ROLLBACK propagation. |
| `concurrent_writers.sh` | Section 4: two processes append 5000 rows each; asserts +10,000, no loss. |
| `run.sh` | Reproduction driver (server bg → client → concurrency). |
| `results.json` | Claim-facing matrix: auth, remote surface, transaction semantics, concurrency, latency (context), server failure. |
| `manifest.json` | Environment, versions, `executed_by`, `backfilled`, retention policy. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
