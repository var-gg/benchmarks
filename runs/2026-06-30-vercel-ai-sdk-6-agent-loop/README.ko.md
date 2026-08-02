# Vercel AI SDK 6 에이전트 툴 루프 — 모델 호출 0회 mock으로 검증

📝 글 (KO): https://var.gg/ko/blog/vercel-ai-sdk-6-agent-loop
📝 글 (EN): https://var.gg/en/blog/vercel-ai-sdk-6-agent-loop
🗓 실행: 2026-06-30 (하네스 2026-08-03 라이브 재실행) · 🤖 실행 주체: **agent** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 이 글의 핵심 주장은 "에이전트는 마법이 아니라 **모델을 다시 부르는 `while` 루프**이고, 루프가
> 도느냐 마느냐는 전적으로 `stopWhen`이 결정한다"는 것이다. 문서를 재서술하는 대신, 이 run은
> **스크립트된 `MockLanguageModelV3`(모델 호출 0회)**로 SDK의 실제 에이전트 루프를 돌려
> 구체적 값을 되읽는다 — 스텝 수, SDK가 뱉는 content 파트 타입, 던지는 에러 클래스, 그리고
> `ToolLoopAgent`의 기본 cap. `git clone` + `./run.sh`로 **핀 고정된** `ai@6.0.212`에서 그대로 재현된다.

## 무엇을 검증하나

`exp.ts`는 `ai@6.0.212`에 대해 5개 그룹·13개 실험을 돌린다. 모델은 손으로 스크립트한 mock이라
**LLM을 한 번도 부르지 않고**, 아래 값은 전부 하드웨어나 프로바이더가 아니라 SDK 버전으로 고정된다.
진실 소스: `probe-result.json`.

## 주장 ↔ 근거

글의 모든 **firsthand** 주장은 `probe-result.json`의 필드로 매핑된다. SDK 타입 선언에서 인용한
주장은 *측정 아님(cited)*으로 따로 분리한다.

### Firsthand (SDK 런타임 동작 — 결정론적)

| 글의 주장 | 근거 (`probe-result.json`) | 값 |
|---|---|---|
| v6 에이전트 클래스는 **한 클래스에 두 이름** | `api_surface.toolLoopAgent_is_experimental_agent` | `ToolLoopAgent === Experimental_Agent` → **true** |
| **`maxSteps`가 v6 표면에서 제거됨** | `api_surface.maxSteps_exported` | **false** (export 안 됨) |
| `stopWhen: stepCountIs(5)`면 tool-call→text 스크립트가 **2회 루프** | `A_loop_stepCountIs5` | steps=**2**, 툴 실행, text `"Seoul is 21C."` |
| **`stopWhen`이 없으면 루프가 없다** — 툴은 실행되지만 답은 비어 있음 | `B_no_stopWhen` | steps=**1**, text `""`, 그러나 `toolResults=[{city:Seoul,tempC:21}]` |
| `stopWhen: hasToolCall('weather')`는 그 호출 직후 정지 | `B2_hasToolCall` | steps=**1** |
| throw하는 툴은 **잡혀서 `tool-error`로 되먹임**(self-heal, 크래시 없음) | `C_tool_throws` | threw=**false**, steps=2, step0=`['tool-call','tool-error']`, text `"recovered"` |
| **미등록 툴** 호출도 `tool-error`로 표면화되고 루프는 계속 | `C2_ghost_tool` | threw=**false**, step0=`['tool-call','tool-error']` |
| 구조화 출력: 유효 JSON은 **런타임에 타입드** | `D_object_valid` | `object={city,tempC}`, `tempC*2=42` |
| 스키마 위반 / 비-JSON은 **`AI_NoObjectGeneratedError` throw** | `D_object_schema_violation`, `D_object_nonjson` | 둘 다 → **AI_NoObjectGeneratedError** |
| `ToolLoopAgent`는 같은 루프의 **얇은 래퍼** | `F_agent_wrapper` | steps=2, text `"Busan 21C."` |
| 에이전트 클래스 **기본 `stopWhen`은 `stepCountIs(20)`** — 끝나지 않는 모델은 조용히 20회 과금, 맨 `generateText`는 루프 안 함 | `F2_default_cap` | agent steps=**20**, `generateText` steps=**1** |
| v5의 `maxSteps`는 v6에서 **무시**(루프가 조용히 1스텝으로 붕괴) | `G_maxSteps_ignored` | steps=**1**, text `""` |

### 측정 아님 — 인용만 (글도 같은 방식으로 표시)

| 주장 | 소스 |
|---|---|
| `generateObject`는 6.0.212에서 `@deprecated`("Use `generateText` with an `output` setting instead"), 권장 경로는 `generateText({ output: Output.object(...) })` (아직 experimental) | `ai@6.0.212` 타입 선언 (`node_modules/ai/dist/*.d.ts`) |
| v6에서 에이전트 시스템 프롬프트 파라미터가 `system` → `instructions`로 개명 | `ai@6.0.212` `ToolLoopAgent` 옵션 |

### 명시적으로 검증 안 함

- **실제 프로바이더 동작.** mock은 `doGenerate`를 손으로 스크립트한다. 실제 LLM의 비결정성
  (잘못된 툴 인자·무한 툴 루프 경향·프로바이더 네이티브 구조화 출력)은 재현 대상이 **아니다** —
  이 run은 SDK의 **계약과 제어흐름**을 보지, 모델 동작을 보지 않는다.
- **tool-error 오버라이드.** self-heal은 **기본값**이며 `onError`/툴 옵션으로 바뀔 수 있다.
- **스트리밍 파트 순서.** `fullStream` emission 순서는 원 firsthand run에서 관찰했으나 이 커밋된
  하네스에서는 재단언하지 않는다(스칼라가 아니라 emission 순서) — 인용만, 재측정 아님.
- **`usage` 토큰**은 mock이 채운 가짜값이다.

## 환경

Windows 11 x64 · 네이티브(Docker 없음) · Node v24.15.0 · `ai@6.0.212`, `zod@4.4.3`(핀 고정), `tsx`.
하드웨어는 무관 — 하네스는 **모델 호출 0회**로 SDK 제어흐름을 관찰하지 타이밍을 재지 않는다.

## 재현

```bash
./run.sh                       # 핀 고정 deps 설치 후 모델 호출 0회 mock 하네스 실행
git diff -- probe-result.json  # meta.node(로컬 Node)만 다르고 나머지는 동일해야 함
```

## 날짜에 대한 정직한 고지

글은 **2026-06-30** 발행됐다. 원 하네스는 gitignore된 `tmp/` 스크래치에 있다가 발행 후 정리됐고,
firsthand **기록**은 보존됐다. `exp.ts`는 그 기록에서 재구성해 **2026-08-03에 같은 핀 고정
`ai@6.0.212`로 라이브 재실행**했다. 하네스가 모델 호출 0회라 결과가 결정론적이고 기록된 모든
단언이 정확히 재현됐다 — 따라서 이건 종이 재구성이 아니라 실측 라이브 run(`backfilled:false`)이다.

## 파일

| 파일 | 설명 |
|---|---|
| `exp.ts` | 하네스. 스크립트된 mock으로 SDK 에이전트 루프를 돌리는 13개 실험. 모델 호출 0회. |
| `probe-result.json` | 커밋된 근거: 13개 실험 매트릭스(스텝 수·content 파트 타입·에러 클래스). |
| `results.json` | 주장 중심 요약(API 표면 / 루프 제어 / self-heal / 구조화 출력 / 에이전트 클래스 / 마이그레이션 함정) + 측정 안 함·인용 분리. |
| `manifest.json` | 환경·핀 고정 버전·`executed_by`·재구성 고지·보존 정책. |
| `package.json` | `run.sh`가 정확한 subject를 설치하도록 `ai@6.0.212`+`zod@4.4.3` 핀 고정. |
| `run.sh` | 재현 진입점(설치 → probe). |
| `checksums.txt` | 커밋된 하네스+근거의 sha256. |
