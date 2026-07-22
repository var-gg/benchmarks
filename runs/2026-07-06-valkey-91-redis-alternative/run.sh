#!/usr/bin/env bash
#
# Reproduce the Valkey 9.1 vs Redis 8 single-host comparison.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-06-valkey-91-redis-alternative
#   ./run.sh                 # full run (~5-10 min, mostly the 1M-key memory phase)
#   SMOKE=1 ./run.sh         # 1/100 scale, mechanics check only (~1 min)
#
# Needs: docker. Pulls two digest-pinned images (~60MB each) and removes the
# containers on exit; the images are left in place (delete them yourself if you
# do not want them: see the digests below).
#
# READ THIS BEFORE COMPARING NUMBERS
#
#   * This is a RECONSTRUCTION of the invocations recorded on 2026-07-05, not the
#     literal script that was executed (none existed — the commands were run ad hoc).
#     See manifest.json -> backfill_note.
#   * The original run did not record which redis-benchmark binary drove which
#     server. This script deliberately uses ONE client (the one inside the pinned
#     redis:8 image) against BOTH servers, so the client is held constant. That is
#     a better experiment, but it means your rps may not land exactly on the
#     recorded figures.
#   * The durable claim is the MEMORY ratio (~23% less on Valkey at a matched key
#     count). The throughput numbers are n=1 (n=2 for unpipelined SET) and the
#     ordering flips with pipeline depth — reproduce the DIRECTION, not the digits.
#
set -euo pipefail

VALKEY_IMAGE="valkey/valkey@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9"
REDIS_IMAGE="redis@sha256:2838d5524559494f6f1cd66e97e76b200d64a633a8614200620755ed395daf32"
# The client is always REDIS_IMAGE's redis-benchmark / redis-cli, for both engines.

NET="firsthand-valkey-bench-net"
PREFIX="firsthand-valkey-91-redis-alternative"

if [ "${SMOKE:-0}" = "1" ]; then
  MEM_N=10000;  MEM_R=10000
  TP1_N=5000
  TP16_N=10000
  echo "### SMOKE MODE — 1/100 scale. Numbers are NOT comparable to results.json."
else
  MEM_N=1000000; MEM_R=1000000
  TP1_N=100000
  TP16_N=200000
fi

cleanup() {
  docker rm -f "$PREFIX-valkey" "$PREFIX-redis" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "docker not found on PATH"; exit 1; }

echo "==> network"
docker network create "$NET" >/dev/null 2>&1 || true

cli()   { docker run --rm --network "$NET" "$REDIS_IMAGE" redis-cli       -h "$1" "${@:2}"; }
bench() { docker run --rm --network "$NET" "$REDIS_IMAGE" redis-benchmark -h "$1" "${@:2}"; }

measure_engine() {
  local label="$1" image="$2" host="$3"

  echo
  echo "############################################################"
  echo "### $label"
  echo "############################################################"

  docker rm -f "$host" >/dev/null 2>&1 || true
  docker run -d --rm --name "$host" --network "$NET" "$image" >/dev/null
  # wait for readiness rather than sleeping a fixed amount
  for _ in $(seq 1 30); do
    if cli "$host" PING 2>/dev/null | grep -q PONG; then break; fi
    sleep 1
  done

  echo "--- server version"
  cli "$host" INFO server | grep -E '^(redis_version|valkey_version|server_name|arch_bits):' || true
  cli "$host" INFO memory | grep -E '^mem_allocator:' || true

  echo
  echo "--- phase 1: memory footprint (-n $MEM_N -r $MEM_R -d 64 -t set -P 32)"
  cli "$host" FLUSHALL >/dev/null
  bench "$host" -n "$MEM_N" -r "$MEM_R" -d 64 -t set -P 32 -q >/dev/null
  echo -n "DBSIZE: ";  cli "$host" DBSIZE
  cli "$host" INFO memory | grep -E '^used_memory(_human)?:' || true

  echo
  echo "--- phase 2: throughput, no pipelining (-n $TP1_N -c 50 -P 1), run twice"
  cli "$host" FLUSHALL >/dev/null
  bench "$host" -n "$TP1_N" -c 50 -P 1 -t set,get -q
  bench "$host" -n "$TP1_N" -c 50 -P 1 -t set,get -q

  echo
  echo "--- phase 3: throughput, pipeline depth 16 (-n $TP16_N -c 50 -P 16)"
  cli "$host" FLUSHALL >/dev/null
  bench "$host" -n "$TP16_N" -c 50 -P 16 -t set,get -q

  docker rm -f "$host" >/dev/null 2>&1 || true
}

measure_engine "Valkey 9.1 ($VALKEY_IMAGE)" "$VALKEY_IMAGE" "$PREFIX-valkey"
measure_engine "Redis 8 ($REDIS_IMAGE)"     "$REDIS_IMAGE"  "$PREFIX-redis"

cat <<'EOF'

==> Done. Compare against results.json:

    MEMORY (the claim)      Valkey ~67.9 MB vs Redis ~88.3 MB at ~632.5k keys
                            -> expect Valkey ~20-25% lower at a similar DBSIZE.
                            If DBSIZE differs by more than ~1%, compare bytes/key,
                            not totals.

    THROUGHPUT P=1          Valkey ahead (~9-13% in our run).
    THROUGHPUT P=16         Redis ahead (~10% in our run).
                            The SIGN FLIP is the point; the percentages are noisy.

    Single host, standalone, default config, no cluster/replication/persistence.
EOF
