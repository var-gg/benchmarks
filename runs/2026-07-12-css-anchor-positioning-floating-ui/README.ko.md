# CSS anchor positioning vs Floating UI — Chromium 147

📝 글: https://var.gg/ko/blog/css-anchor-positioning-floating-ui
🗓 실행: 2026-07-12 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"헤드리스 Chromium 147에 직접 물려 돌려봤다"*고 주장한다. 이 디렉터리가 바로 그
> 실행이다 — 하네스·환경·원시 지원 매트릭스를 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다.
> `git clone` 후 `./run.sh`로 재현된다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json` / `probe-result.json`의 한 줄로 추적된다.
외부 자료에서 인용한 주장은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도 동일하게 구분했다.

### Firsthand (Chromium 147.0.7727.15에서 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `anchor-name`·`position-anchor`·`anchor()`·`position-area`·`anchor-size()`·`@position-try`·`position-visibility` **모두 지원** | `probe-result.json` → `chromium.supports` | 7 / 7 `true` |
| 버튼 아래 툴팁 tether + 중앙정렬, **JS 0줄** | `results.json` → `behaviors_verified[center_tether]` + `demo.html` A | 확인 |
| 오른쪽 넘치면 `@position-try`가 **자동으로 왼쪽 뒤집기** | `results.json` → `behaviors_verified[auto_flip]` + `demo.html` B | 확인 |
| 앵커 요소가 DOM 형제로 **`overflow:hidden` 탈출**(portal 불필요) | `results.json` → `behaviors_verified[overflow_escape]` + `demo.html` C | 확인 |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 전역 지원율 ~82% | [caniuse](https://caniuse.com/css-anchor-positioning) |
| Chrome 125+ / Firefox 147+ / Safari 26+ 기본 지원 | caniuse / MDN |
| MDN "Limited availability" — 아직 Baseline 아님 | [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning/Using) |

### 명시적으로 검증 안 함

Firefox·WebKit는 이 하네스에서 **실행하지 못했다**(로컬 Playwright 브라우저 리비전 불일치 —
`manifest.json.cross_browser` 참조). 글의 크로스 브라우저 서술은 전부 인용이고 firsthand로
제시하지 않는다. 한계를 그대로 밝힌다.

## 환경

Windows 11 · Playwright 1.59.0 (Python 3.11.9), headless · Chromium **147.0.7727.15**.
하드웨어는 무관하다 — 타이밍 벤치가 아니라 기능 지원 감지다.

## 재현

```bash
./run.sh          # venv → 핀 고정 Playwright → Chromium 설치 → probe.py
```

이후 재생성된 `probe-result.json`을 커밋된 `results.json`과 대조한다.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다. `render-chromium.png`는 예시 스크린샷이라
(재현 가능) **일부러 커밋하지 않는다** — 스크린샷은 비결정적이라 재실행 시 해시가 안 맞는다.
결정적 증거인 `probe-result.json`은 커밋한다. 커밋된 하네스·증거의 무결성 해시는 `checksums.txt`.
