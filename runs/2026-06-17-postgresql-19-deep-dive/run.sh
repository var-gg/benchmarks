#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the PostgreSQL 19 Beta 1 capability checks
# from the var.gg post, inside an isolated Docker container.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-17-postgresql-19-deep-dive
#   ./run.sh
#
# The original container + fixtures were discarded per the finite-disk policy (backfill).
# This script reconstructs the METHOD. Findings are deterministic capability/limit/default
# observations, so with the SAME pinned image (postgres:19beta1) the accept/error matrix,
# the REPACK help text, and the GUC defaults should match results.json.
#
# Requires Docker. Production databases are never touched — everything runs in a throwaway
# container named pg19test.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

IMAGE="postgres:19beta1"     # beta tag — names/defaults may change at GA
CONTAINER="pg19test"

command -v docker >/dev/null 2>&1 || { echo "Docker is required."; exit 1; }

echo "==> starting $IMAGE as $CONTAINER (isolated; production DB untouched)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=pg -e POSTGRES_HOST_AUTH_METHOD=trust \
  "$IMAGE" >/dev/null
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "==> waiting for server to accept connections"
for i in $(seq 1 30); do
  docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done

echo "==> SELECT version()"
docker exec -i "$CONTAINER" psql -U postgres -Atc "select version();"

run_sql() {
  local f="$1"
  echo
  echo "======================================================================"
  echo "==> $f"
  echo "======================================================================"
  # -v ON_ERROR_STOP=0 so the intentional 'quantifier not supported' ERROR is shown, not fatal.
  docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=0 < "fixture/$f"
}

echo "==> confirm both plan-advice .so files ship in the image"
docker exec "$CONTAINER" sh -lc 'ls -1 /usr/lib/postgresql/19/lib/pg_plan_advice.so /usr/lib/postgresql/19/lib/pg_stash_advice.so' \
  || echo "   (path may differ on your build; check /usr/lib/postgresql/*/lib)"

run_sql 01-sql-pgq.sql
run_sql 02-plan-advice.sql
run_sql 03-repack.sql
run_sql 04-guc.sql

echo
echo "==> Done. Compare against results.json:"
echo "    - 01: 1-hop + fixed 2-hop rows, then 'element pattern quantifier is not supported' ERROR"
echo "    - 02: 'Generated Plan Advice' block, then 'Supplied Plan Advice ... /* matched */'"
echo "    - 03: REPACK help shows CONCURRENTLY; REPACK (CONCURRENTLY, VERBOSE) succeeds at wal_level=replica"
echo "    - 04: autovacuum_max_parallel_workers=0, io_method=worker, io_max_concurrency=64"
