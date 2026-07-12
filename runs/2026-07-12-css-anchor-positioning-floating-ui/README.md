# CSS anchor positioning vs Floating UI — Chromium 147

📝 Post (KO): https://var.gg/ko/blog/css-anchor-positioning-floating-ui
🗓 Run: 2026-07-12 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran it on headless Chromium 147."* This directory is that run — the
> harness, the environment, and the raw support matrix — so you don't have to take the claim
> on faith. `git clone` and `./run.sh` reproduces it.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json` / `probe-result.json`.
Claims sourced from external references are listed separately as *cited, not measured* — the
post marks them the same way.

### Firsthand (measured on Chromium 147.0.7727.15)

| Claim in the post | Evidence | Value |
|---|---|---|
| `anchor-name`, `position-anchor`, `anchor()`, `position-area`, `anchor-size()`, `@position-try`, `position-visibility` are **all supported** | `probe-result.json` → `chromium.supports` | 7 / 7 `true` |
| Tooltip tethers below a button and centers, **zero JS** | `results.json` → `behaviors_verified[center_tether]` + `demo.html` scenario A | verified |
| `@position-try` **auto-flips** the card left when the right edge overflows | `results.json` → `behaviors_verified[auto_flip]` + `demo.html` scenario B | verified |
| Anchored element **escapes `overflow:hidden`** as a DOM sibling (portal no longer needed) | `results.json` → `behaviors_verified[overflow_escape]` + `demo.html` scenario C | verified |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Global support ~82% | [caniuse](https://caniuse.com/css-anchor-positioning) |
| Chrome 125+ / Firefox 147+ / Safari 26+ ship it by default | caniuse / MDN |
| MDN marks it "Limited availability" — not Baseline | [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning/Using) |

### Explicitly NOT verified

Firefox and WebKit did **not** run in this harness (local Playwright browser-revision
mismatch — see `manifest.json.cross_browser`). The post's cross-browser statements are
cited, never presented as firsthand. This is a limitation, stated plainly.

## Environment

Windows 11 · Playwright 1.59.0 (Python 3.11.9), headless · Chromium **147.0.7727.15**.
Hardware is irrelevant here — this is feature-support detection, not a timing benchmark.

## Reproduce

```bash
./run.sh          # venv → pinned Playwright → install Chromium → probe.py
```

Then compare `probe-result.json` (regenerated) against the committed `results.json`.

## Raw data

None discarded. This run has no large artifacts. `render-chromium.png` is an illustrative
screenshot (regenerable by `run.sh`); it is intentionally **not committed** because
screenshots are non-deterministic and would not hash-match on re-run. The deterministic
evidence — `probe-result.json` — is committed. See `checksums.txt` for integrity hashes of
the committed harness + evidence.

## Files

| File | What it is |
|---|---|
| `probe.py` | The harness. Launches Chromium via Playwright, runs `CSS.supports()`, screenshots. |
| `demo.html` | The three-scenario demo page the probe renders. |
| `probe-result.json` | Raw probe output (support matrix + browser versions). Deterministic. |
| `results.json` | Claim-facing summary: support matrix, behaviors, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, retention policy. |
| `run.sh` / `requirements.txt` | Reproduction. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
