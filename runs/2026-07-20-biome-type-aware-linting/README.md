# Biome 2.5.4 type-aware linting — how far does it get with NO typescript?

📝 Post (KO): https://var.gg/ko/blog/biome-type-aware-linting
🗓 Run: 2026-07-20 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran Biome's type-aware rules on a project with typescript uninstalled,
> and they still fired."* This directory is that run — the fixtures, the config, the harness,
> and the four pass/fail diagnostics — so you don't have to take the claim on faith.
> `git clone` and `./run.sh` reproduces it.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a boolean in `probe-result.json`. The decisive
precondition is that **`typescript` is not installed** — the type-aware rules have to infer
types themselves. Claims about speed and about typescript-eslint parity are sourced from
Biome's own docs and are listed separately as *cited, not measured*.

### Firsthand (measured on @biomejs/biome 2.5.4, typescript ABSENT)

| Claim in the post | Evidence | Value |
|---|---|---|
| A type-aware rule (`noFloatingPromises`) tells a discarded Promise from an awaited one **with no tsc installed** | `probe-result.json` → `exp1_floating_flagged_no_tsc` | `true` (bare `save()` flagged, `await save()` not) |
| The check works **across files** — a Promise return type known only via import is still resolved | `probe-result.json` → `exp2_cross_file_flagged` | `true` (`mod-b.ts` bare call flagged) |
| Biome's inference is **not** a full type system — it misses a hand-rolled thenable that typescript-eslint catches | `probe-result.json` → `exp3_boundary_flagged_lines` | flagged `{3, 11}`; line 8 (custom thenable) **not** flagged |
| A custom rule authored as a single **`.grit` query** (no compiled code) fires with category `plugin` | `probe-result.json` → `exp4_gritql_plugin_flagged` | `true` |

### Cited, not measured (flagged the same way in the post)

| Claim | Source |
|---|---|
| Type-aware rules cover ~75% of typescript-eslint's typed rule set | [Biome v2 announcement](https://biomejs.dev/blog/biome-v2/) |
| ~10-20x faster than ESLint | Biome docs (machine-dependent, not run here) |
| `noFloatingPromises` is still nursery / opt-in as of 2.5.4 | [Biome 2.5 notes](https://biomejs.dev/blog/biome-v2-5/) |

### Explicitly NOT verified

Speed was **not** measured — timing is machine-dependent and out of scope for a pass/fail
behavior check. The typescript-eslint comparison is by cited coverage framing plus one
firsthand data point (the thenable miss), not a side-by-side run of both linters. Stated plainly.

## Environment

Windows 11 · Node **v24.15.0** · npm · `@biomejs/biome` **2.5.4** · **typescript not installed** ·
no Docker. Hardware is irrelevant here — this is diagnostic-presence detection, not a timing benchmark.

## Reproduce

```bash
./run.sh          # node/npm check → probe.sh → installs biome (no tsc) → 4 experiments
```

`probe.sh` builds a throwaway `work/` (installs `@biomejs/biome` only, ~2 packages), copies the
fixtures + `biome.json` + the `.grit` plugin, runs the four experiments, and writes
`probe-result.json`. Compare it against the committed `results.json`.

## Raw data

None discarded. The only large thing this run creates is `work/node_modules` (~2 packages),
which `run.sh` regenerates and which is `.gitignored` — not committed. The deterministic
evidence — `probe-result.json` — is committed. `checksums.txt` holds integrity hashes of the
committed harness + evidence.

## Files

| File | What it is |
|---|---|
| `probe.sh` | The harness. Installs Biome (no tsc), drops fixtures, runs 4 experiments, writes `probe-result.json`. |
| `run.sh` | Third-party entrypoint — node/npm sanity check, then `probe.sh`. |
| `biome.json` | Config under test: `noFloatingPromises: error`, the `.grit` plugin wired in, `recommended: false`. |
| `fixtures/*.ts` | The five fixtures: floating promise, cross-file pair, boundary cases, Object.assign. |
| `plugins/no-object-assign.grit` | The custom GritQL lint rule (no compiled code). |
| `probe-result.json` | Raw probe output — the four booleans + boundary lines. Deterministic. |
| `results.json` | Claim-facing summary: preconditions, behaviors, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, retention policy. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
