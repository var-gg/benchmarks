#!/usr/bin/env bash
#
# Reproduce the cosign v3.1.1 "default vs offline" bundle-shape probe.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-17-cosign-v3-sigstore-bundle
#     ./run.sh
#
# NOTE (backfilled run): the original 2026-06-17 session used a cosign binary that was
# deleted afterward per a finite-disk policy. This script downloads cosign v3.1.1 fresh
# and re-runs the documented command sequence, so you reproduce the METHOD, not the exact
# byte-for-byte artifacts. Step 1-3 need only cosign. Step 4 (OCI) additionally needs a
# local Docker daemon and is guarded so the core probe runs without Docker.
#
# The central claim is STRUCTURAL and is checked in step 3: a key-based sign-blob's
# DEFAULT bundle carries tlogEntries + timestampVerificationData (public log + TSA),
# while the signing-config OFFLINE bundle carries only publicKey.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

COSIGN_VERSION="v3.1.1"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# ---- resolve platform asset ----
uname_s="$(uname -s)"; uname_m="$(uname -m)"
case "$uname_s" in
  Linux)  os=linux ;;
  Darwin) os=darwin ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "unsupported OS: $uname_s"; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo "unsupported arch: $uname_m"; exit 1 ;;
esac
ext=""; [ "$os" = windows ] && ext=".exe"
asset="cosign-${os}-${arch}${ext}"
url="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/${asset}"

echo "==> Downloading cosign ${COSIGN_VERSION} (${asset})"
curl -sSL -o "cosign${ext}" "$url"
chmod +x "cosign${ext}"
COSIGN="./cosign${ext}"
echo "==> cosign version"
$COSIGN version | sed 's/^/    /'
echo "    (expect GitVersion ${COSIGN_VERSION}; a different build may behave differently — that IS why we pin.)"

export COSIGN_PASSWORD="" COSIGN_YES=true

echo
echo "==> Step 1: generate a throwaway keypair + a blob"
$COSIGN generate-key-pair >/dev/null
printf 'var.gg firsthand demo artifact\n' > artifact.txt

echo
echo "==> Step 2: DEFAULT sign-blob (this uploads to the PUBLIC rekor + TSA)"
$COSIGN sign-blob --key cosign.key --bundle artifact.sigstore.json artifact.txt
$COSIGN verify-blob --key cosign.pub --bundle artifact.sigstore.json artifact.txt

echo
echo "==> Step 3: OFFLINE sign-blob via a signing-config (no rekor/tsa/fulcio/oidc)"
$COSIGN signing-config create --no-default-rekor --no-default-tsa \
  --no-default-fulcio --no-default-oidc --out signing-config-offline.json
$COSIGN sign-blob --key cosign.key --signing-config signing-config-offline.json \
  --bundle artifact-offline.sigstore.json artifact.txt

echo
echo "==> Structural check: verificationMaterial keys of each bundle"
python - <<'PY'
import json
d = json.load(open("artifact.sigstore.json"))
o = json.load(open("artifact-offline.sigstore.json"))
dk = sorted(d["verificationMaterial"].keys())
ok = sorted(o["verificationMaterial"].keys())
print("  default bundle mediaType:", d["mediaType"])
print("  default verificationMaterial:", dk)
print("  offline verificationMaterial:", ok)
assert "tlogEntries" in dk, "expected tlogEntries in DEFAULT bundle (public rekor upload)"
assert "timestampVerificationData" in dk, "expected TSA timestamp in DEFAULT bundle"
assert ok == ["publicKey"], f"expected OFFLINE bundle to have only publicKey, got {ok}"
print("  OK: default = public-log shape (publicKey+tlogEntries+timestamp); offline = self-contained (publicKey only)")
print("  -> matches results.json.bundle_shape_matrix and bundle-default-redacted.json")
PY

echo
echo "==> Step 4 (optional, needs Docker): OCI image signing + triangulate deprecation"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker run -d -p 5500:5000 --rm --name firsthand-cosign-reg registry:2 >/dev/null
  sleep 2
  printf 'FROM scratch\nCOPY artifact.txt /artifact.txt\n' > Dockerfile
  docker build -q -t localhost:5500/vargg-demo:v1 . >/dev/null
  docker push -q localhost:5500/vargg-demo:v1 >/dev/null
  ref="$(docker inspect --format='{{index .RepoDigests 0}}' localhost:5500/vargg-demo:v1 2>/dev/null || echo localhost:5500/vargg-demo:v1)"
  $COSIGN sign --key cosign.key --signing-config signing-config-offline.json "$ref"
  $COSIGN verify --key cosign.pub --insecure-ignore-tlog=true "$ref" || true
  echo "    (verify prints: 'Skipping tlog verification is an insecure practice...')"
  $COSIGN triangulate "$ref" || true
  echo "    (triangulate prints: deprecated, will be removed in v4.0.0 — use 'oras discover' or 'cosign tree')"
  docker rm -f firsthand-cosign-reg >/dev/null 2>&1 || true
else
  echo "    Docker not available — skipping OCI step. Steps 1-3 already prove the core finding."
fi

echo
echo "==> Done. Compare the printed verificationMaterial keys against results.json."
