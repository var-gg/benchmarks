# SQLite ALTER COLUMN: 3.52에 들어오고, 3.53로 문서화된다 — 버전 bisect

📝 글(KO): https://var.gg/ko/blog/sqlite-353-alter-column
🗓 실행: 2026-08-04 (2026-06-29 발행 글의 재실행) · 🤖 실행자: **에이전트** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 글의 주장: *"SQLite 문서는 ALTER COLUMN을 3.53.0에 귀속하지만, 핀 고정한 6개 바이너리를 직접
> 돌려보니 3.52.0 바이너리가 이미 이 기능을 실행한다."* 이 디렉터리가 그 검증 — 하네스, 6버전 그리드,
> 결정론적 판정 — 이라 믿음에 기대지 않아도 된다. `git clone` 후 `./run.sh`면 재현된다.

## 무엇을 검증하나

SQLite 3.53.0(2026-04-09)이 매뉴얼·변경로그가 `ALTER TABLE ... ALTER COLUMN`(NOT NULL 설정/해제,
CHECK 제약 추가/제거)의 도입 시점이라 말하는 릴리스다. 그런데 핀 고정한 6개 릴리스 바이너리를 bisect하면
그 문법은 **3.52.0**(2026-03-06)에 이미 들어와 동작한다 — 정작 3.52.0 변경로그는 이 기능을 한 줄도 적지
않았다. 각 판정은 **결정론적**이다: 같은 핀 CLI + 같은 스키마 → 같은 OK/ERR, 같은 에러 문구.

## 주장 ↔ 근거

**직접 측정한** 주장은 모두 `results.json` / `probe-result.json`의 한 줄로 매핑된다. SQLite 문서·변경로그에서
가져온 주장은 *인용(측정 아님)*으로 분리한다 — 글도 똑같이 구분한다.

### 직접 측정 (핀 고정 sqlite3 CLI 빌드들)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 3.48–3.51은 ALTER COLUMN 문법을 **거부**, **3.52.0이 처음으로 수용**하고 3.53.0도 수용 — 4개 연산 모두 | `feature_matrix.py` → `probe-result.json.feature_matrix.grid` | 3.48–3.51 = **ERR**(`near "ALTER": syntax error`), 3.52/3.53 = **OK** |
| NULL 행이 남은 컬럼에 `SET NOT NULL`은 **원자적으로 거부** — 행 보존, 스키마 불변 | `experiments.py` → `…experiments.atomic_rejection_exp2` | `constraint failed`; NULL 행 유지; 스키마 불변 |
| DDL은 **트랜잭션** — `BEGIN; ALTER … SET NOT NULL; ROLLBACK;`로 원복 | `…experiments.rollback_exp6` | reverted = **true** |
| 추가된 `NOT NULL`은 **새 파일 포맷이 아니라 평범한 제약** — ALTER 문법이 없는 3.51.0 빌드가 같은 DB를 열어 `NOT NULL`을 보고 NULL 삽입을 거부, integrity_check 통과 | `…experiments.backward_compat_exp8` | 3.51이 `NOT NULL constraint failed (19)`로 거부; integrity = ok |
| ALTER COLUMN은 **nullability + CHECK 전용** — `SET DEFAULT`/`SET DATA TYPE`/`ADD UNIQUE`/`ADD PRIMARY KEY`/`ADD FOREIGN KEY`는 여전히 구문 에러 | `…experiments.limits_exp10` | 다섯 개 전부 3.52.0에서 구문 에러 |

헤드라인은 경계선이다: **3.51 = ERR, 3.52 = OK** — 문서가 말하는 것보다 한 릴리스 먼저.

### 인용, 측정 아님 (글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 매뉴얼: 이 구문은 "SQLite 3.53.0 (2026-04-09)에 추가됨" | [ALTER TABLE 문서](https://sqlite.org/lang_altertable.html) |
| 3.53.0 변경로그: "Enhance ALTER TABLE to permit adding and removing NOT NULL and CHECK constraints." | [3.53.0 릴리스 로그](https://sqlite.org/releaselog/3_53_0.html) |
| 3.52.0 변경로그(2026-03-06)는 ALTER/NOT NULL/CHECK/CONSTRAINT 미언급 — 그런데 바이너리는 실행함 | [3.52.0 릴리스 로그](https://sqlite.org/releaselog/3_52_0.html) |
| *왜* 3.52에 들어왔는데 3.53로 문서화됐는가 | SQLite가 밝히지 않음; 글은 이를 설명이 아니라 관찰로 제시 |

### 명시적으로 재측정 안 함

원래 2026-06-25 실행은 대용량 테이블 타이밍도 측정했다 — 300만 행에 `SET NOT NULL` ~78 ms이면서
`page_count`·파일 크기 **불변**(검증 스캔 + 메타데이터 플립, 테이블 rewrite 아님), `DROP NOT NULL` ~14 ms
(순수 메타데이터), 첫 위반 행에서 조기 종료. 이 수치들은 **하드웨어 의존**이라 글에서는 그 실행에서 인용하되
여기서는 **재측정하지 않았다**. 이 run 디렉터리는 결정론적 pass/fail과 동작 주장만 재검증한다 —
`results.json`의 `not_measured` 참조.

## 환경

Windows 11 x86_64 · precompiled `sqlite3.exe` CLI 6개 핀 빌드(3.48.0–3.53.0), Docker 없음, 실행 시 네트워크
없음. 이 판정에는 하드웨어가 무관하다 — 타이밍이 아니라 파서 + DDL 동작이다.

## 재현

```bash
./run.sh   # 6개 핀 sqlite-tools 빌드 내려받아 두 probe 실행
```

출력 JSON을 커밋된 `probe-result.json`과 비교. OS별 tools 아카이브가 404면 `run.sh`의 URL로 맞는
`sqlite3`를 `bin/sqlite3-<ver>`에 수동 배치.

## 원자료

폐기 없음 — 근거가 작아 전부 커밋됨. 6개 ~6.4 MB sqlite-tools zip은 내려받아 실행 후 삭제(firsthand 정리);
`run.sh`가 동일 핀 버전을 재취득한다. 무결성 해시는 `checksums.txt` 참조.
