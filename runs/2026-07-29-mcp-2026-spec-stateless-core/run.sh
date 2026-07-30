#!/usr/bin/env bash
#
# Reproduce the "MCP 2026-07-28 spec goes stateless" firsthand check, verified
# against the protocol's OWN machine-readable schema.json (not a press summary).
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-29-mcp-2026-spec-stateless-core
#     ./run.sh
#
# What it does: probe.py fetches two published MCP schemas —
#   - schema/2025-11-25/schema.json  (previous stable revision, FROZEN)
#   - schema/draft/schema.json       (the 2026-07-28 release-candidate line, MUTABLE)
# — and asserts, symbol by symbol, that the JSON-RPC types the changelog says were
# REMOVED are absent and the ones it says were ADDED are present. Writes probe-result.json.
#
# Requires on PATH:
#   - python3 (stdlib only: urllib + json). No external deps, no Docker.
#
# DETERMINISM / DRIFT — read this:
#   The committed probe-result.json is the 2026-07-27 snapshot (20/20 assertions passed).
#   The 2025-11-25 axis is a frozen published revision and reproduces exactly.
#   The 'draft' axis is a MOVING TARGET: after the 2026-07-28 publish, schema/draft/
#   advances to the next revision, so a fresh fetch may show a different symbol set.
#   That drift is expected and is part of the finding. To see it explicitly:
#
#       ./run.sh
#       git diff -- probe-result.json     # deltas vs the committed 2026-07-27 snapshot
#
#   The schema snapshots themselves are NOT committed (174 KB + 180 KB exceed the
#   repo's 100 KB per-run budget, and the draft is mutable); probe.py re-fetches them.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

command -v python3 >/dev/null 2>&1 && PY=python3 || PY=python
command -v "$PY" >/dev/null 2>&1 || { echo "python not on PATH"; exit 1; }

echo "==> Python version"
"$PY" --version

echo
echo "==> Fetching both schemas and running the changelog-vs-schema probe"
"$PY" probe.py --fetch

echo
echo "==> Done. Wrote probe-result.json"
echo "    Expected (2026-07-27 snapshot): 20/20 assertions passed;"
echo "    145 \$defs at 2025-11-25 -> 154 at draft."
echo "    Compare against the committed snapshot:  git diff -- probe-result.json"
echo "    (A non-empty draft-axis diff is expected drift, not a failure — see the header.)"
