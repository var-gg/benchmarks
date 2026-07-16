# Polars 1.42 streaming engine — does `engine="streaming"` really bound memory?

📝 Post: [KO](https://var.gg/ko/blog/polars-streaming-engine) *(Korean-only; no English post)*
🗓 Run: 2026-07-16 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> **What reproduces, and what doesn't.** The dataset is deterministic (no RNG:
> `val = (id*2654435761 % 1000003)/1000`), so the query **checksums reproduce exactly**
> (`15000032831.613`) on a pinned `polars==1.42.1`, as does `equals=False` between engines.
> Peak-memory **MB** varies run-to-run (~±10%) and by machine — the durable claims are the
> **cross-engine ratios** and the **rows-out pattern**, not absolute MB.
> See `manifest.json` → `determinism`.

## Claim ↔ evidence

30M rows, 2,000 groups, 87MB parquet. Every cell is measured in its **own subprocess**
(`psutil peak_wset`, true peak working set on Windows).

| Claim in the post | Evidence | Value |
|---|---|---|
| Streaming genuinely bounds memory on **reducing** queries | `results.json` → `metrics[groupby_agg_peak_memory]` | group-by: **366MB** streaming vs 1035MB in-memory vs 2466MB pandas (**2.8x / 6.7x less**), identical checksum |
| …and on join→agg too | `results.json` → `metrics[per_op_peak_memory]` | equi-join+agg: **667MB** vs 2031MB (**3.0x less**) |
| The same flag does **nothing** for **row-preserving** queries | `results.json` → `metrics[per_op_peak_memory]` | window `.over()`: **1050MB streaming vs 931MB in-memory** (slightly worse); full sort: **2723 vs 2691MB** (a wash, both ~2.7GB) |
| Peak memory is governed by **rows-out**, not the engine flag | same table | 30M→2k rows: 2.8–3x win · 30M→30M rows: no win |
| Results are numerically equal but **not bit-identical** | `results.json` → `findings[numerically_equal_not_bit_identical]` | `equals()` = False; `val_sum` max_abs_diff **1.02e-08** (1392/2000 groups), `val_mean` 6.8e-13; ints/max bit-exact — float addition is non-associative |
| The engine is **opt-in, not the default** (1.42.1) | official docs + `manifest.json` → `subject.freshness_note` | `collect(engine="streaming")`; docs: "not the default" / "will become the default in time" ([#20947](https://github.com/pola-rs/polars/issues/20947)) |

## Freshness — do not overstate the hook

- The new streaming engine was **not "just stabilized"** — it has existed opt-in since ~1.31
  and has been expanded throughout 2026 (1.37 sinks, 1.38 streaming join, 1.39 asof join).
  As of **1.42.1 (2026-06-30)** it is still **not the default**.
- Secondhand summaries claiming it "became the default in 1.41" were checked against the
  official docs and are **wrong**; the post says so explicitly.

## Honestly NOT verified / honest limits

- **n=1 per cell** — single run per op/engine, no distribution. Ratios are large enough
  (2.8–6.7x) that this is fine for the claim made; treat small deltas (931 vs 1050) as noise-adjacent.
- **The 87MB parquet fits in RAM.** This measures memory *bounding* behavior per engine, not a
  genuinely larger-than-RAM out-of-core workload.
- **Which ops silently fell back** to the in-memory engine was not instrumented — the fallback
  explanation comes from official docs; our numbers are peak-memory observations.
- **Windows only.** `peak_wset` is Windows-specific; probe.py falls back to current RSS elsewhere
  (a weaker proxy).
- `rank_over` is in the harness but its measurement was not retained — not reported.
- Absolute MB includes the CPython + library floor (~100–150MB).

## The harness

`harness/probe.py` — one file, six modes: `gen` (deterministic parquet via streaming
`sink_parquet`), `measure <engine>` / `pandas` (experiment A), `equal` (experiment B),
`measop <op> <engine>` (experiment C), `limits`. Each measurement is its own subprocess so
peaks are isolated. The only edit vs the file as executed is a corrected docstring
(see `manifest.json` → `harness_provenance`).

## Reproduce

```bash
./run.sh          # needs python 3.11+; makes a temp venv + 87MB parquet, deletes both
```

Expect: checksum `15000032831.613` exactly; streaming ~2.8–3x below in-memory on group-by/join;
no streaming advantage on window/sort; `equal` reporting `false`.

## Environment

Windows 11 x64 (native, no WSL/Docker) · CPython 3.11.9 (venv) · **polars 1.42.1** ·
pandas 2.3.1 · pyarrow 17.0.0 · psutil 6.0.0. The **Polars version is the load-bearing
variable** — the streaming engine changes fast; pin `1.42.1` for parity.
