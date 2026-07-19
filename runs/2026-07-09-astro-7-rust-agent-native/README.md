# Astro 7 — Rust compiler & agent-native dev server (astro@7.0.6)

📝 Post (KO): https://var.gg/ko/blog/astro-7-rust-agent-native
🗓 Run: 2026-07-09 (packaged 2026-07-20) · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I actually built it on Astro 7."* This directory is that run — the
> fixtures, the environment, and the deterministic outputs — so you don't have to take the
> claim on faith. `git clone` and `./run.sh` reproduces it against `astro@7.0.6`.

> **Backfill note.** The post shipped on 2026-07-09; this run directory was authored on
> 2026-07-20. The original ad-hoc harness was not preserved, but every fixture and command
> was recorded verbatim in the source workspace, so the harness here is a faithful
> reconstruction — and it was **freshly executed** against `astro@7.0.6` on 2026-07-20, not
> paper-backfilled. `probe-result.json` is that real execution's output.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a check in `results.json` / `probe-result.json`.
"Old behavior" contrasts are *cited, not measured* — Astro 6 was never installed here.

### Firsthand (measured on astro@7.0.6, Node v24.15.0, Windows 11)

| Claim in the post | Evidence | Result |
|---|---|---|
| The Rust compiler **collapses insignificant JSX whitespace** — a newline between two `<span>`s yields no visible space | `probe-result.json` → `exp_A1_whitespace_collapse` (`fixtures/index.astro`) | `<p><span>Hello</span><span>World</span></p>` → **PASS** |
| An **unterminated `<p>` is a hard compiler error** (build fails, exit 1) — not silently auto-closed | `probe-result.json` → `exp_A2_unterminated_tag` (`fixtures/broken.astro`) | exit **1**, `CompilerError: Expected corresponding JSX closing tag for 'p'` |
| The failure routes through **Rolldown** (confirms the Vite 8 backend) | `probe-result.json` → `exp_A2…via_rolldown` | **true** |
| **Agent-native background dev server**: `--background` detaches + reports pid, `status` shows background, a `.astro/dev.json` lockfile tracks it, and a redundant `stop` exits 0 | `probe-result.json` → `exp_B_background_dev_server` | 4 / 4 **true** |
| **GFM markdown is built-in** — tables, strikethrough, footnotes, task lists render with **zero** remark/rehype plugins | `probe-result.json` → `exp_C_gfm_builtin_no_plugins` (`fixtures/post.md`) | 4 / 4 **true** |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Rust compiler alone ≈ 6% of the build-time win; the 15–61% headline is mostly Vite 8 / Rolldown | Astro 7 release notes |
| Astro 6's Go compiler preserved whitespace and auto-closed unterminated tags | Astro migration guide |

### Explicitly NOT measured

- **Build/install timing** is deliberately excluded — it is machine-dependent and
  non-deterministic. Only pass/fail behavior is evidence.
- **The Astro 6 side** of every before/after contrast is cited, never executed.

## Environment

Windows 11 · Node **v24.15.0** · npm 11.12.1 · **astro 7.0.6** (Rust compiler, Vite 8 / Rolldown).
Hardware is irrelevant — this is compiler-behavior and CLI-lifecycle verification, not a
timing benchmark.

## Reproduce

```bash
./run.sh    # scaffolds astro@7.0.6 in ./work, drops fixtures/, builds + drives dev server
```

Then compare the regenerated `probe-result.json` against the committed `results.json`.
`exp_A2` asserts a build **failure** (exit 1) is the correct outcome.

## Files

| File | What it is |
|---|---|
| `run.sh` | The harness. Scaffolds a minimal `astro@7.0.6` project, drops `fixtures/`, runs the four checks. |
| `fixtures/index.astro` | A1: two `<span>`s separated by a newline (whitespace-collapse fixture). |
| `fixtures/broken.astro` | A2: an unterminated `<p>` (hard-error fixture). |
| `fixtures/post.md` | C: GFM table / strikethrough / footnote / task list, no plugins. |
| `probe-result.json` | Raw harness output (the four checks). Deterministic. |
| `results.json` | Claim-facing summary: behaviors, cited-vs-measured split, limitations. |
| `manifest.json` | Environment, versions, `executed_by`, backfill note, retention policy. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
