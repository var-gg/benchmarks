# Go 1.26 Green Tea GC — 왜 어떤 팀은 35%를 보고 어떤 팀은 아무것도 못 봤나

📝 글: [KO](https://var.gg/ko/blog/go-126-green-tea-gc) *(한국어만 발행)*
🗓 실행: 2026-07-19 · 🤖 실행 주체: **agent** · 👤 운영자: curioustore
🌐 English: [README.md](./README.md)

> **엇갈린 보고 자체가 실험 대상이다.** Go 팀은 "GC를 많이 쓰는 프로그램에서 GC 오버헤드
> 10~40% 감소"라고 했고, tile38은 ~35%를 보고했지만, DoltHub는 2025-09 실험에서 **사실상
> 중립**이라고 보고했다. 그래서 애플리케이션을 하나 더 벤치마킹하는 대신, 그 보고들이
> 갈리는 축 — **힙의 포인터 밀집도** — 만 스윕했다. 같은 툴체인 변경이 한쪽 끝에서는
> −77%, 다른 끝에서는 무변화를 내는 것을 한 대의 머신에서 한나절에 보여준다.

## 주장 ↔ 근거

같은 소스를 하나의 툴체인(`go1.26.5`)으로 두 번 빌드 — 기본(Green Tea) vs
`GOEXPERIMENT=nogreenteagc`(구 GC) — 세 가지 힙 모양에서 실행. live heap ~400MB,
`GOGC=100`, 중앙값 n=5(flat은 n=3). 지표는 `runtime.MemStats.GCCPUFraction`.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 포인터가 빽빽한 힙에서 GC 오버헤드가 크게 줄었다 | `results.json` → `metrics[gc_cpu_fraction_by_heap_shape]` | tree **10.30% → 2.38%**(−77%), graph **5.72% → 1.72%**(−70%) |
| …그리고 그게 실제 실행 시간으로 이어졌다 | `results.json` → `metrics[wall_time_by_heap_shape]` | tree **4772.6ms → 3377.3ms**(−29%), graph 7540.0 → 6506.4ms(−14%) |
| 포인터 없는 힙에서는 **아무 일도 없다** | 위 두 표 | flat GC CPU 0.34% → 0.09% — 비율은 진짜지만 크기가 무의미 — 실행 시간 **201.9ms → 200.8ms(−0.5%)** |
| 이득은 "GC를 덜 함"이 아니라 **사이클당 비용이 싸짐** | `results.json` → `metrics[gc_cycle_count]` | GC 횟수 35→31, 15→14, 12→12인데 GC CPU는 3~4배 감소 |
| 우리 −77%는 서비스가 기대할 값이 **아니다** | `results.json` → `findings[micro_bench_amplifies]` | 이 하네스는 할당·폐기만 하므로 GC 비중이 과장된다. 계획에 쓸 숫자는 Go 팀의 10~40%다. |
| 구 GC는 사라진다 | `manifest.json` → `subject.freshness_note` | 옵트아웃은 빌드타임 `GOEXPERIMENT=nogreenteagc`이고, 1.26 릴리스노트는 "Go 1.27에서 제거될 것으로 예상"이라고 명시 |

## 2026-07-24 재검증 — 어긋난 부분까지 함께

같은 머신에서 `go1.26.5`를 새로 받아 `run.sh`를 `SMOKE=1`(live=100MB, churn=10,
**n=1**)로 재실행했다:

| 힙 모양 | 구 GC의 GC CPU | Green Tea GC CPU | 변화 | 기록된 변화 |
|---|---|---|---|---|
| tree | 11.63% | 2.65% | **−77%** | −77% ✅ |
| graph | 6.15% | 2.07% | −66% | −70% ✅ |
| flat | 0.34% | **0.66%** | **+97%** ⚠️ | −73%(노이즈) |

tree는 헤드라인 수치를 퍼센트 단위까지 그대로 재현했다. 반면 flat은 **부호가 뒤집혔고**,
graph는 GC CPU가 3분의 2로 줄었는데도 실행 시간이 **+17%**로 나왔다. 두 셀 모두 스모크
규모에서는 GC 사이클이 **2회**밖에 돌지 않는다 — 원래 실행이 이미 달아둔 "flat은 노이즈"
경고가 주장이 아니라 실물로 드러난 셈이다. 이건 "tree가 이겼다"를 반박하는 게 아니라
"flat은 못 믿는다"를 뒷받침한다. 여기 숫자를 `results.json`과 비교하려면 반드시 전체
설정(`N=5 LIVE_MB=400 CHURN=60`)으로 돌려야 한다.

## 정직하게 — 검증하지 **않은** 것

- **Windows/amd64만.** Linux·macOS·ARM64 미측정. Green Tea의 벡터 스캔 경로는 amd64
  전용이라 ARM64 거동은 이 실행이 알지 못한다.
- **AVX-512가 있는 CPU**(Zen 5). 벡터 스캐너의 best case다. AVX-512 없는 구형 amd64를
  재보지 않았으므로 "새 알고리즘"과 "벡터 명령"의 기여를 분리하지 못한다.
- **pause 분포·tail latency 미측정.** `PauseTotalNs`는 기록했지만 이 규모에선 0~9ms
  노이즈다. 글에서 GC *pause*에 관한 언급은 측정이 아니라 인용이다.
- **동작점 하나** — live ~400MB, `GOGC=100`. 힙 크기·GOGC 스윕 없음.
- **실제 애플리케이션 없음.** tile38의 ~35%, DoltHub의 중립 결과는 그쪽 글에서 인용한
  것이지 재현한 게 아니다. 특히 우리 메커니즘 관찰(횟수 동일, 사이클당 저렴)은 DoltHub의
  서술(횟수 감소, 사이클당 증가)과 **반대 방향**인데, 그 차이는 조사하지 않았다.
- **cgo 호출 오버헤드**(1.26에서 ~30% 개선 보고)는 범위 밖.

## 하네스

`harness/gcbench.go` — 파일 하나, 의존성 없음. 세 가지 모양 중 하나로 ~400MB 상주 힙을
만들고(`tree` = 3포인터 32바이트 노드의 삼진 트리 · `graph` = 각 노드가 무작위 3개를
가리킴 · `flat` = 포인터 없는 int64 슬랩), 같은 모양의 4분의 1 크기 쓰레기를 계속
할당·폐기해 그 상주 힙 위로 GC를 강제한 뒤 `MemStats`를 JSON 한 줄로 출력한다.
`results-raw.jsonl`은 기록된 **26회** 실행의 원본 stdout이라, `results.json`의 모든
중앙값을 원본과 대조해 검산할 수 있다.

## 재현

```bash
./run.sh                          # Go 1.26.x 필요 (또는 GO=/path/to/go1.26.5)
SMOKE=1 ./run.sh                  # 20초 남짓 sanity 확인
N=5 LIVE_MB=400 CHURN=60 ./run.sh # 기록된 설정, 약 4분
```

**Go 1.26.x가 필수이고 그 창은 닫히는 중이다** — Green Tea는 1.26 기본값이고
`nogreenteagc` 옵트아웃은 1.27에서 제거될 예정이라, 그때는 비교 기준을 빌드할 방법 자체가
없어진다.

## 환경

Windows 11 x64(네이티브, WSL/Docker 없음) · AMD Ryzen 9 9950X3D(Zen 5, 16C/32T, AVX-512) ·
GOMAXPROCS=32 · **go1.26.5** · GOGC=100 고정. **Go 버전이 핵심 변수**다. `1.26.5`로
핀 고정할 것 — 1.27은 비교 기준 자체를 빌드할 수 없게 만든다.
