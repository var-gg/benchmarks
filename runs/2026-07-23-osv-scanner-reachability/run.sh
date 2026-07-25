#!/usr/bin/env bash
#
# Reproduce the OSV-Scanner Go reachability (call analysis) firsthand check.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-23-osv-scanner-reachability
#     ./run.sh
#
# Produces: probe-result.gen.json — the 2x2 alert matrix (naive vs reachability,
# for the reachable vs unreachable module) plus the experimental_analysis.called
# boolean for GO-2022-1059. Compare it against the committed probe-result.json.
#
# Requires on PATH:
#   - go          (toolchain; call analysis builds the module to construct the call graph)
#   - osv-scanner (v2.x; set OSV=/path/to/osv-scanner to override)
#
# The two modules under reachable/ and unreachable/ share the SAME vulnerable
# dependency golang.org/x/text@v0.3.7 (GO-2022-1059 / CVE-2022-32149, vulnerable
# symbol language.ParseAcceptLanguage). reachable/ calls it; unreachable/ imports
# the same package+version but only calls language.Make.
#
# Deterministic: fixed sources + pinned dep + pinned advisory -> fixed verdicts.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_OSV="2.4.0"
EXPECTED_GO="go1.25.5"

echo "==> Tool versions"
command -v go          >/dev/null || { echo "go not on PATH"; exit 1; }
command -v osv-scanner >/dev/null || [ -n "${OSV:-}" ] || { echo "osv-scanner not on PATH (or set OSV=)"; exit 1; }
go version
"${OSV:-osv-scanner}" --version 2>/dev/null | head -1
echo "    (pinned run used osv-scanner ${EXPECTED_OSV} / ${EXPECTED_GO})"

echo
echo "==> Running the reachability probe over both fixture modules"
./probe.sh

echo
echo "==> Done. Wrote probe-result.gen.json"
echo "    Expected: reachable {naive:true, call_analysis:true, called:true};"
echo "              unreachable {naive:true, call_analysis:false, called:false}."
echo "    Same dep + same CVE; only the call graph differs. Compare with probe-result.json."
