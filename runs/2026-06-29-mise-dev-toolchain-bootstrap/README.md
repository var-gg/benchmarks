# mise on Windows: it locks binaries, not version strings (trust, shims, supply chain)

📝 Post: [KO](https://var.gg/ko/blog/mise-dev-toolchain-bootstrap)
🗓 Run: 2026-06-29 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This run happened on 2026-06-29 on one Windows 11 PC, before this repo
> existed. Per the finite-disk policy only `firsthand-benchmark.md` text was preserved; the
> `mise.exe` standalone binary, the installed node/jq/gh toolchains, and the isolated
> `MISE_DATA_DIR` were discarded. `fixture/*.toml` and `run.sh` are **reconstructed** from
> the recorded methodology so you can reproduce the **method**. The judgments + timings in
> `results.json` are the 2026-06-29 snapshot with **mise v2026.6.14**. **mise ships ~monthly**,
> so your versions and numbers will drift — the *behavioral* findings are the durable claims.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| An **untrusted `mise.toml`** is refused at parse time until `mise trust` (TOFU) | `results.json` → `behavioral_matrix[T]`, `findings[trust_tofu]` + `fixture/env/mise.toml` | `mise env` errors "Config files ... are not trusted"; after `mise trust`, `[env]` loads |
| `mise.lock` locks a **cross-platform binary checksum**, not a version string — and is **OFF by default** | `results.json` → `behavioral_matrix[2]`, `findings[lockfile_is_binary_lock]` + `fixture/lockfile/mise.toml` | `mise use node@22` writes per-`(os,arch)` sha256 + URL; no `mise.lock` unless you opt in |
| The **standalone `mise.exe`** falls back to **file** shim mode (no `mise-shim.exe`), so shims need mise on PATH | `results.json` → `behavioral_matrix[3]`, `findings[windows_file_shim_fallback]` | WARN "mise-shim.exe not found ... falling back to file shim"; each shim = `.cmd` + bash calling `mise x` |
| "mise verifies downloads" means **three tiers** with different guarantees | `results.json` → `behavioral_matrix[6a,6b]`, `findings[supply_chain_three_tiers]` + `fixture/supply-chain/mise.toml` | jq = checksum-only (integrity); gh = attestation (provenance) via mise's API; core = lock sha256 |
| A dependency-aware **task runner** is built in | `results.json` → `behavioral_matrix[4]` + `fixture/tasks/mise.toml` | `mise run build` runs `greet` → `build` in order (95.5 ms), no make/Taskfile |
| **Warm reinstall is idempotent**; the file-shim adds a small per-call cost | `results.json` → `timings`, `findings[idempotent_reinstall,file_shim_overhead]` | cold 3287 ms → warm 110 ms; raw node 76 ms vs `mise exec` 90 ms (~+14 ms) |

### Honestly NOT measured

- **exe shim mode** (Scoop/winget install with `mise-shim.exe` present) was not run — only the
  **file-shim fallback** of the standalone exe was measured. exe-mode behavior is cited from docs.
- Everything is **Windows 11 only**. macOS/Linux `activate` (shell hook) mode was not measured.
- The checksum-only-vs-attestation gap is a **threat-model argument**, not a staged upstream-compromise PoC.
- See `results.json` → `explicitly_not_verified`.

## Reproduce

```bash
./run.sh     # needs mise on PATH; isolates all state to a scratch MISE_DATA_DIR
```

Expect the trust refusal, the file-shim WARN, the per-platform sha256 in `mise.lock`, the
jq-checksum-vs-gh-attestation split, and warm << cold. Exact ms and the node/jq/gh patch
versions will differ from the 2026-06-29 snapshot as mise moves — that is expected and honest.

## Environment

Windows 11 x64 (native, no WSL/Docker) · Git Bash · **mise v2026.6.14** (windows-x64 standalone
exe, 2026-06-25) · `MISE_DATA_DIR`/`MISE_CACHE_DIR`/`MISE_STATE_DIR` all redirected to a tmp dir
so the user home stayed clean · installed: node 22.23.1 / `aqua:jqlang/jq` 1.7.1 / `aqua:cli/cli` 2.62.0.
