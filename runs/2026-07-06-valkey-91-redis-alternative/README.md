# Valkey 9.1 vs Redis 8 — is performance actually a reason to migrate?

📝 Post: [KO](https://var.gg/ko/blog/valkey-91-redis-alternative) *(Korean-only; no English post)*
🗓 Run: 2026-07-05 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> **⚠️ Backfilled harness.** The numbers below are transcribed verbatim from the
> session notes of 2026-07-05, but **no harness file existed at the time** — the
> `redis-benchmark` invocations were run ad hoc from the shell and recorded in prose.
> `run.sh` is a **reconstruction** of those recorded invocations, authored 2026-07-23.
> It was executed at 1/100 scale on 2026-07-23 to confirm the mechanics and the memory
> direction (see *Re-verification* below). See `manifest.json` → `backfill_note`.

## Claim ↔ evidence

Single host (Windows 11 + Docker/WSL2), both engines as local containers, standalone,
default config. Images pinned **by digest**, not by tag.

| Claim in the post | Evidence | Value |
|---|---|---|
| Valkey holds the same dataset in ~23% less memory | `results.json` → `metrics[memory_footprint_same_dataset]` | **67.86 MB** @ 632,539 keys vs **88.31 MB** @ 632,438 keys → **-23.2%** (Redis +30.2%) |
| …at a genuinely matched key count | same table | key counts differ by **101** out of ~632.5k (0.016%) |
| Valkey leads on **unpipelined** throughput | `results.json` → `metrics[throughput_unpipelined]` | SET 315,457 vs 277,778 rps · GET 296,736 vs 270,270 rps (**~9–13%**) |
| Redis leads once the pipeline is **deep** | `results.json` → `metrics[throughput_pipelined]` | P=16: SET 2.27M vs 2.06M · GET 2.70M vs 2.41M (**~10%**, other direction) |
| Therefore "migrate for performance" is a weak argument | `results.json` → `findings[performance_is_a_weak_migration_argument]` | the ordering **flips with workload shape**; the memory gap does not |

## Re-verification (2026-07-23)

`SMOKE=1 ./run.sh` (1/100 scale) was run twice on the same host to check that the
reconstructed harness works and that the memory result still holds on the pinned digests
**with one client binary driving both servers**:

| | keys | used_memory | bytes/key |
|---|---:|---:|---:|
| Valkey 9.1.0 (run 1 / run 2) | 6,273 / 6,358 | 1,754,296 B / 1,761,880 B | 279.7 / 277.1 |
| Redis 8.8.0 (run 1 / run 2) | 6,295 / 6,317 | 2,352,104 B / 2,354,344 B | 373.6 / 372.7 |

→ Valkey **25.1% / 25.7%** lower per key, against **23.2%** at full scale. Server versions
confirmed (`valkey_version:9.1.0`, `redis_version:8.8.0`, both jemalloc-5.3.0).
Verbatim stdout: [`smoke-2026-07-23.txt`](./smoke-2026-07-23.txt).

**Smoke mode does not resolve throughput** — at 5k–10k requests `redis-benchmark`'s rps
output is coarse and both engines landed in the same band. Only the full run speaks to that.

## Honestly NOT verified / honest limits

- **Single-host microbenchmark.** Not a production topology. No p50/p99 distribution was
  retained — throughput only.
- **n=1 almost everywhere.** Only the unpipelined SET cells were repeated (once), and that
  repeat already moved Redis SET by ~4% (277,778 → 289,855). Treat the ~10% pipelined delta,
  which is single-shot, as the weakest number here.
- **The client binary used per engine in the original run is unrecorded.** `run.sh` removes
  that variable by using redis:8's `redis-benchmark` for both — which is a better experiment
  but means a reproduction need not land on the recorded rps.
- **Whether each phase started from a fresh server is unrecorded** for the original run.
  `run.sh` boots a fresh container per engine and `FLUSHALL`s between phases.
- **No cluster, replication, or persistence.** None of the Valkey 9.1 cluster-bus / failover
  changes discussed in the post were measured.
- **New commands** (`HGETDEL`, `MSETEX`, `CLUSTERSCAN`) and the cluster-bus traffic metrics are
  **cited from release notes, not measured**.
- **Windows + Docker Desktop (WSL2 backend).** A native-Linux host would shift the absolute rps
  for both engines; only the cross-engine comparison is meant to carry over.
- `INFO` on Valkey reports `redis_version:7.2.4` next to `valkey_version:9.1.0` — a RESP
  compatibility marker, not the server generation. Do not read it as "Valkey is Redis 7.2".

## Reproduce

```bash
./run.sh            # full: ~5-10 min, dominated by the 1M-key memory phase
SMOKE=1 ./run.sh    # 1/100 scale mechanics check, ~1 min
```

Expect Valkey **20–25% lower** memory at a similar `DBSIZE` (compare bytes/key if the counts
differ by more than ~1%), Valkey ahead unpipelined, and Redis ahead at pipeline depth 16.
**The sign flip is the finding; the percentages are noisy.**

## Environment

Windows 11 + Docker 29.4.3, WSL2 backend (Linux 6.6.114-microsoft-standard-WSL2, x86_64) ·
`valkey/valkey@sha256:4963247a…` (server 9.1.0) · `redis@sha256:2838d552…` (server 8.8.0) ·
both jemalloc-5.3.0, 64-bit. Both digests were re-confirmed resolvable on Docker Hub on
2026-07-23. **The digests are the pin** — the `9.1` and `8` tags move.
