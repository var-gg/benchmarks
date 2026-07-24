# Navigation API vs History API — Chromium 147 / Firefox 148 / WebKit 26.4

📝 글: https://var.gg/ko/blog/navigation-api-spa-routing
🗓 실행: 2026-07-24 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"세 엔진에 직접 물려, 각 API가 실제로 어떤 내비게이션을 보는지 세어봤다"*고 주장한다.
> 이 디렉터리가 바로 그 실행이다 — 하네스·환경·원시 엔진별 관측 매트릭스를 그대로 담아, 주장을
> 그냥 믿지 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json` / `probe-result.json` / `router-check.json`의
한 줄로 추적된다. 외부 자료에서 인용한 주장은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도
동일하게 구분했다.

### Firsthand (Chromium 147.0.7727.15 + Firefox 148.0.2 + WebKit 26.4에서 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 11개 내비게이션 트리거 중 **History API는 2개만**(fragment + 같은 문서 Back) 관측, **Navigation API는 11개 전부** 관측 | `results.json` → `observation_matrix` · `probe-result.json` → `engines[].triggers` | 2 / 11 vs 11 / 11 |
| `popstate`는 `pushState`/`replaceState`·프로그래매틱 nav·링크 클릭·GET 폼·`location.assign()`에 **발화 안 함** | `probe-result.json` → `engines[].triggers` | 해당 케이스 popstate = 0 |
| cross-origin·download 내비게이션은 **`canIntercept=false`**(download는 `downloadRequest` 노출) | `results.json` → `observation_matrix.canIntercept_false_cases` | 확인 |
| History API는 `history.length` 정수 하나뿐(엔진마다 **값도 다름**: 5 vs 4), Navigation API는 **URL 배열 + 현재 인덱스** | `results.json` → `stack_visibility` · `probe-result.json` → `engines[].stack_after_3_pushes` | 확인 |
| `navigate` + `intercept()` 핸들러 하나로 **프레임워크 없이** 뷰 렌더 + URL 갱신(`full_page_reload_avoided=true`) | `results.json` → `spa_intercept_verified` · `probe-result.json` → `engines[].spa_intercept` | 확인 (chromium, firefox) |
| 배포된 **react-router 8.3.0**·**@tanstack/history 1.162.0**은 Navigation API 참조 **0건**, 여전히 `popstate` 사용 | `router-check.json` | 0건, popstate 존재 |
| Playwright **WebKit 26.4엔 `window.navigation` 자체가 없음** | `results.json` → `webkit_absence` · `probe-result.json` → webkit `surface` | 확인 — 아래 주의 |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| Navigation API는 2026-01 Baseline "newly available" 도달 | web.dev / MDN Baseline |
| 지원: Chrome/Edge 102+, Firefox 147+, Safari 26.2+, 전역 ~87.37% | [caniuse](https://caniuse.com/mdn-api_navigation) |

### 명시적으로 검증 안 함 — 여기선 WebKit ≠ Safari 구분이 핵심

Playwright의 **WebKit은 Safari가 아니다.** WebKit 26.4 빌드에는 `window.navigation`이 없어 그
엔진에선 `navigate` 이벤트가 한 번도 안 떴다. 하지만 caniuse는 **Safari 26.2+ 지원**이라 명시하고,
우리는 **실제 Safari를 측정하지 않았다.** 이 WebKit 결과는 *Playwright E2E 환경*에 대한 진짜
관측(그 환경에선 Navigation API 라우터가 조용히 폴백된다)이지, Safari 판정이 아니다. 글과
`results.json.webkit_absence` 양쪽에 그대로 밝혀 둔다.

그 밖에 미측정: 실제 사용자 브라우저(확장·bfcache·복원 세션), scroll/focus 복원,
`intercept()` precommit/commit 옵션, POST 폼, 실사용 `traverseTo()`. 라우터 grep은 **배포 dist
기준**이며 미발행 브랜치·오픈 PR은 보지 않았다.

## 환경

Windows 11 x64 · Playwright 1.59.0 (Python 3.11.9), headless · Chromium **147.0.7727.15** /
Firefox **148.0.2** / WebKit **26.4**. 로컬 origin 두 개(127.0.0.1 vs localhost, 포트도 다름)로
cross-origin 거동을 시뮬이 아니라 실제로 만들었다. 하드웨어는 무관하다 — 얼마나 빠른가가 아니라
어떤 이벤트가 발화하는가를 관측한다.

## 재현

```bash
./run.sh          # venv → 핀 고정 Playwright → 엔진 3종 설치 → probe.py
```

이후 재생성된 `probe-result.json`을 커밋된 `results.json`과 대조한다. `router-check.json`은
`run.sh`가 재생성하지 않는다(`npm pack` + dist grep으로 만든 것) — 방법과 핀 고정 버전은 그
파일 안에 있다.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다. 결정적 증거인 `probe-result.json`(엔진별 매트릭스)과
`router-check.json`(라우터 dist grep)은 커밋한다. 커밋된 하네스·증거의 무결성 해시는 `checksums.txt`.
