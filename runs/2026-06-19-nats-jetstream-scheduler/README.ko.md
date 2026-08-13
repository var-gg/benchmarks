# NATS 2.14 JetStream 메시지 스케줄러 — 단일 노드 프로토콜 검증

📝 글: https://var.gg/ko/blog/nats-jetstream-scheduler
🗓 실행: 2026-06-19 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ♻️ **백필**
🌐 English: [README.md](./README.md)

> 글은 *"단일 노드 nats-server 2.14.2에 직접 물려, 무엇을 받아들이고·교체하고·다운샘플하고·
> 재시작에도 살아남는지 봤다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 — 방법·핀 고정 버전·
> 수락/거부 매트릭스를 담아 주장을 그냥 믿지 않아도 되게 한다. 단 **백필**이다: 원본 바이너리와
> JetStream 스토어는 유한 디스크 정책으로 삭제됐고, `run.sh`·`fixture/`는 기록된 방법론에서
> **재구성**했다. 결과가 (라이브 DB 수치가 아니라) 결정적 프로토콜 동작이라, 같은 버전으로
> 재실행하면 재현된다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 줄로 추적된다. 외부 문서 인용은 없고,
전부 검증 대상 서버에서 직접 관측한 것이다.

### Firsthand (nats-server 2.14.2, nats CLI 0.4.0에서 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 스케줄은 별도 API가 아니라 `--allow-schedules` 스트림에 넣는 컨트롤 메시지의 `Nats-Schedule` **헤더**다 | `results.json` → `method` + `run.sh` | 확인 |
| `@every`·`@at <RFC3339>`·`@hourly`·**6필드**(초 포함) cron 수락 | `results.json` → `schedule_syntax_matrix` | 6 / 6 수락 |
| **표준 5필드 crontab은 거부**(가장 먼저 밟는 함정) | `schedule_syntax_matrix` (`* * * * *`, `*/1 * * * *`) | 2 / 2 거부 |
| CLI `nats publish --schedule-after=DURATION`을 **서버가 거부**(error 10189) — CLI↔서버 계약 불일치 | `results.json` → `cli_server_mismatch` | 5회 재현 |
| 같은 subject 재발행 = **원자적 교체**(`Nats-Rollup: sub`) | `results.json` → `behaviors_verified[rollup_replace]` | 확인 |
| `Nats-Schedule-Source` = **다운샘플**, 매 틱 소스의 최신값만 emit | `results.json` → `behaviors_verified[source_downsample]` | `reading-7,13,19,25,30,30` |
| 스케줄은 **재시작 생존**, 만기 지난 일회성은 **1회** 발화, `@every`는 놓친 틱 **backfill 안 함** | `results.json` → `behaviors_verified[restart_durability]` | `df.once: 1`, catch-up 없음 |
| `@every 1s` inter-arrival 정확히 **1.000s, 드리프트 0** | `results.json` → `timing_observation` | 16 발화 |

### 명시적으로 검증 안 함

- **분산 내구성.** 단일 노드뿐. JetStream Raft 복제·리더 장애복구·`--replicas>=3` 보장은
  건드리지 않았다. 글에도 그대로 밝혔다.
- **서브-ms 드리프트.** 정확도는 초 단위 store 타임스탬프 기준.
- **정확히 1회 전달.** JetStream은 at-least-once — 발화 메시지 중복 가능(소비 측 idempotency
  필요). 일반 JetStream과 동일해 여기선 재검증 안 함.

## 환경

Windows 11 x64, 단일 노드(네이티브, Docker/WSL 없음) · nats-server **2.14.2**(JetStream API
Level 4) · nats CLI **0.4.0**. 프로토콜 수락/거부 + 내구성 검증이라 하드웨어가 결과를 바꾸지
않는다(타이밍 1건 제외).

## 재현

```bash
./run.sh          # 서버 기동 -> --allow-schedules 스트림 -> fixture/schedule-cases.tsv 반복
```

`run.sh`는 Part 1(문법 수락/거부 매트릭스)과 Part 2(`--schedule-after` 불일치)를 자동 재현하고,
타이밍/관측형 3종(rollup 교체·source 다운샘플·재시작 내구성)은 수동 재현용으로 문서화한다.
`results.json`과 대조한다.

## 원시 데이터

**백필 — 원본 런에서 보존한 것 없음.** 내려받은 nats-server / nats CLI 바이너리와 임시 `-sd`
스토어는 2026-06-19 이후 삭제됐다(유한 디스크; Docker 미사용이라 `received_images: none`).
당시 해시를 안 떴다. 가짜 아티팩트를 만드는 대신 **재구성** 하네스(`run.sh` + `fixture/`)를
싣고 이 사실을 그대로 밝힌다. `results.json`은 그날 관측한 동작과 단일 타이밍 값을 담는다.
커밋된 하네스의 무결성 해시는 `checksums.txt`.
