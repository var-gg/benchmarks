# Polars 1.42 스트리밍 엔진 — `engine="streaming"`은 정말 메모리를 바운드하나?

📝 글: [KO](https://var.gg/ko/blog/polars-streaming-engine)
🗓 실행: 2026-07-16 · 🤖 실행 주체: **agent** · 👤 운영자: curioustore
🌐 English: [README.md](./README.md)

> **무엇이 재현되고, 무엇이 재현되지 않는가.** 데이터셋은 결정론적이라(RNG 없음:
> `val = (id*2654435761 % 1000003)/1000`) `polars==1.42.1` 핀 고정 시 쿼리 **체크섬은
> 정확히 재현**되고(`15000032831.613`), 엔진 간 `equals=False`도 재현된다.
> 피크 메모리 **MB 절대값**은 실행마다 ~±10%, 머신마다 다르다 — 내구성 있는 주장은
> **엔진 간 비율**과 **rows-out 패턴**이지 절대 MB가 아니다. `manifest.json` → `determinism` 참조.

## 주장 ↔ 근거

30M행, 2,000그룹, 87MB parquet. 모든 측정은 **독립 subprocess**에서 수행
(Windows `psutil peak_wset` = 진짜 peak working set).

| 글의 주장 | 근거 | 값 |
|---|---|---|
| **행을 줄이는(reducing)** 쿼리에서 스트리밍이 진짜 메모리를 바운드한다 | `results.json` → `metrics[groupby_agg_peak_memory]` | group-by: **366MB** vs in-memory 1035MB vs pandas 2466MB (**2.8x / 6.7x 절약**), 체크섬 동일 |
| join→agg도 마찬가지 | `results.json` → `metrics[per_op_peak_memory]` | equi-join+agg: **667MB** vs 2031MB (**3.0x**) |
| 같은 플래그가 **행 보존** 쿼리에는 아무것도 못 한다 | `results.json` → `metrics[per_op_peak_memory]` | window `.over()`: **스트리밍 1050MB vs in-memory 931MB**(오히려 근소 열세) · 전체 정렬: **2723 vs 2691MB**(무승부, 둘 다 ~2.7GB) |
| 피크 메모리를 정하는 건 플래그가 아니라 **rows-out** | 같은 표 | 30M→2천 행: 2.8~3x 승 · 30M→30M 행: 이점 없음 |
| 결과는 수치적으로 같지만 **bit-identical 아님** | `results.json` → `findings[numerically_equal_not_bit_identical]` | `equals()`=False; `val_sum` 최대차 **1.02e-08**(2000그룹 중 1392), `val_mean` 6.8e-13; 정수/max는 bit-exact — float 덧셈 비결합성 |
| 엔진은 **opt-in이지 기본값이 아님** (1.42.1) | 공식 docs + `manifest.json` → `subject.freshness_note` | `collect(engine="streaming")`; docs: "not the default" / "will become the default in time" ([#20947](https://github.com/pola-rs/polars/issues/20947)) |

## Freshness — hook 과장 금지

- 새 스트리밍 엔진은 **"방금 안정화"된 게 아니다** — ~1.31부터 opt-in으로 존재했고 2026 내내
  확장됐다(1.37 sink, 1.38 streaming join, 1.39 asof join). **1.42.1(2026-06-30) 기준 여전히
  기본값 아님.**
- "1.41에서 기본값이 됐다"는 2차 요약들은 공식 docs와 교차검증 결과 **틀렸다** — 글에도 명시.

## 정직하게 검증 안 된 것 / 정직한 한계

- **셀당 n=1** — op/엔진별 1회 실행, 분포 아님. 주장에 쓴 비율(2.8~6.7x)은 충분히 크지만,
  작은 차이(931 vs 1050)는 노이즈에 가깝게 취급할 것.
- **87MB parquet은 RAM에 들어간다.** 엔진별 메모리 *바운딩* 거동을 측정한 것이지, 진짜
  RAM 초과 out-of-core 워크로드가 아니다.
- 어떤 op가 조용히 in-memory로 **fallback**했는지는 계측 안 함 — fallback 설명은 공식 docs
  출처, 우리 수치는 피크 메모리 관측일 뿐.
- **Windows 전용.** `peak_wset`은 Windows 전용 지표; 타 OS에선 probe.py가 현재 RSS로
  폴백(더 약한 프록시).
- `rank_over`는 하네스에 있으나 측정 기록이 보존 안 됨 — 미보고.
- 절대 MB에는 CPython+라이브러리 바닥(~100–150MB)이 포함됨.

## 하네스

`harness/probe.py` — 파일 하나, 6개 모드: `gen`(결정론적 parquet, 스트리밍 `sink_parquet`) ·
`measure <engine>` / `pandas`(실험 A) · `equal`(실험 B) · `measop <op> <engine>`(실험 C) ·
`limits`. 각 측정은 독립 subprocess라 피크가 섞이지 않는다. 실행본 대비 유일한 수정은
docstring 정정(`manifest.json` → `harness_provenance`).

## 재현

```bash
./run.sh          # python 3.11+ 필요; 임시 venv + 87MB parquet 생성 후 자동 삭제
```

기대값: 체크섬 `15000032831.613` 정확 일치 · group-by/join에서 스트리밍 ~2.8–3x 절약 ·
window/sort에선 이점 없음 · `equal`은 `false`.

## 환경

Windows 11 x64 (native, WSL/Docker 없음) · CPython 3.11.9 (venv) · **polars 1.42.1** ·
pandas 2.3.1 · pyarrow 17.0.0 · psutil 6.0.0. **부하를 지는 변수는 Polars 버전** —
스트리밍 엔진은 빠르게 변하므로 정확한 재현엔 `1.42.1` 핀 고정.
