#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce both experiments from the post
# "파이썬 타입 체커 4종 — 같은 코드, 네 가지 판정".
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-30-python-type-checkers-pyrefly-ty
#   ./run.sh
#
# Reproduces the METHOD. Exact per-fixture wording and seconds are a 2026-06-30
# snapshot on one Windows PC; ty/pyrefly are fast-moving (monthly) so your
# versions and numbers WILL drift. The durable claims are structural — see
# results.json + manifest.drift_warning.
#
set -uo pipefail   # not -e: checkers exit non-zero on findings, which is expected
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

echo "==> versions (original run: mypy 2.1.0 / pyright 1.1.411 / pyrefly 1.1.1 / ty 0.0.55)"
for t in "mypy --version" "pyrefly --version" "ty --version"; do
  command -v "${t%% *}" >/dev/null 2>&1 && $t
done
command -v npx >/dev/null 2>&1 && npx pyright --version 2>/dev/null

echo
echo "############ Experiment A — same code, four verdicts (DEFAULT settings) ############"
for f in fixture/*.py; do
  echo
  echo "==================== $f ===================="
  for tool in "mypy" "pyrefly check" "ty check" "npx pyright"; do
    bin="${tool%% *}"
    command -v "$bin" >/dev/null 2>&1 || { echo "-- ${tool}: (missing)"; continue; }
    echo "-- ${tool}:"
    $tool "$f" 2>&1 | sed 's/^/     /'
  done
done
echo
echo "Expect: 01/03/05 caught by all four; 02 passes all four (only mypy prints a"
echo "        'untyped function bodies not checked' note); 04 mypy widens to"
echo "        tuple[int,str] while others keep Literal; 06 only pyrefly flags missing return."

echo
echo "############ Experiment B — speed on a 2000-module / ~70k-line CLEAN codebase ############"
TARGET="$(mktemp -d)/synthetic"
python gen_codebase.py "$TARGET" 2000
python bench_run.py "$TARGET" --runs 3
rm -rf "$(dirname "$TARGET")"
echo
echo "Expect: Rust tools (ty/pyrefly) ~15-30x faster COLD than pyright; mypy cold slow"
echo "        (~3s) but WARM ~0.27s (incremental cache) = Rust-class; pyright CLI no cache."
