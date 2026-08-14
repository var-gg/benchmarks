# nginx Ingress → Gateway API with ingress2gateway v1.1.0

📝 Post (KO): https://var.gg/ko/blog/gateway-api-ingress-migration
🗓 Run: 2026-06-18 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ⏪ backfilled (packaged later)
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran a real annotated nginx Ingress through ingress2gateway v1.1.0 and read
> what the Gateway API core absorbed, what it dropped, and where it lied."* This directory is that
> run — the exact input fixtures, the actual converted output, and the tool's own warnings — so you
> don't take the claim on faith. `git clone` and `./run.sh` reproduces it (it's a pure offline
> transform: no cluster, no network, no timing).

## Claim ↔ evidence

Every firsthand claim in the post maps to a line in the committed `expected/` output. `ingress2gateway
print --input-file` is deterministic, so the evidence is the output itself, not a summary of it.

### Absorbed into the Gateway API core (measured on ingress2gateway 1.1.0)

| Claim in the post | Evidence |
|---|---|
| Canary Ingress (`canary-weight: 10`) merges into ONE HTTPRoute with native weighted `backendRefs` | `expected/convert-standard.yaml` → `HTTPRoute vargg-canary-var-gg`, `backendRefs[].weight` |
| CORS annotations → `type: CORS` filter, in **Standard** output with **no** experimental flag | `expected/convert-standard.yaml` → `filters[].type: CORS` |
| `ssl-redirect` → separate `:80` HTTPRoute + `type: RequestRedirect` | `expected/convert-standard.yaml` → `:80` listener + `RequestRedirect` |
| `rewrite-target` → `type: URLRewrite` / `ReplaceFullPath` | `expected/*.yaml` → `filters[].type: URLRewrite` |
| TLS secret → Gateway listener `certificateRefs`, 443/80 split | `expected/convert-standard.yaml` → `listeners[].tls.certificateRefs: vargg-tls` |
| Regex path → `path.type: RegularExpression` | `expected/*.yaml` → `path.type: RegularExpression` |

### Dropped with a warning (the honest "what it does NOT give you")

| Claim | Evidence |
|---|---|
| `limit-rps` (rate limit) — **Unsupported** | `expected/convert-standard.warn.txt` → `WARN ... limit-rps` |
| `configuration-snippet` (raw nginx) — **Unsupported**, the escape hatch is gone | `expected/convert-standard.warn.txt` → `WARN ... configuration-snippet` |
| `force-ssl-redirect` — Unsupported annotation warning | `expected/convert-standard.warn.txt` → `WARN ... force-ssl-redirect` |
| `proxy-body-size` — dropped ("most implementations have reasonable defaults") | `expected/convert-standard.warn.txt` → `WARN STANDARD_EMITTER ... proxy-body-size` |
| URL normalization (RFC 3986 §6) unsupported | `expected/*.warn.txt` → `WARN ... URL normalization` |

### Converted but semantically broken (the sharpest firsthand finding)

| Claim | Evidence |
|---|---|
| `rewrite-target: /$2` → `replaceFullPath: /$2` **verbatim** — Gateway API does not interpret nginx `$2` backreferences, so the syntax converts but the meaning breaks, and v1.1.0 emits **no** capture-group warning (silent leak) | `expected/timeout-probe.out.yaml` → `replaceFullPath: /$2`; **absence** of any capture-group warning in `expected/timeout-probe.warn.txt` |
| `proxy-read-timeout: 30` (30s TCP idle) → `timeouts.request: 5m0s` (whole-request, ~10×) — a best-effort approximation that shifts meaning | `expected/timeout-probe.out.yaml` → `timeouts.request: 5m0s`; `expected/timeout-probe.warn.txt` → `WARN ... best-effort translation ... Please verify` |
| Path regex translated messily to `(?i)/api(/|$)(.*).*` with an INFO to fix it | `expected/timeout-probe.out.yaml` → `path.value: (?i)/api(/|$)(.*).*` |

### Freshness correction, on the record

The scout brief said "ingress2gateway 1.0 (2026-03)". The actual latest at run time was **v1.1.0**
(released 2026-05-12) — visible as the `ingress2gateway-1.1.0` generator annotation on every emitted
object in `expected/*.yaml`.

## Environment

Windows 11 · ingress2gateway **1.1.0** (Built Go 1.25.9) · provider `ingress-nginx`, emitter `standard`,
`--input-file` mode (no Kubernetes cluster). Hardware is irrelevant — this is a deterministic config
translation, not a timing benchmark.

## Reproduce

```bash
./run.sh          # go install ingress2gateway@v1.1.0 → convert fixtures/ → diff against expected/
```

An empty diff means it reproduced. If your ingress2gateway is a different version, the output may
differ — that is exactly why the subject version is pinned.

## Raw data

Nothing discarded. The full converted manifests and the tool's stderr warnings are the deterministic
evidence and are committed in full under `expected/`. See `checksums.txt` for integrity hashes.

## Files

| File | What it is |
|---|---|
| `fixtures/sample-ingress.yaml` | Input: a realistic annotated nginx Ingress (main + canary) |
| `fixtures/timeout-probe.yaml` | Input: a focused probe for the timeout + rewrite behaviors |
| `expected/convert-standard.yaml` | Actual converted Gateway API manifest (main fixture) |
| `expected/convert-standard.warn.txt` | Actual tool warnings for the main fixture |
| `expected/timeout-probe.out.yaml` | Actual converted output for the probe |
| `expected/timeout-probe.warn.txt` | Actual tool warnings for the probe |
| `results.json` | Claim-facing summary: absorbed / dropped / semantically-broken |
| `manifest.json` | Environment, versions, `executed_by`, `backfilled`, retention policy |
| `run.sh` | Reproduction: install pinned tool, convert fixtures, diff |
| `checksums.txt` | sha256 of the committed fixtures + evidence |
