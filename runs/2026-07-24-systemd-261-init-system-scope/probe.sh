#!/usr/bin/env bash
#
# probe.sh — firsthand check of the systemd 261 "distro gap".
#
# systemd 261 (upstream tag v261, 2026-06-19) shipped a batch of new binaries that push
# the init system into OS-install / cloud-metadata / storage / software-TPM territory:
#   systemd-imdsd, systemd-imds, systemd-sysinstall, storagectl, systemd-tpm2-swtpm.
#
# This probe does NOT trust a press summary. It launches the CURRENT published container
# image of four Linux distros and asks each one, directly:
#   1. What systemd version do you actually ship right now?
#   2. Are the v261 binaries present on your PATH / in /usr/lib/systemd?
#
# The gap between "released upstream" and "in the image you'd docker pull today" is the
# finding. Deterministic: version strings + file presence, no timing.
#
# Output: probe-result.json
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

IMAGES=("archlinux:latest" "fedora:latest" "ubuntu:24.04" "debian:trixie-slim")
BINS=(systemctl systemd-imdsd systemd-imds systemd-sysinstall storagectl systemd-tpm2-swtpm.service systemd-repart bootctl)

OUT="probe-result.json"
echo "{" > "$OUT"
echo "  \"probe\": \"systemd-261-distro-gap\"," >> "$OUT"
echo "  \"measured_at\": \"$(date -u +%Y-%m-%d)\"," >> "$OUT"
echo "  \"upstream_release\": {\"version\": \"261\", \"date\": \"2026-06-19\", \"source\": \"github.com/systemd/systemd tag v261 NEWS\"}," >> "$OUT"
echo "  \"distros\": [" >> "$OUT"

first=1
for img in "${IMAGES[@]}"; do
  echo "==> probing $img" >&2
  # Single container, deterministic queries. --rm + named for ownership-based cleanup.
  cname="firsthand-systemd261-$(echo "$img" | tr ':/' '--')"
  raw="$(docker run --rm --name "$cname" --entrypoint sh "$img" -c '
    echo "VERSION_START"
    (systemctl --version 2>/dev/null | head -1) || echo "systemctl: not found"
    echo "VERSION_END"
    for b in systemctl systemd-imdsd systemd-imds systemd-sysinstall storagectl systemd-repart bootctl; do
      p="$(command -v "$b" 2>/dev/null)"
      if [ -n "$p" ]; then echo "BIN $b PRESENT $p"; else
        # also look in the systemd libexec dir
        f="$(ls /usr/lib/systemd/"$b" /lib/systemd/"$b" 2>/dev/null | head -1)"
        if [ -n "$f" ]; then echo "BIN $b PRESENT $f"; else echo "BIN $b ABSENT"; fi
      fi
    done
    # software TPM service file presence
    if ls /usr/lib/systemd/system/systemd-tpm2-swtpm.service /lib/systemd/system/systemd-tpm2-swtpm.service >/dev/null 2>&1; then
      echo "UNIT systemd-tpm2-swtpm.service PRESENT"
    else echo "UNIT systemd-tpm2-swtpm.service ABSENT"; fi
  ' 2>/dev/null)"

  ver="$(printf '%s\n' "$raw" | sed -n '/VERSION_START/,/VERSION_END/p' | sed '1d;$d' | head -1)"
  [ -z "$ver" ] && ver="(no systemd / query failed)"

  # build the bins json object
  bins_json=""
  while IFS= read -r line; do
    case "$line" in
      "BIN "*)
        name="$(echo "$line" | awk '{print $2}')"
        state="$(echo "$line" | awk '{print $3}')"
        val=false; [ "$state" = "PRESENT" ] && val=true
        [ -n "$bins_json" ] && bins_json="$bins_json, "
        bins_json="$bins_json\"$name\": $val"
        ;;
      "UNIT systemd-tpm2-swtpm.service "*)
        state="$(echo "$line" | awk '{print $3}')"
        val=false; [ "$state" = "PRESENT" ] && val=true
        [ -n "$bins_json" ] && bins_json="$bins_json, "
        bins_json="$bins_json\"systemd-tpm2-swtpm.service\": $val"
        ;;
    esac
  done <<< "$raw"

  [ $first -eq 0 ] && echo "    ," >> "$OUT"
  first=0
  {
    echo "    {"
    echo "      \"image\": \"$img\","
    echo "      \"systemctl_version\": \"$ver\","
    echo "      \"present\": { $bins_json }"
    echo -n "    }"
  } >> "$OUT"
  echo "" >> "$OUT"
done

echo "  ]" >> "$OUT"
echo "}" >> "$OUT"

echo "==> wrote $OUT" >&2
