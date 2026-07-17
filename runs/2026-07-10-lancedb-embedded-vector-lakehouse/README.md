# LanceDB 0.34.0 — embedded retrieval, firsthand

📝 Post (KO): https://var.gg/ko/blog/lancedb-embedded-vector-lakehouse
🗓 Run: 2026-07-09 (backfilled 2026-07-18) · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims things it *ran locally* on LanceDB 0.34.0 — no server, no Docker, no GPU,
> no network. This directory is that run's method: the harness, the environment, and the
> deterministic output. `git clone` and `./run.sh` reproduces it.

## Backfill honesty

The essay was written 2026-07-09; the original scratch harness was deleted per the finite-disk
policy. `probe.py` here is **reconstructed** from the recorded methodology (workspace
`firsthand-benchmark.md`) and **re-run on 2026-07-18** against the same pinned `lancedb==0.34.0`.
See `manifest.json.reproduction` and `results.json.reproduction_2026_07_18` for exactly what
matched and what drifted — this is stated plainly rather than presented as a pristine original run.

## Claim ↔ evidence

### Firsthand (reproduced on lancedb 0.34.0)

| Claim in the post | Evidence | Value |
|---|---|---|
| `connect(dir)` is embedded — an in-process handle, data as on-disk `.lance` files, no daemon | `probe-result.json.connection_type` | `LanceDBConnection` |
| Exact top-k is deterministic, and `_distance` is **squared L2** (0.02 = 0.01+0.01, a gotcha) | `probe-result.json.exp_b_exact_topk` | order `[0,2,1,3]`, deterministic 3× — **exact match** |
| Versioning / time-travel: checkout an old version, then latest | `probe-result.json.exp_d_versioning` | v1 = 4 rows, latest = 5 rows — **exact match** |
| IVF_PQ **trades recall for speed**; default nprobes ≈ 0.7 recall@10 | `probe-result.json.exp_e_ann_vs_exact` | recall_default **0.7 — exact match** |
| `nprobes`/`refine_factor` tuning **recovers** recall toward 1.0 | `probe-result.json.exp_e_ann_vs_exact` | tuned **0.9** on re-run (authoring note: 1.0) — see drift |
| BM25 full-text search with **zero embeddings** (`create_index(config=FTS())`) | `probe-result.json.exp_f_fts` | `'fox'` → ids `[3, 0]` reproduce |

### Drift (stated, not hidden)

- **EXP E tuned recall**: 0.9 on the 2026-07-18 re-run vs 1.0 in the 2026-07-09 note. The PQ
  codebook (k-means) init is not fully pinned, so tuned recall lands in a **0.9–1.0 band**. The
  *direction* — tuning recovers most of the recall the approximate index gives up — reproduces;
  the last decimal does not.
- **EXP F BM25 scores**: `'fox'` top-2 **ids** reproduce (`[3,0]`), but absolute BM25 scores
  drift (tantivy-build-dependent) and the original FTS **corpus text was not recorded**, so
  `probe.py` reconstructs a plausible corpus. Scores are therefore *not* claimed bit-exact.

### Cited, not measured (flagged in the post too)

| Claim | Source |
|---|---|
| Latest stable at authoring: Python 0.34.0 / Node·Rust 0.31.0 | PyPI / GitHub releases |
| Positioning shifted "vector database" → "OSS embedded retrieval library for multimodal AI" | lancedb.com / README |
| Lance (columnar lakehouse format) vs LanceDB (embedded library on top); OSS and Cloud share the format | LanceDB docs |

## Environment

Windows 11 x64 (native, no WSL/Docker/GPU) · Python 3.11.9, isolated venv · `lancedb==0.34.0`,
`pyarrow==24.0.0`. Embedded library over local files — hardware/timing irrelevant to these
behavioral and recall results.

## Reproduce

```bash
./run.sh          # venv → pinned lancedb 0.34.0 → probe.py → probe-result.json
```

Then compare `probe-result.json` against the committed `results.json`. EXP B/D should match
bit-for-bit; EXP E default recall matches; the tuned recall and EXP F scores may drift within
the bands noted above.

## Files

| File | What it is |
|---|---|
| `probe.py` | The reconstructed harness — EXP B (exact/squared-L2), D (versioning), E (ANN recall), F (BM25). |
| `probe-result.json` | Raw probe output from the 2026-07-18 re-run. Deterministic for B/D. |
| `results.json` | Claim-facing summary: firsthand notes, reproduction deltas, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, backfill + reproduction notes. |
| `run.sh` / `requirements.txt` | Reproduction. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
