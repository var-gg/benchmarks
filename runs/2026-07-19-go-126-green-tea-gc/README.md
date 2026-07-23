# Go 1.26 Green Tea GC — why one team measured ~35% and another measured nothing

📝 Post: [KO](https://var.gg/ko/blog/go-126-green-tea-gc) *(Korean-only; no English post)*
🗓 Run: 2026-07-19 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> **The disagreement is the experiment.** The Go team says 10–40% less GC overhead
> "in programs that heavily use the GC"; tile38 reported ~35%; DoltHub's 2025-09 run
> reported roughly **neutral**. Rather than benchmark one more application, this harness
> sweeps the variable those reports differ in — **heap pointer density** — and shows the
> same toolchain change producing a −77% win and a no-op on one machine, one afternoon.

## Claim ↔ evidence

Same source, one toolchain (`go1.26.5`), compiled twice — default (Green Tea) vs
`GOEXPERIMENT=nogreenteagc` (classic) — over three heap shapes. ~400MB live heap,
`GOGC=100`, medians over n=5 (flat n=3). Metric: `runtime.MemStats.GCCPUFraction`.

| Claim in the post | Evidence | Value |
|---|---|---|
| Pointer-dense heaps see a large GC-overhead cut | `results.json` → `metrics[gc_cpu_fraction_by_heap_shape]` | tree **10.30% → 2.38%** (−77%), graph **5.72% → 1.72%** (−70%) |
| …and it converts to real wall time | `results.json` → `metrics[wall_time_by_heap_shape]` | tree **4772.6ms → 3377.3ms** (−29%), graph 7540.0 → 6506.4ms (−14%) |
| A pointer-free heap sees **nothing** | same two tables | flat GC CPU 0.34% → 0.09% — a real ratio, an irrelevant magnitude — and wall time **201.9ms → 200.8ms (−0.5%)** |
| The win is **cheaper** cycles, not **fewer** cycles | `results.json` → `metrics[gc_cycle_count]` | GC counts 35→31, 15→14, 12→12 while GC CPU fell 3–4× |
| Our −77% is **not** what a service should expect | `results.json` → `findings[micro_bench_amplifies]` | The harness only allocates and drops, so GC is an outsized share of its CPU. The Go team's 10–40% is the figure to plan with. |
| The old GC is going away | `manifest.json` → `subject.freshness_note` | Opt-out is build-time `GOEXPERIMENT=nogreenteagc`, and the 1.26 release notes say it "is expected to be removed in Go 1.27" |

## Re-verified 2026-07-24 — including where it fell over

`run.sh` was re-executed on the same machine in `SMOKE=1` mode (live=100MB, churn=10,
**n=1**) with a freshly downloaded `go1.26.5`:

| shape | classic GC CPU | Green Tea GC CPU | delta | recorded delta |
|---|---|---|---|---|
| tree | 11.63% | 2.65% | **−77%** | −77% ✅ |
| graph | 6.15% | 2.07% | −66% | −70% ✅ |
| flat | 0.34% | **0.66%** | **+97%** ⚠️ | −73% (noise) |

The tree cell reproduced the headline to the percentage point. The flat cell **flipped
sign**, and graph's wall time came out **+17%** even though its GC CPU fell by two thirds.
Both of those cells run only **2 GC cycles** at smoke scale — which is exactly the caveat
the original run already carried, now demonstrated rather than asserted. It is evidence
for "flat is noise", not against "tree wins". Run the full config (`N=5 LIVE_MB=400
CHURN=60`) before comparing any number here to `results.json`.

## Honestly NOT verified

- **Windows/amd64 only.** No Linux, macOS, or ARM64. Green Tea's vectorized scan path is
  amd64-specific; ARM64 behavior is unknown to this run.
- **AVX-512 was present** (Zen 5). This is the best case for the vector scanner. We did not
  measure a pre-AVX-512 amd64, so we cannot split "new algorithm" from "vector instructions".
- **No pause distribution / tail latency.** `PauseTotalNs` was recorded but is 0–9ms noise at
  this scale. Any claim about GC *pause* behavior in the post is cited, not measured.
- **One operating point** — ~400MB live, `GOGC=100`. No heap-size or GOGC sweep.
- **No real application.** tile38's ~35% and DoltHub's neutral result are cited from their
  write-ups, not reproduced. Note our mechanism finding (same cycle count, cheaper cycles)
  points the *opposite* way from DoltHub's description (fewer cycles, pricier each); we did
  not investigate that difference.
- **cgo overhead** (also improved in 1.26, reportedly ~30%) is out of scope.

## The harness

`harness/gcbench.go` — one file, no dependencies. Builds a persistent ~400MB live heap in
one of three shapes (`tree` = ternary tree of 32-byte 3-pointer nodes · `graph` = nodes
pointing at 3 random others · `flat` = pointer-free int64 slabs), then churns quarter-sized
garbage of the same shape to force GC cycles over it, and prints one JSON line of
`MemStats`. `results-raw.jsonl` is the unmodified stdout of all **26** recorded runs, so
every median in `results.json` is auditable against it.

## Reproduce

```bash
./run.sh                          # needs Go 1.26.x on PATH (or GO=/path/to/go1.26.5)
SMOKE=1 ./run.sh                  # ~20s sanity pass
N=5 LIVE_MB=400 CHURN=60 ./run.sh # the recorded configuration, ~4 min
```

**Go 1.26.x is required and the window is closing** — Green Tea is the 1.26 default and the
`nogreenteagc` opt-out is expected to be removed in 1.27, at which point there is no
baseline left to build.

Expect: `tree` and `graph` show a large GC-CPU drop; `flat` sits under ~0.5% GC CPU on both
sides and does not move the wall clock. Absolute percentages will differ on your machine —
especially without AVX-512.

## Environment

Windows 11 x64 (native, no WSL/Docker) · AMD Ryzen 9 9950X3D (Zen 5, 16C/32T, AVX-512) ·
GOMAXPROCS=32 · **go1.26.5** · GOGC=100 pinned. The **Go version is the load-bearing
variable**: pin `1.26.5`, because 1.27 removes the ability to build the baseline at all.
