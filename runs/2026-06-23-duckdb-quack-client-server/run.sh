#!/usr/bin/env bash
#
# Reproduce the DuckDB quack client-server capability run.
# Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-23-duckdb-quack-client-server
#     ./run.sh
#
# Requires the DuckDB v1.5.3 CLI on PATH (https://duckdb.org/docs/installation/).
# quack is an autoloadable core extension; the first INSTALL quack fetches it from
# the network. Boots the server (server.sql) in the background, runs the client
# probes (client.sql), then the concurrency test. Compare output to results.json.
#
# NOTE (backfill): the original 2026-06-23 harness was deleted post-publish per the
# finite-disk firsthand policy; this harness is reconstructed from the recorded
# methodology. Re-running reproduces the same pass/fail + exact-error capability
# outcomes. Section 5 wall times drift and are context, not an evidence claim.
#
# Windows trap: localhost binds to IPv6 ::1, so an IPv4 127.0.0.1 port probe is a
# false negative. The client resolves quack:localhost the same way and works anyway.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

EXPECTED_DUCKDB="1.5.3"

if ! command -v duckdb >/dev/null 2>&1; then
  echo "ERROR: duckdb CLI not on PATH. Install DuckDB v${EXPECTED_DUCKDB} first." >&2
  exit 1
fi
echo "==> duckdb: $(duckdb --version)  (expected v${EXPECTED_DUCKDB})"

echo "==> Booting quack server (server.sql) in background on http://localhost:9494"
duckdb -init server.sql -no-stdin &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
sleep 3

echo "==> Running client capability probes (client.sql)"
duckdb -init client.sql -no-stdin || true

echo "==> Running concurrent-writer test (Section 4)"
bash concurrent_writers.sh || true

echo
echo "==> Done. Compare against results.json:"
echo "    - auth: valid attaches; wrong token / no secret -> distinct errors"
echo "    - remote surface: INSERT/CREATE/DROP/SELECT ok; direct UPDATE/DELETE -> Binder Error"
echo "    - remote.query('... RETURNING *') -> UPDATE works server-side (#176)"
echo "    - BEGIN; INSERT; ROLLBACK -> row survives (#173)"
echo "    - two processes append 5000 each -> +10000 rows, no loss"
echo "    - kill server -> client gets a connect IO Error (fails fast)"
