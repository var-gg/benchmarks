# zizmor 1.26 — 취약 워크플로 3개에서 오프라인으로 15건 탐지

📝 글: [KO](https://var.gg/ko/blog/zizmor-github-actions-audit)
🗓 실행: 2026-06-27 · 🔁 재검증: 2026-08-05 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 2026-06-27 원래 실행의 임시 fixture는 디스크 정책상 폐기됐다.
> `fixture/.github/workflows/`는 기록된 방법론에서 **재구성**했다. OSV 같은 라이브 DB 백필과 달리
> zizmor `--offline` 스캔은 버전 핀 + 고정 입력이면 **결정적**이라, 재구성한 fixture를 **2026-08-05에
> 다시 돌려** regular 페르소나 결과를 그대로 재현했다(15건, 동일 규칙 분해, 동일 심각도 분포,
> SARIF rules 7 / results 15, exit 14). 아래 수치는 그 재검증 결과다.
> 정직한 한계: pedantic/auditor 페르소나 수는 오늘 24/24로, 기록된 25/26과 1~2건 차이가 난다 —
> 재구성 fixture가 regular 페르소나엔 충실하지만 폐기된 원본과 바이트 단위로 같지는 않기 때문이다.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 취약 워크플로 3개에서 **15건 탐지** | `results.json` → `metrics[regular_findings_total]` | unpinned-uses 7 · artipacked 2 · template-injection 2 · excessive-permissions 1 · dangerous-triggers 1 · unsound-ternary 1 · typosquat-uses 1 |
| 심각도 분포 **High 11 / Medium 3 / Low 1** | `results.json` → `by_severity` | High 11, Medium 3, Low 1 |
| **1.26 신규 audit 2개** 모두 발화 | `results.json` → `findings[new_1_26_audits]` + `fixture/.../release.yml` | typosquat-uses(`actons`→`actions`), unsound-ternary(`&& '' \|\| 'staging'`가 항상 fallback) |
| **완전 오프라인** — 토큰·Docker 불필요 | `run.sh`(`--offline`) → `findings[offline]` | 버전 핀 + 고정 입력이면 결정적 |
| 네이티브 **SARIF 2.1.0** (code scanning) | `results.json` → `findings[sarif]` | driver zizmor 1.26.1, rules 7 / results 15 |
| 발견 시 **exit 14** — CI 게이트 직결 | `results.json` → `findings[exit_code]` | 발견 시 nonzero, clean이면 0 |
| `--fix=all` **자동 재작성** 2종 | `results.json` → `findings[auto_fix]` | ci-deploy 3건(template-injection→env 간접참조, artipacked→`persist-credentials: false`), release 1건 |
| 페르소나 상향 = **신호/잡음 트레이드오프** | `results.json` → `metrics[persona_escalation]` | regular 15 → pedantic 24 → auditor 24 (2026-08-05); 기록 15 → 25 → 26 |

## fixture

`fixture/.github/workflows/` 아래 워크플로 3개, 각각 특정 문제를 심어 둠:

- **ci-deploy.yml** — `pull_request_target` 트리거(dangerous-triggers)에 `${{ github.event.pull_request.title/body }}`를 `run:`에 직접 보간(template-injection 2건), 핀 안 된 `checkout@v4`/`setup-node@v4`/`upload-artifact@v3`, 기본 자격증명 checkout(artipacked).
- **release.yml** — `permissions: write-all`(excessive-permissions), `actons/setup-python` 오타 스쿼트(typosquat-uses), `... && '' || 'staging'`(unsound-ternary), 그리고 핀 안 된 uses + artipacked checkout.
- **lint.yml** — 거의 정상: checkout에 `persist-credentials: false`, 최소권한 `permissions`. 핀 안 된 uses 2건만 남긴다. 도구가 무엇이든 다 잡는 게 아님을 보이려고 포함.

이 fixture가 재현 입력이며, regular 페르소나에서 **드리프트하지 않는** 유일한 것.

## 정직한 한계

- **15건 중 7건이 unpinned-uses** — 태그로 핀한 신뢰 액션(`@v4`)까지 잡는 blanket 정책. False positive가 아니라 정책 선택이며, 태그 핀을 의도했다면 강도를 낮출 수 있다.
- 일부 audit(예: ref-confusion)은 **online** 모드(GitHub API)에서만 완전 동작. offline은 baked-in corpus 기반.
- 정적 분석이라 **워크플로 구조**의 위험만 본다 — 런타임 행위·시크릿 값은 못 본다.
- typosquat은 인기 액션 **내장 목록** 기준 — 무명 액션 오타는 놓칠 수 있다.

## 재현

```bash
./run.sh          # uvx(uv 툴체인) 필요; zizmor 1.26.1 핀 고정 후 fixture 오프라인 스캔
```

기대: regular 페르소나에서 **정확히 15건**, 종료 코드는 nonzero(14).

## 환경

Windows 11 · zizmor **1.26.1**(`uvx`, ephemeral) · 스캔 모드 **offline**(네트워크/토큰/Docker 불필요) · 결정적.
