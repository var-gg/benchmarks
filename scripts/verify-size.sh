#!/usr/bin/env bash
# Full-tree size/type gate. Run manually or in CI. Exit non-zero on any violation.
#   bash scripts/verify-size.sh
set -euo pipefail
cd "$(dirname "$0")/.."

FILE_CAP=$((1024 * 1024))   # 1 MB per file
DIR_CAP=100                 # 100 KB per run directory
fail=0

# All tracked files vs per-file cap + blocked extensions.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.log|*.trace|*.tar|*.tar.gz|*.tgz|*.zip|*.gz|*.bin|*.png|*.jpg|*.jpeg|*.mp4|*.pdf)
      echo "❌ blocked file type (raw/binary): $f"; fail=1 ;;
  esac
  size=$(wc -c < "$f")
  if [ "$size" -gt "$FILE_CAP" ]; then
    echo "❌ file over 1 MB: $f ($((size / 1024)) KB)"; fail=1
  fi
done < <(git ls-files)

# Each run directory vs the 100 KB cap.
if [ -d runs ]; then
  for d in runs/*/; do
    [ -d "$d" ] || continue
    kb=$(du -sk "$d" | cut -f1)
    printf '   %-60s %4s KB\n' "$d" "$kb"
    if [ "$kb" -gt "$DIR_CAP" ]; then
      echo "❌ run directory over ${DIR_CAP} KB: $d (${kb} KB)"; fail=1
    fi
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "verify-size: FAILED"; exit 1
fi
echo "✅ verify-size: all runs within budget"
