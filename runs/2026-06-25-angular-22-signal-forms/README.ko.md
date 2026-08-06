# Angular 22 Signal Forms vs Reactive Forms — 동작·타입안전 검증

📝 글: https://var.gg/ko/blog/angular-22-signal-forms
🗓 실행: 2026-08-07 (재실행) · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"Angular 22.0.2 Signal Forms로 실험 4개를 직접 돌렸다"*고 주장한다. 이 디렉터리가 그
> 하네스다 — 글이 핀 고정한 버전 위에서 **새로 재실행**해 두었으니 주장을 믿음에 맡길 필요가 없다.
> `git clone` 후 `./run.sh`면 아래 모든 값이 재현된다.
>
> **백필(backfilled).** 원본 하네스는 글 초안 작성(2026-06-25) 직후 firsthand 정리 정책(로컬 디스크
> 유한)에 따라 삭제됐다. 이 디렉터리는 글의 `firsthand-benchmark.md`에서 재구성해 2026-08-07에
> `@angular/* 22.0.2` 위에서 다시 돌린 것이다. 결과는 복사가 아니라 새로 측정했다 —
> `manifest.json.backfill_note` 참조.

## 주장 ↔ 근거

넷 모두 핀 고정 버전(`@angular/* 22.0.2`, TypeScript 5.9.3, Vitest 3.2.6, Node 24.15.0)에서
결정적이다. 시간(ms) 주장은 없다.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| **A.** 오타 + 잘못된 타입 쓰기가 stringly-typed Reactive 접근에선 런타임까지 생존, Signal Forms에선 둘 다 컴파일 에러 | `results.json` → `experiment_A_type_safety`; `exp-a-types/*.ts` | reactive **0** 에러 · signal **2** (`TS2551` 오타, `TS2345` 타입) |
| **B.** `email`만 읽는 소비자는 무관한 `age` 변경에 재실행되지 않음 | `results.json` → `experiment_B_reactivity_granularity`; `exp-b-granularity.test.ts` | signal 무관 5회 변경 시 **0회 추가** · 자기 필드 1회 변경 시 **1회** |
| **B.** Reactive `group.valueChanges`는 아무 자식이나 바뀌면 소비자를 실행 | 위와 동일 | reactive map이 무관 5회 변경에 **5회** 실행 |
| **C.** 가장 깊은 리프를 touch하면 중간 그룹·루트로 버블, 루트 `touched` computed은 정확히 1회 재계산 | `results.json` → `experiment_C_state_aggregation`; `exp-c-aggregation.test.ts` | leaf→group→root 모두 `true` · **1회** 재계산 |
| **C.** 루트 validity가 자손에서 집계되고 수동 revalidate 없이 회복 | 위와 동일 | 루트 `valid`: required 빈 값 `false` → 리프 채우면 `true` |
| **D.** 값을 도중에 바꾸면 stale 비동기 검증이 abort되고 최신만 반영 | `results.json` → `experiment_D_async_race`; `exp-d-async-race.test.ts` | starts `[taken, free]` · aborted `[taken]` · completed `[free]` |

## 정직한 단서 (글에도 적혀 있음)

- **A** — Angular 14+ *typed forms*는 **정적으로 알려진 리터럴 경로**에서의 잘못된 타입 쓰기는
  잡는다(`group.get('user.email').setValue(42)`는 컴파일 에러). 0-에러 결과는 딱 stringly-typed
  표면에 한정된다: **알 수 없는 키**(`group.get('emial')` — 항상 `AbstractControl | null`이라 오타는
  절대 타입검사를 못 통과), 그리고 **동적/런타임 경로**(`group.get(fieldName)` — `AbstractControl<any>
  | null`). 둘 다 동적·중첩 폼에서 흔한 패턴이다. Signal Forms엔 이런 stringly-typed 탈출구가 없다.
- **D** — 이건 abort *의미론* 검증이지 "Signal Forms만 안전"의 증거가 아니다. Reactive의
  `AsyncValidatorFn`도 뒤늦은 검증을 버린다(RxJS unsubscribe). 차이는 메커니즘(resource 무효화 +
  `AbortSignal`)이고, 실제 작업이 멈추는지는 loader가 `AbortSignal`을 존중하느냐 — 협조적 취소 — 에 달렸다.

## 측정 안 함 (글에 인용, 여기선 별도 검증 X)

- 비동기 검증은 동기 검증이 모두 통과한 뒤에만 실행 — 문서화된 동작, 이 하네스에서 별도 assert 안 함.
- 재실행 횟수는 zoneless jsdom TestBed의 signal/구독 재실행 수이지 실제 컴포넌트 DOM 변경감지
  사이클이 **아니다.** 글은 입도(granularity)를 주장하지 절대 ms를 주장하지 않는다.

## 환경

Windows 11 · Node 24.15.0 · TypeScript 5.9.3 · Vitest 3.2.6 (jsdom, zoneless Angular TestBed) ·
`@angular/core`·`@angular/forms` **22.0.2**. 하드웨어 무관 — 타이밍이 아니라 로직/타입 벤치다.

## 재현

```bash
./run.sh          # npm install(핀 고정) → exp A tsc → vitest B/C/D → probe-result.json
```

이후 `probe-result.json`을 커밋된 `results.json`과 diff.
