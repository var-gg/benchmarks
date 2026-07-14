#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce Elixir 1.20's gradual (set-
# theoretic) type-checker findings from the committed fixture.
#
#   git clone https://github.com/var-gg/benchmarks
#   cd benchmarks/runs/2026-07-13-elixir-120-gradual-typing
#   ./run.sh
#
# Everything runs from fixture/ — no var.gg or otherwise private code. Two parts:
#
#   1. Type-checker matrix. Compile each fixture/src/*.ex with `elixirc`, capture
#      the compiler's type output verbatim, and classify warned-vs-quiet against
#      the recorded 6-case matrix (results.json -> support_matrix).
#   2. Build-failure semantics. Demonstrate the exit codes that decide whether a
#      type warning can actually fail a build:
#        elixirc --warnings-as-errors     -> exit 0  (elixirc ignores the flag)
#        mix compile                      -> exit 0  (warning printed, build ok)
#        mix compile --warnings-as-errors -> exit 1  (the incantation that bites)
#
# The .ex fixtures carry NO @spec and NO type annotations — every warning below
# is pure inference. Type findings are WARNINGS, not errors: they do not fail a
# build unless you opt in (demo 3). And absence of a warning is not proof of
# correctness — see the two 'quiet' cases. Those are the honest limits; the
# READMEs and results.json state them plainly. The original run's raw compile
# logs were discarded (finite disk); this harness + fixture reconstruct the
# METHOD, and no artifact hashes were captured, so none are invented.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ELIXIR_PIN="1.20.2"   # recorded: Elixir 1.20.2 (compiled w/ OTP 27); runtime OTP 29 [erts-17.0.3, jit]

# --- tooling present? (elixir, elixirc, mix all ship with an Elixir install) --
for bin in elixir elixirc mix; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "Missing '$bin' on PATH. Install Elixir ${ELIXIR_PIN}: https://elixir-lang.org/install.html"
    exit 1
  }
done

# --- version guard: warn (do NOT fail) if not 1.20.x -------------------------
ELIXIR_VER="$(elixir --version 2>/dev/null | sed -n 's/^Elixir \([0-9][0-9.]*\).*/\1/p' | head -n1)"
case "${ELIXIR_VER:-}" in
  1.20.*)
    echo "==> elixir ${ELIXIR_VER}  (matches the recorded ${ELIXIR_PIN} line)"
    ;;
  *)
    echo "!! WARNING: this run was recorded on Elixir ${ELIXIR_PIN}; you have '${ELIXIR_VER:-unknown}'."
    echo "!! Elixir's set-theoretic type checker is version-sensitive — on < 1.20 several of"
    echo "!! the cases below legitimately stay quiet. Reproduction fidelity needs Elixir 1.20.x."
    ;;
esac
echo "==> $(elixir --version 2>/dev/null | grep -i '^Elixir' || true)"

WORK="$(mktemp -d)"
OUTDIR="$WORK/out"; mkdir -p "$OUTDIR"   # .beam output lands here, never in the repo
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ============================================================ 6-case matrix ==
# file : expected : one-line description   (the compiler output is captured verbatim)
MATRIX="
bug_disjoint.ex    warn   disjoint dynamic(binary or integer) handed to Map.fetch!/2
bug_missing_key.ex warn   User.name(%{}) — required :name key missing on an empty map
narrow_ok.ex       quiet  data.a + data.b narrows cleanly (false positive avoided)
narrow_bug.ex      warn   data.a + data — map narrowed, then misused as a number
dead_clause.ex     warn   is_binary/1 under an is_integer/1 guard — unreachable (x2)
gradual_escape.ex  quiet  fully dynamic param, never narrowed — gradual escape
"

echo
echo "==> Type-checker matrix:  elixirc -o <tmp> fixture/src/<file>   (output captured verbatim)"
matched=0; total=0
while read -r file expect desc; do
  if [ -z "${file:-}" ]; then continue; fi
  total=$((total + 1))
  CAP_OUT="$(elixirc -o "$OUTDIR" "$HERE/fixture/src/$file" 2>&1)" || true
  wcount="$(printf '%s\n' "$CAP_OUT" | grep -c 'warning:' || true)"
  if [ "$wcount" -gt 0 ]; then observed=warn; else observed=quiet; fi
  if [ "$observed" = "$expect" ]; then
    tag="OK      "; matched=$((matched + 1))
  else
    tag="MISMATCH"
  fi
  echo
  printf '  [%s] %-18s expect %-5s  observed %-5s  (%s warning-line[s])\n' \
         "$tag" "$file" "$expect" "$observed" "$wcount"
  printf '      %s\n' "$desc"
  if [ -n "$CAP_OUT" ]; then
    printf '%s\n' "$CAP_OUT" | sed 's/^/      | /'
  else
    printf '      | (no compiler output — stayed quiet)\n'
  fi
done <<EOF
$MATRIX
EOF
echo
echo "  matrix: ${matched}/${total} cases matched the recorded expectation"

# =================================================== build-failure semantics ==
echo
echo "==> Build-failure semantics — does a type warning fail the build?"

# (1) elixirc ignores --warnings-as-errors (it is a *mix* concept). Even a plain
#     unused-variable warning does not flip the exit code. Recorded: exit 0.
CAP1="$(elixirc --warnings-as-errors -o "$OUTDIR" "$HERE/fixture/src/unused.ex" 2>&1)" && D1=0 || D1=$?
echo
echo "  (1) elixirc --warnings-as-errors src/unused.ex        -> exit ${D1}   (recorded: 0)"
if [ "$D1" -eq 0 ]; then
  echo "      OK: elixirc ignores the flag; the warning does not bite."
else
  echo "      MISMATCH: recorded exit 0."
fi

# (2)+(3) mix DOES honour --warnings-as-errors. Copy the tiny mix project into a
#     temp dir so _build never lands in the repo, then force a recompile each way.
MIXDIR="$WORK/typedemo"
cp -r "$HERE/fixture/typedemo" "$MIXDIR"
( cd "$MIXDIR" && mix compile --force >/dev/null 2>&1 ) && D2=0 || D2=$?
( cd "$MIXDIR" && mix compile --force --warnings-as-errors >/dev/null 2>&1 ) && D3=0 || D3=$?

echo
echo "  (2) mix compile                                       -> exit ${D2}   (recorded: 0)"
if [ "$D2" -eq 0 ]; then
  echo "      OK: the type warning is printed but the build succeeds."
else
  echo "      MISMATCH: recorded exit 0."
fi
echo
echo "  (3) mix compile --warnings-as-errors                  -> exit ${D3}   (recorded: 1)"
if [ "$D3" -eq 1 ]; then
  echo "      OK: this is the incantation that makes type warnings fail CI."
else
  echo "      MISMATCH: recorded exit 1."
fi

# ---------------------------------------------------------------- summary ----
echo
echo "==> Done. Compare against results.json:"
echo "    - support_matrix: 4 warn / 2 quiet. The two quiet cases (narrow_ok, gradual_escape)"
echo "      are the honest limit — no inference signal => no warning => NOT a proof of safety."
echo "    - exit_code_semantics: elixirc 0 / mix 0 / mix --warnings-as-errors 1."
echo "    - no @spec or type annotations anywhere — every warning above is inference-only."
