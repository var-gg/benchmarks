# Jujutsu (jj) 0.43 — letting `jj bisect run` find the commit that planted a bug

📝 Post: [KO](https://var.gg/ko/blog/jujutsu-jj-bisect-run) *(Korean-only; no English post)*
🗓 Run: 2026-07-15 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> **What reproduces, and what doesn't.** jj's behaviour here is deterministic for a pinned
> 0.43.x: bisect narrows the same history to the same first-bad commit in the same number of
> steps, and `jj file search` hits/misses the same revisions. The one thing that does **not**
> reproduce byte-for-byte is the **change-id / git-hash strings** (`xuspwrqt`, `2e5a1b9`, …) —
> jj assigns change-ids **randomly per repo**, so those are run-specific labels, not stable ids.
> Reproduction is about the **method** and the **first-bad description**, not the id strings.
> See `manifest.json` → `determinism`.

## Claim ↔ evidence

The demo builds a **linear 8-commit history** and plants a **single** off-by-one bug in `mean()`
(`sum(xs) / (len(xs) - 1)`) at the commit `refactor: tweak mean() internals`. The other commits
(`total`, `median`, `variance`, docstring, `minmax`) are unrelated. A one-line test —
`mean([2,4,6]) == 4` — is all `jj bisect run` needs.

| Claim in the post | Evidence | Value |
|---|---|---|
| `jj bisect run` **auto-finds the commit that planted the bug** | `harness/bisect-output.txt` · `results.json` → `support_matrix[bisect_run_finds_planted_bug]` | first bad = **`refactor: tweak mean() internals`**, reached in **3 evaluations** of 6 candidates |
| The test's **exit code** drives good / bad / skip / abort | `results.json` → `support_matrix[bisect_exit_code_protocol]` | `0`=good · non-zero=bad · `125`=skip · `127`=abort · `$JJ_BISECT_TARGET` = commit under test · `--find-good` reverses direction |
| `jj file search` searches the tree of **any revision without a checkout** | `harness/setup.sh` · `results.json` → `support_matrix[file_search_any_revision]` | `--pattern variance` → hit at `@`, **empty** at a revision predating the `variance()` commit |
| A **colocated** repo lets plain `git` see the jj commits | `harness/setup.sh` · `results.json` → `support_matrix[git_colocation]` | `git log` shows the jj commits verbatim — jj sits **on top of** git, not replacing it |
| The **operation log** makes the search fully undoable | `harness/bisect-output.txt` (final lines) · `results.json` → `support_matrix[operation_log_undo]` | bisect prints the exact `jj op restore <id>` to discard every temporary revision it created |

## Freshness — do not overstate the hook

- **`jj bisect run` is not new.** It landed in **0.33.0 (2025-09)**, not 0.43. The post says this
  plainly. The genuinely recent surface is **`jj file search` (0.41, 2026-05)** and the 0.42/0.43
  line (mimalloc allocator in 0.42).
- jj is by Martin von Zweigbergk (Google), written in Rust, and uses the **git on-disk format**
  (real git commits). It is still **0.x** (pre-1.0). Sourced from GitHub releases + changelog +
  docs.jj-vcs.dev, cross-checked 2026-07-15.

## Honestly NOT verified / honest limits

- **Bisect assumes monotonicity** — every descendant of the first bad commit is also bad. A
  non-monotone bug (appears, disappears, reappears) breaks that assumption. The demo history is
  deliberately monotone.
- **`jj file search` is early (0.41).** Its `--help` states glob matching only (regex on request),
  no concurrent search, and **no in-file match positions** — it returns a **file list**, not line
  numbers.
- **Still 0.x.** Flags and output can change between minor releases; pin `0.43.x` for exact parity.
- **Large-repo performance was not measured** — this is an 8-commit toy history.
- **Only Windows was exercised** (with a MAX_PATH workaround, below). The bisect logic is
  OS-independent, but no macOS/Linux run was captured.

## The harness

`harness/setup.sh` is the whole demo: it inits a **colocated** jj/git repo, builds the 8-commit
history, plants the `mean()` bug, runs `jj bisect run`, then exercises `jj file search` and shows
`git log` seeing the same commits. `harness/bisect-output.txt` is the **verbatim** `jj bisect run`
transcript from the 2026-07-15 run. Nothing private is involved — the fixture is created fresh
each time; no repo state is committed here.

## Reproduce

```bash
./run.sh          # needs jj 0.43.x on PATH (or JJ=/path/to/jj), plus python + git
```

`run.sh` guards the jj version (warns loudly if you are not on 0.43.x), creates a **short** temp
work dir (Windows MAX_PATH: jj index segment filenames are ~128 chars and overflow a long parent
path with `os error 3`), and drives `harness/setup.sh`. You should see bisect report
**`refactor: tweak mean() internals`** as first-bad in **3 evaluations**, a `file search` hit at
`@` and an empty result at the earlier revision, and `git log` showing the jj commits — with
**different** change-id/hash strings than the recorded transcript, by design.

## Environment

Windows 11 (win32) · jj **0.43.0-89f62ede** (prebuilt `jj-v0.43.0-x86_64-pc-windows-msvc.zip`,
2026-07-01 release) · git colocated · Docker **not used**. The **jj version is the load-bearing
variable**, not the OS.
