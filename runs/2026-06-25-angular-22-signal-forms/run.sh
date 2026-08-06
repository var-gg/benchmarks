#!/usr/bin/env bash
#
# Reproduce the Angular 22 Signal Forms vs Reactive Forms firsthand experiments.
# Pure local, deterministic — no Docker, GPU, browser, or network.
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-25-angular-22-signal-forms
#     ./run.sh
#
# Produces probe-result.json. Compare it against results.json (committed).
# Pinned: @angular/* 22.0.2 · typescript 5.9.3 · vitest 3.2.6 (see package.json).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

echo "==> Installing pinned dependencies"
npm install --no-audit --no-fund

TSC="npx tsc --noEmit --strict --target es2022 --module esnext --moduleResolution bundler --lib es2022,dom --skipLibCheck"

echo "==> Experiment A — type safety (tsc, expect reactive=0, signal=2)"
RE=$($TSC exp-a-types/reactive.ts 2>&1 | grep -c 'error TS' || true)
SE=$($TSC exp-a-types/signal.ts   2>&1 | grep -oE 'error TS[0-9]+' | sort -u | paste -sd, - || true)
SC=$($TSC exp-a-types/signal.ts   2>&1 | grep -c 'error TS' || true)
echo "    reactive tsc errors: $RE   signal tsc errors: $SC ($SE)"
node -e "const fs=require('fs');const f='probe-result.json';let o={};try{o=JSON.parse(fs.readFileSync(f,'utf8'))}catch{};o['A_type_safety']={reactive_tsc_errors:$RE,signal_tsc_errors:$SC,signal_error_codes:'$SE'};fs.writeFileSync(f,JSON.stringify(o,null,2));"

echo "==> Experiments B, C, D — reactivity / aggregation / async race (vitest)"
npx vitest run --reporter=dot

echo
echo "==> Done. Wrote probe-result.json. Diff it against results.json."
