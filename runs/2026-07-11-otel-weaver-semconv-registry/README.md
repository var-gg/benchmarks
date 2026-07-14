# OpenTelemetry Weaver 0.24.2 — semconv registry as a contract

📝 Post (KO): https://var.gg/ko/blog/otel-weaver-semconv-registry
🗓 Run: 2026-07-11 (post) · re-executed 2026-07-15 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims things like *"camelCase passed the built-in check silently"* and *"a rename
> shows up as remove+add."* This directory is the harness that produced those claims — the
> registry fixtures, the Rego policy, the exact commands — so you don't have to take them on
> faith. `git clone` and `./run.sh` reproduces every exit code against pinned **weaver 0.24.2**.

## Why this reproduces exactly

`weaver registry check / diff / generate` are **deterministic** for a pinned version: no live
database, no timing, no randomness. So although the post's original working copy was discarded
(finite-disk policy) and these fixtures were reconstructed from the recorded firsthand log, a
fresh re-run on 2026-07-15 against the same **0.24.2** binary reproduced every result. `latest`
is deliberately not used — weaver's diagnostics evolve across releases, so the pin *is* the evidence.

## Claim ↔ evidence

### Firsthand (measured on weaver 0.24.2 — see `evidence.txt`)

| Claim in the post | Fixture / command | Result |
|---|---|---|
| A clean registry passes `check` | `reg/` → `registry check` | exit **0** |
| A missing `brief` field fails | `reg_b2/` → `registry check` | exit **1** ("does not contain a brief field") |
| An invalid `type: money` fails | `reg_b3/` → `registry check` | exit **1** (type must be boolean/int/double/string/any/…) |
| **camelCase name passes the built-in check silently** | `reg_b1/` → `registry check` | exit **0** — naming is *not* a built-in concern |
| A Rego policy makes naming an enforced contract | `reg_b1/` → `registry check -p ./policies` | exit **1** ("attr_name_not_snake_case … commerce.order.totalAmount") |
| The same registry is clean *with* the policy on the clean fixture | `reg/` → `registry check -p ./policies` | exit **0** |
| A rename is reported as **remove + add** (breaking) | `reg2/` vs `reg/` → `registry diff --format json` | `+commerce.order.identifier`, `−commerce.order.id` (see `diff.json`) |
| One registry source generates docs via a Jinja template | `reg/` → `registry generate … markdown` | exit **0**, wrote `gen_out/attributes.md` |

### Honest limits (the post states these too)

| Limit | Evidence |
|---|---|
| `diff` does **not** surface the in-place `total_amount` `double→int` type change | `diff.json` lists only the add/remove; the type change is absent |
| `diff` exits **0** — it is informational, not a CI gate by itself | `evidence.txt` → `B_diff exit=0` |
| Field-level type/stability enforcement needs the `comparison_after_resolution` policy layer, not the default diff | cited in `results.json.exp_B_diff.honest_limits` |

### ⚠️ One correction the run surfaced

The post says `weaver registry resolve` is deprecated and *"guides you to generate/package and
**stops**."* Measured on 0.24.2, `resolve` prints the deprecation warning to **stderr** and then
**completes the resolution, exiting 0** — it warns, it does not halt (`evidence.txt` →
`resolve_deprecated_but_runs exit=0`). Recorded accurately here; the post's wording overstates it.
See `manifest.json.discrepancy_flag`.

## Environment

Windows 11 x64 · weaver **0.24.2** (2026-06-23 release), native CLI. Hardware is irrelevant —
this checks CLI behavior and exit codes on fixed fixtures, not timing.

## Reproduce

```bash
./run.sh   # downloads pinned weaver 0.24.2 (per-OS) → runs every case → writes evidence.regenerated.txt
```

Then diff `evidence.regenerated.txt` against the committed `evidence.txt` — they must match.

## Files

| File | What it is |
|---|---|
| `reg/` | Clean registry (`manifest.yaml` + one attribute group: `commerce.order.id` string, `commerce.order.total_amount` double) |
| `reg_b1/` `reg_b2/` `reg_b3/` | Violation variants: camelCase name / missing brief / invalid `type: money` |
| `reg2/` | Breaking-change head: `id`→`identifier` rename, `total_amount` `double`→`int` |
| `policies/naming.rego` | `after_resolution` Rego policy denying non-snake_case attribute names |
| `templates/markdown/` | Jinja template for `registry generate` (`weaver.yaml` + `attributes.md.j2`) |
| `evidence.txt` | Exit-code matrix captured from the actual run — the deterministic evidence |
| `diff.json` | Raw JSON output of `registry diff` (the add/remove change list) |
| `gen_out/attributes.md` | Sample output of `registry generate` |
| `run.sh` | Downloads pinned weaver, re-runs everything, regenerates `evidence.txt` |
| `manifest.json` | Environment, version pin, provenance, the resolve discrepancy flag |
| `results.json` | Claim-facing summary of all experiments |
| `checksums.txt` | sha256 of the committed harness + evidence |
