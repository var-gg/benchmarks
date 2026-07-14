#!/usr/bin/env bash
#
# Reproduce the OpenTelemetry Weaver 0.24.2 semconv-registry firsthand run.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-11-otel-weaver-semconv-registry
#     ./run.sh
#
# Downloads the PINNED weaver 0.24.2 binary, then runs every experiment against
# the committed fixtures and writes evidence.txt (exit code per case). Compare
# evidence.txt against results.json — they must match, because check/diff/generate
# are deterministic for a pinned weaver version (no live DB, no timing).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

WEAVER_VERSION="0.24.2"

# ---- resolve platform asset name ----
uname_s="$(uname -s)"
case "$uname_s" in
  Linux*)  ASSET="weaver-x86_64-unknown-linux-gnu.tar.xz"; BIN="weaver" ;;
  Darwin*) if [ "$(uname -m)" = "arm64" ]; then ASSET="weaver-aarch64-apple-darwin.tar.xz"; else ASSET="weaver-x86_64-apple-darwin.tar.xz"; fi; BIN="weaver" ;;
  MINGW*|MSYS*|CYGWIN*) ASSET="weaver-x86_64-pc-windows-msvc.zip"; BIN="weaver.exe" ;;
  *) echo "unsupported OS: $uname_s" >&2; exit 2 ;;
esac
URL="https://github.com/open-telemetry/weaver/releases/download/v${WEAVER_VERSION}/${ASSET}"

echo "==> Fetching weaver ${WEAVER_VERSION} ($ASSET)"
rm -rf .weaver && mkdir -p .weaver && cd .weaver
curl -sSL -o "$ASSET" "$URL"
case "$ASSET" in
  *.zip)    unzip -oq "$ASSET" ;;
  *.tar.xz) tar -xf "$ASSET" ;;
esac
WV="$(find . -name "$BIN" -type f | head -1)"
cd "$HERE"
WV=".weaver/$(basename "$WV")"; [ -f "$WV" ] || WV="$(find .weaver -name "$BIN" -type f | head -1)"

echo "==> weaver version:"; "$WV" --version
[ "$("$WV" --version | awk '{print $2}')" = "$WEAVER_VERSION" ] || { echo "WARN: version drift"; }

run() { "$@" >/dev/null 2>&1; echo $?; }

echo "==> Running experiments"
{
  echo "# evidence.txt — weaver ${WEAVER_VERSION} firsthand run (regenerated)"
  echo "# weaver $("$WV" --version | awk '{print $2}')"
  echo "# each line: <case> exit=<code> (expected)"
  echo "A_clean_check exit=$(run "$WV" registry check -r ./reg) (0)"
  echo "B1_camelCase_builtin exit=$(run "$WV" registry check -r ./reg_b1) (0=builtin_ignores_naming)"
  echo "B2_missing_brief exit=$(run "$WV" registry check -r ./reg_b2) (1)"
  echo "B3_invalid_type_money exit=$(run "$WV" registry check -r ./reg_b3) (1)"
  echo "A2_clean_plus_policy exit=$(run "$WV" registry check -r ./reg -p ./policies) (0)"
  echo "A2_camelCase_plus_policy exit=$(run "$WV" registry check -r ./reg_b1 -p ./policies) (1=policy_catches_naming)"
  echo "B_diff exit=$(run "$WV" registry diff -r ./reg2 --baseline-registry ./reg --format json) (0=informational)"
  echo "C_generate exit=$(run "$WV" registry generate -r ./reg -t ./templates markdown ./gen_out) (0)"
  echo "resolve_deprecated_but_runs exit=$(run "$WV" registry resolve -r ./reg) (0=warns_then_resolves)"
} | tee evidence.regenerated.txt

echo
echo "==> Diff attribute changes (deterministic):"
"$WV" registry diff -r ./reg2 --baseline-registry ./reg --format json 2>/dev/null \
  | python -c "import json,sys;print(json.dumps(json.load(sys.stdin)['changes']['registry_attributes'],indent=2))"

echo
echo "==> Done. Compare evidence.regenerated.txt against the committed evidence.txt / results.json."
echo "    (weaver.exe, .weaver/, and gen_out/ are reproduction byproducts — not committed.)"
