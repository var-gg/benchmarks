# Jujutsu (jj) 0.43 — `jj bisect run`에게 버그 심은 커밋을 찾게 하다

📝 글: [KO](https://var.gg/ko/blog/jujutsu-jj-bisect-run) *(한국어 전용; 영어 글 없음)*
🗓 실행: 2026-07-15 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> **무엇이 재현되고, 무엇이 안 되나.** 여기 jj 동작은 핀 고정된 0.43.x에 대해 결정론적이다:
> bisect는 같은 히스토리를 같은 first-bad 커밋으로 같은 단계 수에 좁히고, `jj file search`도
> 같은 리비전에서 hit/miss 한다. 딱 하나 **바이트 단위로 재현되지 않는 것**은 **change-id /
> git 해시 문자열**(`xuspwrqt`, `2e5a1b9`, …)이다 — jj는 change-id를 **repo마다 무작위로**
> 부여하므로 그건 실행마다 다른 라벨이지 안정적 식별자가 아니다. 재현의 대상은 **방법**과
> **first-bad 설명**이지 id 문자열이 아니다. `manifest.json` → `determinism` 참조.

## 주장 ↔ 근거

데모는 **선형 8커밋 히스토리**를 만들고, `mean()`에 off-by-one 버그 **하나**
(`sum(xs) / (len(xs) - 1)`)를 `refactor: tweak mean() internals` 커밋에 심는다. 나머지 커밋
(`total`, `median`, `variance`, docstring, `minmax`)은 무관하다. `jj bisect run`이 필요로 하는
건 한 줄 테스트 — `mean([2,4,6]) == 4` — 뿐이다.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `jj bisect run`이 **버그 심은 커밋을 자동으로 찾음** | `harness/bisect-output.txt` · `results.json` → `support_matrix[bisect_run_finds_planted_bug]` | first bad = **`refactor: tweak mean() internals`**, 6후보를 **3회 평가**로 좁힘 |
| 테스트의 **exit code**가 good / bad / skip / abort를 결정 | `results.json` → `support_matrix[bisect_exit_code_protocol]` | `0`=good · nonzero=bad · `125`=skip · `127`=abort · `$JJ_BISECT_TARGET`=검사 중인 커밋 · `--find-good`로 방향 반전 |
| `jj file search`는 **체크아웃 없이 임의 리비전의 트리**를 검색 | `harness/setup.sh` · `results.json` → `support_matrix[file_search_any_revision]` | `--pattern variance` → `@`에서 hit, `variance()` 커밋 이전 리비전에서 **빈 결과** |
| **colocate** repo는 일반 `git`이 jj 커밋을 그대로 봄 | `harness/setup.sh` · `results.json` → `support_matrix[git_colocation]` | `git log`가 jj 커밋을 verbatim으로 표시 — jj는 git을 대체가 아니라 **위에 얹힘** |
| **operation log**가 탐색을 완전히 undo 가능하게 함 | `harness/bisect-output.txt`(마지막 줄) · `results.json` → `support_matrix[operation_log_undo]` | 탐색 종료 시 임시 리비전을 폐기하는 정확한 `jj op restore <id>`를 출력 |

## freshness — hook을 과장하지 말 것

- **`jj bisect run`은 신규가 아니다.** **0.33.0(2025-09)**에 도입됐지 0.43이 아니다. 글은 이걸
  분명히 밝힌다. 진짜 최근 표면은 **`jj file search`(0.41, 2026-05)**와 0.42/0.43 라인
  (0.42의 mimalloc 할당자)이다.
- jj는 Google의 Martin von Zweigbergk가 만든 Rust VCS로 **git on-disk 포맷**(진짜 git 커밋)을
  쓴다. 여전히 **0.x**(pre-1.0). GitHub releases + changelog + docs.jj-vcs.dev 교차확인
  (2026-07-15).

## 정직하게 검증 안 함 / 정직한 한계

- **bisect는 단조성(monotonicity)을 가정** — first-bad 커밋의 모든 자손도 bad라고 본다. 버그가
  나타났다 사라졌다 다시 나타나는 비단조 버그는 이 가정을 깨뜨린다. 데모 히스토리는 의도적으로
  단조롭게 구성했다.
- **`jj file search`는 초기판(0.41).** `--help`에 glob matching 기본(regex는 요청 시), 동시 검색
  없음, **파일 내 매치 위치(줄) 미표시** — **파일 목록**만 준다(줄 번호 아님).
- **여전히 0.x.** minor 릴리스 간 flag·출력이 바뀔 수 있다; 정확한 재현엔 `0.43.x`를 핀 고정.
- **대형 repo 성능은 측정 안 함** — 여기는 8커밋 장난감 히스토리다.
- **Windows만 실행**(아래 MAX_PATH 우회). bisect 로직은 OS 독립적이지만 macOS/Linux 실행은
  캡처하지 않았다.

## 하네스

`harness/setup.sh`가 데모 전체다: **colocate** jj/git repo를 init하고, 8커밋 히스토리를 만들고,
`mean()` 버그를 심고, `jj bisect run`을 돌린 뒤 `jj file search`를 시연하고 `git log`가 같은
커밋을 보는 걸 보여준다. `harness/bisect-output.txt`는 2026-07-15 실행의 `jj bisect run`
**verbatim** 트랜스크립트다. 사설 코드는 전혀 없다 — fixture는 매번 새로 생성되고, repo 상태는
여기 커밋하지 않는다.

## 재현

```bash
./run.sh          # jj 0.43.x가 PATH에 필요 (또는 JJ=/path/to/jj), python + git
```

`run.sh`는 jj 버전을 가드하고(0.43.x가 아니면 크게 경고), **짧은** temp work dir를 만들고
(Windows MAX_PATH: jj index segment 파일명이 ~128자라 긴 부모 경로에서 `os error 3` 발생),
`harness/setup.sh`를 구동한다. bisect가 **`refactor: tweak mean() internals`**를 **3회 평가**로
first-bad 보고, `file search`가 `@`에서 hit·이전 리비전에서 빈 결과, `git log`가 jj 커밋을
보여주는 걸 확인할 수 있다 — 단 change-id/해시 문자열은 설계상 기록된 트랜스크립트와 **다르다**.

## 환경

Windows 11 (win32) · jj **0.43.0-89f62ede** (prebuilt `jj-v0.43.0-x86_64-pc-windows-msvc.zip`,
2026-07-01 release) · git colocate · Docker **미사용**. **jj 버전이 load-bearing 변수**이지
OS가 아니다.
