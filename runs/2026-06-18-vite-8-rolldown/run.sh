#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the Vite 7 (Rollup) vs Vite 8
# (Rolldown) build A/B on an identical 24-component React dashboard.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-18-vite-8-rolldown
#   ./run.sh
#
# Builds the SAME generated app (fixture/gen-app.mjs) on both Vite versions and
# times the production build. Absolute ms are machine-dependent; the durable
# signal is the RATIO (Vite 8 build vs Vite 7 build) and the dependency/output
# facts in results.json. Needs: node + npm, network (npm install).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

VITE7="7.3.5"
PLUGIN7="5"
VITE8="8.0.16"
PLUGIN8="6.0.2"

command -v node >/dev/null 2>&1 || { echo "need node (bench recorded on v24.15.0)"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "need npm (bench recorded on 11.12.1)"; exit 1; }
echo "==> node $(node --version) / npm $(npm --version)   (recorded: v24.15.0 / 11.12.1)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

build_one () {
  local label="$1" vite="$2" plugin="$3"
  local dir="$WORK/$label"
  mkdir -p "$dir"
  node "$HERE/fixture/gen-app.mjs" "$dir" >/dev/null

  cat > "$dir/package.json" <<JSON
{
  "name": "$label",
  "private": true,
  "type": "module",
  "scripts": { "build": "vite build" },
  "dependencies": { "react": "^19.0.0", "react-dom": "^19.0.0", "recharts": "^2.13.0", "lucide-react": "^0.400.0" },
  "devDependencies": { "vite": "$vite", "@vitejs/plugin-react": "$plugin" }
}
JSON

  cat > "$dir/vite.config.js" <<'JS'
import react from "@vitejs/plugin-react";
export default { plugins: [react()], logLevel: "error" };
JS

  ( cd "$dir"
    echo "==> [$label] npm install (vite@$vite, plugin-react@$plugin)"
    npm install --silent --no-audit --no-fund >/dev/null 2>&1

    echo "==> [$label] installed packages: $(ls node_modules/.bin | tr '\n' ' ')"
    echo "==> [$label] .bin engines: $(ls node_modules/.bin | grep -E '^(esbuild|rollup|rolldown|vite)$' | tr '\n' ' ')"

    echo "==> [$label] build cold"
    rm -rf dist node_modules/.vite
    /usr/bin/time -p npm run build >/dev/null 2>>"$WORK/$label.time" || time npm run build >/dev/null

    echo "==> [$label] build warm"
    /usr/bin/time -p npm run build >/dev/null 2>>"$WORK/$label.time" || time npm run build >/dev/null

    echo "==> [$label] bundle bytes: $(du -b dist/assets/index-*.js 2>/dev/null | awk '{print $1}' | head -1)"
  )
}

build_one bench7 "$VITE7" "$PLUGIN7"
build_one bench8 "$VITE8" "$PLUGIN8"

echo
echo "==> Done. Compare against results.json:"
echo "    - bench8 build should be ~13-14x faster than bench7 (production build)."
echo "    - bench7 .bin has {esbuild,rollup,vite}; bench8 has {rolldown,vite}."
echo "    - both bundles ~equal size (output parity)."
echo "    Absolute ms differ per machine — the ratio + the .bin engine swap are the durable claims."
