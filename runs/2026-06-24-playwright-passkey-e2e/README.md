# Playwright 1.61 virtual passkey — chromium / firefox / webkit

📝 Post (KO): https://var.gg/ko/blog/playwright-passkey-e2e
🗓 Run: 2026-06-24 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ♻️ **backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I drove the passkey ceremony headlessly on all three engines with
> Playwright 1.61's `context.credentials`."* This directory is that run — the harness, the
> environment, and the measured per-engine matrix — so you don't have to take the claim on
> faith. `git clone` and `./run.sh` reproduces the capability outcomes.

## Backfill honesty

This run executed on **2026-06-24**. Its harness lived in a gitignored `tmp/` dir and was
deleted after publish per the finite-disk firsthand policy. The harness committed here
(`server.mjs` + `public/index.html` + `playwright.config.ts` + `tests/passkey.spec.ts`) is
**reconstructed** from the run's recorded methodology and the API ground truth read from the
installed `@playwright/test@1.61.1` `types.d.ts`. `results.json` holds the qualitative matrix
**measured on 2026-06-24**; re-running reproduces the same per-engine pass/fail outcomes.
Wall time (the original run reported 12/12 in ~6.4s) is machine-dependent and is recorded as
context only, never as an evidence claim.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a row in `results.json`.

### Firsthand (measured on @playwright/test 1.61.1, all three engines)

| Claim in the post | Evidence | Value |
|---|---|---|
| A seeded discoverable credential resolves a **usernameless** `get()` (rawId + userHandle match, signature present) | `results.json` → `behaviors_verified[seed_usernameless_get]` | pass ×3 engines |
| **register → export keys via `get()` → re-seed a fresh context → login** works | `results.json` → `behaviors_verified[register_export_reseed_login]` | pass ×3 engines |
| No matching credential → page `get()` rejects **`NotAllowedError`** | `results.json` → `behaviors_verified[no_credential_rejects]` | pass ×3 engines |
| Omitting **`install()`** is not a clean no-op — it falls through to each engine's native behavior (chromium `NotSupportedError`, firefox **indefinite hang**, webkit `TypeError`) | `results.json` → `install_omitted_native_behavior` | chromium / firefox / webkit differ |

The headline finding: 1.61 promotes the virtual authenticator to a **first-class
cross-engine** `context.credentials` API. The pre-1.61 path (CDP `addVirtualAuthenticator`)
was effectively Chromium-only — the post contrasts them, and this run confirms the same spec
passes on firefox and webkit too.

### Cited, not measured (flagged in the post too)

| Claim | Source |
|---|---|
| Platform-authenticator UX (Windows Hello / iCloud Keychain) — UV gesture, attestation, transport — is **not** modeled by the virtual authenticator | Playwright docs + the API's intentional-minimalism note (P-256 fixed, always discoverable) |

This is the honest limit: the harness verifies the **ceremony wiring**, not the real OS
passkey UX.

## Environment

Windows 11 · Node v24.15.0 · `@playwright/test` **1.61.1**, headless, 3 engine projects.
Hardware is irrelevant — this is a capability/behavior matrix, not a timing benchmark.

## Reproduce

```bash
./run.sh          # npm install (pins 1.61.1) → playwright install → passkey spec ×3 engines
```

Then compare the per-engine pass/fail against `results.json`.

## Files

| File | What it is |
|---|---|
| `tests/passkey.spec.ts` | The harness. 4 scenarios driving `context.credentials` across engines. |
| `public/index.html` | The page with `doRegister` / `doAuthenticate` WebAuthn helpers the spec calls. |
| `server.mjs` | Static server (localhost = secure context, so no HTTPS needed for WebAuthn). |
| `playwright.config.ts` | 3 engine projects + `webServer` wiring. |
| `package.json` | Pins `@playwright/test@1.61.1`. |
| `results.json` | Claim-facing matrix: behaviors, per-engine outcomes, `install()`-omitted behavior, API ground truth. |
| `manifest.json` | Environment, versions, `executed_by`, `backfilled`, retention policy. |
| `run.sh` | Reproduction. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
