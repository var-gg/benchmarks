#!/usr/bin/env bash
#
# Recreate the exact fixtures used in the 2026-06-26 coreutils firsthand run.
# Deterministic and tiny — printf with explicit byte control so CRLF vs LF is exact.
# Byte counts are asserted so a reproducer knows the fixtures match the originals.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# crlf.txt: 4 CRLF lines, "apple" on 2 of them -> wc -c == 30, wc -l == 4.
printf 'apple\r\nbanana\r\napple\r\ncherry\r\n' > crlf.txt
# lf.txt: same content, LF only -> wc -c == 26.
printf 'apple\nbanana\napple\ncherry\n' > lf.txt
# nums.txt: numeric-vs-lexicographic separator (sort -n -> 2,9,10,30,100).
printf '10\n2\n100\n9\n30\n' > nums.txt
# case.txt: locale-collation probe (mixed case, duplicate 'apple').
printf 'Banana\napple\nCherry\napple\nBANANA\n' > case.txt

# Byte-count assertions (portable: wc -c).
assert_bytes() { local f="$1" want="$2"; local got; got=$(wc -c < "$f" | tr -d ' '); [ "$got" = "$want" ] || { echo "FIXTURE MISMATCH $f: $got != $want" >&2; exit 1; }; }
assert_bytes crlf.txt 30
assert_bytes lf.txt 26
echo "fixtures OK: crlf.txt(30B) lf.txt(26B) nums.txt case.txt"

# big.txt: 600k-line perf fixture (~28.6MB). Generated on demand, NEVER committed
# (size gate + it is not deterministic evidence — perf is 'same order', not a claim).
if [ "${1:-}" = "--with-big" ]; then
  : > big.txt
  yes 'INFO line of log text here for grep/sort perf fixture ERROR maybe' | head -n 600000 > big.txt
  echo "big.txt: $(wc -l < big.txt | tr -d ' ') lines, $(wc -c < big.txt | tr -d ' ') bytes"
fi
