# Astro 7 — Rust 컴파일러 & 에이전트-네이티브 dev 서버 (astro@7.0.6)

📝 글 (KO): https://var.gg/ko/blog/astro-7-rust-agent-native
🗓 실행: 2026-07-09 (포장 2026-07-20) · 🤖 실행 주체: **agent** · 👤 운영자: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"Astro 7에서 직접 빌드해봤다"*고 말한다. 이 디렉터리가 바로 그 실행이다 — fixture,
> 환경, 결정론적 출력까지. 믿음에 기댈 필요 없이 `git clone` 후 `./run.sh`면 `astro@7.0.6`에서
> 그대로 재현된다.

> **백필 주석.** 글은 2026-07-09 발행됐고, 이 run 디렉터리는 2026-07-20에 저작됐다. 원래의
> 임시 하네스는 보존되지 않았으나 모든 fixture와 명령이 원본 workspace에 그대로 기록돼 있어
> 여기 하네스는 충실한 재구성이다. 그리고 **2026-07-20에 `astro@7.0.6`으로 실제 재실행**했다 —
> 종이 백필이 아니다. `probe-result.json`이 그 실제 실행의 출력이다.

## 주장 ↔ 근거

글의 모든 **firsthand** 주장은 `results.json` / `probe-result.json`의 체크로 매핑된다.
"예전 동작" 대비는 *인용(cited), 측정 아님* — Astro 6는 여기서 설치하지 않았다.

### Firsthand (astro@7.0.6, Node v24.15.0, Windows 11에서 측정)

| 글의 주장 | 근거 | 결과 |
|---|---|---|
| Rust 컴파일러가 **무의미한 JSX 공백을 접는다** — `<span>` 사이 개행이 가시 공백을 안 만듦 | `probe-result.json` → `exp_A1_whitespace_collapse` (`fixtures/index.astro`) | `<p><span>Hello</span><span>World</span></p>` → **PASS** |
| **닫히지 않은 `<p>`는 하드 컴파일 에러** (빌드 실패, exit 1) — 조용히 자동삽입 안 함 | `probe-result.json` → `exp_A2_unterminated_tag` (`fixtures/broken.astro`) | exit **1**, `CompilerError: Expected corresponding JSX closing tag for 'p'` |
| 실패가 **Rolldown 경유** (Vite 8 백엔드 확인) | `probe-result.json` → `exp_A2…via_rolldown` | **true** |
| **에이전트-네이티브 배경 dev 서버**: `--background` detach + pid 보고, `status`가 background 표시, `.astro/dev.json` lockfile 추적, 중복 `stop`도 exit 0 | `probe-result.json` → `exp_B_background_dev_server` | 4 / 4 **true** |
| **GFM 마크다운 내장** — 표·취소선·각주·태스크리스트가 remark/rehype 플러그인 **0개**로 렌더 | `probe-result.json` → `exp_C_gfm_builtin_no_plugins` (`fixtures/post.md`) | 4 / 4 **true** |

### 인용, 측정 아님 (글에서도 그대로 표시)

| 주장 | 출처 |
|---|---|
| Rust 컴파일러 단독은 빌드시간 개선의 ≈6%; 15–61% 헤드라인은 대부분 Vite 8 / Rolldown | Astro 7 릴리스 노트 |
| Astro 6의 Go 컴파일러는 공백 보존 + 닫힘 태그 자동삽입 | Astro 마이그레이션 가이드 |

### 명시적으로 측정 안 함

- **빌드/설치 시간**은 의도적 제외 — 머신 의존 비결정론이라 근거로 안 씀. pass/fail 동작만 근거.
- 모든 before/after 대비의 **Astro 6 쪽**은 인용이지 실행이 아니다.

## 환경

Windows 11 · Node **v24.15.0** · npm 11.12.1 · **astro 7.0.6** (Rust 컴파일러, Vite 8 / Rolldown).
하드웨어는 무관 — 타이밍 벤치가 아니라 컴파일러 동작·CLI 라이프사이클 검증이다.

## 재현

```bash
./run.sh    # ./work에 astro@7.0.6 스캐폴드, fixtures/ 투입, 빌드 + dev 서버 구동
```

이후 재생성된 `probe-result.json`을 커밋된 `results.json`과 대조. `exp_A2`는 빌드 **실패**(exit 1)가
정상 동작임을 단언한다.

## 파일

| 파일 | 설명 |
|---|---|
| `run.sh` | 하네스. 최소 `astro@7.0.6` 프로젝트 스캐폴드 → `fixtures/` 투입 → 네 가지 체크 실행. |
| `fixtures/index.astro` | A1: 개행으로 분리된 `<span>` 두 개 (공백 접힘 fixture). |
| `fixtures/broken.astro` | A2: 닫히지 않은 `<p>` (하드 에러 fixture). |
| `fixtures/post.md` | C: GFM 표/취소선/각주/태스크리스트, 플러그인 0. |
| `probe-result.json` | 하네스 원시 출력(네 체크). 결정론적. |
| `results.json` | 주장 대면 요약: 동작, 인용-vs-측정 구분, 한계. |
| `manifest.json` | 환경·버전·`executed_by`·백필 주석·보존 정책. |
| `checksums.txt` | 커밋된 하네스 + 근거의 sha256. |
