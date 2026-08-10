#!/usr/bin/env bash
#
# Reproduce the short-lived TLS cert experiments from the post.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-23-short-lived-tls-renewal
#     ./run.sh
#
# Part A (deterministic, no network): mint a 20s leaf under a local EC root CA,
#   stand up a TLS server, probe the handshake before/after NotAfter.
#   -> partA/probe-result.txt   Expect: [valid] OK, then [expired] verify_code=10.
#
# Part B (needs Docker): start a local pebble ACME CA, drive a full ACME order
#   under the 'shortlived' profile with a hand-written pure-Python client, then
#   query the CA's ARI (renewalInfo) endpoint for the suggested renewal window.
#   -> partB/acme-ari-result.txt   Expect: 'shortlived' cert + HTTP 200 ARI window.
#
# NOTE: Part B pulls ghcr.io/letsencrypt/pebble:latest. It was :latest (unpinned)
#   in the original 2026-06-23 run too, so a newer pebble may return different
#   lifetime/window numbers. The MECHANISM (ARI window, CertID derivation) is the
#   portable signal; the exact 144h/window widths are pebble defaults.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

echo "==> Python env (Part B client deps: cryptography, requests)"
python -m venv .venv
if [ -f .venv/Scripts/activate ]; then source .venv/Scripts/activate; else source .venv/bin/activate; fi
pip install -q -r requirements.txt

echo
echo "==================== PART A (deterministic, no network) ===================="
bash partA/run.sh
python partA/tls_probe.py | tee partA/probe-result.repro.txt
echo "    Compare partA/probe-result.repro.txt against the committed partA/probe-result.txt"

echo
echo "==================== PART B (real ACME, needs Docker) ======================"
if ! command -v docker >/dev/null 2>&1; then
  echo "!! docker not found — skipping Part B. Part A already reproduced above."
  exit 0
fi
echo "==> Starting local pebble ACME CA (PEBBLE_VA_ALWAYS_VALID=1)"
docker rm -f firsthand-tls-pebble >/dev/null 2>&1 || true
docker run -d --rm --name firsthand-tls-pebble \
  -e PEBBLE_VA_ALWAYS_VALID=1 \
  -p 14000:14000 -p 15000:15000 \
  ghcr.io/letsencrypt/pebble:latest >/dev/null
echo "    waiting for pebble directory to come up..."
for i in $(seq 1 30); do
  if curl -sk https://localhost:14000/dir >/dev/null 2>&1; then break; fi
  sleep 1
done
python partB/acme_ari.py | tee partB/acme-ari-result.repro.txt || true
docker rm -f firsthand-tls-pebble >/dev/null 2>&1 || true
echo "    Compare partB/acme-ari-result.repro.txt against the committed partB/acme-ari-result.txt"
echo
echo "==> Done."
