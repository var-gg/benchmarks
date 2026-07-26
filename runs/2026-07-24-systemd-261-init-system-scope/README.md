# systemd 261 — the "distro gap" between upstream and what you can `docker pull`

📝 Post (KO): https://var.gg/ko/blog/systemd-261-init-system-scope
🗓 Run: 2026-07-24 · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post claims *"systemd 261 shipped OS-install / cloud-metadata / storage binaries — but
> only rolling distros actually have them today."* This directory is that run — the two bash
> probes, the environment, and the raw JSON — so you don't have to take the claim on faith.
> `git clone` and `./run.sh` reproduces it (needs Docker).

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a line in `probe-result.json` /
`probe-pkg-result.json`. Claims about what v261 *contains* are cited from upstream NEWS and
listed separately as *cited, not measured* — the post marks them the same way.

### Firsthand (measured on Docker 29.4.3, 2026-07-24)

| Claim in the post | Evidence | Value |
|---|---|---|
| Arch already runs **systemd 261** in its base image | `probe-result.json` → `archlinux:latest.systemctl_version` | `systemd 261 (261.1-1-arch)` |
| The new v261 binaries (`systemd-imdsd`, `systemd-imds`, `systemd-sysinstall`, `storagectl`, `systemd-tpm2-swtpm.service`, …) are **all present on Arch** | `probe-result.json` → `archlinux:latest.present` | 8 / 8 `true` |
| Stable distros are **behind**: Fedora −2, Debian −4, Ubuntu LTS −6 | `probe-pkg-result.json` → `distros[].packaged_systemd` | 259.7 / 257.13 / 255.4 |
| `systemctl --version` in minimal fedora/ubuntu/debian images returns nothing — because those images **don't install systemd**, not because the distro lacks it | `probe-result.json` (absent) → corrected by `probe-pkg-result.json` | bias self-caught |

### Cited, not measured (honestly flagged in the post too)

| Claim | Source |
|---|---|
| v261 codename Edinburgh, released 2026-06-19 | [systemd v261 NEWS](https://github.com/systemd/systemd) |
| What each new binary does (IMDS / storage / OS installer / software TPM / dlopen migration) | systemd v261 NEWS (upstream) |

### Explicitly NOT verified

- **Binary presence ≠ working feature.** `storagectl` and `systemd-imdsd` exist as files on
  Arch; this run did **not** confirm they fetch cloud IMDS or install an OS end-to-end
  (container PID1, no cloud metadata).
- **Software TPM / LUO / BPF LSM policy** verified to unit-file/source presence only, runtime untested.
- **Container images are the stable-channel snapshot**, not the whole distro (backports/PPA/rawhide may be newer).

## Environment

Windows 11 x64 · Docker **29.4.3** (Linux containers) · bash harness. Hardware is irrelevant —
this is version/feature-presence detection, not a timing benchmark.

## Reproduce

```bash
./run.sh          # probe.sh (binary presence) + probe-pkg.sh (packaged version)
```

Then compare the regenerated `probe-result.json` / `probe-pkg-result.json` against the
committed `results.json`. **Caveat:** the distro image tags are mutable, so re-running later
pulls whatever those distros ship then — that drift is the point. The committed JSON is the
2026-07-24 snapshot.

## Raw data

None discarded. This run has no large artifacts — the evidence is two small deterministic
JSON files (version strings + presence booleans). The four container images pulled to run the
probes were removed after the run (ownership-based cleanup; `run.sh` re-pulls them). See
`checksums.txt` for integrity hashes of the committed harness + evidence.

## Files

| File | What it is |
|---|---|
| `probe.sh` | Harness 1. Launches each distro image, checks for v261 binaries + `systemctl --version`. |
| `probe-pkg.sh` | Harness 2. Corrects a measurement bias — asks each package manager the packaged systemd version. |
| `probe-result.json` | Raw output of probe.sh (binary presence matrix). Deterministic. |
| `probe-pkg-result.json` | Raw output of probe-pkg.sh (packaged version per distro). Deterministic. |
| `results.json` | Claim-facing summary: presence matrix + version-gap table + cited-vs-measured split. |
| `manifest.json` | Environment, versions, `executed_by`, image-pin caveat, retention policy. |
| `run.sh` | Reproduction (needs Docker). |
| `checksums.txt` | sha256 of the committed harness + evidence. |
