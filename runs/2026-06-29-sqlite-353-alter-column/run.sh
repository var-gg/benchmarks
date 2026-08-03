#!/usr/bin/env bash
#
# Reproduce the "SQLite ALTER COLUMN ships in 3.52, documented in 3.53" bisect.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-29-sqlite-353-alter-column
#     ./run.sh
#
# Downloads the SIX pinned sqlite-tools builds (3.48.0 .. 3.53.0) for your OS,
# lays each sqlite3 down as bin/sqlite3-<ver>[.exe], then runs:
#   feature_matrix.py  -> the 6-version x 4-op OK/ERR grid
#   experiments.py     -> atomic rejection / rollback / cross-version / limits
# Compare the printed JSON against the committed probe-result.json.
#
# Deterministic: pinned CLI builds + fixed schemas -> fixed verdicts. The whole
# point of pinning is that the boundary is 3.51 (ERR) -> 3.52 (OK); a different
# set of versions would move it.
#
# The original blog run was on Windows x86_64. The Linux/macOS branches use
# sqlite.org's -x64 tools archives (best effort); if a download 404s, grab the
# matching sqlite-tools archive from https://sqlite.org/ manually into bin/.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
mkdir -p bin .dl

# version -> "<year>/<sevendigit>" (verified against sqlite.org download index)
declare -A NUM=(
  [3.48.0]="2025/3480000" [3.49.0]="2025/3490000" [3.50.0]="2025/3500000"
  [3.51.0]="2025/3510000" [3.52.0]="2026/3520000" [3.53.0]="2026/3530000"
)

os="$(uname -s)"
case "$os" in
  MINGW*|MSYS*|CYGWIN*) infix="win-x64";   zipext="zip"; binname="sqlite3.exe"; suffix=".exe" ;;
  Linux)                infix="linux-x64"; zipext="zip"; binname="sqlite3";     suffix="" ;;
  Darwin)               infix="osx-x64";   zipext="zip"; binname="sqlite3";     suffix="" ;;
  *) echo "Unsupported OS '$os'. Fetch sqlite-tools manually from https://sqlite.org/ into bin/."; exit 1 ;;
esac

fetch() {
  command -v curl >/dev/null 2>&1 && curl -fSL "$1" -o "$2" || wget -O "$2" "$1"
}

for v in 3.48.0 3.49.0 3.50.0 3.51.0 3.52.0 3.53.0; do
  out="bin/sqlite3-${v}${suffix}"
  [ -x "$out" ] && { echo "==> have $out"; continue; }
  yr="${NUM[$v]%/*}"; num="${NUM[$v]#*/}"
  file="sqlite-tools-${infix}-${num}.zip"
  url="https://sqlite.org/${yr}/${file}"
  echo "==> Downloading pinned sqlite ${v}: ${url}"
  fetch "$url" ".dl/${file}" || { echo "    FAILED ${url} -- fetch manually into bin/${out##*/}"; continue; }
  rm -rf ".dl/ex_${v}"; mkdir -p ".dl/ex_${v}"
  unzip -oq ".dl/${file}" -d ".dl/ex_${v}"
  found="$(find ".dl/ex_${v}" -iname "$binname" | head -1)"
  cp "$found" "$out"; chmod +x "$out" 2>/dev/null || true
  echo "    -> $("$out" --version | awk '{print $1, $2}')"
done

echo
echo "==> feature_matrix.py"
python3 feature_matrix.py || python feature_matrix.py
echo
echo "==> experiments.py"
python3 experiments.py || python experiments.py
