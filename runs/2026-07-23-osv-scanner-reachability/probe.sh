#!/usr/bin/env bash
# Reproduce the OSV-Scanner reachability (call analysis) firsthand check.
#   ./probe.sh
#
# Requires on PATH: `go` (toolchain, needed for Go call-graph analysis) and
# `osv-scanner` (v2.x). Set OSV=/path/to/osv-scanner.exe to override.
#
# Two Go modules under reachable/ and unreachable/ share the SAME vulnerable
# dependency golang.org/x/text@v0.3.7 (GO-2022-1059 / CVE-2022-32149, vulnerable
# symbol language.ParseAcceptLanguage). reachable/ calls it; unreachable/ imports
# the same package+version but only calls language.Make.
#
# Deterministic: fixed sources + pinned dep + pinned advisory -> fixed verdicts.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OSV="${OSV:-osv-scanner}"

count() {  # dir, extra-flag -> number of vulns in the "Total N package(s) affected" line
  "$OSV" scan source $2 "$HERE/$1" 2>/dev/null \
    | grep -oE "Total [0-9]+ packages? affected by [0-9]+" | grep -oE "by [0-9]+" | grep -oE "[0-9]+"
}
called() {  # dir -> the experimental_analysis called flag for GO-2022-1059
  "$OSV" scan source --call-analysis=go --all-vulns --format json "$HERE/$1" 2>/dev/null \
    | python -c "import sys,json;d=json.load(sys.stdin);print(str([g['experimental_analysis']['GO-2022-1059']['called'] for r in d['results'] for p in r['packages'] for g in p.get('groups',[]) if 'experimental_analysis' in g][0]).lower())"
}

R_NAIVE=$(count reachable "--no-call-analysis=go")
R_REACH=$(count reachable "--call-analysis=go")
U_NAIVE=$(count unreachable "--no-call-analysis=go")
U_REACH=$(count unreachable "--call-analysis=go")
R_CALLED=$(called reachable)
U_CALLED=$(called unreachable)

cat > "$HERE/probe-result.gen.json" <<EOF
{
  "osv_scanner_version": "$("$OSV" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)",
  "go_version": "$(go version | grep -oE 'go[0-9.]+' | head -1)",
  "reachable_variant":   { "naive_reported": $([ "$R_NAIVE" -gt 0 ] && echo true || echo false), "call_analysis_reported": $([ "$R_REACH" -gt 0 ] && echo true || echo false), "called": $R_CALLED },
  "unreachable_variant": { "naive_reported": $([ "$U_NAIVE" -gt 0 ] && echo true || echo false), "call_analysis_reported": $([ "$U_REACH" -gt 0 ] && echo true || echo false), "called": $U_CALLED }
}
EOF
echo "==> wrote probe-result.gen.json"; cat "$HERE/probe-result.gen.json"
echo
echo "Expected: reachable {naive:true, call_analysis:true, called:true};"
echo "          unreachable {naive:true, call_analysis:false, called:false}."
echo "Same dep + same CVE; only the call graph differs."
