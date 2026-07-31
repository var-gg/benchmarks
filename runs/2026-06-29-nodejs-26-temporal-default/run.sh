#!/usr/bin/env bash
#
# Reproduce the Node.js 26 Temporal-vs-Date behavior probe on the PINNED build
# the post measured (v26.4.0). Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-29-nodejs-26-temporal-default
#     ./run.sh
#
# Downloads the official node v26.4.0 portable build into ./.node (isolated,
# gitignored), then runs exp.mjs. Produces probe-result.json — compare it against
# the committed results.json.
#
# Why pin v26.4.0: Temporal became a default global in Node 26, and V8 14.6 adds
# Map.getOrInsert / Iterator.concat. On Node <26 the Temporal rows would be absent;
# that difference is exactly what the pin protects.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VER="26.4.0"

# TZ pinning matters for the two "string parsing" rows: `new Date("2026/06/29")`
# resolves to LOCAL midnight, so on a UTC-only machine it would coincide with the
# ISO/UTC parse. Pin to Asia/Seoul to match the recorded run.
export TZ="Asia/Seoul"

uname_s="$(uname -s)"
case "$uname_s" in
  Linux*)  pkg="node-v${VER}-linux-x64";  ext="tar.xz"; bin=".node/${pkg}/bin/node" ;;
  Darwin*)
    arch="$(uname -m)"; [ "$arch" = "arm64" ] && a="arm64" || a="x64"
    pkg="node-v${VER}-darwin-${a}"; ext="tar.xz"; bin=".node/${pkg}/bin/node" ;;
  MINGW*|MSYS*|CYGWIN*)
    pkg="node-v${VER}-win-x64"; ext="zip"; bin=".node/${pkg}/node.exe" ;;
  *) echo "unsupported OS: $uname_s"; exit 1 ;;
esac

if [ ! -x "$bin" ] && [ ! -f "$bin" ]; then
  echo "==> Fetching official Node ${VER} portable build ($pkg)"
  mkdir -p .node
  url="https://nodejs.org/dist/v${VER}/${pkg}.${ext}"
  if [ "$ext" = "zip" ]; then
    curl -sSL -o ".node/${pkg}.zip" "$url"
    ( cd .node && unzip -q "${pkg}.zip" )
  else
    curl -sSL "$url" | tar -xJ -C .node
  fi
fi

echo "==> node $("$bin" --version)  (expected v${VER})"
echo "==> Running exp.mjs (TZ=${TZ})"
"$bin" exp.mjs

echo
echo "==> Done. Wrote probe-result.json."
echo "    Confirm probe-result.json.environment.node == ${VER}, then diff the"
echo "    behavior fields against results.json (behaviors_verified / cited_not_measured)."
