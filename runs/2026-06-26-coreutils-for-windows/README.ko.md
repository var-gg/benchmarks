# Microsoft Coreutils for Windows 2026.6.16 — 방언 디스패치와 도구 간 동작

📝 글: https://var.gg/ko/blog/coreutils-for-windows
🗓 실행: 2026-06-26 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ⚠️ **backfill** (`manifest.json` 참조)
🌐 English: [README.md](./README.md)

> 글은 *"네이티브 Windows에 Microsoft Coreutils를 깔고 grep·find·sort를 System32·PowerShell·
> Git Bash와 직접 붙여봤다"*고 주장한다. 이 디렉터리가 그 실험이다 — fixture·하네스·관측된 동작
> 매트릭스를 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다. Windows + Git Bash에서 `./run.sh`가
> 핀 고정 **Coreutils 2026.6.16**으로 재현한다.

## backfill 정직성

이 run 디렉터리는 2026-08-06에, 원래 2026-06-26 실험의 firsthand 노트로부터 저작했다. 원본
임시 스크립트와 내려받은 바이너리는 발행 후 정리 정책으로 삭제됐으므로, 여기의 `run.sh`/`probe.sh`는
**재구성한** 하네스다 — 동일 fixture를 다시 만들고 같은 명령을 핀 고정 바이너리에 다시 돌린다.
`results.json`은 2026-06-26의 관측을 기록하고, 하네스는 그것을 재확인하게 해준다. 지어낸 측정치는
없다. 측정이 아니라 Microsoft 문서로 확인한 항목은 *인용(실측 아님)*으로 분리했다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json.behaviors_verified` 한 항목 + `probe.sh` 한
스텝으로 추적된다.

### Firsthand (Coreutils 2026.6.16, 네이티브 Windows 11에서 관측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 하나의 multi-call 바이너리가 **인자 형태로 DOS/Unix 방언을 가름** (`find /C` vs `find -type f`, `sort /R` vs `sort -n`) | `dual_dispatch_shim` | 확인 |
| coreutils `find`(트리 순회)와 System32 `find.exe`(파일 내 검색)는 **의미가 정반대**; GNU식 인자는 System32 find에서 오해됨 | `find_semantic_collision` | 확인 |
| 바이너리가 **자체 Windows-CRT argv 글로빙**을 해서 `find -name *.txt`가 따옴표 없이는 깨짐 — 따옴표 생존은 cmd/PowerShell마다 다름 | `argv_wildcard_globbing` | 확인 |
| 숫자정렬 3-way; coreutils `sort -n`만 진짜 숫자정렬 | `numeric_sort_three_way` | 2,9,10,30,100 vs 10,100,2,30,9 |
| coreutils sort는 **로케일 인식 + `LC_ALL=C`로도 바이트순 강제 안 됨** — CI `LC_ALL=C sort` 결정성 트릭이 안 통할 수 있음 | `locale_collation_trap` | `od` 바이트로 확인 |
| 줄끝 처리가 도구마다 다름: **grep은 `\r` 제거, sort는 `\r\n` 보존**; `wc -c`가 30 vs 26 바이트 차이를 드러냄 | `crlf_handling_divergence` | 30B / 26B |
| grep 0.1.0은 **ERE(`-E`)·PCRE(`-P`)** 되지만 LANG/localization 아직 없음 | `grep_regex_modes` | match / match |

### 인용 (실측 아님 — 글에서도 동일 표기)

| 주장 | 실측 안 한 이유 |
|---|---|
| uutils GNU test-suite 호환률 (0.8.0 ~94.7%, 0.9.0 ~90.6%) | **Linux 실행** 기준, Windows end-to-end 아님 |
| 설치 = hardlink + PowerShell 프로필 + 레지스트리 설정 | 무인 실행은 argv0 **셰임 사본**(동작 동일)을 썼고 실제 설치는 안 함 |

### 근사치 — 명시적으로 주장 아님

600k줄 / 28.6MB 파일 warm 단발에서 coreutils와 Git Bash는 **같은 자릿수**였다(grep ~109ms vs
~67ms; sort ~135ms vs ~130ms). 타이밍은 하드웨어/캐시 의존이라 **벤치 수치로 커밋하지 않는다** —
글은 성능 우위를 주장하지 않는다. 보고 싶으면 `WITH_BIG=1 ./run.sh`.

## 환경

Windows 11 Pro 26200 (ko-KR) · 네이티브 `cmd.exe` + PowerShell + Git Bash, Docker 미사용 ·
Microsoft Coreutils **2026.6.16** (uutils 0.8.0, grep 0.1.0).

## 재현

```bash
# Windows Git Bash:
./run.sh                 # 핀 고정 coreutils 확보 → argv0 셰임 → fixture → probe
WITH_BIG=1 ./run.sh      # 28MB 성능 fixture도 생성 (선택)
```

`run.sh`는 PATH에서 `coreutils.exe`를 찾거나, `COREUTILS_ZIP_URL`을 주면 핀 고정 포터블 zip을
받는다(2026.6.16 x64 자산은 microsoft/coreutils 릴리스 페이지에서 정확한 태그 확인). 이후
`probe-output.txt`를 `results.json`과 대조한다.

fixture·shims·`probe-output.txt`는 `.gitignore` 대상이다 — 재현 가능하고, CRLF fixture를
커밋하면 git이 검증 대상 바이트를 훼손하기 때문이다.
