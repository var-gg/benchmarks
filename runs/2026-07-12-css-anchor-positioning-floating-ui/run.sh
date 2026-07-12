#!/usr/bin/env bash
#
# Reproduce the CSS anchor-positioning support + behavior probe for Chromium 147.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-12-css-anchor-positioning-floating-ui
#     ./run.sh
#
# Produces: probe-result.json (the CSS.supports() matrix) and render-chromium.png
# (an illustrative screenshot). Compare probe-result.json against results.json.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_CHROMIUM="147.0.7727.15"

echo "==> Creating isolated Python environment"
python -m venv .venv
# Windows Git Bash uses Scripts/; POSIX uses bin/.
if [ -f .venv/Scripts/activate ]; then source .venv/Scripts/activate; else source .venv/bin/activate; fi

echo "==> Installing pinned Playwright (ships Chromium ${EXPECTED_CHROMIUM})"
pip install -q -r requirements.txt

echo "==> Installing the Chromium build under test"
python -m playwright install chromium

echo "==> Running the probe"
python probe.py

echo
echo "==> Done. Wrote probe-result.json and render-chromium.png"
echo "    Confirm probe-result.json.chromium.version == ${EXPECTED_CHROMIUM} (manifest.json.subject.version)."
echo "    If your Playwright ships a different Chromium build, the support matrix may differ — that IS the point of pinning."
