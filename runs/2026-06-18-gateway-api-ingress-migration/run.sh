#!/usr/bin/env bash
#
# Reproduce the ingress2gateway v1.1.0 conversion behind the var.gg post.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-18-gateway-api-ingress-migration
#     ./run.sh
#
# Requires the Go toolchain (>= 1.24). Installs the pinned ingress2gateway v1.1.0,
# then converts the two committed fixtures in --input-file mode (NO cluster needed):
#
#   fixtures/sample-ingress.yaml  -> out/convert-standard.yaml  + out/convert-standard.warn.txt
#   fixtures/timeout-probe.yaml   -> out/timeout-probe.out.yaml + out/timeout-probe.warn.txt
#
# Then diffs the regenerated output against the committed expected/ evidence.
# The transform is deterministic and offline, so a clean run should match expected/
# (modulo the tool's own version — pinning v1.1.0 is the point).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_VERSION="1.1.0"

echo "==> Installing pinned ingress2gateway v${EXPECTED_VERSION}"
GOBIN="$HERE/bin" go install github.com/kubernetes-sigs/ingress2gateway@v${EXPECTED_VERSION}
I2GW="$HERE/bin/ingress2gateway"

echo "==> Tool version"
"$I2GW" version || true

mkdir -p out

echo "==> Converting fixtures/sample-ingress.yaml (provider ingress-nginx)"
"$I2GW" print --input-file fixtures/sample-ingress.yaml --providers ingress-nginx \
  > out/convert-standard.yaml 2> out/convert-standard.warn.txt || true

echo "==> Converting fixtures/timeout-probe.yaml (provider ingress-nginx)"
"$I2GW" print --input-file fixtures/timeout-probe.yaml --providers ingress-nginx \
  > out/timeout-probe.out.yaml 2> out/timeout-probe.warn.txt || true

echo
echo "==> Diff regenerated output against committed expected/ (empty diff == reproduced)"
rc=0
for f in convert-standard.yaml convert-standard.warn.txt timeout-probe.out.yaml timeout-probe.warn.txt; do
  src="out/$f"; [ "$f" = "convert-standard.yaml" ] || true
  exp="expected/$f"
  echo "--- $f ---"
  if diff -u "$exp" "$src"; then echo "(match)"; else rc=1; fi
done

echo
if [ "$rc" -eq 0 ]; then
  echo "✅ Reproduced: regenerated output matches expected/."
else
  echo "⚠️  Output differs from expected/. If your ingress2gateway is not v${EXPECTED_VERSION},"
  echo "    that IS the point of pinning — the conversion behavior is version-specific."
fi

echo "    Cleanup: rm -rf out bin"
