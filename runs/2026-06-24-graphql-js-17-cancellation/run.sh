#!/usr/bin/env bash
#
# Reproduce the GraphQL.js v16-vs-v17 cancellation / cleanup / observability probe.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-24-graphql-js-17-cancellation
#     ./run.sh
#
# Installs graphql@16.14.2 and graphql@17.0.1 side by side (npm aliases in
# package.json), runs all four contracts in one Node process, and writes
# probe-result.json. Compare it against results.json.
#
# The evidence is the CONTRACTS (throw vs resolve, event ordering, whether the
# cooperative child aborts, the diagnostics channel payloads, error.abortedResult),
# not the millisecond timings — those drift per machine and are context only.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_NODE_MAJOR="24"
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$node_major" != "$EXPECTED_NODE_MAJOR" ]; then
  echo "WARN: pinned run used Node ${EXPECTED_NODE_MAJOR}.x (v24.15.0); you have $(node --version)."
  echo "      The CONTRACTS should still hold; only timings/ordering micro-details may vary."
fi

echo "==> Installing pinned graphql 16.14.2 (baseline) + 17.0.1 (subject)"
npm install --no-audit --no-fund

echo "==> Running the four-contract probe"
node probe.mjs

echo
echo "==> Done. Wrote probe-result.json. Compare against results.json:"
echo "    1. v16 ignores abortSignal (both fields resolve)  vs  v17 throws AbortedGraphQLExecutionError"
echo "    2. v17 cooperative: db:abort:coop fires, but a non-propagating resolver's db:done:slow still runs (orphan)"
echo "    3. cancel != rollback: both mutation steps commit despite the abort"
echo "    4. error.abortedResult keeps the partial data { fast, slow:null }"
