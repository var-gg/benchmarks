#!/usr/bin/env bash
#
# Reproduce the Wasmtime 46 WASI permission experiments.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-07-wasmtime-46-wasi-sandbox
#     ./run.sh
#
# Requires: rustc + cargo (1.95 used originally), the wasm32-wasip1 target, curl,
# and network access (downloads two pinned wasmtime CLI releases + builds the
# embedding host twice against the pinned crates).
#
# Everything is created under work/, which is .gitignored.
#
# EXP-A  capability boundary, via the wasmtime CLI.
# EXP-C  GHSA-4ch3-9j33-3pmj A/B, via the embedding host — 46.0.0 then 46.0.1.
#
# Compare the output against observed-output.txt / results.json. The line that
# decides the CVE is step 4 of EXP-C, not step 3.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VULN="46.0.0"
FIXED="46.0.1"
WORK="$HERE/work"

echo "==> toolchain"
rustc --version
cargo --version
rustup target add wasm32-wasip1 2>/dev/null || true

# ---------------------------------------------------------------- platform ---
case "$(uname -s)" in
  Linux)   ASSET_OS="x86_64-linux";        EXT="tar.xz"; BIN="wasmtime" ;;
  Darwin)  case "$(uname -m)" in
             arm64) ASSET_OS="aarch64-macos" ;;
             *)     ASSET_OS="x86_64-macos" ;;
           esac;                            EXT="tar.xz"; BIN="wasmtime" ;;
  MINGW*|MSYS*|CYGWIN*) ASSET_OS="x86_64-windows"; EXT="zip"; BIN="wasmtime.exe" ;;
  *) echo "unsupported platform: $(uname -s)"; exit 1 ;;
esac

fetch_wasmtime() {  # $1 = version
  local v="$1" dir="$WORK/wasmtime-$v"
  [ -x "$dir/$BIN" ] && { echo "$dir/$BIN"; return; }
  mkdir -p "$dir"
  local name="wasmtime-v${v}-${ASSET_OS}"
  local url="https://github.com/bytecodealliance/wasmtime/releases/download/v${v}/${name}.${EXT}"
  echo "    downloading $url" >&2
  curl -sSL "$url" -o "$dir/pkg.$EXT"
  ( cd "$dir"
    if [ "$EXT" = "zip" ]; then unzip -q -o "pkg.$EXT"; else tar xf "pkg.$EXT"; fi
    mv "$name/$BIN" . )
  echo "$dir/$BIN"
}

mkdir -p "$WORK"

# ------------------------------------------------------------------ EXP-A ---
echo
echo "==> EXP-A  capability / preopen boundary (CLI)"
WT_FIXED="$(fetch_wasmtime "$FIXED")"
"$WT_FIXED" --version

mkdir -p "$WORK/expA/sandbox"
echo -n "allowed-content-123"  > "$WORK/expA/sandbox/allowed.txt"
echo -n "SECRET-outside"       > "$WORK/expA/secret.txt"
rustc -O --target wasm32-wasip1 harness/guest_a.rs -o "$WORK/expA/guest_a.wasm"

( cd "$WORK/expA"
  echo "--- with --dir sandbox::/ ---"
  "$WT_FIXED" run --dir sandbox::/ guest_a.wasm
  echo "--- with no --dir at all ---"
  "$WT_FIXED" run guest_a.wasm )

echo "--- CLI --dir help (note: no read-only variant) ---"
"$WT_FIXED" run --help | grep -A1 -- '--dir' || true

# ------------------------------------------------------------------ EXP-C ---
echo
echo "==> EXP-C  FilePerms hard-link bypass, ${VULN} vs ${FIXED}"
rustc -O --target wasm32-wasip1 harness/guest_cve.rs -o "$WORK/guest_cve.wasm"

run_host() {  # $1 = wasmtime crate version, $2 = label
  local v="$1" label="$2"
  local stage="$WORK/host-$v"
  rm -rf "$stage"; mkdir -p "$stage"
  cp -r harness/host/. "$stage/"
  # Repin both crates to the version under test.
  sed -i.bak -E "s/^(wasmtime(-wasi)?) = \"=.*\"/\1 = \"=${v}\"/" "$stage/Cargo.toml"
  rm -f "$stage/Cargo.toml.bak"
  ( cd "$stage" && cargo build --release --quiet )

  # Fresh fixture per version — the point is the file's final CONTENT.
  local play="$WORK/play-$v"
  rm -rf "$play"; mkdir -p "$play/ro" "$play/rw"
  echo -n "SECRET-readonly-original" > "$play/ro/secret.txt"
  cp "$WORK/guest_cve.wasm" "$play/guest_cve.wasm"

  echo
  echo "=== wasmtime ${v} (${label}) ==="
  ( cd "$play" && "$stage/target/release/wasi-perms-host"* ) || true
}

run_host "$VULN" "vulnerable"
run_host "$FIXED" "patched"

echo
echo "==> Done."
echo "    Expected: ${VULN} → step2 LINKED, step4 \"MODIFIED-VIA-LINK\""
echo "              ${FIXED} → step2 BLOCKED, step4 \"SECRET-readonly-original\""
echo "    Step 3 prints WROTE on both. That line is not evidence — step 4 is."
echo "    Compare against observed-output.txt (original 2026-07-01 run)."
