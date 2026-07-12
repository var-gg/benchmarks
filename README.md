# var.gg benchmarks

Reproducible evidence for the firsthand experiments in the [var.gg](https://var.gg) engineering blog.

Every post on var.gg that says *"I ran it myself"* has a run here: the **harness** (so you can
re-run it), a **summary** of what was measured, an **environment manifest** (so you know the
conditions), and **integrity hashes**. An anonymous first-person claim is unverifiable — and an
unverifiable benchmark is indistinguishable from one an LLM made up. This repo exists to close
that gap.

We do **not** publish raw dumps. Logs, traces, per-iteration samples, and binaries are
discarded at run time (finite local disk). When a run had large raw artifacts, their sha256 is
committed as an integrity commitment and the harness regenerates them. That is more honest than
most public benchmarks, not less.

## Runs

| Date | Run | Post | Kind |
|---|---|---|---|
| 2026-07-12 | [css-anchor-positioning-floating-ui](./runs/2026-07-12-css-anchor-positioning-floating-ui/) | [KO](https://var.gg/ko/blog/css-anchor-positioning-floating-ui) | capability verification |

## Layout

```
runs/{YYYY-MM-DD}-{post-slug}/    # dir name == blog slug (bidirectional link)
  README.md        # claim ↔ evidence map (English)   ⭐ start here
  README.ko.md     # same, Korean
  manifest.json    # environment, versions, executed_by, retention
  results.json     # summary statistics or capability matrix — never raw samples
  run.sh           # the harness; a third party can clone and run it
  probe.py / ...   # supporting harness files
  checksums.txt    # sha256 of committed harness + evidence
```

## Rules (enforced, not aspirational)

- **100 KB hard cap per run directory.** 1 MB hard cap per file. A pre-commit hook and CI both
  reject violations — git history is permanent, so oversize never gets in.
- **No raw dumps.** Summary statistics or capability matrices only. Distributions go in as
  histograms, never sample arrays.
- **Artifacts are produced by the run itself**, at run time — never a log-parsing job days later.
- **Pin versions.** No `latest`. A run that can't be reproduced isn't evidence.
- **`executed_by` is honest.** Many of these runs are executed by an AI agent. That is the point,
  and it is stated in every `manifest.json`.

See [`.githooks/pre-commit`](./.githooks/pre-commit) and
[`scripts/verify-size.sh`](./scripts/verify-size.sh). Enable the hook with:

```bash
git config core.hooksPath .githooks
```

## License

[Apache-2.0](./LICENSE) — reproduction encouraged.
