# uv audit vs pip-audit — same findings, ~20× faster

📝 Post: [KO](https://var.gg/ko/blog/uv-audit-supply-chain) · [EN](https://var.gg/en/blog/uv-audit-supply-chain)
🗓 Run: 2026-06-20 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This run happened on 2026-06-20, before this repo existed; its raw
> artifacts were discarded (finite disk). `run.sh` + `fixture/pyproject.toml` are
> reconstructed from the recorded methodology so you can reproduce the **method**. The
> numbers in `results.json` are the 2026-06-20 snapshot against the **live OSV database** —
> re-running today will drift as OSV updates. The speed ratio and result-parity finding are
> the durable claims; exact vuln counts are point-in-time.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| uv audit is **~20× faster** than pip-audit | `results.json` → `metrics[audit_speed]` | 0.82s vs 16.1s warm ≈ **19.6×** (same OSV source) |
| Both tools find the **same** vulnerabilities | `results.json` → `findings[result_parity]` | vuln id set identical (79), symmetric diff **0**; PYSEC 18 / CVE 30 / GHSA 30 / SNYK 1 |
| The fixture has **48 known vulns / 6 packages** | `results.json` → `findings[fixture_detection]` + `fixture/pyproject.toml` | 48 across 13 pkgs, 6 vulnerable (as-of 2026-06-20) |
| **Exit 1** on findings — CI-ready | `results.json` → `findings[exit_code]` | exit 1 dirty / exit 0 clean |
| Native **SARIF 2.1.0** output | `results.json` → `findings[sarif]` | rules 48 / results 48, driver uv 0.11.23 |
| `--ignore` matches by **alias** | `results.json` → `findings[suppression]` | 48 → 46 on one GHSA id |
| `uv audit` is a **preview** feature | `results.json` → `findings[audit_is_preview]` | experimental warning; flag only silences it |

### Honestly NOT verified

uv's **malware check** is a *separate* feature — it runs on `uv sync` (install-time gate), **not**
on `uv audit`. We confirmed it activates and gates installs (`UV_MALWARE_CHECK=1`, message path),
but did **not** install a real malicious package to force a true-positive (safety). See
`results.json` → `explicitly_not_verified`. The post makes the `audit` ≠ `malware-check`
distinction the same way.

## The fixture

`fixture/pyproject.toml` pins deliberately-vulnerable releases (`requests==2.19.1`,
`jinja2==2.10`, `pyyaml==5.3`, `flask==0.12.2`) so both tools have something to find. This is
the reproducible input — the one thing that does **not** drift.

## Reproduce

```bash
./run.sh          # needs uv 0.11.23+ ; resolves the fixture, times uv audit vs pip-audit
```

Expect: the two tools report an **identical** vuln id set, and uv audit runs ~20× faster warm.
Counts will differ from the 2026-06-20 snapshot as OSV updates — that is expected and honest.

## Environment

Windows 11 · uv **0.11.23** (standalone) · Python 3.12.13 (uv-managed) · data source **OSV** (live).
