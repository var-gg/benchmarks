# Vite 8 (Rolldown) vs Vite 7 (Rollup) — ~13× faster build, same output

📝 Post: [KO](https://var.gg/ko/blog/vite-8-rolldown) · [EN](https://var.gg/en/blog/vite-8-rolldown)
🗓 Run: 2026-06-18 · 🤖 Executed by: **agent** · 👤 Operator: curioustore · **⏪ backfilled**
🌐 한국어: [README.ko.md](./README.ko.md)

> **Backfill note.** This scaffold bench ran on 2026-06-18, before this repo existed; the two
> throwaway project trees (`tmp/vite-bench/`) were deleted (finite disk). `run.sh` +
> `fixture/gen-app.mjs` are reconstructed from the recorded methodology so you can rebuild the
> **identical 24-component app** on both Vite versions and re-measure. The numbers in
> `results.json` are the 2026-06-18 snapshot; absolute ms are machine-dependent and drift, but
> the **build ratio** and the **dependency/output facts** are the durable claims. This is a
> scaffold bench, not a production-app migration — var.gg's own frontend is Next.js, not Vite.

## Claim ↔ evidence

| Claim in the post | Evidence | Value |
|---|---|---|
| Vite 8 makes **Rolldown the default**; esbuild + rollup leave the deps | `results.json` → `findings[rolldown_default]` | `vite@8.0.16` direct dep = `rolldown@1.0.3`; `.bin` goes {esbuild,rollup,vite} → {rolldown,vite} |
| Installed **package count 107 → 62** | `results.json` → `findings[package_count]` | two toolchains collapse into one Rust binary (win-x64, this fixture) |
| **Production build ~13–14× faster** | `results.json` → `metrics[build_cold]`,`[build_warm]` | 2230ms → 167ms cold; 2185ms → 154ms warm median |
| The "10–30×" is **build, not dev** | `results.json` → `metrics[dev_ready]` | dev-ready is cache-noise: 0.74× cold / 1.38× warm — not a durable win |
| 13× is **not skipped work** (output parity) | `results.json` → `findings[output_parity]` | both exit 0; bundle 602,411 B vs 588,318 B (~2.3% smaller) |
| Official **React plugin needs a major bump** 5.x → 6.0.2 | `results.json` → `findings[plugin_major_bump]` | peer `vite ^4\|5\|6\|7` → `vite ^8.0.0`, pulls `@rolldown/plugin-babel` |
| **Fewer packages, heavier binary** | `results.json` → `findings[install_size]` | native ~16MB → ~33MB (+~17MB, matches official +~15MB) |

### Honestly NOT verified

- **Large real apps** — this is a 24-component scaffold; ratio + compatibility can differ at thousands of modules (`explicitly_not_verified[large_real_app]`).
- **Rollup plugin ecosystem** — only the React plugin's major bump was checked; "almost fully compatible" is treated as a caution area, not a measured claim (`[plugin_ecosystem_compat]`).
- **Dev HMR latency** — not automatically measured; the post stays build-centric (`[dev_hmr_latency]`).
- **Dev-server model** — `findings[dev_model_unchanged]` (still native ESM) is **cited from the official migration docs, not measured** here.

## The fixture

`fixture/gen-app.mjs` deterministically writes a React 19 dashboard: 24 chart modules, each importing a
`recharts` chart family + a `lucide-react` icon, wired into one `App.jsx`. `run.sh` generates it twice and
installs only different `vite` + `@vitejs/plugin-react` versions, so the source tree is identical and the
bundler is the only variable.

## Reproduce

```bash
./run.sh          # needs node + npm + network; builds the app on Vite 7.3.5 and 8.0.16, times both
```

Expect: bench8 (Rolldown) production build ~13–14× faster than bench7 (Rollup); `.bin` engine set swaps
from {esbuild,rollup} to {rolldown}; both bundles ~equal size. Absolute ms differ per machine — the
**ratio** and the **engine swap** are what reproduce.

## Environment

Windows 11 x64 · Node **v24.15.0** · npm **11.12.1** · Vite **7.3.5** (Rollup) vs **8.0.16** (Rolldown).
Dependency pins re-confirmed stable on 2026-08-16.
