# Wasmtime 46 WASI 권한 — 읽기 전용 파일이 하드링크로 덮어써지다

📝 글: https://var.gg/ko/blog/wasmtime-46-wasi-sandbox
🗓 실행: 2026-07-01 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"파일 내용을 읽기 전용으로 건넨 디렉터리인데도, Wasmtime 46.0.0에서는 게스트가 그 파일을
> 쓰기 가능한 preopen으로 하드링크해 덮어썼다. 46.0.1에서는 같은 게스트가 거부당했다"* 고 주장한다.
> 이 디렉터리가 그 실행이다 — 임베딩 호스트·게스트 프로그램·콘솔 전사를 그대로 담았다.
> [GHSA-4ch3-9j33-3pmj](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-4ch3-9j33-3pmj).

⚠️ **백필(backfilled).** 실험은 2026-07-01에 돌렸고 이 디렉터리는 2026-07-22에 포장했다. 호스트
소스와 콘솔 전사는 **원본 그대로** 보존했다. 게스트 프로그램 2개·호스트 `Cargo.toml`·`run.sh`는
제3자가 같은 방법을 재현할 수 있도록 실행 기록에서 **다시 작성한 것**이지 원본 바이트가 아니다.
당시 바이너리 해시는 남기지 않았다. `manifest.json → backfill_note` 참조. 꾸미지 않고 그대로 밝힌다.

## 주장 ↔ 근거

### Firsthand (2026-07-01 실측 — 전사는 `observed-output.txt`)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| WASI 게스트는 **앰비언트 권한이 0** — preopen이 없으면 디스크에 있는 파일도 게스트에겐 존재하지 않음 | `observed-output.txt` → EXP-A 두 번째 전사 | `--dir` 없이 `allowed.txt` → *No such file or directory (os error 44)* |
| preopen이 곧 **경계** — 안쪽은 읽히고, `../` 탈출은 권한 위반, 절대 경로는 아예 안 보임 | `observed-output.txt` → EXP-A 첫 전사 | `"allowed-content-123"` · `../secret.txt` → os error 63 · `/etc/hosts` → os error 44 |
| **46.0.0**에서 `FilePerms::READ` 파일이 `FilePerms::all()` preopen으로 하드링크되어 변조됨 | `observed-output.txt` → EXP-C, 46.0.0 | 1 BLOCKED · 2 **LINKED** · 3 WROTE · 4 **`"MODIFIED-VIA-LINK"`** |
| **46.0.1**에서는 링크 자체가 거부되고 원본이 무사 | `observed-output.txt` → EXP-C, 46.0.1 | 2 **BLOCKED**(os error 63) · 4 `"SECRET-readonly-original"` |
| **"쓰기가 성공했다"는 보안 신호가 아니다** — 3단계는 두 버전 모두 `WROTE`인데 의미가 정반대 | 같은 전사, 3단계 vs 4단계 | 3단계 줄은 동일, 4단계 내용은 반대 |

결정적 전제는 preopen 구성이고, 이건 의도적이다. `ro` = `DirPerms::all()` + `FilePerms::READ` —
*디렉터리는 정리해도 되지만 파일 내용은 못 바꾼다*. `ro`에 `DirPerms::READ`만 주면 링크의 source
쪽이 이미 막혀 버그가 아예 나타나지 않는다. 취약한 그 조합이 오히려 현실적인 구성이다.

### 인용 (실측 아님 — 글에서도 동일 표기)

| 주장 | 출처 |
|---|---|
| 취약 코드는 디렉터리 변경 권한만 검증하고 파일 권한 일치는 확인 안 함. `rename`도 같은 경로. 심링크는 무영향 | [GHSA-4ch3-9j33-3pmj](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-4ch3-9j33-3pmj) |
| `wasmtime` CLI는 모든 preopen에 `FilePerms::all()`을 주므로 영향 없음 | 같은 권고문. 이번 실행에서 관측한 `--dir` 도움말(읽기 전용 플래그 부재)과 일관되나, 소스를 직접 확인한 건 아님 |
| 영향 `<24.0.11`, `25.0.0–<36.0.12`, `37.0.0–<45.0.3`, `46.0.0` → 패치 `24.0.11 / 36.0.12 / 45.0.3 / 46.0.1`, CVSS 6.5 Moderate | 같은 권고문 |
| WASI 0.3.0 2026-06-11 비준, Wasmtime 46.0.0이 이를 기본값으로 켠 첫 릴리스 | [WASI 0.3 발표](https://bytecodealliance.org/articles/WASI-0.3) + v46.0.0 릴리스 노트 |

### 명시적으로 검증 안 함

실행한 건 **46.0.0 ↔ 46.0.1** 경계뿐이다 — 24.x / 36.x / 45.x 브랜치는 인용이다.
**`wasm32-wasip1`**(preview1)만 돌렸고 preview2/컴포넌트 게스트는 안 돌렸다. **`hard_link`** 만
실행했고, 권고문이 같은 부류로 지목한 `rename`은 시도하지 않았다. 호스트는 **Windows 11** 하나 —
하드링크·rename 의미는 OS마다 미묘하게 다르다.

## 환경

Windows 11(네이티브, WSL 미사용) · rustc 1.95 · 타깃 `wasm32-wasip1` · Docker 미사용 ·
`wasmtime 46.0.0 (423be7a4e 2026-06-22)`·`46.0.1 (823d1b8f2 2026-06-24)`. CLI 실험은 공식 배포
바이너리, 호스트는 정확한 크레이트 핀(`=46.0.0` / `=46.0.1`). 하드웨어는 무관하다 — 타이밍 벤치가
아니라 권한 경계 확인이다.

## 재현

```bash
./run.sh          # 툴체인 확인 → EXP-A(CLI) → EXP-C(호스트를 46.0.0·46.0.1로 각각 빌드)
```

`run.sh`가 핀 고정된 wasmtime 릴리스 2개를 받고, 게스트 둘을 `wasm32-wasip1`로 빌드하고, 임베딩
호스트를 크레이트 버전별로 한 번씩 빌드해 **매번 새 `ro/secret.txt`** 를 두고 실행한다. 산출물은
전부 `.gitignore` 된 `work/`에 떨어진다. 출력을 `observed-output.txt`와 대조하면 된다.

네트워크(릴리스 다운로드 + crates.io)와 Rust 툴체인이 필요하다. 참고로 이 CVE는 `wasmtime` CLI로는
아예 재현되지 않는다 — CLI는 모든 preopen에 파일 권한을 전부 주므로 우회할 읽기 전용 쪽이 없다.
임베딩 호스트가 있어야 한다.

## 파일

| 파일 | 설명 |
|---|---|
| `harness/host/src/main.rs` | 임베딩 호스트. 원본 그대로 **보존**. 서로 다른 `FilePerms`를 가진 두 preopen이 실험의 핵심. |
| `harness/host/Cargo.toml` | 정확한 크레이트 핀. `run.sh`가 버전 전환 시 다시 쓴다. 재작성본. |
| `harness/guest_a.rs` | EXP-A 게스트: preopen 안 읽기, `../` 탈출, 절대 경로 읽기. 재작성본. |
| `harness/guest_cve.rs` | EXP-C 게스트: 직접 쓰기 → 하드링크 → 링크로 쓰기 → 원본 재확인. 재작성본. |
| `run.sh` | 제3자 진입점: 핀 고정 런타임 받고 빌드·양쪽 실행. |
| `observed-output.txt` | 2026-07-01 원본 콘솔 전사. 이것이 증거다. |
| `results.json` | 주장 대응 요약: 전제·검증 항목·인용/실측 구분·미검증 목록. |
| `manifest.json` | 환경·버전·권고문 메타·`backfilled` 출처 표기. |
| `checksums.txt` | 커밋된 하네스·증거의 sha256. |
