#!/usr/bin/env bash
#
# Reproduce the Jujutsu (jj) 0.43.x firsthand demo: build a linear history with a
# single planted off-by-one bug in mean(), then let `jj bisect run` binary-search
# for the first bad commit automatically. Also exercises `jj file search` (search
# the tree of any revision without a checkout), git colocation, and the operation
# log (which makes the whole search undoable).
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-15-jujutsu-jj-bisect-run
#   ./run.sh
#
# Requirements: jj 0.43.x on PATH (or set JJ=/path/to/jj), Python 3, and git.
# Nothing private is used — the demo repo is created fresh from harness/setup.sh.
#
# What you should see (results.json -> support_matrix):
#   - bisect reports first-bad = "refactor: tweak mean() internals" in 3 evaluations
#   - `jj file search --pattern variance` hits at @, is empty at an earlier revision
#   - `git log` sees the same commits (colocation)
# The change-id / hash STRINGS will differ from harness/bisect-output.txt — jj
# randomizes change-ids per repo; the first-bad description and step count are what
# reproduce, not the id strings (see manifest.determinism).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

JJ_PIN="0.43"

# --- tooling present? --------------------------------------------------------
JJ="${JJ:-jj}"
command -v "$JJ" >/dev/null 2>&1 || {
  echo "Missing jj on PATH. Install jj ${JJ_PIN}.x: https://github.com/jj-vcs/jj/releases"
  echo "(or run: JJ=/path/to/jj ./run.sh)"
  exit 1
}
for bin in python git; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing '$bin' on PATH."; exit 1; }
done

# --- version guard: warn (do NOT fail) if not 0.43.x -------------------------
JJ_VER="$("$JJ" --version 2>/dev/null | sed -n 's/^jj \([0-9][0-9.]*\).*/\1/p' | head -n1)"
case "${JJ_VER:-}" in
  0.43.*)
    echo "==> jj ${JJ_VER}  (matches the recorded ${JJ_PIN}.x line)" ;;
  *)
    echo "!! WARNING: this run was recorded on jj ${JJ_PIN}.x; you have '${JJ_VER:-unknown}'."
    echo "!! jj is still 0.x — flags/output can shift between minor releases. `jj bisect run`"
    echo "!! has existed since 0.33; `jj file search` since 0.41. Pin 0.43.x for exact parity." ;;
esac

# --- short work dir (Windows MAX_PATH: jj index segment names are ~128 chars) -
WORK="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/jjbench.$$")"
mkdir -p "$WORK"
cleanup() { rm -rf "$WORK" 2>/dev/null || true; }
trap cleanup EXIT
echo "==> work dir: $WORK"

# harness/setup.sh drives the whole demo (build history -> bisect -> file search
# -> git colocation). It expects JJ set to the binary and a short work dir arg.
JJ="$JJ" bash "$HERE/harness/setup.sh" "$WORK"

echo
echo "==> Done. Compare against results.json and harness/bisect-output.txt:"
echo "    - support_matrix[bisect_run_finds_planted_bug]: first bad = 'refactor: tweak mean() internals', 3 evals."
echo "    - support_matrix[file_search_any_revision]: hit at @, empty at the pre-variance revision."
echo "    - support_matrix[git_colocation]: git log shows the jj commits verbatim."
echo "    - The change-id/hash strings differ per run by design (jj randomizes change-ids)."
