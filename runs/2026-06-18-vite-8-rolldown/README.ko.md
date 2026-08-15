# Vite 8(Rolldown) vs Vite 7(Rollup) — 빌드 약 13× 빠름, 결과물은 동일

📝 글: [KO](https://var.gg/ko/blog/vite-8-rolldown) · [EN](https://var.gg/en/blog/vite-8-rolldown)
🗓 실행: 2026-06-18 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 스캐폴드 벤치는 2026-06-18에 돌렸고(레포 생성 전), 임시 프로젝트 트리
> (`tmp/vite-bench/`)는 디스크 정책상 폐기됐다. `run.sh` + `fixture/gen-app.mjs`는 기록된
> 방법론에서 **재구성**해, 두 Vite 버전 위에 **동일한 24-컴포넌트 앱**을 다시 세워 재측정할 수
> 있게 했다. `results.json`의 수치는 2026-06-18 스냅샷이며, 절대 ms는 머신마다 달라져 드리프트하지만
> **빌드 배수**와 **의존성·출력 사실**은 지속되는 주장이다. 이건 스캐폴드 벤치이지 운영 앱 마이그레이션이
> 아니다 — var.gg 프론트엔드 자체는 Vite가 아니라 Next.js다.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| Vite 8은 **Rolldown이 기본**; esbuild·rollup이 의존에서 빠짐 | `results.json` → `findings[rolldown_default]` | `vite@8.0.16` 직접 의존 = `rolldown@1.0.3`; `.bin` {esbuild,rollup,vite} → {rolldown,vite} |
| 설치 **패키지 수 107 → 62** | `results.json` → `findings[package_count]` | 두 툴체인이 단일 Rust 바이너리로 collapse (win-x64, 이 fixture) |
| **배포 빌드 ~13–14× 빠름** | `results.json` → `metrics[build_cold]`,`[build_warm]` | 2230ms → 167ms cold; 2185ms → 154ms warm median |
| "10–30×"는 **빌드지 dev 아님** | `results.json` → `metrics[dev_ready]` | dev-ready는 캐시 노이즈: cold 0.74× / warm 1.38× — 지속되는 이득 아님 |
| 13×는 **일을 건너뛴 게 아님**(출력 동등) | `results.json` → `findings[output_parity]` | 둘 다 exit 0; 번들 602,411 B vs 588,318 B (~2.3% 작음) |
| 공식 **React 플러그인 메이저 범프** 5.x → 6.0.2 | `results.json` → `findings[plugin_major_bump]` | peer `vite ^4\|5\|6\|7` → `vite ^8.0.0`, `@rolldown/plugin-babel` 포함 |
| **패키지 수↓, 바이너리↑** | `results.json` → `findings[install_size]` | 네이티브 ~16MB → ~33MB (+~17MB, 공식 +~15MB와 일치) |

### 정직하게 검증 안 함

- **대형 실앱** — 24-컴포넌트 스캐폴드다; 수천 모듈에서는 배수·호환 양상이 다를 수 있다 (`explicitly_not_verified[large_real_app]`).
- **Rollup 플러그인 생태계** — react 플러그인 메이저 범프만 확인; "거의 완전 호환"은 측정이 아니라 주의 영역으로 다룸 (`[plugin_ecosystem_compat]`).
- **dev HMR 지연** — 자동 측정 안 함; 글은 빌드 중심 (`[dev_hmr_latency]`).
- **dev 서버 모델** — `findings[dev_model_unchanged]`(여전히 native ESM)는 여기서 측정한 게 아니라 **공식 마이그레이션 문서 인용**이다.

## fixture

`fixture/gen-app.mjs`가 React 19 대시보드를 결정적으로 생성한다: 24개 차트 모듈, 각각 `recharts` 차트 +
`lucide-react` 아이콘을 import 해 하나의 `App.jsx`로 묶는다. `run.sh`는 이걸 두 번 생성하고 `vite` +
`@vitejs/plugin-react` 버전만 다르게 설치한다 — 소스 트리는 동일하고 번들러만 변수다.

## 재현

```bash
./run.sh          # node + npm + 네트워크 필요; Vite 7.3.5와 8.0.16으로 각각 빌드 후 시간 측정
```

기대: bench8(Rolldown) 배포 빌드가 bench7(Rollup)보다 ~13–14× 빠름; `.bin` 엔진 집합이
{esbuild,rollup} → {rolldown}으로 교체; 두 번들 크기 ~동일. 절대 ms는 머신마다 다르다 — **배수**와
**엔진 교체**가 재현되는 지점이다.

## 환경

Windows 11 x64 · Node **v24.15.0** · npm **11.12.1** · Vite **7.3.5**(Rollup) vs **8.0.16**(Rolldown).
의존성 핀은 2026-08-16 안정 재확인.
