#!/usr/bin/env bash
#
# Reproduce the Python 3.15 UTF-8-default (PEP 686) encoding probe.
# Third-party runnable on Windows (Git Bash / MSYS) with any host python3:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-22-python-315-utf8-default
#     ./run.sh
#
# Downloads two PINNED python.org embeddable builds, runs the probe under each,
# and writes probe-result.json. Compare it against the committed results.json.
#
# IMPORTANT — environment sensitivity:
#   This experiment is about the DEFAULT text encoding, which on Windows is
#   derived from the ANSI codepage. The essay's contrast (cp949 -> utf-8) only
#   appears on a NON-UTF-8 ANSI codepage. On a Korean/Japanese/etc. Windows it
#   reproduces as recorded; on a UTF-8 locale both builds already default to
#   UTF-8 and the "flip" is a no-op. That dependence is the whole point.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

OLD_VER="3.14.6"
NEW_VER="3.15.0b2"
OLD_URL="https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-amd64.zip"
NEW_URL="https://www.python.org/ftp/python/3.15.0/python-3.15.0b2-embed-amd64.zip"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Fetching pinned python.org embeddable builds (Windows amd64)"
curl -sSL "$OLD_URL" -o "$WORK/old.zip"
curl -sSL "$NEW_URL" -o "$WORK/new.zip"

echo "==> Extracting"
python -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$WORK/old.zip" "$WORK/old"
python -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$WORK/new.zip" "$WORK/new"

echo "==> Running the encoding probe under ${OLD_VER} and ${NEW_VER}"
python probe.py \
  --old "$WORK/old/python.exe" --new "$WORK/new/python.exe" \
  --old-label "$OLD_VER" --new-label "$NEW_VER" \
  > probe-result.json

echo
echo "==> Wrote probe-result.json"
echo "    Confirm interpreters.${NEW_VER}.utf8_mode == 1 and .getpreferredencoding == 'utf-8',"
echo "    and interpreters.${OLD_VER}.getpreferredencoding == 'cp949' (on a CP949 host)."
