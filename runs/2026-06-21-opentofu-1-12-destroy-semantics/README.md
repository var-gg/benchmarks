# OpenTofu 1.12 destroy / state semantics — firsthand

📝 Post (KO): https://var.gg/ko/blog/opentofu-1-12-destroy-semantics
🗓 Run: 2026-06-21 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran OpenTofu 1.12 locally and watched destroy stop deleting things."*
> This directory is that run — the `.tf` fixtures, the environment, and the observed plan
> verbs and exit codes — so you don't have to take the claim on faith. `git clone` and
> `./run.sh` reproduces it with the `hashicorp/local` provider only (no cloud account).

> ⚠️ **Backfill note.** The experiments ran firsthand on 2026-06-21 (same day as the post);
> the observations here come from that session. The exact ad-hoc shell commands were not
> retained, so the harness (`run.sh` + fixtures) is **reconstructed from the fully-documented
> steps**. It reproduces the documented behavior — it is not a fresh re-measurement. See
> `manifest.json.backfill_note`.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to an entry in `results.json`. The one cross-tool
claim (what Terraform does) is cited from docs and flagged *not measured* — the post marks it
the same way.

### Firsthand (observed on OpenTofu 1.12.0, re-verified 1.12.3)

| Claim in the post | Evidence | Observation |
|---|---|---|
| `prevent_destroy` now takes an **expression** — `prevent_destroy = var.lock` is rejected by 1.11 at validate but accepted by 1.12 | `results.json` → `var_driven_prevent_destroy` + `fixtures/exp-a.tf` | 1.11: "Variables not allowed"; 1.12: accepted; `lock=true` blocks destroy, `lock=false` allows it |
| `lifecycle { destroy = false }` on a **managed** resource turns destroy into **"forget"** (state removed, file kept) and OpenTofu **exits non-zero** to flag the orphan | `results.json` → `managed_destroy_false_forget` + `fixtures/exp-b.tf` | `Plan: … 1 to forget.`, exit 1, `keep.txt` survives; `-suppress-forget-errors` → exit 0 |
| `destroy = false` **outranks** `prevent_destroy = true` — the "protected" resource is silently forgotten | `results.json` → `precedence_destroy_false_over_prevent_destroy` + `fixtures/exp-d.tf` | `1 to forget`, `both.txt` present, prevent_destroy did not block |
| A `removed` block with **no lifecycle** defaults to **forget** on OpenTofu (keeps the real object) + warns | `results.json` → `removed_block_default_forget` + `fixtures/exp-r-*.tf` | warning + `1 forgotten`, `demo.txt` present |
| Local backend now writes **pretty-printed JSON** state | `results.json` → `pretty_printed_state` | indented `terraform.tfstate`, version 4 |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Terraform defaults to **destroy** (not forget) when a `removed` block omits `lifecycle` | HashiCorp docs — no `terraform` binary was run here |
| CHANGELOG PR numbers (#3474/#3507, #3409, #3588, #1947) | CHANGELOG.md shipped in the 1.12.0 zip |
| v1.12.x supported until 2027-02-01 | OpenTofu release policy |

## Environment

Windows 11 · OpenTofu **1.12.0** (re-verified **1.12.3**), local backend · provider
`hashicorp/local ~> 2.5`. Baseline **1.11.10** for the Exp A validate-time contrast.
Hardware is irrelevant — these are plan/destroy semantics, not timing.

## Reproduce

```bash
./run.sh          # needs `tofu` >= 1.12 on PATH; local provider only, no cloud
```

Each experiment prints the plan verb (`to destroy` vs `to forget`) and exit code; compare
against `results.json`.

## Raw data

None discarded. This run has no large artifacts. `terraform.tfstate` is transient (embeds
absolute local paths, regenerable by `run.sh`) and intentionally not committed. The durable
evidence — the plan verbs and exit codes — lives in `results.json`. See `checksums.txt` for
integrity hashes of the committed harness.

## Files

| File | What it is |
|---|---|
| `fixtures/exp-a.tf` | Variable-driven `prevent_destroy`. |
| `fixtures/exp-b.tf` | Managed `destroy = false` (forget). |
| `fixtures/exp-d.tf` | `destroy = false` vs `prevent_destroy` precedence. |
| `fixtures/exp-r-step1.tf` / `exp-r-step2.tf` | `removed` block default (two-phase). |
| `run.sh` | Reconstructed harness — applies each fixture, prints plan verb + exit code. |
| `results.json` | Claim-facing summary: behaviors, observations, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, backfill note, retention policy. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
