#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the METHOD from the post
# "mise — 버전이 아니라 바이너리를 잠그는 개발 환경 도구".
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-29-mise-dev-toolchain-bootstrap
#   ./run.sh
#
# Reproduces the METHOD, not the exact ms/versions. mise ships ~monthly; the
# original run used mise v2026.6.14 on Windows 11 with an ISOLATED data dir.
# The durable claims are behavioral (trust gate, shim fallback, lockfile
# contents, supply-chain tiers) — see results.json + manifest.drift_warning.
#
# Requires: mise on PATH. Everything is isolated to a scratch dir so your real
# ~/.local/share/mise is never touched.
set -uo pipefail   # not -e: some steps intentionally exit non-zero (trust refusal)

command -v mise >/dev/null 2>&1 || { echo "mise not on PATH — install it first (https://mise.jdx.dev)"; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRATCH="$(mktemp -d)"
# --- isolation: never pollute the user's real mise state (same as the original run)
export MISE_DATA_DIR="$SCRATCH/data"
export MISE_CACHE_DIR="$SCRATCH/cache"
export MISE_STATE_DIR="$SCRATCH/state"
mkdir -p "$MISE_DATA_DIR" "$MISE_CACHE_DIR" "$MISE_STATE_DIR"
trap 'rm -rf "$SCRATCH"' EXIT

echo "==> mise version (original run: v2026.6.14)"; mise --version

run_in() {   # run_in <fixture-subdir> <cmd...>
  local dir="$HERE/fixture/$1"; shift
  ( cd "$dir" && "$@" )
}

echo
echo "############ T — trust gate (expect REFUSAL before trust) ############"
echo "-- mise env on an UNtrusted config:"
run_in env mise env 2>&1 | sed 's/^/     /' || true
echo "   ^ expect: 'Config files ... are not trusted. Trust them with \`mise trust\`.'"
echo "-- after trust:"
run_in env mise trust >/dev/null 2>&1
run_in env mise env 2>&1 | sed 's/^/     /' || true
echo "   ^ expect: APP_ENV=firsthand exported and ./bin prepended to PATH"

echo
echo "############ 1 & 7 — cold vs warm install node@22 (timing SHAPE, not exact ms) ############"
run_in tasks mise trust >/dev/null 2>&1
echo "-- cold:"; time run_in tasks mise use node@22 2>&1 | tail -2 | sed 's/^/     /'
echo "-- warm (idempotent re-run):"; time run_in tasks mise use node@22 2>&1 | tail -2 | sed 's/^/     /'
echo "   ^ expect warm << cold (original: 3287ms cold -> 110ms warm)"

echo
echo "############ 4 — task runner + depends (expect greet BEFORE build) ############"
run_in tasks mise run build 2>&1 | sed 's/^/     /' || true

echo
echo "############ 2 — lockfile = cross-platform binary checksums (OFF by default) ############"
run_in lockfile mise trust >/dev/null 2>&1
( cd "$HERE/fixture/lockfile" && : > mise.lock && mise use node@22 >/dev/null 2>&1 && \
  echo "     mise.lock now contains per-platform sha256 + URL:" && \
  grep -iE 'sha256|url|platform|checksum' mise.lock | head -12 | sed 's/^/       /'; \
  rm -f mise.lock )
echo "   ^ expect sha256 + URL entries for multiple (os,arch), not just 'node = 22'"

echo
echo "############ 6a/6b — supply-chain verification tiers (watch the logs) ############"
echo "-- installing jq (checksum-only) + gh (attestation); read the per-tool lines:"
run_in supply-chain mise trust >/dev/null 2>&1
run_in supply-chain mise install 2>&1 | grep -iE 'attest|checksum|verify|download|sha256' | sed 's/^/     /' || true
echo "   ^ expect jq: checksum only; gh: 'verify ... attestations' THEN checksum"

echo
echo "############ 8 — file-shim overhead (raw node vs mise exec) ############"
echo "-- raw resolved node:"; time run_in tasks bash -c 'mise exec -- node -e "0"' 2>&1 | sed 's/^/     /'
echo "   ^ the file-shim path re-spawns 'mise x' each call (~+14ms in the original run)"

echo
echo "Done. Behavioral outcomes are the durable claims; ms/versions drift by design."
