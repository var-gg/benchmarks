#!/usr/bin/env bash
#
# Reproduce the Go 1.26 Green Tea GC A/B (heap-shape sweep).
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-19-go-126-green-tea-gc
#   ./run.sh
#
# Needs: Go **1.26.x** on PATH (or set GO=/path/to/go1.26.5). The version is the
# load-bearing variable — Green Tea is the default GC in 1.26, and the opt-out
# `GOEXPERIMENT=nogreenteagc` is documented as going away in 1.27, so on 1.27+
# this A/B stops being buildable at all.
#
# The SAME source is compiled twice from one toolchain:
#   default                     -> Green Tea GC     (label "green")
#   GOEXPERIMENT=nogreenteagc   -> pre-1.26 classic (label "classic")
# and each binary is run over three heap SHAPES (tree / graph / flat).
#
# Headline metric: runtime.MemStats.GCCPUFraction (share of process CPU spent in
# GC since start). Output is one JSON object per run, same schema as the recorded
# results-raw.jsonl next to this script.
#
# Knobs:
#   SMOKE=1     quick sanity pass (live=100MB, churn=10, n=1) — ~20s, still shows
#               the tree-vs-flat split. Do NOT compare SMOKE numbers to results.json
#               absolutely; the split is the point.
#   N=5 LIVE_MB=400 CHURN=60    full recorded configuration (~4 min)
#
# What reproduces: the DIRECTION and the SHAPE DEPENDENCE — pointer-dense heaps
# (tree/graph) show a large GC-CPU drop, the pointer-free heap (flat) shows GC
# overhead already near zero and no wall-time change. Absolute percentages are
# machine-specific: the recorded run was a Zen 5 (AVX-512) part where Green Tea's
# vectorized scan path is enabled. Expect smaller wins without AVX-512.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

GO="${GO:-go}"
command -v "$GO" >/dev/null 2>&1 || { echo "no go on PATH; set GO=/path/to/go1.26.x" >&2; exit 2; }
GOVER="$("$GO" version | awk '{print $3}')"
case "$GOVER" in
  go1.26*) ;;
  *) echo "need Go 1.26.x (Green Tea default + nogreenteagc opt-out); found $GOVER" >&2
     echo "  get it: https://go.dev/dl/  (recorded run used go1.26.5)" >&2
     exit 2 ;;
esac

if [ "${SMOKE:-0}" = "1" ]; then
  N="${N:-1}"; LIVE_MB="${LIVE_MB:-100}"; CHURN="${CHURN:-10}"
else
  N="${N:-5}"; LIVE_MB="${LIVE_MB:-400}"; CHURN="${CHURN:-60}"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GOCACHE="$WORK/gocache"        # keep the host build cache untouched
export GOFLAGS=-mod=mod
EXE=""
case "$(uname -s 2>/dev/null || echo unknown)" in MINGW*|MSYS*|CYGWIN*) EXE=".exe";; esac

echo "==> $GOVER · live=${LIVE_MB}MB churn=${CHURN} n=${N} (each JSON line reports its own gomaxprocs)"

mkdir -p "$WORK/src"
cp "$HERE/harness/gcbench.go" "$WORK/src/main.go"
( cd "$WORK/src" && "$GO" mod init gcbench >/dev/null 2>&1 )

echo "==> build A: default toolchain (Green Tea GC is the 1.26 default)"
( cd "$WORK/src" && "$GO" build -o "$WORK/gcbench-green$EXE" . )

echo "==> build B: GOEXPERIMENT=nogreenteagc (pre-1.26 classic GC)"
( cd "$WORK/src" && GOEXPERIMENT=nogreenteagc "$GO" build -o "$WORK/gcbench-classic$EXE" . )

OUT="$WORK/results.jsonl"
: > "$OUT"
for shape in tree graph flat; do
  for gc in green classic; do
    for _ in $(seq 1 "$N"); do
      GCBENCH_LABEL="$gc" "$WORK/gcbench-$gc$EXE" "$shape" "$LIVE_MB" "$CHURN" | tee -a "$OUT"
    done
  done
done

echo
echo "==> medians"
python - "$OUT" <<'PY' 2>/dev/null || echo "(python not found — read the JSON lines above)"
import json,statistics as st,sys
from collections import defaultdict
g=defaultdict(list)
for line in open(sys.argv[1],encoding='utf-8'):
    if line.strip(): r=json.loads(line); g[(r['shape'],r['gc'])].append(r)
print(f"{'shape':6} {'classic GC CPU':>15} {'green GC CPU':>14} {'delta':>8} {'wall delta':>11}")
for shape in ('tree','graph','flat'):
    c,gr=g.get((shape,'classic')),g.get((shape,'green'))
    if not c or not gr: continue
    cc=st.median(x['gc_cpu_fraction'] for x in c); gg=st.median(x['gc_cpu_fraction'] for x in gr)
    cw=st.median(x['wall_ms'] for x in c); gw=st.median(x['wall_ms'] for x in gr)
    print(f"{shape:6} {cc*100:14.2f}% {gg*100:13.2f}% {(gg-cc)/cc*100:+7.0f}% {(gw-cw)/cw*100:+10.1f}%")
PY

echo
echo "==> Expect (see results.json): pointer-dense tree/graph show a large GC-CPU"
echo "    drop and a real wall-time win; flat starts under ~0.5% GC CPU and moves"
echo "    the wall clock by ~nothing. Same flag, opposite verdicts — that is the finding."
