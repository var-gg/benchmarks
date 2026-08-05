#!/usr/bin/env bash
#
# Reproduce the Microsoft Coreutils 2026.6.16 dialect-dispatch / cross-tool behavior
# study. Windows only (needs System32 find.exe/sort.exe + a Git Bash /usr/bin/sort as
# baselines). Run from Git Bash:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-26-coreutils-for-windows
#     ./run.sh
#
# What it does:
#   1. Obtains Microsoft Coreutils 2026.6.16 (pinned). Two paths:
#        a) winget install --version 2026.6.16 Microsoft.Coreutils   (needs elevation)
#        b) portable zip via $COREUTILS_ZIP_URL                      (what the original run used)
#   2. Builds argv0 shims (find.exe/sort.exe/grep.exe/echo.exe/wc.exe = copies of
#      coreutils.exe) — this is exactly how the multi-call binary dispatches.
#   3. Recreates the fixtures (fixtures.sh) and runs the harness (probe.sh).
#
# NOTE: this run is a backfill (see manifest.json.backfilled). results.json records the
# 2026-06-26 observations; this script lets you re-confirm them against the pinned binary.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VERSION="2026.6.16"
WORK="$HERE/.work"
mkdir -p "$WORK"

echo "==> 1. obtaining Microsoft Coreutils ${VERSION}"
COREUTILS=""
if command -v coreutils.exe >/dev/null 2>&1; then
  COREUTILS="$(command -v coreutils.exe)"
  echo "    found on PATH: $COREUTILS"
  "$COREUTILS" --version | grep -q "$VERSION" || echo "    WARN: PATH coreutils is not ${VERSION}; behavior may differ (that is the point of pinning)."
elif [ -n "${COREUTILS_ZIP_URL:-}" ]; then
  echo "    downloading portable zip: $COREUTILS_ZIP_URL"
  curl -fsSL "$COREUTILS_ZIP_URL" -o "$WORK/coreutils.zip"
  ( cd "$WORK" && unzip -oq coreutils.zip )
  COREUTILS="$(find "$WORK" -name coreutils.exe -type f | head -1)"
else
  cat >&2 <<EOF
    Could not find coreutils.exe on PATH and \$COREUTILS_ZIP_URL is unset.
    Pick one:
      winget install --version ${VERSION} Microsoft.Coreutils   # then re-run ./run.sh
    or set the pinned portable release asset (confirm the exact tag on the
    microsoft/coreutils releases page — the ${VERSION} x64 zip):
      COREUTILS_ZIP_URL="https://github.com/microsoft/coreutils/releases/download/v${VERSION}/coreutils-${VERSION}-x64.zip" ./run.sh
EOF
  exit 2
fi
echo "    using: $COREUTILS"
export COREUTILS

echo "==> 2. building argv0 shims"
SHIM_DIR="$HERE/shims"
rm -rf "$SHIM_DIR"; mkdir -p "$SHIM_DIR"
for name in find sort grep echo wc; do
  cp "$COREUTILS" "$SHIM_DIR/$name.exe"
done
export SHIM_DIR
echo "    shims: $(ls "$SHIM_DIR" | tr '\n' ' ')"

echo "==> 3. fixtures"
bash "$HERE/fixtures.sh" ${WITH_BIG:+--with-big}

echo "==> 4. probe"
bash "$HERE/probe.sh" | tee "$HERE/probe-output.txt"

echo
echo "==> done. Transcript in probe-output.txt. Compare against results.json."
echo "    (probe-output.txt, shims/, .work/, *.txt fixtures are all regenerable and git-ignored.)"
