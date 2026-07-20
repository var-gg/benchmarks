#!/usr/bin/env bash
#
# Reproduce the Biome 2.5.4 type-aware-linting probe.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-20-biome-type-aware-linting
#     ./run.sh
#
# Requires: node + npm (Node v24 used originally). NO typescript is installed —
# that absence is the point: the type-aware rules must infer types on their own.
#
# Delegates to probe.sh, which installs @biomejs/biome into a throwaway work/ dir,
# drops the fixtures, runs the four experiments, and writes probe-result.json.
# Compare the regenerated probe-result.json against the committed results.json.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_BIOME="2.5.4"

echo "==> Node / npm"
node --version
npm --version

echo "==> Running probe.sh (installs @biomejs/biome ${EXPECTED_BIOME}, no typescript)"
bash ./probe.sh

echo
echo "==> Done. Wrote probe-result.json"
echo "    Confirm probe-result.json.biome_version == ${EXPECTED_BIOME} (manifest.json.subject.version)."
echo "    All four booleans should be true; boundary line 8 (custom thenable) stays UNflagged — the honest coverage gap."
