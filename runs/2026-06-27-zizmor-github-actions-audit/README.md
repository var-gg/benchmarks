# zizmor 1.26 — 15 findings on 3 vulnerable GitHub Actions workflows, offline

📝 Post: [KO](https://var.gg/ko/blog/zizmor-github-actions-audit)
🗓 Run: 2026-06-27 · 🔁 Re-verified: 2026-08-05 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** The original 2026-06-27 run's temporary fixture was discarded (finite disk).
> `fixture/.github/workflows/` is reconstructed from the recorded methodology. Unlike an OSV-style
> live-database backfill, zizmor's `--offline` scan is **deterministic** for a pinned version + fixed
> input — so the reconstruction was **re-run on 2026-08-05** and reproduces the regular-persona result
> byte-for-byte (15 findings, same rule breakdown, same severity split, SARIF rules 7 / results 15,
> exit 14). The numbers below are that re-verified output, not just recorded ones.
> Honest gap: the pedantic/auditor persona counts drift (24/24 today vs 25/26 recorded) because the
> reconstructed fixture is faithful for the regular persona but not byte-identical to the deleted original.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| **15 findings** on 3 deliberately-vulnerable workflows | `results.json` → `metrics[regular_findings_total]` | 7 unpinned-uses · 2 artipacked · 2 template-injection · 1 excessive-permissions · 1 dangerous-triggers · 1 unsound-ternary · 1 typosquat-uses |
| Severity split **High 11 / Medium 3 / Low 1** | `results.json` → `metrics[regular_findings_total].by_severity` | High 11, Medium 3, Low 1 |
| Both **new 1.26 audits** fire | `results.json` → `findings[new_1_26_audits]` + `fixture/.../release.yml` | typosquat-uses (`actons`→`actions`), unsound-ternary (`&& '' \|\| 'staging'` always falls through) |
| **Fully offline** — no token, no Docker | `run.sh` (`--offline`) → `findings[offline]` | deterministic for pinned version + fixed input |
| Native **SARIF 2.1.0** for code scanning | `results.json` → `findings[sarif]` | driver zizmor 1.26.1, rules 7 / results 15 |
| **Exit 14** on findings — CI gate ready | `results.json` → `findings[exit_code]` | non-zero on findings, 0 when clean |
| `--fix=all` **auto-rewrites** two finding classes | `results.json` → `findings[auto_fix]` | ci-deploy 3 fixes (template-injection → env indirection, artipacked → `persist-credentials: false`); release 1 fix |
| Persona escalation = **signal/noise tradeoff** | `results.json` → `metrics[persona_escalation]` | regular 15 → pedantic 24 → auditor 24 (2026-08-05); 15 → 25 → 26 recorded 2026-06-27 |

## The fixture

Three workflow files under `fixture/.github/workflows/`, each planting specific issues:

- **ci-deploy.yml** — `pull_request_target` trigger (dangerous-triggers) with `${{ github.event.pull_request.title/body }}` interpolated straight into `run:` (2× template-injection), unpinned `checkout@v4` / `setup-node@v4` / `upload-artifact@v3`, and a default-credential checkout (artipacked).
- **release.yml** — `permissions: write-all` (excessive-permissions), `actons/setup-python` typosquat (typosquat-uses), and `... && '' || 'staging'` (unsound-ternary), plus unpinned uses and an artipacked checkout.
- **lint.yml** — almost clean: `persist-credentials: false` on checkout and least-privilege `permissions`, leaving only 2 unpinned uses. Included to show the tool does not just flag everything.

This fixture is the reproducible input; the one thing that does **not** drift for the regular persona.

## Honest limits

- **7/15 findings are unpinned-uses**, a blanket policy that flags even trusted actions pinned by tag (`@v4`). Not a false positive — a policy choice you can dial down.
- Some audits (e.g. ref-confusion) need **online** mode (GitHub API); offline uses the baked-in corpus only.
- Static analysis sees **workflow structure** risk, not runtime behavior or secret values.
- typosquat matches a **baked-in list** of popular actions; a typo of an obscure action may slip through.

## Reproduce

```bash
./run.sh          # needs uvx (uv toolchain); pins zizmor 1.26.1, scans the fixture offline
```

Expect **exactly 15 findings** on the regular persona and a non-zero exit (14).

## Environment

Windows 11 · zizmor **1.26.1** (via `uvx`, ephemeral) · scan mode **offline** (no network / token / Docker) · deterministic.
