# Playwright 1.61 가상 패스키 — chromium / firefox / webkit

📝 글: https://var.gg/ko/blog/playwright-passkey-e2e
🗓 실행: 2026-06-24 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ♻️ **백필**
🌐 English: [README.md](./README.md)

> 글은 *"Playwright 1.61의 `context.credentials`로 패스키 ceremony를 세 엔진 모두에서
> 헤드리스로 돌렸다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 — 하네스·환경·엔진별
> 실측 매트릭스를 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다. `git clone` 후
> `./run.sh`로 capability 결과가 재현된다.

## 백필 정직성

이 런은 **2026-06-24**에 실행됐다. 하네스는 gitignore된 `tmp/`에 있었고 유한 디스크
firsthand 정책에 따라 발행 후 삭제됐다. 여기 커밋한 하네스(`server.mjs` +
`public/index.html` + `playwright.config.ts` + `tests/passkey.spec.ts`)는 그 런의 기록된
방법론과, 설치돼 있던 `@playwright/test@1.61.1`의 `types.d.ts`에서 직접 읽은 API 그라운드
트루스로 **재구성**했다. `results.json`은 **2026-06-24에 실측한** 정성 매트릭스다 —
재실행하면 엔진별 pass/fail이 동일하게 재현된다. 벽시계 시간(원래 런은 12/12를 ~6.4초로
보고)은 머신 의존이라 맥락으로만 기록하며 근거 주장이 아니다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 줄로 추적된다.

### Firsthand (@playwright/test 1.61.1, 세 엔진 모두 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| seed된 discoverable 자격증명이 **usernameless** `get()`을 resolve(rawId·userHandle 일치, signature 존재) | `results.json` → `behaviors_verified[seed_usernameless_get]` | 3엔진 pass |
| **register → `get()`으로 키 export → 새 context에 re-seed → 로그인** 동작 | `results.json` → `behaviors_verified[register_export_reseed_login]` | 3엔진 pass |
| 매칭 자격증명 없음 → 페이지 `get()`이 **`NotAllowedError`**로 reject | `results.json` → `behaviors_verified[no_credential_rejects]` | 3엔진 pass |
| **`install()` 생략**은 깔끔한 no-op이 아니라 엔진별 native 동작으로 샌다(chromium `NotSupportedError`, firefox **무한 hang**, webkit `TypeError`) | `results.json` → `install_omitted_native_behavior` | 엔진마다 다름 |

핵심 발견: 1.61이 가상 인증기를 **엔진을 가로지르는 1급** `context.credentials` API로
끌어올렸다. 예전(CDP `addVirtualAuthenticator`)은 사실상 Chromium 한정이었다 — 글은
둘을 대비하고, 이 런은 같은 스펙이 firefox·webkit에서도 통과함을 확인한다.

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 플랫폼 인증기 UX(Windows Hello / iCloud Keychain) — UV gesture·attestation·transport — 는 가상 인증기가 **모사하지 않음** | Playwright 문서 + API의 의도적 미니멀리즘(P-256 고정, 항상 discoverable) |

정직한 한계: 하네스는 ceremony **배선**을 검증하지, 실제 OS 패스키 UX를 검증하지 않는다.

## 환경

Windows 11 · Node v24.15.0 · `@playwright/test` **1.61.1**, headless, 3 엔진 프로젝트.
하드웨어는 무관하다 — 타이밍 벤치가 아니라 capability/동작 매트릭스다.

## 재현

```bash
./run.sh          # npm install(1.61.1 핀) → playwright install → passkey 스펙 ×3엔진
```

이후 엔진별 pass/fail을 커밋된 `results.json`과 대조한다.
