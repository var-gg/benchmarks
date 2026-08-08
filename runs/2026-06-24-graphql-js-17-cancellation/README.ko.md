# GraphQL.js v16 vs v17 — 취소·정리·관측

📝 글(KO): https://var.gg/ko/blog/graphql-js-17-cancellation
🗓 실행: 2026-06-24 firsthand · 2026-08-08 재실행 · 🤖 실행 주체: **agent** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"v16과 v17을 나란히 돌려서 abort()가 실제로 무엇을 하는지 봤다"* 고 주장한다. 이 디렉터리가
> 그 실행이다 — 하네스·고정 버전·원시 이벤트 로그까지. `git clone` 후 `./run.sh` 하면 재현된다.
>
> 원본 2026-06-24 하네스는 발행 후 유한 디스크 정책으로 삭제됐지만, 이건 외부 의존이 0인 순수 로컬
> Node 벤치이고 이 머신이 기록된 Node 빌드(v24.15.0)를 그대로 돌리므로, 하네스를 기록된 방법론에서
> 재작성해 2026-08-08에 **실제로 재실행**했다. `probe-result.json`은 그 재실행의 진짜 출력이지 재구성이
> 아니다(`manifest.json.rerun_note`). 아래 계약은 전부 재현됐다.

## 주장 ↔ 근거

두 버전을 npm 별칭으로 한 프로세스에서 로드한다(`graphql-v16`=`graphql@16.14.2`,
`graphql-v17`=`graphql@17.0.1`). 근거는 **계약**(던짐 vs 반환, 이벤트 순서, 채널 페이로드)이지 밀리초가 아니다.

### 직접 측정 (graphql 16.14.2 baseline vs 17.0.1 subject)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| v16은 `abortSignal`을 **조용히 무시** — 두 필드 모두 resolve, `info.getAbortSignal` 없음 | `probe-result.json` → `experiment1_cancel_ab.v16` | `resolved`, `getAbortSignal:undefined` |
| v17 `execute({abortSignal})`는 abort 즉시 **`AbortedGraphQLExecutionError`를 던진다** | `experiment1_cancel_ab.v17` | `threw AbortedGraphQLExecutionError` |
| v17 취소는 **협조적** — 실행기는 대기를 멈추지만, 하위 작업은 resolver가 `info.getAbortSignal()`를 전파해야만 멈춘다 | `experiment1_cancel_ab.v17.events` | `db:abort:coop`(취소됨) **와** abort 후에도 `db:done:slow`(고아) |
| **취소 ≠ 롤백** — 진행 중 mutation은 이미 시작된 쓰기를 커밋하고, 호출자는 에러만 받는다 | `experiment2_cancel_not_rollback_v17` | abort에도 `A:wrote`+`B:wrote`; `isAborted:true` |
| v17은 **`diagnostics_channel` TracingChannel** 표면과 필드별 풍부한 `resolve` 페이로드를 노출 | `experiment3_diagnostics_v17` | 채널 순서대로 발화; resolve 키 = `alias,args,fieldName,fieldPath,fieldType,isDefaultResolver,parentType` |
| abort 시 v17은 `error.abortedResult`로 **부분 결과**를, `error.cause`로 사유를 보존 | `experiment4_partial_result_v17` | `cause='client gone'`, `abortedResult.data = {fast:'FAST', slow:null}` |

### 인용(측정 아님) — 글에서도 같은 방식으로 표시

| 주장 | 출처 |
|---|---|
| 구독자 없으면 추적 비용 0 (`shouldTrace`가 `channel.hasSubscribers` 검사) | graphql 17 `diagnostics.mjs` 소스 — 이 실행은 구독자가 있어 무구독 비용은 소스로만 확인 |
| 실제 DB 드라이버가 `AbortSignal`을 존중하는지는 드라이버마다 다름 | 프로브는 `setTimeout` fake DB로 **전파 메커니즘**만 입증; 실드라이버 협조는 글의 한계로 명시 |
| `@defer`/`@stream` 점진 전송은 별도 실험 표면 | GraphQL.js v17 릴리스 노트 — 범위 밖 |

### 여기서 검증 안 된 것 (솔직히)

이 실행은 미리 `parse()`한 문서로 `execute()`를 호출해서 `graphql:validate`는 **발화하지 않았다**
(검증은 실행과 별개 단계). `parse → validate → execute` 전체 사슬은 `graphql()`/전체 파이프라인에서만 보인다.

## 환경

Windows 11 · Node **v24.15.0** · npm 11.12.1 · 순수 Node 단일 프로세스, 네트워크/DB/GPU 0.
하드웨어는 무관 — 처리량이 아니라 엔진 계약이다. `results.json.timings_context_only`의
`309ms`(v16 완주) vs `91ms`(v17 abort-throw)는 맥락일 뿐 근거가 아니다.

## 재현

```bash
./run.sh          # npm install (고정 16.14.2 + 17.0.1) → node probe.mjs
```

재생성된 `probe-result.json`을 커밋된 `results.json`과 비교하라.

## 파일

| 파일 | 설명 |
|---|---|
| `probe.mjs` | 하네스. 두 버전에 4개 계약을 한 프로세스에서 실행. |
| `package.json` | npm 별칭으로 두 graphql 버전 고정. |
| `probe-result.json` | 원시 출력(이벤트 로그 + 계약 결과). 순서 결정론적. |
| `results.json` | 주장 대면 요약: 동작·인용vs측정 분리·맥락 전용 타이밍. |
| `manifest.json` | 환경·버전·`executed_by`·`rerun_note`·보존 정책. |
| `run.sh` | 재현 진입점. |
| `checksums.txt` | 커밋된 하네스 + 근거의 sha256. |
