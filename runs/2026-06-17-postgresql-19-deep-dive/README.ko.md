# PostgreSQL 19 Beta 1 — 컨테이너에서 기능·한계 직접 검증

📝 글: https://var.gg/ko/blog/postgresql-19-deep-dive
🗓 실행: 2026-06-17 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ♻️ **백필**
🌐 English: [README.md](./README.md)

> 글은 *"postgres:19beta1을 일회용 컨테이너로 띄워, 간판 기능들이 실제로 무엇을 하는지 —
> 어디서 멈추는지까지 — 직접 확인했다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 — 방법·핀
> 고정 이미지·수락/에러 관측을 담아 주장을 그냥 믿지 않아도 되게 한다. 단 **백필**이다: 원본
> 컨테이너와 SQL fixture는 유한 디스크 정책으로 삭제됐고, `run.sh`·`fixture/*.sql`는 기록된
> 방법론에서 **재구성**했다. 결과가 결정적 기능 동작(문법이 수락되거나 에러나거나, 명령이
> 존재하거나, GUC 기본값이 고정)이라 같은 이미지로 재실행하면 재현된다. 운영 Cloud SQL은
> 건드리지 않았다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 줄로 추적된다. 외부 문서 인용은
*cited, not measured*로 분리한다.

### Firsthand (PostgreSQL 19beta1, 컨테이너 내부 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| SQL/PGQ는 실재 — `CREATE PROPERTY GRAPH` + `GRAPH_TABLE ... MATCH` 파싱·실행, 고정 2-hop 포함 | `results.json` → `sql_pgq_fixed_length` · `fixture/01-sql-pgq.sql` | 1-hop + 고정 2-hop 행 |
| …그러나 **가변 길이/수량자 경로는 미지원** — 임의 깊이 도달성은 여전히 recursive CTE 필요 | `results.json` → `sql_pgq_quantifier_limit` | `quantifier -> ERROR` |
| 플래너 조언은 **로드형 라이브러리**(`EXPLAIN (PLAN_ADVICE)`)지 `CREATE EXTENSION`이 아니다 — 2차 자료 이름이 부정확 | `results.json` → `plan_advice_library_and_extension` (`correction`) | `/* matched */` 피드백 |
| 자동 적용은 별도 **`pg_stash_advice` 확장**이 `query_id → advice`로 저장(함수 6개) | `results.json` → `plan_advice_library_and_extension` · `fixture/02-plan-advice.sql` | `demo\|12345\|JOIN_ORDER(d f)` |
| **REPACK이 코어 진입**(pg_repack 흡수), `CONCURRENTLY` 옵션 존재 | `results.json` → `repack_in_core` · `fixture/03-repack.sql` | help에 `CONCURRENTLY` |
| REPACK CONCURRENTLY가 여기선 **`wal_level=logical`을 강제하지 않음**(`replica`, 동시 writer 없음) | `results.json` → `repack_concurrently_wal_level` | 200k행, 1082 페이지 |
| parallel autovacuum은 **옵트인**(`autovacuum_max_parallel_workers` 기본 **0**) | `results.json` → `guc_defaults` · `fixture/04-guc.sql` | `0` |
| 비동기 I/O 기본값: `io_method=worker`, `io_max_concurrency=64`(변경 시 재시작) | `results.json` → `guc_defaults` | `worker` / `64` |

### Cited, not measured (인용, 미측정)

- **AIO는 PG18 도입** — 여기선 19beta1의 기본 worker 모드만 확인.
- **REPACK CONCURRENTLY가 라이브 동시 쓰기 하에서 logical decoding을 쓰는지** — 이 런에선
  동시 writer로 구동하지 않았다(리포트의 메커니즘 주장).
- 테스트한 고정 길이 패턴 너머의 **SQL/PGQ 문법 적합성 범위**.

## 환경

Windows 11 x64 호스트, Docker Desktop; 검증 대상 PostgreSQL은 컨테이너 **내부**에서 실행
`docker run --name pg19test postgres:19beta1`(Debian 19~beta1-1.pgdg13+1, gcc 14.2.0). 기능/
한계/기본값 검증이라 호스트 하드웨어가 수락/에러 결과를 바꾸지 않는다.

> **Beta 1.** 문법·라이브러리/확장 이름·`EXPLAIN` 옵션 철자·GUC 기본값이 **GA 전에 바뀔 수
> 있다**. 모든 결과는 `postgres:19beta1` 이미지에 핀 고정.

## 재현

```bash
./run.sh          # docker run postgres:19beta1 -> psql이 fixture/01..04 실행
```

`run.sh`는 일회용 컨테이너를 띄우고 네 개의 SQL 프로브를 돌리며, 의도된
`element pattern quantifier is not supported` ERROR를 중단 없이 그대로 보여준다.
출력을 `results.json`과 대조한다.

## 원시 데이터

**백필 — 원본 런에서 보존한 것 없음.** 내려받은 이미지(`postgres:19beta1`)와 컨테이너는
2026-06-17 이후 유한 디스크 정책으로 삭제됐고, 당시 해시를 안 떴다(패키징 이전). 가짜
아티팩트를 만드는 대신 `firsthand-benchmark.md`에서 **재구성**한 하네스(`run.sh` +
`fixture/*.sql`)를 싣고 이 사실을 그대로 밝힌다. `results.json`은 그날 기록한 기능·한계·두
동작 관측을 담는다. 커밋된 하네스의 무결성 해시는 `checksums.txt`.
