# 파이썬 타입 체커 4종 — 같은 코드, 네 가지 판정 (mypy / pyright / pyrefly / ty)

📝 글: [KO](https://var.gg/ko/blog/python-type-checkers-pyrefly-ty)
🗓 실행: 2026-06-30 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-06-30에 이뤄졌고(레포 생성 전), 도구 바이너리와 합성 벤치
> 코드베이스는 디스크 정책상 폐기됐다. `fixture/*`·`gen_codebase.py`·`bench_run.py`·`run.sh`는
> 기록된 방법론에서 **재구성**해 **방법**을 재현할 수 있게 했다. `results.json`의 판정·초 값은
> 한 Windows PC에서의 2026-06-30 스냅샷이다. **ty·pyrefly는 월간 릴리스**라 버전·수치는
> 달라진다 — 지속되는 주장은 개별 초가 아니라 **구조적 발견**이다.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| **주석 없는 매개변수**면 네 도구 모두 본문 버그를 통과, mypy만 건너뛴다고 알림 | `results.json` → `findings[untyped_param_blindspot]` + `fixture/02_untyped_def.py` | 4/4 모두 0; mypy만 `--check-untyped-defs` note. 매개변수에 주석 달면 4/4가 즉시 잡음 |
| **mypy는** `reveal_type`을 **확장(widen)**, 나머지는 `Literal` 보존 | `results.json` → `findings[reveal_widening]` + `fixture/04_reveal.py` | mypy `tuple[int, str]` vs `tuple[Literal[1], Literal['two']]` |
| pyrefly/ty는 `reveal_type` 미임포트에 **깐깐** | `results.json` → `findings[rust_pedantry]` | pyrefly/ty 진단 출력; mypy/pyright 침묵 |
| Rust 도구가 **cold ~15-30× 빠름**, mypy **warm**은 Rust급 | `results.json` → `experiment_b_speed` | ty 0.19s / pyrefly 0.24s / mypy cold 3.24s → warm 0.27s / pyright 5.9s |
| pyright CLI는 **증분 캐시 없음** | `results.json` → `experiment_b_speed.rows[pyright]` | cold 5.92s ≈ warm 5.90s |
| pyrefly는 **config 없으면** 0 errors + exit 0 (검사 안 함) | `results.json` → `findings[pyrefly_config_footgun]` | "0 errors" + "Run pyrefly init"; config 있어야 실제 검사 |
| pyright는 버전 미고정 시 PEP 695에 **보수적** 기본값 | `results.json` → `findings[pyright_conservative_default]` + `fixture/05_match_exhaustive.py` | `type X = ...` → `pythonVersion` 주기 전까지 "requires 3.12+" |

### 정직하게 측정 안 함

- **typing-spec 적합성 순서**(pyright/Zuban > pyrefly >90% > mypy > ty)는 공개 conformance 자료 **인용**이지
  이 벤치로 측정한 값이 아니다.
- 속도 벤치는 **균일·얕은 타입의 합성** 코드베이스다. 무거운 제네릭/오버로드/메타클래스는 도구별로 다르게
  부하가 걸린다. 그리고 **ty는 beta** — 빠른 이유에 "아직 구현 안 한 규칙(strict 모드 없음)"이 포함되니
  절대 격차는 할인해 읽어야 한다. `results.json` → `explicitly_not_verified` 참조.

## 재현

```bash
./run.sh     # PATH에 mypy·pyright(npx)·pyrefly·ty 필요; 두 실험 모두 실행
```

기대: 위 판정 패턴 + cold/warm 속도 형태. 정확한 진단 문구·초는 도구가 움직이면서 2026-06-30
스냅샷과 달라진다 — 예상된 정직한 결과다.

## 환경

Windows 11 · CPython **3.13.13**(uv 관리) · uv 0.11.14 · Node v24.15.0 ·
mypy **2.1.0** / pyright **1.1.411** / pyrefly **1.1.1** / ty **0.0.55**(beta, 빌드 2026-06-26).
