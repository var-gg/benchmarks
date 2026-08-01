#!/usr/bin/env bash
#
# Reproduce the Zig 0.16 "Writergate" / I/O-as-an-Interface firsthand checks.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-26-zig-016-writergate-io-interface
#     ./run.sh
#
# Fetches the PINNED zig 0.16.0 toolchain for your OS/arch, then runs probe.sh,
# which compiles four tiny programs and records observed behavior into
# probe-result.gen.json. Compare that against the committed probe-result.json.
#
# If you already have zig 0.16.x on PATH, set ZIG=/path/to/zig to skip the download.
#
# Deterministic: fixed sources + the pinned 0.16.0 compiler -> fixed verdicts.
# The point of pinning is that a DIFFERENT zig version may produce a different
# matrix (the std.Io API landed across 0.15.1 -> 0.16.0).
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

PINNED="0.16.0"
BASE="https://ziglang.org/download/${PINNED}"

# --- If zig is already provided, just run the probe -------------------------
if [ -n "${ZIG:-}" ] || command -v zig >/dev/null 2>&1; then
  ZIG="${ZIG:-zig}"
  have="$("$ZIG" version 2>/dev/null || true)"
  echo "==> Using zig on PATH: ${have}"
  case "$have" in
    0.16.*) ;;
    *) echo "    WARNING: expected 0.16.x; got '${have}'. The matrix may differ — that IS the point of pinning." ;;
  esac
  ZIG="$ZIG" ./probe.sh
  exit $?
fi

# --- Otherwise download the pinned toolchain --------------------------------
# Zig 0.16.0 tarball naming is zig-<arch>-<os>-<ver> (arch first), e.g.
# zig-x86_64-linux-0.16.0.tar.xz, zig-x86_64-windows-0.16.0.zip.
os="$(uname -s)"; arch="$(uname -m)"
case "$arch" in arm64) arch="aarch64" ;; esac
case "$os" in
  Linux)  file="zig-${arch}-linux-${PINNED}.tar.xz"; ext="tar.xz" ;;
  Darwin) file="zig-${arch}-macos-${PINNED}.tar.xz"; ext="tar.xz" ;;
  MINGW*|MSYS*|CYGWIN*) file="zig-${arch}-windows-${PINNED}.zip"; ext="zip" ;;
  *) echo "Unsupported OS '$os'. Download zig ${PINNED} manually from ${BASE}/ and set ZIG=."; exit 1 ;;
esac

url="${BASE}/${file}"
echo "==> Downloading pinned zig ${PINNED}: ${url}"
mkdir -p .zig
if command -v curl >/dev/null 2>&1; then curl -fSL "$url" -o ".zig/${file}"
else wget -O ".zig/${file}" "$url"; fi

echo "==> Extracting"
cd .zig
if [ "$ext" = "zip" ]; then unzip -oq "$file"; else tar xf "$file"; fi
dir="$(find . -maxdepth 1 -type d -name "zig-*-${PINNED}" | head -1)"
cd "$HERE"
ZIG="${HERE}/.zig/${dir#./}/zig"
[ -x "$ZIG" ] || ZIG="${ZIG}.exe"

echo "==> zig version: $("$ZIG" version)"
ZIG="$ZIG" ./probe.sh
