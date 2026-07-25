# OSV-Scanner reachability (Go call analysis) — v2.4.0 / Go 1.25.5

📝 Post (KO): https://var.gg/ko/blog/osv-scanner-reachability
🗓 Run: 2026-07-23 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"the same vulnerable dependency produces a High alert in one module and
> zero in another — because reachability checks whether the vulnerable function is actually
> called."* This directory is that run: two Go modules with the **identical** vulnerable
> dependency and advisory, differing only in which function they call. `git clone` and
> `./run.sh` reproduces the 2×2 alert matrix so you don't have to take it on faith.

## The fixture

Both modules require the **identical** `golang.org/x/text@v0.3.7`, flagged by
**GO-2022-1059 / GHSA-69ch-w2m2-3vjp / CVE-2022-32149** (CVSS 7.5 High) — a DoS in
`language.ParseAcceptLanguage`, fixed in v0.3.8. They differ by one function call:

- `reachable/main.go` — **calls** `language.ParseAcceptLanguage(...)` (the vulnerable symbol).
- `unreachable/main.go` — imports the same package+version but calls only `language.Make(...)`.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json` / `probe-result.json`.
Claims sourced from external references are listed separately as *cited, not measured* — the
post marks them the same way.

### Firsthand (measured on osv-scanner 2.4.0 + Go 1.25.5)

| Claim in the post | Evidence | Value |
|---|---|---|
| Naive lockfile matching (`--no-call-analysis=go`) reports the **same High vuln for BOTH modules** | `results.json` → `alert_matrix` · `probe-result.json` | reachable 1 High / unreachable 1 High |
| The unreachable module's naive alert is a **reproduced false positive** | `results.json` → `alert_matrix.unreachable_imports_only.naive` | "1 High — false positive" |
| Reachability (`--call-analysis=go`, default for Go) keeps the alert only where the symbol is **actually called** | `probe-result.json` → `reachable_variant.call_analysis_default_reported` | reachable 1 shown |
| Reachability **filters the alert to zero** where the symbol is imported but never called | `probe-result.json` → `unreachable_variant.call_analysis_default_reported` | unreachable 0 |
| The `experimental_analysis.GO-2022-1059.called` flag is **true / false** for the two modules | `probe-result.json` → `*_variant.experimental_analysis_called` | true vs false |
| Suppressed findings are **demoted, not deleted** — `--all-vulns` re-surfaces them under "Uncalled vulnerabilities" | `results.json` → `demotion_not_deletion` | verified |
| Reachability needs **the Go toolchain + a buildable module** ("Will run build scripts"); naive works from `go.mod` alone | `results.json` → `tradeoff_observed` · `manifest.json` → `environment` | verified |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Go reachability is powered by govulncheck's call-graph analysis | OSV-Scanner docs / govulncheck |
| GO-2022-1059 = CVE-2022-32149 (DoS via crafted Accept-Language, `x/text` < 0.3.8) | [osv.dev](https://osv.dev/vulnerability/GO-2022-1059) |

### Explicitly NOT verified

- **Dynamic dispatch / reflection / cgo** can evade a static call graph → reachability can
  produce *false negatives*. Cited from govulncheck docs, **not** exercised here.
- **Whole-package advisories** (no affected symbol) can't be filtered per-function and are
  always reported. Cited, not exercised.
- **Language coverage**: osv-scanner reachability supports **Go and Rust only**; this run
  measured Go only.
- **Speed**: not measured. This is a deterministic alert/called verdict, not a timing benchmark.

## Environment

Windows 11 x64 · native (no Docker) · osv-scanner **2.4.0** (GitHub release binary) · Go
**1.25.5**. Hardware is irrelevant — this observes whether an alert is present, not how fast.

## Reproduce

```bash
./run.sh          # checks go + osv-scanner, then runs probe.sh over both modules
```

`probe.sh` scans `reachable/` and `unreachable/` three ways (naive, reachability, and the
JSON `called` flag) and writes `probe-result.gen.json`. Compare it against the committed
`probe-result.json`. Fixed sources + pinned dep + pinned advisory make the verdict deterministic.

## Raw data

None discarded. This run has no large artifacts. The deterministic evidence —
`probe-result.json` (the 2×2 alert matrix + `called` boolean) plus the two fixture modules —
is committed. See `checksums.txt` for integrity hashes.

## Files

| File | What it is |
|---|---|
| `reachable/` | Go module that **calls** `ParseAcceptLanguage` (vulnerable symbol reachable from main). |
| `unreachable/` | Go module with the same `x/text@v0.3.7` but calling only `language.Make`. |
| `probe.sh` | The harness. Scans both modules naive vs reachability and extracts the `called` flag. |
| `probe-result.json` | Raw probe output: the 2×2 alert matrix + `experimental_analysis.called`. Deterministic. |
| `results.json` | Claim-facing summary: alert matrix, demotion-not-deletion, tradeoff, cited-vs-measured split. |
| `manifest.json` | Environment, versions, fixture design, `executed_by`, retention policy. |
| `run.sh` | Reproduction entry point (tool-version checks → `probe.sh`). |
| `checksums.txt` | sha256 of the committed harness + evidence. |
