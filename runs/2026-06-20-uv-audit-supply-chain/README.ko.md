# uv audit vs pip-audit — 같은 결과, 약 20× 빠름

📝 글: [KO](https://var.gg/ko/blog/uv-audit-supply-chain) · [EN](https://var.gg/en/blog/uv-audit-supply-chain)
🗓 실행: 2026-06-20 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-06-20에 이뤄졌고(레포 생성 전), 원시 산출물은 디스크 정책상
> 폐기됐다. `run.sh` + `fixture/pyproject.toml`은 기록된 방법론에서 **재구성**해 **방법**을
> 재현할 수 있게 했다. `results.json`의 수치는 **라이브 OSV** 기준 2026-06-20 스냅샷이라
> 오늘 다시 돌리면 OSV 갱신으로 달라진다. 지속되는 주장은 **속도 배수**와 **결과 동일성**이고,
> 정확한 취약점 수는 특정 시점 값이다.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| uv audit이 pip-audit보다 **~20× 빠름** | `results.json` → `metrics[audit_speed]` | 0.82s vs 16.1s warm ≈ **19.6×** (같은 OSV) |
| 두 도구가 **같은** 취약점을 찾음 | `results.json` → `findings[result_parity]` | vuln id 집합 동일(79), 차집합 **0**; PYSEC 18 / CVE 30 / GHSA 30 / SNYK 1 |
| fixture에 **48 취약점 / 6 패키지** | `results.json` → `findings[fixture_detection]` + `fixture/pyproject.toml` | 13패키지 중 48, 6개 취약(2026-06-20 기준) |
| 발견 시 **exit 1** — CI 직결 | `results.json` → `findings[exit_code]` | dirty exit 1 / clean exit 0 |
| 네이티브 **SARIF 2.1.0** 출력 | `results.json` → `findings[sarif]` | rules 48 / results 48, driver uv 0.11.23 |
| `--ignore`가 **alias**로 매칭 | `results.json` → `findings[suppression]` | 한 GHSA id로 48 → 46 |
| `uv audit`은 **preview** 기능 | `results.json` → `findings[audit_is_preview]` | experimental 경고; 플래그는 경고만 끔 |

### 정직하게 검증 안 함

uv의 **malware 검사**는 *별개* 기능 — `uv sync`(설치 시점 게이트)에 붙지 `uv audit`에 붙지 않는다.
활성화·설치 차단·메시지 경로는 확인했으나, 실제 악성 패키지를 설치해 true-positive를 강제하지는
**않았다**(안전). `results.json` → `explicitly_not_verified` 참조. 글도 `audit` ≠ `malware-check`를
동일하게 구분한다.

## fixture

`fixture/pyproject.toml`이 의도적으로 취약한 릴리스(`requests==2.19.1`·`jinja2==2.10`·`pyyaml==5.3`·
`flask==0.12.2`)를 핀 고정해 두 도구가 찾을 게 있게 한다. 이게 재현 입력이자 **드리프트 안 하는** 유일한 것.

## 재현

```bash
./run.sh          # uv 0.11.23+ 필요; fixture resolve 후 uv audit vs pip-audit 시간 측정
```

기대: 두 도구가 **동일한** vuln id 집합을 보고하고, uv audit이 warm 기준 ~20× 빠름.
수는 OSV 갱신으로 2026-06-20 스냅샷과 달라진다 — 예상된 정직한 결과다.

## 환경

Windows 11 · uv **0.11.23**(standalone) · Python 3.12.13(uv 관리) · 데이터소스 **OSV**(라이브).
