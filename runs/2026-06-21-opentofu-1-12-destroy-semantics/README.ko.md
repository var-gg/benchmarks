# OpenTofu 1.12 destroy / state 시맨틱 — firsthand

📝 글: https://var.gg/ko/blog/opentofu-1-12-destroy-semantics
🗓 실행: 2026-06-21 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"OpenTofu 1.12를 로컬에 물려 돌려보니 destroy가 더 이상 지우지 않더라"*고 주장한다.
> 이 디렉터리가 바로 그 실행이다 — `.tf` fixture·환경·관찰된 plan 동사와 종료 코드를 그대로
> 담아, 주장을 그냥 믿지 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현되며, `hashicorp/local`
> provider만 쓰므로 클라우드 계정이 필요 없다.

> ⚠️ **백필 안내.** 실험은 2026-06-21(글 발행 당일)에 firsthand로 돌렸고, 여기 관찰값은 그
> 세션에서 나온 것이다. 당시의 즉석 셸 명령을 그대로 보관하지는 않았으므로 하네스(`run.sh` +
> fixture)는 **문서화된 단계에서 재구성**했다. 문서화된 동작을 재현할 뿐, 새로 측정한 값이
> 아니다. `manifest.json.backfill_note` 참조.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 항목으로 추적된다. 유일한 cross-tool
주장(Terraform은 어떻게 동작하나)은 문서 인용이며 *실측 아님*으로 표기했다 — 글에서도 동일하다.

### Firsthand (OpenTofu 1.12.0에서 관찰, 1.12.3 재확인)

| 글의 주장 | 근거 | 관찰 |
|---|---|---|
| `prevent_destroy`가 이제 **표현식** — `prevent_destroy = var.lock`은 1.11이 validate에서 거부, 1.12는 수용 | `results.json` → `var_driven_prevent_destroy` + `fixtures/exp-a.tf` | 1.11: "Variables not allowed"; 1.12: 수용; `lock=true`면 destroy 차단, `lock=false`면 허용 |
| **관리 리소스**의 `lifecycle { destroy = false }`는 destroy를 **"forget"**으로 바꾼다(state만 제거, 파일 유지) + OpenTofu가 orphan을 알리려 **비정상 종료** | `results.json` → `managed_destroy_false_forget` + `fixtures/exp-b.tf` | `Plan: … 1 to forget.`, exit 1, `keep.txt` 생존; `-suppress-forget-errors` → exit 0 |
| `destroy = false`가 `prevent_destroy = true`보다 **우선** — "보호했다고 믿은" 리소스가 조용히 forget됨 | `results.json` → `precedence_destroy_false_over_prevent_destroy` + `fixtures/exp-d.tf` | `1 to forget`, `both.txt` 존재, prevent_destroy 차단 안 함 |
| lifecycle **없는** `removed` 블록은 OpenTofu에서 **forget**이 기본(실물 유지) + 경고 | `results.json` → `removed_block_default_forget` + `fixtures/exp-r-*.tf` | 경고 + `1 forgotten`, `demo.txt` 존재 |
| 로컬 백엔드가 이제 **pretty-print JSON** state를 쓴다 | `results.json` → `pretty_printed_state` | 들여쓴 `terraform.tfstate`, version 4 |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| Terraform은 `removed` 블록에 lifecycle이 없으면 **destroy**가 기본(forget 아님) | HashiCorp 문서 — 여기서 `terraform` 바이너리는 실행 안 함 |
| CHANGELOG PR 번호 (#3474/#3507, #3409, #3588, #1947) | 1.12.0 zip에 동봉된 CHANGELOG.md |
| v1.12.x는 2027-02-01까지 지원 | OpenTofu 릴리스 정책 |

## 환경

Windows 11 · OpenTofu **1.12.0** (**1.12.3** 재확인), 로컬 백엔드 · provider
`hashicorp/local ~> 2.5`. Exp A validate 대조용 baseline **1.11.10**.
하드웨어는 무관 — 타이밍이 아니라 plan/destroy 시맨틱이다.

## 재현

```bash
./run.sh          # PATH에 `tofu` >= 1.12 필요; 로컬 provider만, 클라우드 불필요
```

각 실험은 plan 동사(`to destroy` vs `to forget`)와 종료 코드를 출력한다 — `results.json`과 대조.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다. `terraform.tfstate`는 절대 경로를 담는 임시
파일이라(재현 가능) 커밋하지 않는다. 지속 증거인 plan 동사·종료 코드는 `results.json`에 있다.
커밋된 하네스·증거의 무결성 해시는 `checksums.txt`.
