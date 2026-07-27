# Python type checkers: same code, four verdicts (mypy / pyright / pyrefly / ty)

📝 Post: [KO](https://var.gg/ko/blog/python-type-checkers-pyrefly-ty)
🗓 Run: 2026-06-30 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This run happened on 2026-06-30, before this repo existed; the tool
> binaries and the synthetic bench codebase were discarded (finite disk). `fixture/*`,
> `gen_codebase.py`, `bench_run.py`, and `run.sh` are **reconstructed** from the recorded
> methodology so you can reproduce the **method**. The judgments + seconds in `results.json`
> are the 2026-06-30 snapshot on one Windows PC. **ty and pyrefly ship monthly**, so your
> versions and numbers will drift — the *structural* findings are the durable claims.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| An **unannotated parameter** makes all four skip a body bug; only mypy warns it skipped | `results.json` → `findings[untyped_param_blindspot]` + `fixture/02_untyped_def.py` | 4/4 report 0; mypy alone prints the `--check-untyped-defs` note. Annotate the param → 4/4 catch it |
| **mypy widens** `reveal_type`, the others keep `Literal` | `results.json` → `findings[reveal_widening]` + `fixture/04_reveal.py` | mypy `tuple[int, str]` vs `tuple[Literal[1], Literal['two']]` |
| pyrefly/ty are **pedantic** about `reveal_type` without import | `results.json` → `findings[rust_pedantry]` | diagnostic from pyrefly/ty; mypy/pyright silent |
| Rust checkers are **~15-30× faster cold**; mypy **warm** is Rust-class | `results.json` → `experiment_b_speed` | ty 0.19s / pyrefly 0.24s / mypy cold 3.24s → warm 0.27s / pyright 5.9s |
| pyright CLI has **no incremental cache** | `results.json` → `experiment_b_speed.rows[pyright]` | cold 5.92s ≈ warm 5.90s |
| pyrefly with **no config** reports 0 errors + exit 0 without checking | `results.json` → `findings[pyrefly_config_footgun]` | "0 errors" + "Run pyrefly init" hint; config required to actually check |
| pyright defaults **conservative** on PEP 695 without a pinned version | `results.json` → `findings[pyright_conservative_default]` + `fixture/05_match_exhaustive.py` | `type X = ...` → "requires 3.12+" until `pythonVersion` is set |

### Honestly NOT measured

- **Typing-spec conformance ordering** (pyright/Zuban > pyrefly >90% > mypy > ty) is **cited** from public
  conformance data, not measured here.
- The speed bench is a **uniform, shallow-typed synthetic** codebase. Heavy generics/overloads/metaclasses
  load tools differently. And **ty is beta** — part of its speed is rules not yet implemented (no strict mode).
  Discount the absolute lead accordingly. See `results.json` → `explicitly_not_verified`.

## Reproduce

```bash
./run.sh     # needs mypy, pyright (npx), pyrefly, ty on PATH; runs both experiments
```

Expect the verdict pattern above and the cold/warm speed shape. Exact diagnostics and seconds
will differ from the 2026-06-30 snapshot as the tools move — that is expected and honest.

## Environment

Windows 11 · CPython **3.13.13** (uv-managed) · uv 0.11.14 · Node v24.15.0 ·
mypy **2.1.0** / pyright **1.1.411** / pyrefly **1.1.1** / ty **0.0.55** (beta, build 2026-06-26).
