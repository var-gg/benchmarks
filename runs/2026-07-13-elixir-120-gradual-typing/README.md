# Elixir 1.20's gradual type checker — what it catches from inference alone, and when it fails a build

📝 Post: [KO](https://var.gg/ko/blog/elixir-120-gradual-typing) *(Korean-only; no English post)*
🗓 Run: 2026-07-13 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This run happened on 2026-07-13. Its raw artifacts — the per-module
> compile logs and the `.beam` output — were discarded (finite disk), so `run.sh` +
> `fixture/` (the 7 `.ex` demo modules and a minimal mix project) are committed to reconstruct
> the **method**. Unlike this repo's advisory-database runs, the compiler's type output is
> **deterministic** for a pinned Elixir: re-run on Elixir 1.20.x and the same warnings appear
> **verbatim** — nothing drifts. So `results.json` is a qualitative **capability matrix +
> exit codes**, not a point-in-time snapshot. No artifact hashes were captured at the time, so
> none are invented.

## Claim ↔ evidence

Every warning below comes from **inference alone** — there is **no `@spec` and no type
annotation** anywhere in the fixture.

| Claim in the post | Evidence | Value |
|---|---|---|
| The checker flags a **disjoint-type** misuse (an `integer\|binary` value handed to `Map.fetch!`) | `results.json` → `support_matrix[disjoint_map_fetch]` | WARN: given `dynamic(binary() or integer())`, expected `map()` |
| It flags a **provably-missing map key** | `results.json` → `support_matrix[missing_map_key]` | WARN: given `empty_map()`, expected `%{..., name: term()}` |
| It **avoids a false positive** when narrowing is internally consistent | `results.json` → `support_matrix[narrowing_ok]` | `data.a + data.b` → **no warning** |
| It catches **narrowing misuse** — a map narrowed, then used as a number | `results.json` → `support_matrix[narrowing_misuse]` | WARN: `data` narrowed to `%{..., a: float() or integer()}`, then used as a number |
| It flags **dead / unreachable clauses** | `results.json` → `support_matrix[dead_clause]` | **2 warnings**: `is_integer/1` always matches + `is_binary/1` never matches (under an `is_integer` guard) |
| A **fully dynamic** parameter yields **no warning** (gradual escape) | `results.json` → `support_matrix[gradual_escape]` | `Map.fetch!(x, :any_key)` on unconstrained `x` → **no warning** (honest limit) |
| These are **warnings, not errors** — only `mix compile --warnings-as-errors` fails a build | `results.json` → `exit_code_semantics` | `elixirc --warnings-as-errors` **exit 0** · `mix compile` **exit 0** · `mix compile --warnings-as-errors` **exit 1** |

### The exit-code nuance (do not skip this)

The checker catching a bug does **not**, on its own, stop a build or a deploy. Three commands,
three different outcomes — only the last one gates CI:

| Command | Exit | Why |
|---|---|---|
| `elixirc --warnings-as-errors -o out src/unused.ex` | **0** | `--warnings-as-errors` is a *mix* concept; `elixirc` ignores it — even for a plain unused-variable warning. |
| `mix compile` | **0** | The type warning is printed, but a plain compile does not fail the build. |
| `mix compile --warnings-as-errors` | **1** | The only one of the three that makes type warnings bite. This is what a CI job must run. |

### Honestly NOT verified / honest limits

- **Warnings ≠ enforcement.** By default the findings are warnings; they inform, they do not
  gate, unless you opt in with `--warnings-as-errors`. See `results.json` → `caveats`.
- **Absence of a warning is not proof of correctness.** The `gradual_escape` case stays quiet
  only because a fully `dynamic()` parameter gave the checker nothing to narrow — not because the
  code is verified safe.
- **Inference only.** No `@spec`/annotations were used, so the stronger-signal annotated path was
  not exercised. Adding `@spec` would give the checker more to work with.
- **Large-codebase compile-time cost was not measured** — these are tiny single-module fixtures.
- **No cross-version sweep** — only Elixir 1.20.2 was run; earlier versions produce a different
  (generally smaller) set of these warnings. See `results.json` → `explicitly_not_verified`.

## The fixture

`fixture/src/*.ex` are seven standalone modules. Six map 1:1 to the rows above (compiled with
`elixirc`); `unused.ex` is the plain unused-variable control for the `elixirc --warnings-as-errors`
exit-code demo. `fixture/typedemo/` is a **minimal mix project** (no deps, offline) whose
`lib/typedemo.ex` reproduces the missing-key warning — it exists only so `run.sh` can show the
`mix compile` vs `mix compile --warnings-as-errors` exit codes that a bare `elixirc` cannot. This
is the reproducible input; on Elixir 1.20.x it does not drift.

Compiled output (`.beam`, `_build/`) is **never committed** — `run.sh` compiles into a temp dir
and cleans up on exit.

## Reproduce

```bash
./run.sh          # needs Elixir 1.20.x (elixir + elixirc + mix, all ship together)
```

`run.sh` pins/guards the Elixir version (warns loudly if you are not on 1.20.x), compiles each
`fixture/src/*.ex` capturing the compiler's type output **verbatim**, classifies each as
**warned** or **quiet** against the recorded matrix, and then demonstrates the three exit-code
behaviours above. On Elixir 1.20.x you should see **4 warned / 2 quiet** and exit codes **0 / 0 / 1**.

## Environment

Windows 11 (win32) · Elixir **1.20.2** (compiled with Erlang/OTP 27) · runtime Erlang/OTP **29**
[erts-17.0.3, jit] · installed via **scoop**. Type checking is compile-time and OS-independent —
the warnings reproduce on any platform running Elixir 1.20.x. The **Elixir version is the
load-bearing variable**, not the OS.
