# Python 3.15 UTF-8 default (PEP 686) — silent byte changes on Windows/CP949

📝 Post (KO): https://var.gg/ko/blog/python-315-utf8-default
📝 Post (EN): https://var.gg/en/blog/python-315-utf8-default
🗓 Run: 2026-06-22 · 🔁 Re-verified: 2026-08-12 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I ran both interpreters on a Korean (CP949) Windows box and watched the
> same one-line program write different bytes — with no error."* This directory is that run:
> the harness, the pinned builds, and the raw report, so you don't have to take the claim on
> faith. `git clone` and `./run.sh` reproduces it on a CP949 host.

> ⚠️ **Backfill, honestly labeled.** The post's *original* harness scripts were not preserved
> (only the recorded experiment log survived). `probe.py` / `run.sh` here are a **faithful
> reconstruction**, and were **freshly re-executed on 2026-08-12** against the same pinned
> builds on the same class of host. The committed `probe-result.json` is that fresh re-run and
> reproduces every recorded observation. `manifest.json.backfilled = true`.

## Why hardware is omitted

This is a **default text-encoding contract** check, not a timing benchmark. The result depends
only on the CPython build and the host **ANSI codepage** — not CPU/GPU/RAM. On a UTF-8 host
locale the contrast disappears (both builds already default to UTF-8). That dependence *is* the
finding, so the environment records the codepage (949) and omits hardware.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json` / `probe-result.json`,
measured on **CPython 3.14.6 (baseline) vs 3.15.0b2 (subject)**, host ANSI codepage **949**.

| Claim in the post | Evidence | Value |
|---|---|---|
| The default text encoding **flips** cp949 → utf-8 (open/stdio), while **filesystem encoding was already utf-8** on both | `probe-result.json` → `interpreters.*` | 3.14.6: `cp949`/`cp949`/fs `utf-8` · 3.15.0b2: `utf-8`/`utf-8`/fs `utf-8` |
| The **same one-line program writes different on-disk bytes**, no error either way | `results.json` → `exp2_producer_side_byte_shift` | **24 bytes (CP949)** vs **32 bytes (UTF-8)** |
| Bytes valid under **both** encodings decode with **no error to different strings** (silent corruption) | `results.json` → `exp9_silent_divergence` | `c2 af` → **짱** vs **¯** · `eb ac b8 ec 84 9c` → **臾몄꽌** vs **문서** |
| `subprocess(text=True)` capturing CP949 output: on 3.15 the reader **thread** dies, `subprocess.run` returns **`stdout=None`, rc 0** — output silently lost | `results.json` → `exp7_subprocess_text_reader_thread_crash` | 3.14.6: `'한글상태'` · 3.15.0b2: `None` + `UnicodeDecodeError: ... byte 0xc7 ...` |
| The default changed but the **opt-out is intact** (`PYTHONUTF8` / `-X utf8`) | `results.json` → `exp8_opt_out_toggles` | 3.15 + `PYTHONUTF8=0` → cp949 · 3.14 + `PYTHONUTF8=1` → utf-8 |

### Cited, not measured (flagged the same way in the post)

| Claim | Source |
|---|---|
| PEP 686 makes UTF-8 mode the default in 3.15 | [PEP 686](https://peps.python.org/pep-0686/) |
| Windows filesystem encoding has been UTF-8 since 3.6 | [PEP 529](https://peps.python.org/pep-0529/) |
| Final 3.15.0 behavior (measured on 3.15.0b2 beta); full installer / Store builds | expected identical for PEP 686, not separately measured |

### Honest limits

Korean cross-decode is *usually* a **loud** `UnicodeDecodeError` — CP949 and UTF-8 hangul byte
patterns are mostly mutually invalid. The genuinely **silent** in-Python cases are the specific
dual-valid byte ranges (exp9). The post separates "loud failure" from "silent corruption"
rather than claiming everything is silent. Measured on the embeddable amd64 build and on
3.15.0b2 (beta); see `manifest.json`.

## Environment

Windows 11 (10.0.26200) · ANSI codepage **949 (CP949, Korean)** · driver Python 3.11.9.
Subject **CPython 3.15.0b2** embeddable-amd64 · baseline **CPython 3.14.6** embeddable-amd64
(both pinned by python.org URL and downloaded by `run.sh`).

## Reproduce

```bash
./run.sh    # downloads the two pinned embeddable builds → runs probe.py under each
```

Then compare the regenerated `probe-result.json` against the committed `results.json`.
**Must be a non-UTF-8 ANSI codepage host** (the essay used CP949) or the flip is a no-op.

## Raw data

None discarded. This run has no large artifacts. `run.sh` downloads the embeddable zips into a
temp dir and deletes them on exit; they are pinned by URL, not committed. The deterministic
evidence — `probe-result.json` — is committed. See `checksums.txt`.

## Files

| File | What it is |
|---|---|
| `probe.py` | Driver. Runs `_probe_inner.py` under both interpreters, merges reports + toggle matrix. |
| `_probe_inner.py` | The per-interpreter harness: reports the encoding contract and runs EXP2 / EXP7 / EXP9 deterministically. |
| `probe-result.json` | Raw merged probe output (contract + experiments + toggles). Deterministic per (build, codepage). |
| `results.json` | Claim-facing summary: contract, behaviors, honest limits, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, backfill + re-verify notes, retention policy. |
| `run.sh` | Reproduction: fetch pinned builds → run the probe. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
