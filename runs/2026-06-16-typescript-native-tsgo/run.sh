#!/usr/bin/env bash
#
# Generic harness (backfill) — measure `tsc --noEmit` vs `tsgo --noEmit` on YOUR repo.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-16-typescript-native-tsgo
#   ./run.sh /path/to/your/typescript/repo      # defaults to the current directory
#
# IMPORTANT — this harness is NOT tied to var.gg's code. The original run measured
# var.gg's PRIVATE 728-file Next.js monorepo, which cannot be shared, so there is no
# fixture and you will NOT reproduce our absolute seconds or diagnostic counts. What you
# CAN reproduce is the METHOD: time both type-checkers cold+warm on your own repo, and
# diff their diagnostics. Durable claims (verify both on your repo):
#   * tsgo is meaningfully faster — but the magnitude is scale-dependent. We saw ~3x on
#     728 files with skipLibCheck on, NOT the headline 10x (that is a large-codebase figure).
#   * tsc and tsgo-preview diagnostics can DIVERGE. On our repo tsgo reported one extra
#     error tsc did not. A green tsc does not guarantee a green tsgo.
#
set -euo pipefail

REPO="${1:-.}"
[ -d "$REPO" ] || { echo "not a directory: $REPO"; exit 1; }
cd "$REPO"
[ -f tsconfig.json ] || { echo "no tsconfig.json in $REPO — point me at a TypeScript project root (pass the dir as \$1)"; exit 1; }

command -v npx >/dev/null 2>&1 || { echo "npx not found — install Node.js (the original run used Node v24.15.0)."; exit 1; }

TSC="npx tsc"                          # prefers the repo's local TypeScript
TSGO="npx @typescript/native-preview"  # === tsgo; first run downloads the preview

# --- timing helper: prints wall-clock seconds for "$@" (bash `time`, portable) ---
TIMEFORMAT='%R'
timeit() { local t; t=$( { time "$@" >/dev/null 2>&1 || true; } 2>&1 ); echo "$t"; }

rm_cache() { rm -f tsconfig.tsbuildinfo ./*.tsbuildinfo 2>/dev/null || true; }

DIAG_DIR="$(mktemp -d)"
trap 'rm -rf "$DIAG_DIR"' EXIT

echo "==> repo: $(pwd)"
echo "==> tsc:  $($TSC  --version 2>/dev/null || echo '?? (no local TypeScript?)')"
echo "==> tsgo: $($TSGO --version 2>/dev/null || echo '?? (first run downloads @typescript/native-preview)')"
echo

echo "==> tsc  cold (cache cleared) + warm ..."
rm_cache; TSC_COLD=$(timeit $TSC --noEmit)
TSC_WARM=$(timeit $TSC --noEmit)
$TSC --noEmit > "$DIAG_DIR/tsc.txt" 2>&1 || true    # capture diagnostics

echo "==> tsgo cold (cache cleared) + warm ..."
rm_cache; TSGO_COLD=$(timeit $TSGO --noEmit)
TSGO_WARM=$(timeit $TSGO --noEmit)
$TSGO --noEmit > "$DIAG_DIR/tsgo.txt" 2>&1 || true   # capture diagnostics

echo
echo "  compiler   version                          cold      warm"
echo "  ---------   ------------------------------   -------   -------"
printf "  tsc         %-30s  %6ss   %6ss\n" "$($TSC  --version 2>/dev/null || echo '?')" "$TSC_COLD"  "$TSC_WARM"
printf "  tsgo        %-30s  %6ss   %6ss\n" "$($TSGO --version 2>/dev/null || echo '?')" "$TSGO_COLD" "$TSGO_WARM"
echo
echo "  For reference — var.gg's private 728-file monorepo (2026-06-16, NOT reproducible by you):"
echo "    tsc 6.0.3   cold 6.7s / warm 1.9s"
echo "    tsgo 7.0dev cold 2.1s / warm 0.7s   -> ~3.2x cold, ~2.7x warm (NOT 10x at this scale)."
echo "  Your numbers WILL differ — different codebase. The point is the ratio + the diagnostic diff below."

echo
echo "==> diagnostic diff (tsc vs tsgo) — the key check when migrating"
tsc_n=$(grep -cE ': error TS[0-9]+' "$DIAG_DIR/tsc.txt"  || true)
tsgo_n=$(grep -cE ': error TS[0-9]+' "$DIAG_DIR/tsgo.txt" || true)
echo "    tsc errors:  ${tsc_n:-0}"
echo "    tsgo errors: ${tsgo_n:-0}"
if diff <(sort "$DIAG_DIR/tsc.txt") <(sort "$DIAG_DIR/tsgo.txt") >/dev/null 2>&1; then
  echo "    -> diagnostics are IDENTICAL on this repo."
else
  echo "    -> diagnostics DIVERGE. Lines only one tool reports (< tsc, > tsgo):"
  diff <(sort "$DIAG_DIR/tsc.txt") <(sort "$DIAG_DIR/tsgo.txt") | grep -E '^[<>]' || true
  echo
  echo "    On var.gg's repo tsgo reported one EXTRA error (TS2769 'No overload matches this call'"
  echo "    on a useInfiniteQuery initialData overload) that tsc 6.0.3 did not. See results.json ->"
  echo "    findings[diagnostics_divergence]. Do NOT assume a green tsc means a green tsgo."
fi
