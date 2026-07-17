# LanceDB 0.34.0 — 임베디드 검색, 직접 검증

📝 글(KO): https://var.gg/ko/blog/lancedb-embedded-vector-lakehouse
🗓 실행: 2026-07-09 (백필 2026-07-18) · 🤖 실행: **agent** · 👤 오퍼레이터: curioustore
🌐 English: [README.md](./README.md)

> 이 글은 LanceDB 0.34.0을 **로컬에서 직접 돌려** 확인한 것들을 주장한다 — 서버·Docker·GPU·
> 네트워크 0, 로컬 파일만. 이 디렉터리가 그 실행의 방법이다: 하네스·환경·결정적 출력.
> `git clone` 후 `./run.sh`면 재현된다.

## 백필 정직성

글은 2026-07-09에 작성됐고, 당시 임시 하네스는 유한 디스크 정책에 따라 삭제됐다. 여기 `probe.py`는
워크스페이스 `firsthand-benchmark.md`에 기록된 방법론에서 **재구성**했고, 같은 핀 버전
`lancedb==0.34.0`으로 **2026-07-18에 다시 실행**했다. 무엇이 일치하고 무엇이 드리프트했는지는
`manifest.json.reproduction`과 `results.json.reproduction_2026_07_18`에 그대로 적었다 — 원본 그대로인
척하지 않는다.

## 주장 ↔ 근거

### 직접 검증 (lancedb 0.34.0에서 재현됨)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `connect(dir)`은 임베디드 — 데몬 없는 in-process 핸들, 데이터는 온디스크 `.lance` 파일 | `probe-result.json.connection_type` | `LanceDBConnection` |
| exact top-k는 결정론적, `_distance`는 **제곱 L2**(0.02 = 0.01+0.01, gotcha) | `probe-result.json.exp_b_exact_topk` | 순서 `[0,2,1,3]`, 3회 동일 — **정확 일치** |
| 버저닝/시간여행: 과거 버전 checkout 후 최신 복귀 | `probe-result.json.exp_d_versioning` | v1 = 4행, 최신 = 5행 — **정확 일치** |
| IVF_PQ는 **recall을 속도와 교환**; default nprobes ≈ recall@10 0.7 | `probe-result.json.exp_e_ann_vs_exact` | recall_default **0.7 — 정확 일치** |
| `nprobes`/`refine_factor` 튜닝이 recall을 1.0 쪽으로 **회복** | `probe-result.json.exp_e_ann_vs_exact` | 재실행 튜닝 **0.9**(작성 노트 1.0) — 드리프트 참조 |
| 임베딩 0으로 BM25 전문 검색(`create_index(config=FTS())`) | `probe-result.json.exp_f_fts` | `'fox'` → id `[3, 0]` 재현 |

### 드리프트 (숨기지 않고 명시)

- **EXP E 튜닝 recall**: 2026-07-18 재실행 0.9 vs 2026-07-09 노트 1.0. PQ 코드북(k-means) 초기화가
  완전히 핀 고정되지 않아 튜닝 recall이 **0.9–1.0 밴드**에 든다. *방향*(튜닝이 근사 인덱스가 잃은
  recall 대부분을 회복)은 재현되고, 마지막 소수점은 아니다.
- **EXP F BM25 점수**: `'fox'` 상위 2개 **id**는 재현(`[3,0]`)되지만 절대 BM25 점수는 드리프트하고
  (tantivy 빌드 의존), 원래 FTS **말뭉치 텍스트가 기록되지 않아** `probe.py`가 그럴듯한 말뭉치를
  재구성한다. 따라서 점수는 bit-exact로 주장하지 않는다.

### 인용, 미측정 (글에서도 그렇게 표시)

| 주장 | 출처 |
|---|---|
| 작성 시점 최신 안정판: Python 0.34.0 / Node·Rust 0.31.0 | PyPI / GitHub releases |
| 포지셔닝 이동 "vector database" → "멀티모달 AI용 OSS 임베디드 검색 라이브러리" | lancedb.com / README |
| Lance(컬럼형 레이크하우스 포맷) vs LanceDB(그 위 임베디드 라이브러리); OSS·Cloud가 포맷 공유 | LanceDB 문서 |

## 환경

Windows 11 x64 (네이티브, WSL/Docker/GPU 없음) · Python 3.11.9, 격리 venv · `lancedb==0.34.0`,
`pyarrow==24.0.0`. 로컬 파일 위 임베디드 라이브러리 — 이 동작/recall 결과에 하드웨어·타이밍은 무관.

## 재현

```bash
./run.sh          # venv → 핀 lancedb 0.34.0 → probe.py → probe-result.json
```

이후 `probe-result.json`을 커밋된 `results.json`과 비교. EXP B/D는 bit 단위로 일치, EXP E default
recall도 일치하고, 튜닝 recall과 EXP F 점수는 위 밴드 안에서 드리프트할 수 있다.

## 파일

| 파일 | 설명 |
|---|---|
| `probe.py` | 재구성 하네스 — EXP B(exact/제곱 L2), D(버저닝), E(ANN recall), F(BM25). |
| `probe-result.json` | 2026-07-18 재실행 원시 출력. B/D는 결정론적. |
| `results.json` | 주장 대면 요약: 직접 검증 노트, 재현 델타, 인용 vs 측정 분리. |
| `manifest.json` | 환경·버전·`executed_by`·백필+재현 노트. |
| `run.sh` / `requirements.txt` | 재현. |
| `checksums.txt` | 커밋된 하네스+근거의 sha256. |
