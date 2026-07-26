#!/usr/bin/env bash
#
# probe-pkg.sh — corrects a measurement bias in probe.sh.
#
# probe.sh ran `systemctl --version` inside minimal base images. archlinux:latest answered
# "systemd 261" and had every new binary. But fedora/ubuntu/debian minimal images don't
# INSTALL systemd at all, so systemctl was simply absent — that says nothing about which
# systemd version the distro currently PACKAGES. Wrong question for those images.
#
# The honest question: "what systemd version does this distro ship in its repos RIGHT NOW?"
# We ask each distro's package manager directly, without needing systemd to run as PID 1.
#
# Output: probe-pkg-result.json
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"

OUT="probe-pkg-result.json"
echo "{"                                                        >  "$OUT"
echo "  \"probe\": \"systemd-261-packaged-version-by-distro\"," >> "$OUT"
echo "  \"measured_at\": \"$(date -u +%Y-%m-%d)\","             >> "$OUT"
echo "  \"question\": \"What systemd version does each distro package right now, per its own package manager?\"," >> "$OUT"
echo "  \"distros\": ["                                         >> "$OUT"

emit () { # image  channel  version  raw
  local img="$1" ch="$2" ver="$3"
  [ "$FIRST" -eq 0 ] && echo "    ," >> "$OUT"; FIRST=0
  {
    echo "    {"
    echo "      \"image\": \"$img\","
    echo "      \"channel\": \"$ch\","
    echo "      \"packaged_systemd\": \"$ver\""
    echo -n "    }"
  } >> "$OUT"; echo "" >> "$OUT"
}
FIRST=1

echo "==> arch (pacman)" >&2
ver=$(docker run --rm --name firsthand-systemd261-arch --entrypoint sh archlinux:latest -c 'pacman -Q systemd 2>/dev/null' 2>/dev/null)
emit "archlinux:latest" "rolling" "${ver:-query-failed}"

echo "==> fedora (dnf/rpm)" >&2
ver=$(docker run --rm --name firsthand-systemd261-fedora --entrypoint sh fedora:latest -c 'rpm -q systemd 2>/dev/null || dnf -q info systemd 2>/dev/null | awk -F": " "/^Version/{print \$2; exit}"' 2>/dev/null)
emit "fedora:latest" "stable" "${ver:-query-failed}"

echo "==> ubuntu 24.04 (apt)" >&2
ver=$(docker run --rm --name firsthand-systemd261-ubuntu --entrypoint sh ubuntu:24.04 -c 'apt-get update >/dev/null 2>&1; apt-cache policy systemd 2>/dev/null | awk "/Candidate:/{print \$2; exit}"' 2>/dev/null)
emit "ubuntu:24.04" "LTS-stable" "${ver:-query-failed}"

echo "==> debian trixie (apt)" >&2
ver=$(docker run --rm --name firsthand-systemd261-debian --entrypoint sh debian:trixie-slim -c 'apt-get update >/dev/null 2>&1; apt-cache policy systemd 2>/dev/null | awk "/Candidate:/{print \$2; exit}"' 2>/dev/null)
emit "debian:trixie-slim" "stable" "${ver:-query-failed}"

echo "  ]" >> "$OUT"
echo "}"   >> "$OUT"
echo "==> wrote $OUT" >&2
