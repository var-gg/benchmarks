# cosign v3.1.1 — Sigstore bundle shape: default (public log) vs offline

📝 Post (KO): https://var.gg/ko/blog/cosign-v3-sigstore-bundle
🗓 Run: 2026-06-17 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · ♻️ **backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I signed a blob with cosign v3.1.1 and inspected the bundle — a key-based
> `sign-blob` still uploads to the public transparency log by default."* This directory is that
> run: the command sequence, the environment, and the surviving redacted bundle. `git clone` and
> `./run.sh` reproduces the **method** (it downloads cosign v3.1.1 fresh).

## Backfilled — read this first

The original 2026-06-17 session used a ~198 MB cosign binary and a local `registry:2` container
that were deleted afterward per a finite-disk cleanup policy. `run.sh` is **reconstructed** from the
recorded command sequence and downloads cosign v3.1.1 again, so you reproduce the method end-to-end.
`bundle-default-redacted.json` is the one structural artifact retained from the run, with all
cryptographic values redacted. No hashes of the original binary were captured at run time — stated
plainly rather than fabricated. See `manifest.json.backfill_note`.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json`. External facts (spec
versions, latest release) are listed separately as *cited, not measured* — the post marks them the
same way.

### Firsthand (observed on cosign v3.1.1, windows/amd64)

| Claim in the post | Evidence | Value |
|---|---|---|
| A key-based `sign-blob` **uploads to the public Rekor by default** — the bundle carries `tlogEntries` (rekor.sigstore.dev, hashedrekord) **and** an RFC3161 TSA timestamp | `bundle-default-redacted.json` → `verificationMaterial` keys · `results.json` → `behaviors_verified[default_uploads_to_public_rekor]` | `publicKey` + `tlogEntries` + `timestampVerificationData` |
| `--tlog-upload=false` is **deprecated** in v3; the offline path is a `--signing-config` file | `results.json` → `behaviors_verified[tlog_upload_false_deprecated]` · `run.sh` step 3 | verified |
| The offline signing-config bundle is the **same `bundle.v0.3+json` format but self-contained** — `verificationMaterial` = `['publicKey']` only | `results.json` → `bundle_shape_matrix.offline_signing` · `run.sh` step 3 assertion | `publicKey` only |
| `cosign triangulate` warns it is **deprecated, removed in v4** (use `oras discover` / `cosign tree`); signatures attach as legacy `.sig` tag **and** OCI referrer | `results.json` → `behaviors_verified[triangulate_deprecated_for_v4]` · `run.sh` step 4 | verified (Docker) |
| Offline verify needs `--insecure-ignore-tlog=true` and cosign **warns it is insecure** | `results.json` → `behaviors_verified[offline_verify_warns_insecure]` | verified |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Bundle spec v0.3 / signing-config v0.2 media types | [sigstore/protobuf-specs](https://github.com/sigstore/protobuf-specs) |
| Latest cosign is v3.1.2 (2026-07-17); v4 removes the deprecated flags | [sigstore/cosign releases](https://github.com/sigstore/cosign/releases) |

### Explicitly NOT verified

Only **windows/amd64** was run. The **keyless (Fulcio OIDC)** flow and **Rekor v2 storage internals**
are discussed in the post conceptually but were not inspected firsthand. Stated as limitations, not
presented as measurements.

## Drift

Pinned to **cosign v3.1.1** (2026-06-09 build). Latest is v3.1.2 as of 2026-07-17. The tlog entry
values inside `bundle-default-redacted.json` (logIndex, integratedTime, merkle proof) are a
point-in-time snapshot of the live `rekor.sigstore.dev` log and will **not** match a fresh run — the
*shape* (which keys are present) is the reproducible signal, not the values. See
`manifest.json.drift_warning`.

## Environment

Windows 11 x64 · cosign **v3.1.1** (go1.26.3, windows/amd64) · Docker 29.4.3 (local `registry:2`
only, no production contact). Hardware is irrelevant — this is a signing-behavior / bundle-shape
check, not a timing benchmark.

## Reproduce

```bash
./run.sh          # download cosign v3.1.1 → keypair → default vs offline sign-blob → assert bundle shapes
```

Steps 1–3 need only cosign and reproduce the core finding. Step 4 (OCI signing + `triangulate`) also
needs a local Docker daemon and is skipped automatically if Docker is absent.

## Files

| File | What it is |
|---|---|
| `run.sh` | The harness. Downloads cosign v3.1.1, signs two ways, asserts the two bundle shapes. |
| `bundle-default-redacted.json` | Surviving structural artifact: a DEFAULT bundle's `verificationMaterial` (crypto values redacted). Proves the public-log-by-default finding. |
| `results.json` | Claim-facing summary: bundle-shape matrix, behaviors, cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, `backfilled`, drift + retention notes. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
