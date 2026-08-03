# SQLite ALTER COLUMN: ships in 3.52, documented in 3.53 — version bisect

📝 Post (KO): https://var.gg/ko/blog/sqlite-353-alter-column
🗓 Run: 2026-08-04 (re-run of a 2026-06-29 post) · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"SQLite's docs credit ALTER COLUMN to 3.53.0, but I ran six pinned builds and
> the 3.52.0 binary already does it."* This directory is that check — the harness, the six-version
> grid, and the deterministic verdicts — so you don't have to take it on faith. `git clone` and
> `./run.sh` reproduces it.

## What this verifies

SQLite 3.53.0 (2026-04-09) is where the manual and the changelog say `ALTER TABLE ... ALTER COLUMN`
(setting/dropping `NOT NULL`, adding/dropping `CHECK` constraints) arrived. Bisecting six pinned
release builds shows the grammar is actually present and working in **3.52.0** (2026-03-06) — whose
own changelog never mentions the feature. Each verdict is a **deterministic** parser/DDL outcome:
same pinned CLI + same schema → same OK/ERR, same error text.

## Claim ↔ evidence

Every **firsthand** claim maps to a line in `results.json` / `probe-result.json`. Claims sourced
from the SQLite docs/changelog are listed separately as *cited, not measured* — the post marks
them the same way.

### Firsthand (measured across pinned sqlite3 CLI builds)

| Claim in the post | Evidence | Value |
|---|---|---|
| 3.48–3.51 **reject** the ALTER COLUMN grammar; **3.52.0 is the first build that accepts it**, and 3.53.0 too — across all four operations | `feature_matrix.py` → `probe-result.json.feature_matrix.grid` | 3.48–3.51 = **ERR** (`near "ALTER": syntax error`), 3.52/3.53 = **OK** |
| `SET NOT NULL` on a column that still holds a NULL row is rejected **atomically** — row survives, schema unchanged | `experiments.py` → `…experiments.atomic_rejection_exp2` | `constraint failed`; null row kept; schema unchanged |
| The DDL is **transactional** — `BEGIN; ALTER … SET NOT NULL; ROLLBACK;` reverts | `…experiments.rollback_exp6` | reverted = **true** |
| The added `NOT NULL` is an **ordinary constraint, not a new file format** — a 3.51.0 build (no ALTER grammar) opens the DB, sees the `NOT NULL`, rejects a NULL insert, passes integrity_check | `…experiments.backward_compat_exp8` | 3.51 rejects with `NOT NULL constraint failed (19)`; integrity = ok |
| ALTER COLUMN is **nullability + CHECK only** — `SET DEFAULT` / `SET DATA TYPE` / `ADD UNIQUE` / `ADD PRIMARY KEY` / `ADD FOREIGN KEY` are still syntax errors | `…experiments.limits_exp10` | all five: syntax error on 3.52.0 |

The headline is the boundary: **3.51 = ERR, 3.52 = OK**, one release before the docs say so.

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| The manual says the syntax "was added in SQLite 3.53.0 (2026-04-09)" | [ALTER TABLE docs](https://sqlite.org/lang_altertable.html) |
| 3.53.0 changelog: "Enhance ALTER TABLE to permit adding and removing NOT NULL and CHECK constraints." | [3.53.0 release log](https://sqlite.org/releaselog/3_53_0.html) |
| 3.52.0 changelog (2026-03-06) does not mention ALTER/NOT NULL/CHECK/CONSTRAINT — yet the binary runs it | [3.52.0 release log](https://sqlite.org/releaselog/3_52_0.html) |
| *Why* it shipped in 3.52 but was documented against 3.53 | not stated by SQLite; the post presents it as an observation, not an explanation |

### Explicitly NOT re-measured

The original 2026-06-25 run also timed the operation on large tables — `SET NOT NULL` on a
3,000,000-row table at ~78 ms with `page_count` and file size **unchanged** (a verifying scan +
metadata flip, *not* a table rewrite), `DROP NOT NULL` at ~14 ms (pure metadata), early-exit on
the first violating row. Those numbers are **hardware-specific** and are cited in the post from that
run, **not** re-measured here. This run dir re-verifies only the deterministic pass/fail and
behavioral claims — see `results.json` `not_measured`.

## Environment

Windows 11 x86_64 · precompiled `sqlite3.exe` CLI, six pinned builds (3.48.0–3.53.0), no Docker,
no network at run time. Hardware is irrelevant to these verdicts — it is parser + DDL behavior,
not timing.

## Reproduce

```bash
./run.sh   # downloads the six pinned sqlite-tools builds, runs both probes
```

Then compare the printed JSON against the committed `probe-result.json`. If your OS's tools archive
404s, drop the matching `sqlite3` into `bin/sqlite3-<ver>` manually (URLs are in `run.sh`).

## Raw data

None discarded — all evidence is small and committed. The six ~6.4 MB sqlite-tools zips were
downloaded, executed, and deleted after the run (firsthand cleanup); `run.sh` re-fetches the same
pinned versions. See `checksums.txt` for integrity hashes.

## Files

| File | What it is |
|---|---|
| `feature_matrix.py` | Runs the four ALTER COLUMN ops against all six pinned builds on `:memory:`; emits the OK/ERR grid. |
| `experiments.py` | Deterministic behavioral checks: atomic rejection, rollback, cross-version enforcement, limits. |
| `probe-result.json` | Combined raw output of both scripts. Deterministic. |
| `results.json` | Claim-facing summary: grid, behaviors, cited-vs-measured, not-measured. |
| `manifest.json` | Environment, versions, `executed_by`, reconstruction note, retention policy. |
| `run.sh` | Reproduction: fetch the six pinned builds, run both probes. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
