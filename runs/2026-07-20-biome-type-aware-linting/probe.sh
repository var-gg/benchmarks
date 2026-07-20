#!/usr/bin/env bash
# Reproduce the Biome 2.5 type-aware-linting firsthand checks.
#   ./probe.sh
# Installs @biomejs/biome (NO typescript), drops fixtures/, runs 4 experiments,
# writes probe-result.json. Deterministic (fixed fixtures -> fixed diagnostics).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/work"; rm -rf "$WORK"; mkdir -p "$WORK/src"; cd "$WORK"
echo '{ "name":"biome-fh","private":true,"version":"0.0.0","type":"module" }' > package.json
echo "==> npm install @biomejs/biome (no typescript)"
npm install --no-audit --no-fund --loglevel=error @biomejs/biome
VER=$(npx biome --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
TS_PRESENT=$([ -d node_modules/typescript ] && echo true || echo false)
cp "$HERE"/fixtures/*.ts src/
cp -r "$HERE"/plugins ./plugins
cp "$HERE"/biome.json ./biome.json

flag() { npx biome lint "$1" 2>&1 | grep -qE "$2" && echo true || echo false; }

# EXP1 single file, no tsc
E1_FLOAT=$(npx biome lint src/floating.ts 2>&1 | grep -c "floating.ts:4")
# EXP2 cross-file
E2=$(npx biome lint ./src 2>&1 | grep -c "mod-b.ts:4")
# EXP3 boundary
BND=$(npx biome lint src/boundary.ts 2>&1 | grep -oE "boundary.ts:[0-9]+" | sort -u | tr '\n' ' ')
# EXP4 gritql plugin
E4=$(npx biome lint src/spread.ts 2>&1 | grep -c "Object.assign")

cat > "$HERE/probe-result.json" <<EOF
{
  "biome_version": "$VER",
  "typescript_installed": $TS_PRESENT,
  "exp1_floating_flagged_no_tsc": $([ "$E1_FLOAT" -gt 0 ] && echo true || echo false),
  "exp2_cross_file_flagged": $([ "$E2" -gt 0 ] && echo true || echo false),
  "exp3_boundary_flagged_lines": "$BND (3=nativePromise 11=Promise.all; line 8 custom thenable expected ABSENT)",
  "exp4_gritql_plugin_flagged": $([ "$E4" -gt 0 ] && echo true || echo false)
}
EOF
echo "==> wrote probe-result.json"; cat "$HERE/probe-result.json"
