# OSV-Scanner 도달성(Go 콜 분석) — v2.4.0 / Go 1.25.5

📝 글(KO): https://var.gg/ko/blog/osv-scanner-reachability
🗓 실행: 2026-07-23 · 🤖 실행 주체: **에이전트** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 이 글의 주장은 *"똑같은 취약 의존성인데 한 모듈에선 High 경보가, 다른 모듈에선 0이 나온다 —
> 도달성(reachability)이 취약 함수가 실제로 호출되는지를 보기 때문"*이다. 이 디렉터리가 그 실행이다.
> **동일한** 취약 의존성·advisory를 가진 Go 모듈 두 개가 호출하는 함수 하나만 다르다. `git clone` 후
> `./run.sh`로 2×2 경보 매트릭스를 재현할 수 있다.

## 픽스처(fixture)

두 모듈 모두 **동일한** `golang.org/x/text@v0.3.7`을 require한다. 이 버전은
**GO-2022-1059 / GHSA-69ch-w2m2-3vjp / CVE-2022-32149**(CVSS 7.5 High)로 지정돼 있고,
`language.ParseAcceptLanguage`의 DoS 취약점이며 v0.3.8에서 고쳐졌다. 두 모듈은 함수 호출 하나만 다르다.

- `reachable/main.go` — 취약 심볼 `language.ParseAcceptLanguage(...)`를 **호출**한다.
- `unreachable/main.go` — 같은 패키지·버전을 import하지만 `language.Make(...)`만 호출한다.

## 주장 ↔ 근거

글의 **직접 측정(firsthand)** 주장은 각각 `results.json` / `probe-result.json`의 한 줄에 대응한다.
외부 출처에서 인용한 주장은 *인용(실측 아님)*으로 분리했다 — 글에서도 같은 방식으로 표시한다.

### 직접 측정 (osv-scanner 2.4.0 + Go 1.25.5)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 나이브 락파일 매칭(`--no-call-analysis=go`)은 **두 모듈에 똑같은 High 경보**를 준다 | `results.json` → `alert_matrix` | reachable 1 High / unreachable 1 High |
| unreachable 쪽 나이브 경보는 **재현된 false positive**다 | `results.json` → `alert_matrix.unreachable_imports_only.naive` | "1 High — 오탐" |
| 도달성(`--call-analysis=go`, Go 기본값)은 심볼이 **실제 호출되는** 쪽에만 경보를 남긴다 | `probe-result.json` → `reachable_variant` | reachable 1 표시 |
| 도달성은 import만 하고 호출 안 한 쪽 경보를 **0으로 거른다** | `probe-result.json` → `unreachable_variant` | unreachable 0 |
| `experimental_analysis.GO-2022-1059.called` 플래그가 두 모듈에서 **true / false** | `probe-result.json` → `*_variant.experimental_analysis_called` | true vs false |
| 걸러진 항목은 **삭제가 아니라 강등** — `--all-vulns`가 "Uncalled vulnerabilities"로 다시 표시 | `results.json` → `demotion_not_deletion` | 확인됨 |
| 도달성은 **Go 툴체인 + 빌드 가능한 모듈**이 필요("Will run build scripts"), 나이브는 `go.mod`만으로 동작 | `results.json` → `tradeoff_observed` | 확인됨 |

### 인용(실측 아님) — 글에서도 정직하게 표시

| 주장 | 출처 |
|---|---|
| Go 도달성은 govulncheck의 콜그래프 분석으로 동작 | OSV-Scanner 문서 / govulncheck |
| GO-2022-1059 = CVE-2022-32149 (crafted Accept-Language DoS, `x/text` < 0.3.8) | [osv.dev](https://osv.dev/vulnerability/GO-2022-1059) |

### 명시적으로 검증하지 않은 것

- **동적 디스패치 / 리플렉션 / cgo**는 정적 콜그래프를 회피 → 도달성이 *false negative*를 낼 수 있다.
  govulncheck 문서 **인용**이며 여기서 실측하지 않았다.
- **패키지 전체 advisory**(affected symbol 없음)는 함수 단위로 못 거르므로 항상 보고된다. 인용, 미실측.
- **언어 범위**: osv-scanner 도달성은 **Go·Rust만** 지원. 이 실행은 Go만 측정.
- **속도**: 미측정. 이건 결정론적 경보/호출 판정이지 속도 벤치가 아니다.

## 환경

Windows 11 x64 · 네이티브(Docker 미사용) · osv-scanner **2.4.0**(GitHub 릴리스 바이너리) · Go
**1.25.5**. 하드웨어는 무관하다 — 속도가 아니라 경보 유무를 관측한다.

## 재현

```bash
./run.sh          # go + osv-scanner 확인 후 probe.sh를 두 모듈에 실행
```

`probe.sh`는 `reachable/`·`unreachable/`을 세 방식(나이브·도달성·JSON `called` 플래그)으로 스캔해
`probe-result.gen.json`을 쓴다. 커밋된 `probe-result.json`과 대조하라. 고정 소스 + 핀 고정 의존성 +
핀 고정 advisory라 판정은 결정론적이다.

## 원시 데이터

폐기 없음. 큰 산출물이 없다. 결정론적 근거 — `probe-result.json`(2×2 경보 매트릭스 + `called` 불리언)와
픽스처 모듈 두 개 — 를 커밋했다. 무결성 해시는 `checksums.txt` 참조.
