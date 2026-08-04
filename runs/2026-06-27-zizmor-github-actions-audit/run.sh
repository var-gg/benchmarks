#!/usr/bin/env bash
#
# Reproduce the zizmor GitHub Actions audit run.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-27-zizmor-github-actions-audit
#   ./run.sh
#
# Deterministic: pinned zizmor 1.26.1 + the committed fixture + --offline produce
# the SAME output on any machine. Expect exactly 15 findings on the regular persona
# (7 unpinned-uses, 2 artipacked, 2 template-injection, 1 excessive-permissions,
#  1 dangerous-triggers, 1 unsound-ternary, 1 typosquat-uses; High 11 / Medium 3 / Low 1)
# and a non-zero exit code (14).
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ZIZMOR_VERSION="1.26.1"

command -v uvx >/dev/null 2>&1 || {
  echo "This harness runs zizmor via uvx (from the uv toolchain): https://docs.astral.sh/uv/"
  echo "Or install zizmor directly: https://github.com/woodruffw/zizmor/releases/tag/v${ZIZMOR_VERSION}"
  exit 1
}

WF="fixture/.github/workflows"
echo "==> zizmor ${ZIZMOR_VERSION}, offline, regular persona"
uvx "zizmor@${ZIZMOR_VERSION}" --offline --persona regular "$WF"
RC=$?
echo "==> exit code: ${RC}   (expected 14 — findings present, CI gate would fail)"

echo
echo "==> machine-readable summary (regular persona)"
uvx "zizmor@${ZIZMOR_VERSION}" --offline --persona regular --format json "$WF" \
  | python -c "import sys,json,collections;d=json.load(sys.stdin);c=collections.Counter(f['ident'] for f in d);print('total:',len(d));[print(f'  {n:2d} {k}') for k,n in sorted(c.items(),key=lambda x:-x[1])]" \
  || true

echo
echo "==> persona escalation (signal/noise tradeoff)"
for P in regular pedantic auditor; do
  N=$(uvx "zizmor@${ZIZMOR_VERSION}" --offline --persona "$P" --format json "$WF" 2>/dev/null \
        | python -c "import sys,json;print(len(json.load(sys.stdin)))")
  echo "     ${P}: ${N}"
done

echo
echo "==> SARIF 2.1.0 output (GitHub code scanning)"
uvx "zizmor@${ZIZMOR_VERSION}" --offline --format sarif "$WF" 2>/dev/null \
  | python -c "import sys,json;d=json.load(sys.stdin);r=d['runs'][0];print('     version',d.get('version'),'driver',r['tool']['driver']['name'],r['tool']['driver'].get('version'),'rules',len(r['tool']['driver'].get('rules',[])),'results',len(r.get('results',[])))" \
  || true

echo
echo "==> auto-fix demo (on a scratch copy, original fixture untouched)"
TMP="$(mktemp -d)"
cp -r fixture/.github "$TMP/.github"
( cd "$TMP" && uvx "zizmor@${ZIZMOR_VERSION}" --offline --fix=all .github/workflows 2>&1 | grep -iE "fix summary|applied|fixes" || true )
rm -rf "$TMP"

echo
echo "==> Done. Compare against results.json (regular persona is byte-stable)."
