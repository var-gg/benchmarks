# OpenTelemetry Weaver 0.24.2 — semconv registry를 계약으로

📝 글(KO): https://var.gg/ko/blog/otel-weaver-semconv-registry
🗓 실행: 2026-07-11(글) · 재실행 2026-07-15 · 🤖 실행: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"camelCase가 내장 check를 조용히 통과했다"*, *"리네임은 remove+add로 잡힌다"* 같은
> 주장을 한다. 이 디렉터리가 그 주장을 만든 하네스다 — registry 픽스처, Rego 정책, 정확한 명령어.
> `git clone` 후 `./run.sh`면 고정된 **weaver 0.24.2**에서 모든 종료 코드가 그대로 재현된다.

## 왜 정확히 재현되나

`weaver registry check / diff / generate`는 고정 버전에서 **결정론적**이다 — 라이브 DB도, 타이밍도,
난수도 없다. 글의 원본 작업본은 유한 디스크 정책으로 삭제됐지만, 픽스처를 기록된 firsthand 로그에서
재구성해 2026-07-15에 같은 **0.24.2** 바이너리로 새로 돌리니 모든 결과가 그대로 나왔다. `latest`를
쓰지 않은 건 의도다 — weaver의 진단은 릴리스마다 바뀌므로 **버전 고정 자체가 증거**다.

## 주장 ↔ 근거

### 직접 측정 (weaver 0.24.2 — `evidence.txt`)

| 글의 주장 | 픽스처 / 명령 | 결과 |
|---|---|---|
| 깨끗한 registry는 `check` 통과 | `reg/` → `registry check` | 종료 **0** |
| `brief` 누락은 실패 | `reg_b2/` → `registry check` | 종료 **1** ("brief 필드가 없다") |
| 잘못된 `type: money`는 실패 | `reg_b3/` → `registry check` | 종료 **1** (타입은 boolean/int/double/string/any/…) |
| **camelCase 이름은 내장 check를 조용히 통과** | `reg_b1/` → `registry check` | 종료 **0** — 이름 표기는 내장의 관심사가 아님 |
| Rego 정책을 얹으면 이름이 강제되는 계약이 됨 | `reg_b1/` → `registry check -p ./policies` | 종료 **1** ("attr_name_not_snake_case … commerce.order.totalAmount") |
| 같은 정책도 깨끗한 registry엔 무해 | `reg/` → `registry check -p ./policies` | 종료 **0** |
| 리네임은 **remove + add**(breaking)로 표시 | `reg2/` vs `reg/` → `registry diff --format json` | `+commerce.order.identifier`, `−commerce.order.id` (`diff.json`) |
| registry 한 벌 → Jinja 템플릿으로 문서 생성 | `reg/` → `registry generate … markdown` | 종료 **0**, `gen_out/attributes.md` 생성 |

### 정직한 한계 (글에도 명시됨)

| 한계 | 근거 |
|---|---|
| `diff`는 `total_amount`의 in-place `double→int` 타입 변경을 **요약에 안 띄움** | `diff.json`엔 add/remove만, 타입 변경 없음 |
| `diff`는 종료 **0** — 그 자체로 게이트가 아니라 정보 제공 | `evidence.txt` → `B_diff exit=0` |
| 필드 단위 타입·안정성 강제는 `comparison_after_resolution` 정책 계층 필요 | `results.json` 참조 |

### ⚠️ 이번 실행이 잡은 정정 한 건

글은 `weaver registry resolve`가 deprecated라 *"generate/package로 안내하며 **멈춘다**"*고 썼다.
0.24.2 실측 결과, `resolve`는 deprecation 경고를 **stderr**로 찍은 **뒤 resolution을 완료하고
종료 코드 0으로 끝난다** — 경고할 뿐 멈추지 않는다(`evidence.txt` → `resolve_deprecated_but_runs exit=0`).
여기엔 정확히 기록했고, 글의 표현은 과장이다. `manifest.json.discrepancy_flag` 참조.

## 환경

Windows 11 x64 · weaver **0.24.2**(2026-06-23 릴리스), 네이티브 CLI. 하드웨어 무관 — 타이밍이
아니라 고정 픽스처에 대한 CLI 동작·종료 코드 검증이다.

## 재현

```bash
./run.sh   # 고정 weaver 0.24.2 다운로드(OS별) → 전 케이스 실행 → evidence.regenerated.txt 생성
```

이후 `evidence.regenerated.txt`를 커밋된 `evidence.txt`와 비교 — 일치해야 한다.
