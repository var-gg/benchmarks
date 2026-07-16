#!/usr/bin/env bash
#
# Reproduce the Polars streaming-engine memory measurements.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-16-polars-streaming-engine
#   ./run.sh
#
# Needs: python 3.11+ on PATH. Creates a throwaway venv + a deterministic 30M-row
# parquet (~87MB) in a temp dir; both are deleted at the end.
#
# What reproduces exactly on a pinned polars==1.42.1: the dataset, the checksums
# (15000032831.613 on val_sum), equals=False between engines, and the rows-out
# pattern. Peak-memory MB varies ~±10% run-to-run and by machine — compare the
# RATIOS, not the absolute MB, against results.json.
#
# Memory metric caveat: probe.py reads psutil peak_wset, which exists on Windows
# only. On Linux/macOS it falls back to CURRENT RSS at end-of-query — a weaker
# proxy (real peaks are higher). The recorded run was Windows.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PY="${PY:-python}"
command -v "$PY" >/dev/null 2>&1 || PY=python3

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export POLARS_DEMO_DATA="$WORK/big.parquet"

echo "==> venv + pinned deps (polars 1.42.1 / pandas 2.3.1 / pyarrow 17.0.0 / psutil 6.0.0)"
"$PY" -m venv "$WORK/venv"
if [ -x "$WORK/venv/Scripts/python.exe" ]; then VPY="$WORK/venv/Scripts/python.exe"; else VPY="$WORK/venv/bin/python"; fi
"$VPY" -m pip install --quiet --disable-pip-version-check \
  polars==1.42.1 pandas==2.3.1 pyarrow==17.0.0 psutil==6.0.0

PROBE="$HERE/harness/probe.py"

echo "==> generate deterministic 30M-row parquet (streaming write, ~87MB)"
"$VPY" "$PROBE" gen

echo "==> Experiment A — group-by aggregate (each cell = own subprocess)"
"$VPY" "$PROBE" measure streaming
"$VPY" "$PROBE" measure in-memory
"$VPY" "$PROBE" pandas

echo "==> Experiment B — result equality between engines"
"$VPY" "$PROBE" equal   # expect streaming_equals_in_memory: false (float sum order)

echo "==> Experiment C — same streaming flag, different ops"
for op in group_by_sum equi_join cum_sum window_over full_sort; do
  "$VPY" "$PROBE" measop "$op" streaming
done
for op in group_by_sum equi_join window_over full_sort; do
  "$VPY" "$PROBE" measop "$op" in-memory
done

echo
echo "==> Done. Compare against results.json:"
echo "    - checksum 15000032831.613 must match exactly (deterministic data)."
echo "    - reducing ops (group_by/join): streaming peak ~2.8-3x below in-memory."
echo "    - row-preserving ops (window_over/full_sort): no streaming advantage."
echo "    - equal: false, by design (non-associative float addition)."
