# Angular 22 Signal Forms vs Reactive Forms — behavior & type-safety

📝 Post (KO): https://var.gg/ko/blog/angular-22-signal-forms
🗓 Run: 2026-08-07 (re-executed) · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran four experiments on Angular 22.0.2 Signal Forms."* This directory is
> that harness — reconstructed and **re-executed fresh** on the versions the post pins — so the
> claims don't rest on faith. `git clone` and `./run.sh` reproduces every value below.
>
> **Backfilled.** The original harness was deleted after the post was drafted (2026-06-25) per the
> firsthand-cleanup policy. This directory was rebuilt from the post's `firsthand-benchmark.md`
> and re-run on 2026-08-07 against `@angular/* 22.0.2`. Results are newly measured — see
> `manifest.json.backfill_note`.

## Claim ↔ evidence

All four are deterministic for the pinned versions (`@angular/* 22.0.2`, TypeScript 5.9.3,
Vitest 3.2.6, Node 24.15.0). No timing is claimed.

| Claim in the post | Evidence | Value |
|---|---|---|
| **A.** Typo + wrong-type write survive to runtime under stringly-typed Reactive access; both are compile errors in Signal Forms | `results.json` → `experiment_A_type_safety`; `exp-a-types/*.ts` | reactive **0** tsc errors · signal **2** (`TS2551` typo, `TS2345` type) |
| **B.** A consumer reading only `email` does **not** re-run when unrelated `age` changes | `results.json` → `experiment_B_reactivity_granularity`; `exp-b-granularity.test.ts` | signal **0** extra runs on 5 unrelated changes · **1** on its own change |
| **B.** Reactive `group.valueChanges` runs the consumer for **any** child change | same | reactive map ran **5** times for 5 unrelated changes |
| **C.** Touching the deepest leaf buckets up to group and root; root `touched` computed recalcs exactly once | `results.json` → `experiment_C_state_aggregation`; `exp-c-aggregation.test.ts` | leaf→group→root all `true` · **1** recalc |
| **C.** Root validity aggregates from descendants and recovers with no manual revalidate | same | root `valid` `false` (required empty) → `true` after filling leaf |
| **D.** Changing the value mid-flight aborts the stale async validation; latest wins | `results.json` → `experiment_D_async_race`; `exp-d-async-race.test.ts` | starts `[taken, free]` · aborted `[taken]` · completed `[free]` |

## Honest caveats (the post makes these too)

- **A** — Angular 14+ *typed* forms DO catch a wrong-type write on a **statically-known literal
  path** (`group.get('user.email').setValue(42)` is a compile error). The 0-error result is
  specifically the stringly-typed surface: an **unknown key** (`group.get('emial')`, always
  `AbstractControl | null` — a typo never type-checks) and a **dynamic/runtime path**
  (`group.get(fieldName)`, `AbstractControl<any> | null`). Both are idiomatic for dynamic and
  deeply-nested forms. Signal Forms have no stringly-typed escape hatch. See `results.json`
  `experiment_A_type_safety.caveat`.
- **D** — this verifies abort *semantics*, not that Signal Forms is uniquely safe. Reactive
  Forms' `AsyncValidatorFn` also drops a superseded validation (RxJS unsubscribe); the difference
  is mechanism (resource invalidation + `AbortSignal`). Whether real work stops depends on the
  loader honoring `AbortSignal` — cooperative cancellation.

## Not measured (cited in the post, not asserted here)

- Async validation only fires after sync validators pass — documented behavior, not separately
  asserted in this harness.
- Re-run counts are signal/subscription re-executions in a zoneless jsdom TestBed, **not** real
  component DOM change-detection cycles. The post argues granularity, never absolute ms.

## Environment

Windows 11 · Node 24.15.0 · TypeScript 5.9.3 · Vitest 3.2.6 (jsdom, zoneless Angular TestBed) ·
`@angular/core` & `@angular/forms` **22.0.2**. Hardware is irrelevant — this is a logic/type
benchmark, not a timing one.

## Reproduce

```bash
./run.sh          # npm install (pinned) → tsc on exp A → vitest B/C/D → probe-result.json
```

Then diff `probe-result.json` against the committed `results.json`.

## Files

| File | What it is |
|---|---|
| `exp-a-types/reactive.ts`, `exp-a-types/signal.ts` | Type-safety experiment. Type-checked by `tsc`, never executed. |
| `exp-b-granularity.test.ts` | Reactivity-granularity experiment (Vitest). |
| `exp-c-aggregation.test.ts` | Nested touched/validity aggregation experiment (Vitest). |
| `exp-d-async-race.test.ts` | Async-validation abort experiment (Vitest). |
| `_collect.ts` | Tiny helper that records results into `probe-result.json`. |
| `probe-result.json` | Deterministic run output. Compare against `results.json`. |
| `results.json` | Claim-facing summary + caveats + limitations. |
| `manifest.json` | Versions, `executed_by`, `backfilled` provenance. |
| `run.sh`, `package.json`, `tsconfig.json`, `vitest.config.ts`, `test-setup.ts` | Reproduction. |
| `checksums.txt` | sha256 of committed harness + evidence. |
