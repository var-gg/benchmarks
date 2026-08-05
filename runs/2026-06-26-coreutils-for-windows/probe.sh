#!/usr/bin/env bash
#
# The harness. Runs the coreutils-vs-baseline commands from the 2026-06-26 firsthand
# study and prints their outputs so you can diff against results.json.
#
# Prereqs (see run.sh, which sets these up):
#   - COREUTILS = path to coreutils.exe (Microsoft Coreutils 2026.6.16 multi-call binary)
#   - argv0 shims find.exe / sort.exe / grep.exe / echo.exe / wc.exe next to it
#     (copies of coreutils.exe named after the subcommand — how the binary dispatches)
#   - fixtures.sh already run (crlf.txt, lf.txt, nums.txt, case.txt present)
#
# This prints a labelled transcript; it does not assert (outputs like timing and
# backslash paths are environment-shaped). Compare the SHAPE against results.json.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

COREUTILS="${COREUTILS:-./coreutils.exe}"
SHIM="${SHIM_DIR:-./shims}"
export PATH="$SHIM:$PATH"

hr() { printf -- '---- %s\n' "$1"; }

hr "versions"
"$COREUTILS" --version || true
"$COREUTILS" sort --version || true
"$COREUTILS" grep --version || true
echo "list count: $("$COREUTILS" --list | wc -w)"

hr "dual_dispatch_shim: find (GNU tree walk)"
"$SHIM/find.exe" . -type f || true
hr "dual_dispatch_shim: find (DOS match count)"
"$SHIM/find.exe" /C "apple" crlf.txt || true
hr "dual_dispatch_shim: sort -n (numeric) vs /R (DOS reverse)"
"$SHIM/sort.exe" -n nums.txt || true
"$SHIM/sort.exe" /R nums.txt || true

hr "find_semantic_collision: System32 find on GNU-style args"
C:/Windows/System32/find.exe "apple" crlf.txt || true
C:/Windows/System32/find.exe . -name "*.txt" || true

hr "argv_wildcard_globbing"
"$COREUTILS" echo *.txt || true
echo "# unquoted -name *.txt (expect: Unrecognized flag from expanded file list)"
"$SHIM/find.exe" . -name *.txt || true
echo "# quoted -name \"*.txt\" (expect: works)"
"$SHIM/find.exe" . -name "*.txt" || true

hr "numeric_sort_three_way"
echo "coreutils sort -n:";      "$SHIM/sort.exe" -n nums.txt || true
echo "coreutils sort default:"; "$SHIM/sort.exe" nums.txt || true
echo "System32 sort.exe:";      C:/Windows/System32/sort.exe nums.txt || true

hr "locale_collation_trap (bytes via od)"
echo "coreutils sort case.txt:";           "$SHIM/sort.exe" case.txt | od -c | head
echo "coreutils sort case.txt (LC_ALL=C):"; LC_ALL=C "$SHIM/sort.exe" case.txt | od -c | head
echo "git-bash /usr/bin/sort case.txt:";    /usr/bin/sort case.txt | od -c | head

hr "crlf_handling_divergence"
echo "wc -l crlf/lf:"; "$SHIM/wc.exe" -l crlf.txt lf.txt || true
echo "wc -c crlf/lf:"; "$SHIM/wc.exe" -c crlf.txt lf.txt || true
echo "grep apple (CRLF) output bytes:"; "$SHIM/grep.exe" apple crlf.txt | od -c | head
echo "sort (CRLF) output bytes:";       "$SHIM/sort.exe" crlf.txt | od -c | head

hr "grep_regex_modes"
printf 'aaab\n' | "$SHIM/grep.exe" -E "a+b" && echo "  -> ERE match"
printf 'abc123\n' | "$SHIM/grep.exe" -P "\d+" && echo "  -> PCRE match"

hr "perf (approximate, NOT a claim — needs big.txt: ./fixtures.sh --with-big)"
if [ -f big.txt ]; then
  echo "coreutils grep -c:"; time "$SHIM/grep.exe" -c ERROR big.txt || true
  echo "git-bash grep -c:";  time /usr/bin/grep -c ERROR big.txt || true
  echo "coreutils sort:";    time "$SHIM/sort.exe" big.txt > /dev/null || true
  echo "git-bash sort:";     time /usr/bin/sort big.txt > /dev/null || true
else
  echo "big.txt absent — skipping perf (this is fine; perf is not committed evidence)."
fi

echo
echo "==> probe done. Compare the SHAPE of these outputs against results.json.behaviors_verified."
