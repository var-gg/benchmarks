# NATS 2.14 JetStream message scheduler — single-node protocol checks

📝 Post (KO): https://var.gg/ko/blog/nats-jetstream-scheduler
🗓 Run: 2026-06-19 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ♻️ **backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran the scheduler on a single-node nats-server 2.14.2 and watched what
> it accepts, replaces, downsamples, and survives."* This directory is that run — the method,
> the pinned versions, and the accept/reject matrix — so you don't have to take the claim on
> faith. It is a **backfill**: the original binaries and JetStream store were deleted per the
> finite-disk policy, so `run.sh` + `fixture/` are reconstructed from the recorded methodology.
> Because the findings are deterministic protocol behaviors (not live-DB numbers), re-running
> with the same versions should reproduce them.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json`. Nothing here is cited
from external docs — it is all local observation on the server under test.

### Firsthand (nats-server 2.14.2, nats CLI 0.4.0)

| Claim in the post | Evidence | Value |
|---|---|---|
| A schedule is not a separate API — it's the `Nats-Schedule` header on a control message in an `--allow-schedules` stream | `results.json` → `method` + `run.sh` | verified |
| `@every`, `@at <RFC3339>`, `@hourly`, and **6-field** cron (with seconds) are accepted | `results.json` → `schedule_syntax_matrix` | 6 / 6 accept |
| **Standard 5-field crontab is rejected** (the first pitfall) | `schedule_syntax_matrix` (`* * * * *`, `*/1 * * * *`) | 2 / 2 reject |
| CLI `nats publish --schedule-after=DURATION` is **rejected by the server** (error 10189) — a CLI-vs-server contract mismatch | `results.json` → `cli_server_mismatch` | reproduced 5× |
| Re-publishing to the **same subject atomically replaces** the schedule (`Nats-Rollup: sub`) | `results.json` → `behaviors_verified[rollup_replace]` | verified |
| `Nats-Schedule-Source` **downsamples** — each tick emits only the source's latest value | `results.json` → `behaviors_verified[source_downsample]` | `reading-7,13,19,25,30,30` |
| Schedules **survive restart**; an overdue one-shot fires **once**; `@every` **does not backfill** missed ticks | `results.json` → `behaviors_verified[restart_durability]` | `df.once: 1`, no catch-up |
| `@every 1s` inter-arrival was exactly **1.000s, drift 0** | `results.json` → `timing_observation` | 16 firings |

### Explicitly NOT verified

- **Distributed durability.** Single node only. JetStream Raft replication, leader failover,
  and `--replicas>=3` guarantees were not exercised. The post says so plainly.
- **Sub-millisecond drift.** Accuracy is judged against second-granularity store timestamps.
- **Delivery-once.** JetStream is at-least-once; firing messages can duplicate (consumer-side
  idempotency needed). Same as ordinary JetStream — not re-verified here.

## Environment

Windows 11 x64, single node (native, no Docker/WSL) · nats-server **2.14.2** (JetStream API
Level 4) · nats CLI **0.4.0**. This is a protocol accept/reject + durability check, so hardware
does not change the outcome (the one timing figure aside).

## Reproduce

```bash
./run.sh          # start server -> --allow-schedules stream -> iterate fixture/schedule-cases.tsv
```

`run.sh` reproduces Part 1 (syntax accept/reject matrix) and Part 2 (the `--schedule-after`
mismatch) automatically, and documents the three timing/observation tests (rollup replace,
source downsample, restart durability) for manual reproduction. Compare against `results.json`.

## Raw data

**Backfill — nothing preserved from the original run.** The downloaded nats-server / nats CLI
binaries and the temporary `-sd` store were deleted after 2026-06-19 (finite local disk; no
Docker was used, so `received_images: none`). No hashes were captured at the time. Rather than
fabricate artifacts, the run ships a **reconstructed** harness (`run.sh` + `fixture/`) and states
this openly. `results.json` holds the behaviors and the single timing figure observed on the day.
`checksums.txt` hashes the committed harness for integrity.

## Files

| File | What it is |
|---|---|
| `run.sh` | Reconstructed harness: starts the server, creates an `--allow-schedules` stream, iterates the fixture. |
| `fixture/schedule-cases.tsv` | The `Nats-Schedule` values tested and their expected accept/reject. |
| `results.json` | Claim-facing summary: syntax matrix, CLI-vs-server mismatch, behaviors, honest limits. |
| `manifest.json` | Environment, pinned versions, `executed_by`, `backfilled`, retention policy. |
| `checksums.txt` | sha256 of the committed harness. |
