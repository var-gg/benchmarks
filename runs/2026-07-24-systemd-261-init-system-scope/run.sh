#!/usr/bin/env bash
#
# Reproduce the systemd 261 "distro gap" probe.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-07-24-systemd-261-init-system-scope
#     ./run.sh
#
# Requires: Docker (Linux containers). No other dependencies.
#
# Produces:
#   probe-result.json      — v261 binary presence per distro image (+ systemctl version)
#   probe-pkg-result.json  — systemd version each distro PACKAGES right now
#
# Compare both against the committed results.json. NOTE: the distro image tags
# (:latest / :24.04 / :trixie-slim) are MUTABLE — re-running later pulls whatever
# those distros ship then, which is exactly the drift this probe measures. The
# committed *-result.json files are the 2026-07-24 snapshot.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. This probe needs Docker (Linux containers)." >&2
  exit 1
fi

echo "==> docker version"
docker --version

echo
echo "==> Probe 1: v261 binary presence per distro image (probe.sh)"
./probe.sh

echo
echo "==> Probe 2: packaged systemd version per distro (probe-pkg.sh)"
./probe-pkg.sh

echo
echo "==> Done. Wrote probe-result.json and probe-pkg-result.json."
echo "    Compare against the committed results.json (binary_presence_matrix + packaged_version_matrix)."
echo "    Cleanup: docker rmi archlinux:latest fedora:latest ubuntu:24.04 debian:trixie-slim"
