# nginx Ingress → Gateway API, ingress2gateway v1.1.0

📝 글: https://var.gg/ko/blog/gateway-api-ingress-migration
🗓 실행: 2026-06-18 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ⏪ backfilled(사후 포장)
🌐 English: [README.md](./README.md)

> 글은 *"실제 annotation 붙은 nginx Ingress를 ingress2gateway v1.1.0에 직접 물려, Gateway API
> 코어가 무엇을 흡수하고 무엇을 버리고 어디서 거짓말을 하는지 읽었다"*고 주장한다. 이 디렉터리가
> 바로 그 실행이다 — 입력 fixture, 실제 변환 출력, 도구가 뱉은 경고를 그대로 담아 주장을 그냥
> 믿지 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다(클러스터·네트워크·타이밍 없는 순수
> 오프라인 변환).

## 주장 ↔ 근거

글의 firsthand 주장은 전부 커밋된 `expected/` 출력의 한 줄로 추적된다. `ingress2gateway print
--input-file`은 결정적이라, 근거는 출력의 요약이 아니라 **출력 그 자체**다.

### 코어가 흡수한 것 (ingress2gateway 1.1.0에서 실측)

| 글의 주장 | 근거 |
|---|---|
| canary Ingress(`canary-weight: 10`)가 **하나의 HTTPRoute**로 병합, 네이티브 가중 `backendRefs` | `expected/convert-standard.yaml` → `HTTPRoute vargg-canary-var-gg`, `backendRefs[].weight` |
| CORS annotation → `type: CORS` 필터, experimental 플래그 **없이 Standard** 출력에 | `expected/convert-standard.yaml` → `filters[].type: CORS` |
| `ssl-redirect` → 별도 `:80` HTTPRoute + `type: RequestRedirect` | `expected/convert-standard.yaml` → `:80` 리스너 + `RequestRedirect` |
| `rewrite-target` → `type: URLRewrite` / `ReplaceFullPath` | `expected/*.yaml` → `filters[].type: URLRewrite` |
| TLS Secret → Gateway 리스너 `certificateRefs`, 443/80 분리 | `expected/convert-standard.yaml` → `listeners[].tls.certificateRefs: vargg-tls` |
| 정규식 경로 → `path.type: RegularExpression` | `expected/*.yaml` → `path.type: RegularExpression` |

### 경고와 함께 버려진 것 ("안 주는 것"을 정직하게)

| 주장 | 근거 |
|---|---|
| `limit-rps`(레이트리밋) — **Unsupported** | `expected/convert-standard.warn.txt` → `WARN ... limit-rps` |
| `configuration-snippet`(raw nginx) — **Unsupported**, 만능 탈출구 사라짐 | `expected/convert-standard.warn.txt` → `WARN ... configuration-snippet` |
| `force-ssl-redirect` — Unsupported 경고 | `expected/convert-standard.warn.txt` → `WARN ... force-ssl-redirect` |
| `proxy-body-size` — 버림("대부분 구현체가 합리적 기본값") | `expected/convert-standard.warn.txt` → `WARN STANDARD_EMITTER ... proxy-body-size` |
| URL 정규화(RFC 3986 §6) 미지원 | `expected/*.warn.txt` → `WARN ... URL normalization` |

### 변환됐지만 의미가 깨진 것 (가장 날카로운 firsthand 발견)

| 주장 | 근거 |
|---|---|
| `rewrite-target: /$2` → `replaceFullPath: /$2` **그대로 복사** — Gateway API는 nginx `$2` 백레퍼런스를 해석하지 않아 문법은 변환돼도 의미가 깨지고, v1.1.0은 캡처그룹 경고를 **안 낸다**(조용히 샘) | `expected/timeout-probe.out.yaml` → `replaceFullPath: /$2`; `expected/timeout-probe.warn.txt`에 캡처그룹 경고 **부재** |
| `proxy-read-timeout: 30`(30초 TCP idle) → `timeouts.request: 5m0s`(전체 request, 약 10×) — 의미를 바꾸는 best-effort 근사 | `expected/timeout-probe.out.yaml` → `timeouts.request: 5m0s`; `expected/timeout-probe.warn.txt` → `WARN ... best-effort translation ... Please verify` |
| 경로 정규식이 `(?i)/api(/|$)(.*).*`로 지저분하게 번역 + 고치라는 INFO | `expected/timeout-probe.out.yaml` → `path.value: (?i)/api(/|$)(.*).*` |

### freshness 정정 (기록에 남김)

스카우트 brief는 "ingress2gateway 1.0 (2026-03)"이라 했으나, 실행 시점 실제 최신은 **v1.1.0**
(2026-05-12 릴리스)였다 — `expected/*.yaml`의 모든 객체에 붙은 `ingress2gateway-1.1.0` generator
annotation으로 확인된다.

## 환경

Windows 11 · ingress2gateway **1.1.0** (Built Go 1.25.9) · provider `ingress-nginx`, emitter
`standard`, `--input-file` 모드(클러스터 없음). 하드웨어 무관 — 타이밍 벤치가 아니라 결정적 설정 변환.

## 재현

```bash
./run.sh          # go install ingress2gateway@v1.1.0 → fixtures/ 변환 → expected/와 diff
```

diff가 비면 재현된 것이다. 도구 버전이 다르면 출력이 달라질 수 있는데, 그게 바로 subject 버전을
핀 고정한 이유다.

## 원시 데이터

폐기한 것 없음. 변환된 전체 매니페스트와 도구 stderr 경고가 결정적 증거라 `expected/`에 통째로
커밋한다. 무결성 해시는 `checksums.txt`.
