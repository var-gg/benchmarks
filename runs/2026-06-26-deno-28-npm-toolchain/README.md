# Deno 2.8 as an npm toolchain — faster install, stricter resolution, same advisories

📝 Post: [KO](https://var.gg/ko/blog/deno-28-npm-toolchain) · [EN](https://var.gg/en/blog/deno-28-npm-toolchain)
🗓 Run: 2026-06-26 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This run happened on 2026-06-26, before this repo existed; its raw
> artifacts (the standalone `deno.exe`, both `node_modules` trees, the DENO_DIR/npm caches)
> were discarded (finite disk). `run.sh` + `fixture/package.json` are reconstructed from the
> recorded methodology so you can reproduce the **method**. The numbers in `results.json` are
> the 2026-06-26 snapshot: install timings are **machine/cache-dependent**, and audit counts
> **drift** as the advisory DB updates. The durable claims are the install-speed **ratio** and
> the qualitative behaviours (layout, phantom-dep, pack-is-transpile, Node-API parity). No
> artifact hashes were captured, so none are invented.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| `deno install` is **~3.1× faster** than `npm install` here | `results.json` → `metrics[cold_install_speed]` | 559ms (deno cold) vs 1744ms (npm warm) ≈ **3.1×**; 2nd run 131ms vs 452ms |
| The official **"3.66×" is not vs npm** | `results.json` → `metrics[cold_install_speed].caveat` | 3.66× = Deno **2.7→2.8** self-improvement (Linux; React/Vite/Babel/ESLint) |
| deno **isolates** node_modules pnpm-style; npm **hoists flat** | `results.json` → `findings[layout]` | npm **8** top-level dirs vs deno **4** junctions + `node_modules/.deno/` |
| deno **blocks phantom** (undeclared transitive) deps | `results.json` → `findings[phantom_dep]` | `require("has-flag")`: node **OK** / deno **Cannot find module** |
| npm/deno audit share the **same advisories**, count differently | `results.json` → `findings[audit_granularity]` | same GHSA ids; npm **2** (per-package) vs deno **7** (per-advisory), exit 1 |
| **ci/frozen** both reject a lock mismatch; deno gives a precise diff | `results.json` → `findings[ci_frozen]` | both **exit 1**; deno prints integrity old/new |
| deno **pack transpiles**; npm **zips source** | `results.json` → `findings[pack_transpile]` | npm 944B source zip vs deno 680B transpile + generated `.d.ts` |
| Node CJS entrypoint runs **byte-identical** under deno | `results.json` → `findings[nodeapi_parity]` | recorded sha256 prefix `7a97f5f99f54`; 7 tricky builtins OK |
| deno **skips lifecycle** postinstall | `results.json` → `findings[lifecycle_scripts]` | npm runs it / deno does not — security win **and** build trap |
| `require` under deno is **context-dependent** | `results.json` → `findings[require_context]` | outside a `type:commonjs` scope → `require is not defined` |

### Honestly NOT verified

**Native addons** (node-gyp-built `.node` binaries) are documented by Deno as a compatibility
boundary, but we did **not** probe them — the fixture is pure-JS on purpose and no native-addon
package was installed to force the case. That boundary is reported on the authority of Deno's
docs, not reproduced here. See `results.json` → `explicitly_not_verified`. The post keeps the
"documented boundary" ≠ "we tested it" line the same way.

One more honesty flag on **audit**: the only empirical claim is that npm and deno surfaced the
**same GHSA ids**. We do **not** claim the source is OSV — Deno's own docs name it inconsistently
(GitHub CVE / vulnerability databases / npm advisory), so the post says "same GHSA" and stops there.

## The fixture

`fixture/package.json` pins three deliberately old, pure-JS releases (`lodash@4.17.15`,
`minimist@1.2.5`, `chalk@4.1.2`) so that: audit has something to find, `chalk` drags in an
**undeclared transitive** (`has-flag`) for the phantom-dep check, and nothing needs a native
addon. `type` is `commonjs` so the Node-API/require experiments run in the intended scope. This
is the reproducible input — the one thing that does **not** drift.

## Reproduce

```bash
./run.sh          # needs node/npm + deno 2.8.x ; installs the fixture, times npm vs deno, audits both
```

Expect: `deno install` (cold) still beats `npm install` (warm); npm hoists ~8 flat dirs while deno
keeps ~4 junctions + `node_modules/.deno/`; `require("has-flag")` resolves under node but not deno;
both audits show the **same GHSA ids** but different counts. Install ms and audit counts will differ
from the 2026-06-26 snapshot — that is expected and honest; the **ratio** and the behaviours hold.

## Environment

Windows 11 x64 (native) · Node **v24.15.0** / npm **11.12.1** · deno **2.8.0** (standalone zip) ·
audit data = GitHub Advisory (empirical, same GHSA ids in both tools).
