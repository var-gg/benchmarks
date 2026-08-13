#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the NATS 2.14 JetStream message-scheduler
# protocol checks from the var.gg post.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-06-19-nats-jetstream-scheduler
#   ./run.sh
#
# The original run's binaries + store were discarded per the finite-disk policy (backfill).
# This script reconstructs the METHOD. Findings are deterministic protocol behaviors, so with
# the SAME pinned versions the accept/reject matrix and durability observations should match
# results.json. Requires nats-server 2.14.2 and nats CLI 0.4.0 on PATH.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

SERVER_VERSION="2.14.2"   # first line with the message scheduler this post documents
CLI_VERSION="0.4.0"
PORT=4222
MON=8222

command -v nats-server >/dev/null 2>&1 || {
  echo "Install nats-server ${SERVER_VERSION} first: https://github.com/nats-io/nats-server/releases/tag/v${SERVER_VERSION}"
  exit 1
}
command -v nats >/dev/null 2>&1 || {
  echo "Install nats CLI ${CLI_VERSION} first: https://github.com/nats-io/natscli/releases/tag/v${CLI_VERSION}"
  exit 1
}
echo "==> nats-server: $(nats-server --version)   (original run: ${SERVER_VERSION})"
echo "==> nats CLI:    $(nats --version)          (original run: ${CLI_VERSION})"

STORE="$(mktemp -d)"
echo "==> starting nats-server -js -sd ${STORE} -p ${PORT} -m ${MON}"
nats-server -js -sd "$STORE" -p "$PORT" -m "$MON" >/tmp/nats-server.log 2>&1 &
SRV=$!
cleanup() { kill "$SRV" 2>/dev/null; rm -rf "$STORE"; }
trap cleanup EXIT
sleep 1

export NATS_URL="nats://127.0.0.1:${PORT}"

echo "==> creating scheduler-enabled stream (--allow-schedules)"
nats stream add SCHED --subjects 'sched.>' --allow-schedules \
  --storage file --retention limits --discard old --max-msgs=-1 --max-bytes=-1 \
  --max-age=0 --dupe-window=2m --replicas 1 --defaults >/dev/null 2>&1 \
  || echo "   (if this flag name changed, check 'nats stream add --help' for the schedule flag on your build)"

echo
echo "==> Part 1: schedule syntax accept/reject matrix"
printf '%-28s %-8s %-8s\n' "Nats-Schedule value" "expect" "observed"
printf '%-28s %-8s %-8s\n' "-------------------" "------" "--------"
i=0
while IFS=$'\t' read -r value expected; do
  case "$value" in \#*|"") continue;; esac
  i=$((i+1))
  subj="sched.case${i}"
  # Publish a control message carrying the schedule header + a target; judge by server reply.
  if nats publish "$subj" "ctl" \
        -H "Nats-Schedule:${value}" \
        -H "Nats-Schedule-Target:fire.case${i}" >/tmp/pub.out 2>&1; then
    observed="accept"
  else
    observed="reject"   # server rejects invalid patterns (e.g. error 10189)
  fi
  mark=" "; [ "$observed" = "$expected" ] && mark="OK" || mark="XX"
  printf '%-28s %-8s %-8s [%s]\n' "$value" "$expected" "$observed" "$mark"
done < fixture/schedule-cases.tsv

echo
echo "==> Part 2: CLI-vs-server mismatch — nats publish --schedule-after"
if nats publish sched.after "ctl" --schedule-after=5s --schedule-dest=fire.after >/tmp/after.out 2>&1; then
  echo "   --schedule-after=5s ACCEPTED (differs from the 2.14.2 finding — check your version)"
else
  echo "   --schedule-after=5s REJECTED — expected on 2.14.2 (error 10189 'message schedules pattern is invalid')"
  grep -oiE '10189|schedules pattern is invalid' /tmp/after.out | head -1 | sed 's/^/   server said: /'
fi

echo
echo "==> Part 3 (manual): rollup replace, source downsample, restart durability"
cat <<'NOTE'
   These three are timing/observation tests documented in results.json (behaviors_verified):
     - rollup_replace   : publish @every 5s to r.job, 1s later re-publish @every 1s to r.job;
                          exactly one control message remains and cadence switches to 1s.
     - source_downsample: @every 2s with Nats-Schedule-Source=src.sensor; flood reading-1..30 at
                          0.3s spacing; the target emits only each tick's latest value.
     - restart_durability: set @every 2s + a one-shot @at due during downtime; kill the server,
                          restart with the SAME -sd store; the overdue one-shot fires once,
                          @every resumes forward without backfilling missed ticks.
   Run these by hand and compare against results.json; they need wall-clock observation.
NOTE

echo
echo "==> Done. Compare Part 1/2 output against results.json (schedule_syntax_matrix, cli_server_mismatch)."
