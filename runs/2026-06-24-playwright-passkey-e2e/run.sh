#!/usr/bin/env bash
#
# Reproduce the Playwright 1.61 virtual-passkey capability run across three engines.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-24-playwright-passkey-e2e
#     ./run.sh
#
# Boots the static harness (server.mjs), then runs tests/passkey.spec.ts on
# chromium/firefox/webkit. Compare the per-engine pass/fail against results.json.
#
# NOTE (backfill): the original 2026-06-24 harness was deleted post-publish per the
# finite-disk firsthand policy; this harness is reconstructed from the recorded
# methodology + the 1.61.1 API ground truth. Re-running reproduces the same per-engine
# capability outcomes; wall time drifts and is not an evidence claim.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_PLAYWRIGHT="1.61.1"

echo "==> Installing pinned Playwright (${EXPECTED_PLAYWRIGHT}) + engines"
npm install
npx playwright install

echo "==> Running the passkey spec on chromium / firefox / webkit"
npx playwright test

echo
echo "==> Done. 4 scenarios x 3 engines. Compare against results.json:"
echo "    - seeded discoverable credential resolves a usernameless get()"
echo "    - register -> export -> re-seed a new context -> login"
echo "    - no credential -> NotAllowedError"
echo "    - install() omitted -> native fallback differs per engine (never a clean success)"
