# Short-lived TLS certificate renewal — expiry semantics + ACME ARI

📝 Post (KO): https://var.gg/ko/blog/short-lived-tls-renewal
🗓 Run: 2026-06-23 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"I stood up a real ACME CA locally and drove it by hand — I watched the
> exact moment a short-lived cert breaks the TLS handshake, and I asked the CA when to renew."*
> This directory is that run: the two harnesses, the environment, and the captured logs, so you
> don't have to take the claim on faith. `git clone` and `./run.sh` reproduces it (Part A needs
> only OpenSSL; Part B needs Docker for pebble).

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `results.json` and one of the two
captured logs. Claims sourced from external references are listed separately as *cited, not
measured* — the post marks them the same way.

### Firsthand — Part A: expiry is a hard deadline (deterministic, no network)

OpenSSL 3.5.6, a local EC P-256 root CA, a **20-second** leaf, and a picky Python `ssl` client
(`CERT_REQUIRED` + hostname check, like a real browser/curl).

| Claim in the post | Evidence | Value |
|---|---|---|
| A fresh short-lived cert completes the handshake | `partA/probe-result.txt` → `[valid]` | `HANDSHAKE OK` |
| The instant `NotAfter` passes with renewal stalled, the handshake breaks — **no grace period**, app code never runs | `partA/probe-result.txt` → `[expired]` | `verify_code=10` (`X509_V_ERR_CERT_HAS_EXPIRED`) |

### Firsthand — Part B: the CA hands back a renewal window (real ACME on pebble)

A hand-written pure-Python ACME client (ES256 JWS, `cryptography` only — no `acme`/certbot lib)
walks the full order state machine under pebble's `shortlived` profile, then queries ARI.

| Claim in the post | Evidence | Value |
|---|---|---|
| The **CA** picks the lifetime, not the client | `partB/acme-ari-result.txt` → `[cert] Lifetime` | `144.0 hours` (pebble default) |
| ARI returns a renewal **time window** + `Retry-After`, not a single instant | `partB/acme-ari-result.txt` → `[ARI] HTTP 200` | window `[NotAfter−72h .. NotAfter−24h]`, `Retry-After 21600` |
| The ARI path (CertID) is **derived from the cert** (AKI + serial), unique per cert | `partB/acme_ari.py` (CertID computation) | `3GDLB8LPWmGDwp_DBKNDj7uiI2Q.BSs2vQAelpg` |
| pebble exposes ARI under the **draft path**; read it from the directory, don't hardcode | `directory.renewalInfo` | `.../draft-ietf-acme-ari-03/renewalInfo` |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| Cert max lifetime shrinks from 2026-03, → 47 days by 2029 | CA/Browser Forum SC-081 / Let's Encrypt announcements |
| ARI is finalized as **RFC 9773** (was a draft) | [RFC 9773](https://www.rfc-editor.org/rfc/rfc9773) |
| Real Let's Encrypt short-lived lifetimes/windows ≠ pebble's 144h default | Let's Encrypt docs (pebble is a test CA) |
| ARI client support (Certbot 4.1.0+, …) | each client's changelog |
| Short lifetimes absorb mass-revocation, cutting OCSP/CRL dependence | ARI design rationale (reasoned) |

### Explicitly NOT verified

- **Real production CA numbers.** Only pebble's default 144h + window were observed. The
  2026→2029 industry timeline and Let's Encrypt's real profile are cited, never firsthand.
- **DCV failure modes.** Part B ran pebble with `PEBBLE_VA_ALWAYS_VALID=1`, auto-satisfying
  domain validation. Real DCV failures are abstracted by Part A's *renewal stalled* case:
  whatever the cause, once `NotAfter` passes the outcome is identical.
- **pebble version.** Pulled as `:latest` (unpinned) in the original run too. Re-running may
  surface a newer pebble with different numbers — the *mechanism* is the portable signal, not
  the exact 144h.

## Environment

Windows 11 (Git Bash) · OpenSSL **3.5.6** · Python 3.11 (`cryptography` 48) · Docker (pebble,
Part B only). This is a behavior/protocol check, not a timing benchmark — hardware is irrelevant.

## Reproduce

```bash
./run.sh          # Part A: OpenSSL + Python ssl probe;  Part B: docker pebble + ACME client
```

Part A runs with OpenSSL alone. Part B is skipped automatically if Docker is absent.

## Raw data

Per-run generated keys and certs (`ca.key`, `leaf.*`) are **not committed** — they are fresh
each run (new keys + wall-clock validity) and would not hash-match, same rationale as a
non-deterministic screenshot. The committed evidence is the two harnesses plus the captured
2026-06-23 logs (`partA/probe-result.txt`, `partB/acme-ari-result.txt`). Integrity hashes of
the committed files are in `checksums.txt`.

## Files

| File | What it is |
|---|---|
| `partA/run.sh` | Mints a local EC root CA + a short-lived leaf via OpenSSL. |
| `partA/tls_probe.py` | Stands up a TLS server with the short-lived cert; probes the handshake before/after expiry. |
| `partA/leaf.ext` | SAN/keyUsage extensions for the leaf. |
| `partA/probe-result.txt` | Captured Part A log (deterministic: `[valid]` then `verify_code=10`). |
| `partB/acme_ari.py` | Hand-written pure-Python ACME client; orders under `shortlived`, queries ARI. |
| `partB/acme-ari-result.txt` | Captured Part B log (144h cert + ARI window). |
| `run.sh` / `requirements.txt` | Reproduction (Part A always; Part B if Docker present). |
| `results.json` | Claim-facing summary: observations + cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, retention policy, drift warnings. |
| `checksums.txt` | sha256 of the committed harness + evidence. |
