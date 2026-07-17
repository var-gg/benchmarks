#!/usr/bin/env bash
#
# Reproduce the LanceDB 0.34.0 firsthand probe (embedded, no Docker/GPU/network).
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-10-lancedb-embedded-vector-lakehouse
#     ./run.sh
#
# Produces probe-result.json. Compare it against the committed results.json.
# EXP B (exact top-k order + squared-L2) and EXP D (versioning) are bit-deterministic
# and should match exactly. EXP E default recall (0.7) matches; the tuned recall and
# EXP F BM25 scores can drift slightly with the pinned tantivy/PQ build — see results.json.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

echo "==> Creating isolated Python environment"
python -m venv .venv
if [ -f .venv/Scripts/activate ]; then source .venv/Scripts/activate; else source .venv/bin/activate; fi

echo "==> Installing pinned lancedb==0.34.0"
pip install -q -r requirements.txt

echo "==> Running the probe (embedded — writes to a scratch dir, no daemon)"
python probe.py

echo
echo "==> Done. Wrote probe-result.json."
echo "    Confirm probe-result.json.lancedb_version == 0.34.0 (manifest.json.subject.version)."
