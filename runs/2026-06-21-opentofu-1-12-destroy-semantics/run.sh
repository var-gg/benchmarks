#!/usr/bin/env bash
#
# Reconstructed harness (backfill) — reproduce the OpenTofu 1.12 destroy/state
# semantics experiments. Third-party runnable:
#
#     git clone https://github.com/var-gg/benchmarks
#     cd benchmarks/runs/2026-06-21-opentofu-1-12-destroy-semantics
#     ./run.sh
#
# Uses the hashicorp/local provider only — NO cloud account, NO credentials, NO
# remote objects. Each experiment prints the OpenTofu plan verb and the process
# exit code; compare those against results.json.behaviors_verified.
#
# Requires: a `tofu` binary >= 1.12.0 on PATH (the original run used 1.12.0, then
# re-verified 1.12.3). Install from https://github.com/opentofu/opentofu/releases.
# The original run also downloaded 1.11.10 as a contrast for Exp A; if a second
# binary `tofu1.11` is on PATH this script runs that contrast too, otherwise it
# skips it with a note.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

command -v tofu >/dev/null 2>&1 || {
  echo "Install OpenTofu >= 1.12.0 first: https://github.com/opentofu/opentofu/releases"
  exit 1
}
echo "==> tofu version: $(tofu version | head -1)   (original run: 1.12.0, re-verified 1.12.3)"

run_exp() {
  # run_exp <name> <fixture.tf>  -> fresh temp workdir with just that fixture
  local name="$1" fixture="$2"
  local work; work="$(mktemp -d)"
  cp "$HERE/fixtures/$fixture" "$work/main.tf"
  ( cd "$work" && tofu init -input=false >/dev/null 2>&1 || true; echo "$work" )
}

hr() { echo "------------------------------------------------------------"; }

# ---- Exp A: variable-driven prevent_destroy -------------------------------
hr; echo "== Exp A: prevent_destroy = var.lock =="
WA="$(run_exp expA exp-a.tf)"
( cd "$WA"
  tofu apply -auto-approve -input=false >/dev/null 2>&1
  echo "-- destroy -var lock=true (expect BLOCKED, note.txt present):"
  tofu destroy -auto-approve -input=false -var lock=true 2>&1 | grep -Ei "cannot be destroyed|prevent_destroy|Plan:" | head -3
  echo "   note.txt present? $([ -f note.txt ] && echo yes || echo no)  (expect yes)"
  echo "-- destroy -var lock=false (expect 1 to destroy, note.txt gone):"
  tofu destroy -auto-approve -input=false -var lock=false 2>&1 | grep -E "Plan:|Destroy complete" | head -2
  echo "   note.txt present? $([ -f note.txt ] && echo yes || echo no)  (expect no)"
)
rm -rf "$WA"

# Optional 1.11 contrast (validate-time rejection)
if command -v tofu1.11 >/dev/null 2>&1; then
  echo "-- 1.11 contrast (expect validate error 'Variables not allowed'):"
  W11="$(mktemp -d)"; cp "$HERE/fixtures/exp-a.tf" "$W11/main.tf"
  ( cd "$W11" && tofu1.11 init -input=false >/dev/null 2>&1; tofu1.11 validate 2>&1 | grep -Ei "Variables (not allowed|may not be used)" | head -1 )
  rm -rf "$W11"
else
  echo "-- 1.11 contrast SKIPPED (no 'tofu1.11' on PATH). Original run: 1.11.10 rejected it at validate."
fi

# ---- Exp B: managed destroy = false -> forget ------------------------------
hr; echo "== Exp B: lifecycle { destroy = false } (managed) =="
WB="$(run_exp expB exp-b.tf)"
( cd "$WB"
  tofu apply -auto-approve -input=false >/dev/null 2>&1
  echo "-- destroy (expect '1 to forget', exit 1, keep.txt survives):"
  tofu destroy -auto-approve -input=false 2>&1 | grep -E "to forget|forgotten instances|incur charges" | head -3
  echo "   destroy exit code: $?  (expect 1)"
  echo "   keep.txt present? $([ -f keep.txt ] && echo yes || echo no)  (expect yes — orphan)"
  echo "   state entries: $(tofu state list 2>/dev/null | wc -l)  (expect 0)"
  echo "-- pretty-printed state check (Exp C): first chars of terraform.tfstate:"
  tofu apply -auto-approve -input=false >/dev/null 2>&1
  head -3 terraform.tfstate 2>/dev/null
)
rm -rf "$WB"

# ---- Exp D: precedence destroy=false vs prevent_destroy --------------------
hr; echo "== Exp D: destroy=false + prevent_destroy=true on one resource =="
WD="$(run_exp expD exp-d.tf)"
( cd "$WD"
  tofu apply -auto-approve -input=false >/dev/null 2>&1
  echo "-- destroy (expect '1 to forget', NOT blocked, both.txt present):"
  tofu destroy -auto-approve -input=false 2>&1 | grep -E "to forget|cannot be destroyed" | head -2
  echo "   both.txt present? $([ -f both.txt ] && echo yes || echo no)  (expect yes — forgotten, not blocked)"
)
rm -rf "$WD"

# ---- Exp R: removed block default when lifecycle omitted --------------------
hr; echo "== Exp R: removed { } with NO lifecycle (default = forget on OpenTofu) =="
WR="$(mktemp -d)"
cp "$HERE/fixtures/exp-r-step1.tf" "$WR/main.tf"
( cd "$WR"
  tofu init -input=false >/dev/null 2>&1
  tofu apply -auto-approve -input=false >/dev/null 2>&1
  cp "$HERE/fixtures/exp-r-step2.tf" main.tf
  echo "-- apply removed block (expect warning + '1 forgotten', demo.txt present):"
  tofu apply -auto-approve -input=false 2>&1 | grep -Ei "Missing lifecycle|will not be destroyed|forgotten|to forget" | head -3
  echo "   demo.txt present? $([ -f demo.txt ] && echo yes || echo no)  (expect yes — kept)"
)
rm -rf "$WR"

hr
echo "==> Done. Terraform's contrasting default (destroy, not forget) is cited from"
echo "    HashiCorp docs and was NOT run here — see manifest.json.cross_tool."
