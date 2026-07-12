#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the uv audit vs pip-audit A/B.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-20-uv-audit-supply-chain
#   ./run.sh
#
# Reproduces the METHOD from fixture/pyproject.toml. Vulnerability COUNTS are
# point-in-time against the live OSV database — your numbers may differ from the
# 2026-06-20 snapshot in results.json (OSV updates). The ~20x speed ratio and the
# result-parity finding are the durable claims.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

UV_VERSION="0.11.23"   # first build with `uv audit --output-format sarif`

command -v uv >/dev/null 2>&1 || {
  echo "Install uv ${UV_VERSION} first:  https://github.com/astral-sh/uv/releases/tag/${UV_VERSION}"
  echo "(The original run used a standalone ${UV_VERSION} binary; global uv was left untouched.)"
  exit 1
}
echo "==> uv version: $(uv --version)   (original run: ${UV_VERSION})"

WORK="$(mktemp -d)"
cp fixture/pyproject.toml "$WORK/pyproject.toml"
cd "$WORK"

echo "==> resolve the deliberately-vulnerable fixture"
uv lock

echo "==> uv audit (text)  — time it"
time uv audit --preview-features audit-command || true   # exit 1 on findings is expected

echo "==> uv audit (json summary)"
uv audit --preview-features audit-command --output-format json | \
  python -c "import sys,json;d=json.load(sys.stdin);s=d.get('summary',{});print('   summary:',s)" || true

echo "==> pip-audit over the same deps (baseline) — time it"
uv export --format requirements-txt --no-hashes > requirements.txt 2>/dev/null || uv pip compile pyproject.toml -o requirements.txt
time uvx --from pip-audit pip-audit -r requirements.txt --vulnerability-service osv || true

echo
echo "==> Done. Compare the vuln id sets + timings against results.json."
echo "    Expect: identical vuln id set between the two tools; uv audit ~20x faster warm."
echo "    Counts will drift from the 2026-06-20 snapshot as OSV updates — that is expected."
rm -rf "$WORK"
