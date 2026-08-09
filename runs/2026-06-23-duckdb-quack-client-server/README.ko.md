# DuckDB quack — 인프로세스 OLAP 엔진이 클라이언트-서버가 되다

📝 글: https://var.gg/ko/blog/duckdb-quack-client-server
🗓 실행: 2026-06-23 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ♻️ **백필**
🌐 English: [README.md](./README.md)

> 글은 *"`quack_serve`로 서버를 띄우고, 두 번째 DuckDB에서 ATTACH해서 이 클라이언트-서버
> 세션이 실제로 무엇을 지원하는지 찔러봤다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 —
> 하네스·환경·관측된 동작 매트릭스를 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다.
> `git clone` 후 `./run.sh`로 capability 결과가 재현된다.

## 백필 정직성

이 런은 **2026-06-23**에 **DuckDB v1.5.3 (Variegata)** + **quack** 코어 익스텐션으로, 단일
Windows 머신 루프백에서 실행됐다. 하네스(SQL 스크립트 + `quack_serve` 호출)는 gitignore된
`tmp/`에 있었고 유한 디스크 firsthand 정책에 따라 발행 후 삭제됐다. 여기 커밋한 하네스
(`server.sql` + `client.sql` + `concurrent_writers.sh` + `run.sh`)는 그 런의 기록된 방법론으로
**재구성**해, 제3자가 핀 고정된 DuckDB 빌드에서 capability 주장을 재현할 수 있게 했다.
`results.json`은 **2026-06-23에 관측한** 정성 매트릭스다 — 재실행하면 pass/fail과 정확한
에러 메시지가 동일하게 재현된다. 5절 지연 수치는 머신 의존 맥락이며 근거 주장이 아니다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 줄로 추적된다.

### Firsthand (DuckDB v1.5.3 + quack, 루프백 관측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `ATTACH` 후 클라이언트가 원격 테이블을 투명하게 읽는다 | `results.json` → `1_basic_roundtrip` | hello 2행 · big `count(*)` = 1,000,000 |
| 인증은 공유 토큰: 정상은 attach, **틀린 토큰 / 시크릿 없음은 서로 다른 에러로 실패** | `results.json` → `2_auth` | `Authentication failed` / `Could not find a Quack authentication token` |
| 원격 쓰기 표면은 **append + DDL**이지 임의 수정이 아니다: `INSERT`/`CREATE`/`DROP`/`SELECT`는 되지만 **직접 `UPDATE`/`DELETE`는 실패** | `results.json` → `3_remote_write_surface` | `Binder Error: Can only update/delete base table` |
| `UPDATE`/`DELETE`가 *불가능*한 게 아니라 직접 문법만 안 wired — **`remote.query('… RETURNING *')`로 server-side 동작** | `results.json` → `3b_update_delete_serverside_workaround` | quack 이슈 #176과 일치 |
| 원격 **`BEGIN; INSERT; ROLLBACK`인데 삽입 행이 남는다** — ROLLBACK이 전파되지 않음 | `results.json` → `3c_transaction_rollback_not_propagated` | before 0 → after 1 · 이슈 #173과 일치 |
| **별도 프로세스** 두 개가 동시 append해도 둘 다 커밋, 행 손실·lockout 없음 | `results.json` → `4_concurrent_writers` | +10,000행 (A 5000 / B 5000) |
| 서버를 kill하면 **즉시 connect 에러**로 표면화, 조용한 hang 아님 | `results.json` → `6_server_failure` | `Could not connect to server` IO Error |

핵심 발견: quack은 인프로세스 OLAP DuckDB를 **양 끝이 모두 DuckDB인 클라이언트-서버 쌍**으로
바꾼다. 다만 v1.5.3에서 "멀티플레이어" 서사에는 경계가 있다 — 동시 append와 DDL은 되지만,
직접 원격 `UPDATE`/`DELETE`와 전파되는 `ROLLBACK`은 안 된다.

### Cited, not measured (글에도 한계로 명시)

| 주장 | 출처 |
|---|---|
| quack이 "Arrow Flight보다 ~3.5× 빠름" | 공식 quack 자료의 *다른 와이어 프로토콜* 대비 주장 — 여기선 Arrow Flight 베이스라인을 돌리지 않았다. 인프로세스 제로카피를 버리는 절대 비용(0ms → 루프백 0.5~1s)이 5절이 보여주는 것. |
| 안정판 목표는 v2.0 (2026-09) | 작성 시점 로드맵; v1.5.3은 beta. |

정직한 한계: 이 런은 단일 루프백 머신에서 **클라이언트-서버 capability 표면**을 검증하지,
다중 호스트 처리량이나 Arrow Flight 비교를 재현하지 않는다.

## 환경

Windows 11 · DuckDB **v1.5.3 (Variegata)** amd64 CLI · quack 코어 익스텐션(autoload) ·
단일 머신 루프백. 하드웨어는 pass/fail 매트릭스와 무관하며, 5절 지연은 맥락 전용이다.

**Windows 함정:** `localhost`는 IPv6 `::1`로 바인딩되므로 IPv4 `127.0.0.1:9494` 포트 프로브는
false negative다. 클라이언트는 `quack:localhost`를 동일 resolve하므로 그래도 동작한다.

## 재현

```bash
./run.sh   # server.sql 부팅 → client.sql 프로브 → concurrent_writers.sh
```

DuckDB v1.5.3 CLI가 PATH에 있어야 하고, `INSTALL quack`이 익스텐션을 네트워크에서 1회
가져온다. 이후 출력을 `results.json`과 대조한다.

## 파일

| 파일 | 설명 |
|---|---|
| `server.sql` | seed 테이블(`hello`, `big`, `t`, `upd_probe`, `tx_probe`)로 quack 서버 부팅. |
| `client.sql` | capability 프로브: 인증, 왕복, 원격 DML/DDL 표면, server-side `UPDATE`, ROLLBACK 전파. |
| `concurrent_writers.sh` | 4절: 두 프로세스가 각 5000행 append; +10,000·무손실 검증. |
| `run.sh` | 재현 드라이버(서버 bg → 클라이언트 → 동시성). |
| `results.json` | 주장 대응 매트릭스: 인증·원격 표면·트랜잭션·동시성·지연(맥락)·서버 장애. |
| `manifest.json` | 환경·버전·`executed_by`·`backfilled`·보존 정책. |
| `checksums.txt` | 커밋된 하네스 + 근거의 sha256. |
