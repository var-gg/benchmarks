# Python 3.15 UTF-8 기본화(PEP 686) — Windows/CP949에서의 조용한 바이트 변화

📝 글(KO): https://var.gg/ko/blog/python-315-utf8-default
📝 글(EN): https://var.gg/en/blog/python-315-utf8-default
🗓 실행: 2026-06-22 · 🔁 재검증: 2026-08-12 · 🤖 실행 주체: **agent** · 👤 운영: curioustore

> 이 글은 *"한국어(CP949) Windows에서 두 인터프리터를 직접 돌려, 같은 한 줄짜리 프로그램이
> 에러 없이 서로 다른 바이트를 쓰는 걸 확인했다"*고 주장한다. 이 디렉터리가 바로 그 실행이다 —
> 하네스·핀 고정 빌드·원시 리포트까지. 믿음이 아니라 `git clone` 후 `./run.sh`로 CP949 호스트에서 재현된다.

> ⚠️ **정직한 백필.** 글의 *원본* 하네스 스크립트는 보존되지 않았고(기록된 실험 로그만 남음),
> 여기의 `probe.py` / `run.sh`는 그 실험의 **충실한 재구성**이다. 그리고 **2026-08-12에 같은 핀
> 고정 빌드·같은 종류의 호스트(Windows, CP949)에서 새로 재실행**했다. 커밋된
> `probe-result.json`은 그 재실행 결과이며 기록된 모든 관찰을 재현한다. `manifest.json.backfilled = true`.

## 왜 하드웨어를 뺐나

이건 타이밍 벤치마크가 아니라 **기본 텍스트 인코딩 계약** 확인이다. 결과는 CPython 빌드와 호스트
**ANSI 코드페이지**에만 의존하고 CPU/GPU/RAM과 무관하다. UTF-8 로캘 호스트에서는 대비가 사라진다
(양쪽 다 UTF-8 기본). 그 의존성 자체가 발견이라, 환경엔 코드페이지(949)만 남기고 하드웨어는 뺐다.

## 주장 ↔ 근거

글의 모든 **firsthand** 주장이 `results.json` / `probe-result.json`의 한 줄로 추적된다.
**CPython 3.14.6(baseline) vs 3.15.0b2(subject)**, 호스트 ANSI 코드페이지 **949**에서 측정.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 기본 텍스트 인코딩이 cp949 → utf-8로 **뒤집힌다**(open/stdio). 단 **파일시스템 인코딩은 양쪽 다 이미 utf-8** | `probe-result.json` → `interpreters.*` | 3.14.6: `cp949`/`cp949`/fs `utf-8` · 3.15.0b2: `utf-8`/`utf-8`/fs `utf-8` |
| **같은 한 줄 프로그램이 다른 on-disk 바이트**를 쓴다(양쪽 무에러) | `results.json` → `exp2_producer_side_byte_shift` | **24바이트(CP949)** vs **32바이트(UTF-8)** |
| **양쪽 다 valid**한 바이트가 **무에러로 다른 문자열**로 디코딩(조용한 손상) | `results.json` → `exp9_silent_divergence` | `c2 af` → **짱** vs **¯** · `eb ac b8 ec 84 9c` → **臾몄꽌** vs **문서** |
| `subprocess(text=True)`로 CP949 출력 캡처: 3.15에선 reader **스레드**가 죽고 `subprocess.run`이 **`stdout=None`, rc 0** 반환 — 출력이 조용히 유실 | `results.json` → `exp7_subprocess_text_reader_thread_crash` | 3.14.6: `'한글상태'` · 3.15.0b2: `None` + `UnicodeDecodeError: ... byte 0xc7 ...` |
| 기본값은 바뀌었지만 **옵트아웃은 그대로**(`PYTHONUTF8` / `-X utf8`) | `results.json` → `exp8_opt_out_toggles` | 3.15 + `PYTHONUTF8=0` → cp949 · 3.14 + `PYTHONUTF8=1` → utf-8 |

### 인용(측정 아님) — 글에서도 동일하게 표기

| 주장 | 출처 |
|---|---|
| PEP 686이 3.15에서 UTF-8 모드를 기본으로 | [PEP 686](https://peps.python.org/pep-0686/) |
| Windows 파일시스템 인코딩은 3.6부터 UTF-8 | [PEP 529](https://peps.python.org/pep-0529/) |
| 정식 3.15.0 동작(3.15.0b2 beta에서 측정) · 정식 인스톨러/Store 빌드 | PEP 686상 동일 예상, 별도 측정 아님 |

### 정직한 한계

한국어 cross-decode는 *대개* **시끄러운** `UnicodeDecodeError`다 — CP949·UTF-8 한글 바이트 패턴이
서로 대부분 invalid라서. 진짜 **조용한** in-Python 케이스는 양쪽 valid인 특정 구간(exp9)뿐이다.
글은 "시끄러운 실패"와 "조용한 손상"을 뭉뚱그리지 않고 분리 서술한다. embeddable amd64 빌드 ·
3.15.0b2(beta) 기준(`manifest.json` 참조).

## 환경

Windows 11 (10.0.26200) · ANSI 코드페이지 **949 (CP949, 한국어)** · 드라이버 Python 3.11.9.
subject **CPython 3.15.0b2** embeddable-amd64 · baseline **CPython 3.14.6** embeddable-amd64
(둘 다 python.org URL로 핀 고정, `run.sh`가 다운로드).

## 재현

```bash
./run.sh    # 핀 고정 embeddable 빌드 2개 다운로드 → 각 인터프리터로 probe.py 실행
```

재생성된 `probe-result.json`을 커밋된 `results.json`과 비교하라. **non-UTF-8 ANSI 코드페이지
호스트**(essay는 CP949)여야 flip이 나타난다 — UTF-8 로캘이면 no-op다.

## 원시 데이터

폐기 없음. 큰 산출물이 없다. `run.sh`가 embeddable zip을 임시 디렉터리에 받아 종료 시 삭제하며,
URL로 핀 고정될 뿐 커밋하지 않는다. 결정적 근거 `probe-result.json`만 커밋. `checksums.txt` 참조.
