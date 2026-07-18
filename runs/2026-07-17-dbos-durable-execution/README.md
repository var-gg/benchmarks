# DBOS Transact 2.27.0 — does killing the process really resume the workflow?

📝 Post: [KO](https://var.gg/ko/blog/dbos-durable-execution) *(Korean-only; no English post)*
🗓 Run: 2026-07-17 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ✅ Re-verified: 2026-07-19
🌐 한국어: [README.ko.md](./README.ko.md)

> **What reproduces, and what doesn't.** The *recovery behavior* is deterministic and
> reproduces exactly: a mid-step crash re-runs only the uncheckpointed step, a completed
> step never re-runs, a mismatched app version leaves the workflow PENDING, and the SQLite
> system db always has the same 10 tables. Absolute **recovery latency** (0.01–0.06s) drifts
> run-to-run and by machine — it is an observation, not a claim. The whole `probe.py` was
> re-run on 2026-07-19 (fresh venv, dbos 2.27.0) and every finding below held.

## Claim ↔ evidence

`probe.py` drives five experiments, each in its own work dir with a fixed workflow id
(`kill-test-1`). Ground truth is an **append-only ledger** (`ledger.txt`): each step writes
`stepN EXECUTED` *before* any checkpoint, so the ledger records every real (re-)execution —
that is how "the step ran again" is distinguished from "DBOS replayed a recorded output
without running the function". Hard kills are `os._exit()` (skips even `finally`).

| Claim in the post | Evidence | Value |
|---|---|---|
| Hard-kill mid-step, then just relaunch → workflow finishes | `results.json` → `findings[kill_test_mid_step]` | step3 dies (`os._exit(42)`) before its output is recorded; relaunch **replays step1/2** (no re-run), **re-runs step3**, then 4/5 → **SUCCESS**. No server, no queue — `pip install dbos` + decorators + SQLite default |
| The unit of at-least-once is the **step** | `results.json` → `findings[step_is_at_least_once]` | crash *after* step3 completes → relaunch does **NOT** re-run step3, continues from step4. A completed (checkpointed) step never re-runs; only a step that died before recording does |
| So a side effect inside a step can run **more than once** | same finding | step-level at-least-once ⇒ idempotency keys remain the caller's job; "exactly-once" holds for the workflow only if each step is idempotent |
| The "magic" is a **database**, not a runtime trick | `results.json` → `findings[recovery_is_db_replay]` | DBOS system db = **10 tables**, 164KB; `operation_outputs` holds per-step `function_id` + serialized output; recovery returns a recorded output *without calling the function*. `workflow_status.recovery_attempts=2` |
| Change the code (app version) and **recovery stops** | `results.json` → `findings[version_trap]` | crash under `alpha`; relaunch under `beta` → **PENDING** for the full 30s (mismatched version is never handed the workflow); relaunch under `alpha` → immediate **SUCCESS** |
| Durability has a **per-step cost** | `results.json` → `metrics[durability_tax_ms_per_step]` | 200 no-op durable steps ≈ 0.46s vs ~9e-06s plain → **~2.3ms/step** (the checkpoint write). Don't wrap tight-loop calls as steps |
| DBOS 2.27.0 is **days old**; SQLite is the **default** | `manifest.json` → `subject.freshness_note` + official docs | released 2026-07-14; "By default, DBOS uses SQLite, which requires no configuration". 2.28.0 alphas ship near-daily |

## Freshness — do not overstate the hook

- **Durable execution is not a new pattern.** Temporal (2019) defined the category;
  Azure Durable Functions predates it. What is fresh in 2026 is (a) **AWS Lambda durable
  functions** (2025-12, rolling out through H1 2026) mainstreaming it, and (b) DBOS's
  **library-only + SQLite-default** approach dropping the entry barrier to one `pip install`.
- The post says this explicitly and does **not** claim DBOS invented durable execution.

## Honestly NOT verified / honest limits

- **SQLite backend only.** The production-recommended **Postgres** backend adds network RTT
  to every checkpoint — its durability tax is *cited as larger, not measured*.
- **DBOS recovers on relaunch; it does not resurrect the process.** A supervisor
  (systemd / k8s / a human) must restart it. That layer is out of scope here.
- **Single-process recovery only.** Multi-executor / distributed recovery and queue
  contention were not tested.
- **Python SDK only.** TS/Go/Java SDKs share the design but were not run.
- **Recovery latency is an observation, not a benchmark** — n is small and machine-bound.

## The harness

`probe.py` — one file, seven modes: `run` (baseline), `crash-during` / `crash-between`
(the two kill points), `resume` (relaunch + wait for auto-recovery), `inspect` (dump the
SQLite system db), `overhead` (durability tax), `status`. Deterministic: fixed workflow id,
fixed step count, no RNG, no clock reads inside steps. Committed **verbatim** as executed.

## Reproduce

```bash
./run.sh          # needs bash + python 3.11+; makes a temp venv (dbos==2.27.0), deletes it
```

Expect: mid-step crash re-runs only the uncheckpointed step; completed steps never re-run;
version mismatch → PENDING; ~1–10ms per durable step on local SQLite.

## Environment

Windows 11 x64 (native, no WSL/Docker) · CPython 3.11.9 (venv) · **dbos 2.27.0** ·
SQLAlchemy 2.0.51 · backend = **SQLite** (DBOS default, zero server). The **DBOS version is
the load-bearing variable** — the API surface moves between minor versions; pin `2.27.0`.
