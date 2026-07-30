# MCP 2026-07-28 스펙 "stateless로 간다" — schema.json으로 검증

📝 글(KO): https://var.gg/ko/blog/mcp-2026-spec-stateless-core
🗓 실행: 2026-07-29 · 🤖 실행 주체: **에이전트** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 이 글의 주장은 2026-07-28 MCP 스펙이 **initialize 핸드셰이크와 세션 상태를 없앤다**는 것이다 —
> 이제 서버를 평범한 라운드로빈 로드밸런서 뒤에 둘 수 있다. 이 실행은 changelog를 재서술하는 대신
> 그 주장을 프로토콜 **자신의 기계 판독용 `schema.json`**에 대고 검증한다. 이전 안정 리비전
> (`2025-11-25`)과 `2026-07-28` 릴리스 후보 draft를 diff해서, changelog가 **삭제**됐다고 말한
> JSON-RPC 타입이 실제로 없어졌고 **추가**됐다고 말한 타입이 실제로 있는지를 심볼 단위로 단언한다.
> `git clone` + `./run.sh`로 재현된다.

## 무엇을 확인하나

`probe.py`는 published 스키마 두 개를 받아 최상위 `$defs`(프로토콜이 정의하는 JSON-RPC 메시지 타입
집합)를 비교한다:

- `schema/2025-11-25/schema.json` — 이전 **안정** 리비전. `$defs` **145개**.
- `schema/draft/schema.json` — **2026-07-28 릴리스 후보** 라인. `$defs` **154개** (2026-07-27 스냅샷).

20개 단언이 각각 특정 changelog 주장을 "두 리비전 중 정확히 한 쪽에만 존재해야 하는" 구체 심볼에
묶는다. **20 / 20 통과.**

## 주장 ↔ 근거

글의 **직접 측정(firsthand)** 주장은 각각 `probe-result.json`의 한 심볼에 대응한다. 블로그·changelog
산문에서 인용한 주장은 *인용(실측 아님)*으로 분리했다.

### 직접 측정 (스키마 `$defs` 멤버십 — 결정론적)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| **initialize 핸드셰이크 삭제** (statelessness, SEP-2575) | `probe-result.json` → `InitializeRequest`, `InitializedNotification` | 2025-11-25엔 있고 draft엔 **없음** |
| **`ping` 삭제** | `probe-result.json` → `PingRequest` | 있음 → **없음** |
| **`logging/setLevel` 삭제** (logLevel은 요청별 `_meta`로) | `probe-result.json` → `SetLevelRequest` | 있음 → **없음** |
| **`resources/subscribe` → `subscriptions/listen`으로 교체** | `probe-result.json` → `SubscribeRequest`(삭제), `SubscriptionsListenRequest`(신규) | 없어짐 ← / → 생김 |
| **서버발 요청 → MRTR로 교체** (SEP-2322) | `probe-result.json` → `ServerRequest`(삭제), `InputRequiredResult`+`ResultType`(신규) | 없어짐 ← / → 생김 |
| **Tasks가 core에서 extension으로 이동** (SEP-2663) | `probe-result.json` → `Task`, `CreateTaskResult`, `ListTasksRequest`, `GetTaskRequest` | 모두 있음 → **없음** |
| **`server/discover` 추가** — 사전 버전 협상 (SEP-2575) | `probe-result.json` → `DiscoverRequest`, `DiscoverResult` | 없음 → **있음** |
| **캐시 가능 결과**(`ttlMs`/`cacheScope`) 추가 (SEP-2549) | `probe-result.json` → `CacheableResult` | 없음 → **있음** |
| **새 명시적 에러 타입** — 버전/헤더 불일치 (SEP-2575 / SEP-2243) | `probe-result.json` → `UnsupportedProtocolVersionError`, `HeaderMismatchError` | 없음 → **있음** |
| 심볼 총량이 **145 → 154**로 증가 | `probe-result.json` → `compared` | 145 → 154 (`removed_defs` 32, `added_defs` 41) |

전체 심볼 목록: `probe-result.json` → `removed_defs`(32) / `added_defs`(41).

### 인용(실측 아님) — 글에서도 같은 방식으로 표시

| 주장 | 출처 |
|---|---|
| RC는 2026-05-21 lock, 2026-07-28 발행 | [MCP 블로그: 2026-07-28 RC](https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/) |
| SEP별 근거 (SEP-2575 / 2322 / 2663 / 2549 / 2243) | [MCP draft changelog](https://modelcontextprotocol.io/specification/draft/changelog) |

### 명시적으로 검증하지 않은 것

- **런타임 상호운용.** 스키마 존재/부재는 동작이 아니다. `InitializeRequest`가 스키마에서 사라진 건
  확인했지만, 실제 서버·SDK가 *핸드셰이크 없이 end-to-end*로 붙는지는 여기서 **미검증**(SDK Tier-1
  지원은 인용).
- **인증 하드닝**(RFC 9207 `iss` 검증), **MCP Apps 샌드박스 iframe**, **deprecation-window
  거버넌스**는 문서/스키마 존재까지만 확인 — 런타임 미검증.
- **성능.** "라운드로빈 LB 뒤에서 동작", `tools/list` 캐시는 스펙의 설계 의도 인용 — 부하 실측 아님.

## 정직한 한계 — draft는 움직이는 타깃

`schema/draft/schema.json`은 **가변**이다: 2026-07-28 발행 전까지 계속 바뀌었고, 발행 후엔 `draft`가
다음 리비전으로 넘어간다. 커밋된 `probe-result.json`은 **2026-07-27 스냅샷**이다. `./run.sh`를 다시
돌리면 *지금*의 draft를 받으므로 draft 축 심볼이 달라질 수 있다 — `git diff -- probe-result.json`이
그 드리프트를 보여주며, 그게 요지의 일부다. `2025-11-25` 축은 frozen이라 정확히 재현된다.

## 환경

Windows 11 x64 · 네이티브(Docker 미사용) · Python 3.11 · stdlib만(`urllib` + `json`). 하드웨어는
무관하다 — 속도가 아니라 스키마 심볼 멤버십을 관측한다.

## 재현

```bash
./run.sh                       # 두 스키마를 받아 20개 단언 실행
git diff -- probe-result.json  # 커밋된 2026-07-27 스냅샷 대비 델타(draft 드리프트는 정상)
```

## 원시 데이터

스키마 스냅샷 두 개(174 KB + 180 KB)는 **커밋하지 않았다** — 저장소의 런당 100 KB 예산을 초과하고
draft는 가변이기 때문. 결정론적 근거 — `probe-result.json`(20/20 단언 매트릭스 + 전체
`removed_defs`/`added_defs`) — 는 커밋했다. `run.sh`가 스키마를 다시 받는다. 무결성 해시는
`checksums.txt` 참조.

## 파일

| 파일 | 설명 |
|---|---|
| `probe.py` | 하네스. 두 스키마를 받아 20개 changelog-주장 ↔ `$defs`-심볼 매핑을 단언. 순수 stdlib. |
| `probe-result.json` | 커밋된 근거: 20-단언 매트릭스 + `removed_defs`(32) / `added_defs`(41). 2026-07-27 스냅샷. |
| `results.json` | 주장 대면 요약: removed/added 그룹, 미측정 축, 인용-vs-측정 분리, 드리프트 노트. |
| `manifest.json` | 환경, 비교 리비전, `executed_by`, 보존 정책. |
| `run.sh` | 재현 진입점(fetch → probe → diff 안내). |
| `checksums.txt` | 커밋된 하네스 + 근거의 sha256. |
