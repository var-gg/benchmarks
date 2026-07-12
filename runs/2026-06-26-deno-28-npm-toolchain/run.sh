#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the Deno 2.8 vs npm toolchain A/B.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-26-deno-28-npm-toolchain
#   ./run.sh
#
# Reproduces the METHOD from fixture/package.json. Install TIMINGS are machine-
# and cache-dependent, and audit COUNTS are point-in-time against a live advisory
# database — your numbers may differ from the 2026-06-26 snapshot in results.json.
# The durable claims are the install-speed RATIO and the qualitative behaviours
# (pnpm-style layout, phantom-dep block, audit granularity, pack-is-transpile,
# Node-API parity, skipped lifecycle scripts).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

DENO_PIN="2.8.0"   # pin 2.8.x; 2.9.0 (2026-06-25) changed lockfile seeding

for bin in node npm deno; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "Missing '$bin' on PATH."
    [ "$bin" = deno ] && echo "  Install Deno ${DENO_PIN}: https://github.com/denoland/deno/releases/tag/v${DENO_PIN}"
    exit 1
  }
done

echo "==> node   $(node --version)"
echo "==> npm    $(npm --version)"
echo "==> deno   $(deno --version | head -n1)   (original run: deno ${DENO_PIN})"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ------------------------------------------------------------------ npm side --
NPM_DIR="$WORK/npm"
mkdir -p "$NPM_DIR"
cp "$HERE/fixture/package.json" "$NPM_DIR/package.json"
cd "$NPM_DIR"

echo
echo "==> npm install  (3 deps; your npm cache may already be warm)  — time it"
time npm install --no-fund --no-audit

echo "    node_modules top-level entries (npm hoists flat — expect ~8):"
ls -1 node_modules 2>/dev/null | grep -v '^\.' | wc -l

echo
echo "==> npm audit  (per-PACKAGE counts; exit 1 on findings is expected)"
npm audit || true

echo
echo "==> phantom dep under node (flat hoist leaks an undeclared transitive):"
printf '%s\n' "try{const h=require('has-flag');console.log('  node: resolved has-flag ->',typeof h)}catch(e){console.log('  node:',e.message)}" > phantom.cjs
node phantom.cjs || true

# ----------------------------------------------------------------- deno side --
DENO_DIR_PROJECT="$WORK/deno"
mkdir -p "$DENO_DIR_PROJECT"
cp "$HERE/fixture/package.json" "$DENO_DIR_PROJECT/package.json"
cd "$DENO_DIR_PROJECT"

# Fresh DENO_DIR so this is a genuine COLD cache (the recorded run did the same).
export DENO_DIR="$WORK/.deno_cache"

echo
echo "==> deno install  (fresh DENO_DIR = cold)  — time it"
# Depending on your deno.json config, deno may need --node-modules-dir=auto to
# materialise a node_modules/ tree; add it if you don't see one below.
time deno install

echo "    node_modules layout (deno isolates pnpm-style — expect ~4 + .deno/):"
ls -1 node_modules 2>/dev/null | grep -v '^\.' | wc -l
[ -d node_modules/.deno ] && echo "    node_modules/.deno present -> real files live there; top level is junctions"

echo
echo "==> deno audit  (per-ADVISORY counts; exit 1 on findings is expected)"
# If your deno build gates this behind a flag, try: deno audit --preview-features
deno audit || true

echo
echo "==> phantom dep under deno (pnpm-style isolation blocks it):"
cp "$NPM_DIR/phantom.cjs" ./phantom.cjs
deno run -A phantom.cjs || true

echo
echo "==> Done. Compare against results.json:"
echo "    - install: deno (cold) should still beat npm (warm); RATIO is the point, not the ms."
echo "    - layout:  npm ~8 flat dirs vs deno ~4 junctions + node_modules/.deno/."
echo "    - phantom: has-flag resolves under node, 'Cannot find module' under deno."
echo "    - audit:   SAME GHSA ids; npm counts per-package, deno per-advisory (counts drift)."
