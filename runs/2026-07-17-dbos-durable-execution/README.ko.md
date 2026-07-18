# DBOS Transact 2.27.0 — 프로세스를 죽여도 정말 워크플로가 이어지나?

📝 글: [KO](https://var.gg/ko/blog/dbos-durable-execution) *(한국어만; 영문 글 없음)*
🗓 실행: 2026-07-17 · 🤖 실행 주체: **에이전트** · 👤 오퍼레이터: curioustore · ✅ 재검증: 2026-07-19
🌐 English: [README.md](./README.md)

> **무엇이 재현되고 무엇이 아닌가.** *복구 동작*은 결정론적이고 정확히 재현된다 — 스텝 도중 크래시는
> 기록 안 된 스텝만 재실행하고, 완료된 스텝은 절대 재실행 안 하며, 앱 버전이 다르면 워크플로가 PENDING으로
> 남고, SQLite 시스템 DB는 항상 같은 10개 테이블을 가진다. 절대 **복구 지연**(0.01~0.06초)은 실행마다·머신마다
> 흔들리므로 주장이 아니라 관찰이다. `probe.py` 전체를 2026-07-19에 재실행(새 venv, dbos 2.27.0)했고 아래 발견은
> 전부 그대로였다.

## 주장 ↔ 근거

`probe.py`가 5개 실험을 각각 독립 work dir + 고정 workflow id(`kill-test-1`)로 돌린다. ground truth는
**append-only 원장**(`ledger.txt`)이다: 각 스텝이 체크포인트 *이전에* `stepN EXECUTED`를 기록하므로,
원장은 실제 (재)실행을 모두 남긴다 — 이게 "스텝이 다시 돌았다"와 "DBOS가 함수를 실행하지 않고 기록된 output을
리플레이했다"를 구분하는 근거다. 하드킬은 `os._exit()`(파이썬 `finally`도 안 도는 즉사)다.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 스텝 도중 하드킬 → 재기동만으로 워크플로가 완주 | `results.json` → `findings[kill_test_mid_step]` | step3가 output 기록 전 죽음(`os._exit(42)`); 재기동 시 **step1/2는 리플레이**(재실행 X), **step3만 재실행**, 이후 4/5 → **SUCCESS**. 서버·큐 없음 — `pip install dbos` + 데코레이터 + SQLite 기본값 |
| at-least-once의 단위는 **스텝** | `results.json` → `findings[step_is_at_least_once]` | step3 **완료 직후** 크래시 → 재기동은 step3를 **재실행하지 않고** step4부터 이어감. 완료(체크포인트)된 스텝은 재실행 X, 기록 전 죽은 스텝만 재실행 |
| 그래서 스텝 안 부작용은 **중복 실행될 수 있다** | 같은 finding | 스텝 단위 at-least-once ⇒ 멱등키는 여전히 사용자 몫; "exactly-once"는 각 스텝이 멱등할 때만 워크플로에 성립 |
| "마법"의 실체는 **데이터베이스** | `results.json` → `findings[recovery_is_db_replay]` | 시스템 DB = **10개 테이블**, 164KB; `operation_outputs`에 스텝별 `function_id` + 직렬화 output; 복구는 기록된 output을 *함수 실행 없이* 반환. `workflow_status.recovery_attempts=2` |
| 코드(앱 버전)가 바뀌면 **복구가 멈춘다** | `results.json` → `findings[version_trap]` | `alpha`로 크래시; `beta`로 재기동 → 30초 내내 **PENDING**(버전 불일치 프로세스엔 안 넘김); `alpha`로 재기동 → 즉시 **SUCCESS** |
| 지속성엔 **스텝당 비용**이 있다 | `results.json` → `metrics[durability_tax_ms_per_step]` | no-op 스텝 200개 ≈ 0.46초 vs 순수 호출 ~9e-06초 → **스텝당 ~2.3ms**(체크포인트 쓰기). 루프 안 잔호출을 스텝화하지 말 것 |
| DBOS 2.27.0은 **며칠 전** 릴리스, SQLite가 **기본값** | `manifest.json` → `subject.freshness_note` + 공식 docs | 2026-07-14 릴리스; "By default, DBOS uses SQLite, which requires no configuration". 2.28.0 알파가 매일 올라옴 |

## 신선도 — hook을 과장하지 않는다

- **durable execution은 새 패턴이 아니다.** Temporal(2019)이 카테고리를 정의했고 Azure Durable Functions는
  그보다 앞선다. 2026에 신선한 건 (a) **AWS Lambda durable functions**(2025-12, H1 2026 롤아웃)의 주류화,
  (b) DBOS의 **라이브러리-only + SQLite 기본값** 접근이 진입장벽을 `pip install` 하나로 낮춘 것이다.
- 글은 이를 명시하고 DBOS가 durable execution을 발명했다고 주장하지 **않는다**.

## 솔직히 검증 안 한 것 / 정직한 한계

- **SQLite 백엔드만.** 프로덕션 권장 **Postgres**는 체크포인트마다 네트워크 RTT가 더해진다 —
  그쪽 durability tax는 *더 크다고 인용만, 실측 아님*.
- **DBOS는 재기동 시 복구할 뿐, 프로세스를 부활시키진 않는다.** supervisor(systemd/k8s/사람)가 재시작해야 한다.
- **단일 프로세스 복구만.** 멀티 executor·분산 복구·큐 경합은 미테스트.
- **Python SDK만.** TS/Go/Java SDK는 설계는 같으나 미실행.
- **복구 지연은 벤치마크가 아니라 관찰** — 표본 작고 머신 종속.

## 하네스

`probe.py` — 한 파일, 7개 모드: `run`(baseline), `crash-during`/`crash-between`(두 크래시 지점),
`resume`(재기동+자동복구 대기), `inspect`(SQLite 시스템 DB 덤프), `overhead`(durability tax), `status`.
결정론적: 고정 workflow id, 고정 스텝 수, RNG 없음, 스텝 안 시계 읽기 없음. 실행한 파일 그대로 커밋.

## 재현

```bash
./run.sh          # bash + python 3.11+ 필요; 임시 venv(dbos==2.27.0) 만들고 지움
```

기대: 스텝 도중 크래시는 기록 안 된 스텝만 재실행 · 완료 스텝은 재실행 X · 버전 불일치 → PENDING ·
로컬 SQLite에서 스텝당 ~1~10ms.

## 환경

Windows 11 x64 (네이티브, WSL/Docker 없음) · CPython 3.11.9 (venv) · **dbos 2.27.0** ·
SQLAlchemy 2.0.51 · 백엔드 = **SQLite**(DBOS 기본값, 서버 0). **DBOS 버전이 load-bearing 변수** —
API 표면이 minor마다 바뀌므로 `2.27.0`으로 핀 고정.
