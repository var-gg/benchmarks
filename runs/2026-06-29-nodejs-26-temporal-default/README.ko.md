# Node.js 26 — Temporal(기본 global) vs 레거시 Date — v26.4.0

📝 글(KO): https://var.gg/ko/blog/nodejs-26-temporal-default · (EN): https://var.gg/en/blog/nodejs-26-temporal-default
🗓 실행: 2026-06-29 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"Node 26.4.0에 직접 물려 돌려봤다 — Temporal이 플래그 없이 global이고, `Date`와 정확히
> 이렇게 다르다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 — 하네스(`exp.mjs`)·핀 고정 빌드·원시
> 출력을 그대로 담아 주장을 그냥 믿지 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다.

> **정직 고지(백필).** 글은 2026-06-29 firsthand 실행을 바탕으로 2026-06-30 발행됐고, 당시의
> 일회용 하네스는 보관되지 않아 기록 노트만 남았다. 여기 `exp.mjs`는 그 실험의 충실한 재구성이며,
> 포장하면서 **새로 받은 공식 Node v26.4.0(동일 빌드)에서 실제로 재실행**했다 — `probe-result.json`은
> 그 진짜 새 출력이고 모든 값이 2026-06-29 기록과 일치한다. 핀 고정 빌드의 결정적 언어 동작이라
> 전사(轉寫)가 아니라 재현 가능하다. `manifest.json.backfill_note` 참조.

## 주장 ↔ 근거

**firsthand(실측)** 주장은 전부 `results.json` / `probe-result.json`의 한 필드로 추적된다. 외부
자료(릴리스 날짜·LTS 주기)에서 인용한 주장은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도 동일하다.

### Firsthand (Node 26.4.0에서 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `Temporal`이 **플래그 없이** top-level global | `probe-result.json.temporal_global` | `true` |
| `Date`는 **0-base** 월, `Temporal`은 **1-base** 월 | `.month_indexing` | 인자 `6`→"July"; `month:7`→`2026-07-29` |
| `Date.setMonth`는 **원본 파괴**, `PlainDate.add`는 **새 값** 반환 | `.mutability` | `2026-07-29`→`2026-08-29`(같은 객체) vs 원본 보존 |
| DST spring-forward에서 **캘린더 `+1일`(12:00)** ≠ **물리 `+24h`(13:00)**; 레거시 ms 산술은 DST 모름(13:00) | `.dst` | `12` vs `13` vs `13` |
| 1월 31일 **+1개월**: `Date`는 **3월 3일**로 넘침, Temporal은 **2월 28일로 constrain**, `reject`는 **예외** | `.month_end_overflow` | `2026-03-03` / `2026-02-28` / `RangeError` |
| `new Date('2026-06-29')`=UTC 자정; `'2026/06/29'`=**로컬** 자정; `PlainDate`는 **타임존 없음** | `.parsing` | epoch 다름; `PlainDate` `2026-06-29` |
| **네 가지 Temporal 타입** 모두 존재 | `.types_present` | Instant/PlainDate/PlainDateTime/ZonedDateTime → `true` |
| V8 14.6 보너스: `Map.getOrInsert`·`getOrInsertComputed`·`Iterator.concat` | `.v8_146` | 3 / 3 `true` |
| Node 26이 `http…writeHeader`·`_stream_wrap` **제거** | `.removals` | 제거됨 / `MODULE_NOT_FOUND` |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| Node 26.0.0 2026-05-05 릴리스; 최신 26.x = v26.4.0 (2026-06-24) | [nodejs.org](https://nodejs.org/en/blog/release/v26.0.0) |
| Temporal 기본 global — nodejs/node #61806 | [release tag](https://github.com/nodejs/node/releases/tag/v26.0.0) |
| 2026-10 LTS 진입; Node 27부터 연 1회 메이저(4월), 전부 LTS | [InfoQ](https://www.infoq.com/news/2026/06/nodejs-release-changes/) |
| Python 3.9 빌드 지원 종료·GCC 13.2+ 필요·`--experimental-transform-types` 제거 | Node 26 changelog |

### 명시적으로 검증 안 함

Windows x64에서만 실행했다. Temporal/`Date` 동작은 명세상 플랫폼 독립이지만 이 실행에선
Linux/macOS에서 돌리지 않았다(`run.sh`는 셋 다 지원). LTS 타임라인·릴리스 주기 주장은 문서 사실이지
하네스 관측이 아니다.

## 환경

Windows 11 · 공식 포터블 **Node v26.4.0** (V8 14.6.202.34-node.21, undici 8.5.0, uv 1.52.1,
`NODE_MODULE_VERSION` 147) · 네트워크·의존성 없음. 타이밍 벤치가 아니라 동작 검증이라 하드웨어 무관.
`probe-result.json`이 `tz "(unset)"`로 나오는 건 하네스 TZ export가 Windows `node.exe` 자식에
전달되지 않아서다 — 시스템 시계가 Asia/Seoul이라 두 파싱 행은 KST 기준으로 그대로 해석됐다. POSIX에선
`run.sh`의 `export TZ=Asia/Seoul`가 정상 전달된다.

## 재현

```bash
./run.sh    # 핀 고정 node v26.4.0을 ./.node에 받아 exp.mjs 실행
```

이후 재생성된 `probe-result.json`을 `results.json`과 대조한다. UTC 전용 머신에선 slash vs ISO 파싱
행이 일치하므로 `run.sh`가 `TZ=Asia/Seoul`을 핀 고정한다.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다. 받은 node 바이너리(압축해제 ~120MB)는 **커밋하지 않고**
`run.sh`가 핀 고정 공식 빌드를 `./.node`(gitignore)로 다시 받는다. 결정적 증거인
`probe-result.json`은 커밋한다. 무결성 해시는 `checksums.txt`.
