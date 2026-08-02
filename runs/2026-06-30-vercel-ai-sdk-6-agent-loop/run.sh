#!/usr/bin/env bash
#
# Reproduce the "Vercel AI SDK 6 agent tool loop" firsthand check.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-30-vercel-ai-sdk-6-agent-loop
#     ./run.sh
#
# What it does: installs the PINNED SDK (ai@6.0.212 + zod@4.4.3) and runs exp.ts,
# a pure MockLanguageModelV3 harness that makes ZERO model calls. Every assertion is
# about the SDK's own control flow (step counts, tool-error feedback, structured-output
# throws, the ToolLoopAgent default stopWhen cap), so the result is fully deterministic.
# Writes probe-result.json.
#
# DETERMINISM:
#   No network to any LLM, no Docker, no timing. The model is a scripted mock, so the
#   step counts and error types are pinned by the SDK version, not by hardware or a
#   provider. Re-running with ai@6.0.212 reproduces the committed probe-result.json
#   (the 'meta.node' field will reflect your local Node; the experiment values will not).
#
# Requires on PATH:
#   - node + npm (npm installs ai/zod/tsx into a local node_modules; node_modules is gitignored)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

command -v node >/dev/null 2>&1 || { echo "node not on PATH"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "npm not on PATH"; exit 1; }

echo "==> Node / npm versions"
node --version
npm --version

echo
echo "==> Installing pinned deps (ai@6.0.212, zod@4.4.3, tsx)"
npm install --no-audit --no-fund

echo
echo "==> Running the deterministic mock harness (0 model calls)"
npx tsx exp.ts

echo
echo "==> Done. Wrote probe-result.json"
echo "    Expected: F2 default cap = ToolLoopAgent 20 steps vs generateText 1 step;"
echo "    B (no stopWhen) = 1 step, empty text, tool still executed;"
echo "    G (maxSteps:5) = ignored, 1 step, empty text."
echo "    Compare against the committed snapshot:  git diff -- probe-result.json"
