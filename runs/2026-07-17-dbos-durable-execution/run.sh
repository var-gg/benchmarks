#!/usr/bin/env bash
#
# Reproduce the DBOS Transact 2.27.0 durable-execution kill test.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-17-dbos-durable-execution
#   ./run.sh
#
# Makes a throwaway venv, installs dbos==2.27.0, and drives probe.py through five
# experiments, each in its own work dir. The DURABLE signal is WHICH steps replay
# vs re-run (printed ledgers) and the version-trap / durability-tax SHAPE — not the
# absolute seconds, which are machine-dependent. Deletes the venv + work dirs at the end.
#
# Requires: bash, python 3.11+ (the recorded run used 3.11.9).
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

DBOS_VERSION="2.27.0"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> creating throwaway venv + installing dbos==${DBOS_VERSION}"
python -m venv "$WORK/venv"
if [ -x "$WORK/venv/Scripts/python.exe" ]; then PY="$WORK/venv/Scripts/python.exe"; else PY="$WORK/venv/bin/python"; fi
"$PY" -m pip install --quiet --disable-pip-version-check "dbos==${DBOS_VERSION}"
echo "    dbos: $("$PY" -c 'import importlib.metadata as m;print(m.version("dbos"))')"

run() { # run <work-subdir> <app_version> <mode...>
  local wd="$WORK/$1"; local ver="$2"; shift 2
  DBOS_DEMO_WORK="$wd" APP_VERSION="$ver" "$PY" probe.py "$@"
}

echo
echo "===== A: baseline — a clean 5-step workflow ====="
run w-baseline pin1 run | tail -8

echo
echo "===== B: crash-during — hard-kill mid step3, then relaunch ====="
echo "-- crash (exits 42 via os._exit; that is the point) --"
run w-during pin1 crash-during || true
echo "-- relaunch: expect step1/2 replayed (not re-run), step3 RE-RUN, then 4/5, SUCCESS --"
run w-during pin1 resume

echo
echo "===== C: crash-between — hard-kill AFTER step3 completes ====="
run w-between pin1 crash-between || true
echo "-- relaunch: expect step3 NOT re-run, continue from step4, SUCCESS --"
run w-between pin1 resume

echo
echo "===== D: inspect the DBOS SQLite system db (10 tables, replay log) ====="
run w-during pin1 inspect

echo
echo "===== E: version trap — crash under 'alpha', try to recover under 'beta' ====="
run w-trap alpha crash-during || true
echo "-- relaunch under BETA (mismatch): expect PENDING, NO recovery (30s wait) --"
run w-trap beta resume
echo "-- relaunch under ALPHA (match): expect immediate SUCCESS --"
run w-trap alpha resume

echo
echo "===== F: durability tax — 200 no-op durable steps vs plain calls ====="
run w-overhead pin1 overhead

echo
echo "==> Done. Compare the ledgers + numbers against results.json."
echo "    Expect: mid-step crash re-runs only the uncheckpointed step; completed steps never re-run;"
echo "    a version mismatch leaves the workflow PENDING; ~1-10ms per durable step on local SQLite."
