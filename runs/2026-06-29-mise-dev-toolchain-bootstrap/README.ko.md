# Windows의 mise — 버전 문자열이 아니라 바이너리를 잠근다 (trust·shim·공급망)

📝 글: [KO](https://var.gg/ko/blog/mise-dev-toolchain-bootstrap)
🗓 실행: 2026-06-29 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-06-29 한 대의 Windows 11 PC에서 이뤄졌고(레포 생성 전),
> 디스크 정책상 `firsthand-benchmark.md` 텍스트만 보존됐다. `mise.exe` 바이너리, 설치된
> node/jq/gh 툴체인, 격리된 `MISE_DATA_DIR`는 폐기됐다. `fixture/*.toml`·`run.sh`는 기록된
> 방법론에서 **재구성**해 **방법**을 재현할 수 있게 했다. `results.json`의 판정·시간은 **mise
> v2026.6.14**로 얻은 2026-06-29 스냅샷이다. **mise는 ~월간 릴리스**라 버전·수치는 달라진다 —
> 지속되는 주장은 개별 ms가 아니라 **동작(behavioral) 발견**이다.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| **신뢰 안 한 `mise.toml`**은 `mise trust` 전까지 파싱 거부 (TOFU) | `results.json` → `behavioral_matrix[T]`, `findings[trust_tofu]` + `fixture/env/mise.toml` | `mise env`가 "Config files ... are not trusted" 에러; `mise trust` 후 `[env]` 로드 |
| `mise.lock`은 **크로스플랫폼 바이너리 체크섬**을 잠근다(버전 문자열 아님) — 기본 **OFF** | `results.json` → `behavioral_matrix[2]`, `findings[lockfile_is_binary_lock]` + `fixture/lockfile/mise.toml` | `mise use node@22`가 `(os,arch)`별 sha256+URL 기록; opt-in 안 하면 `mise.lock` 없음 |
| **standalone `mise.exe`**는 **file** shim 모드로 폴백(`mise-shim.exe` 없음) → shim이 PATH의 mise에 의존 | `results.json` → `behavioral_matrix[3]`, `findings[windows_file_shim_fallback]` | WARN "mise-shim.exe not found ... file shim"; shim = `.cmd`+bash, 본문 `mise x` |
| "mise가 다운로드를 검증한다"는 보장 범위가 다른 **3단계** | `results.json` → `behavioral_matrix[6a,6b]`, `findings[supply_chain_three_tiers]` + `fixture/supply-chain/mise.toml` | jq=checksum-only(무결성); gh=attestation(provenance, mise API 경유); core=lock sha256 |
| 의존성 인식 **태스크 러너** 내장 | `results.json` → `behavioral_matrix[4]` + `fixture/tasks/mise.toml` | `mise run build`가 `greet`→`build` 순 실행(95.5ms), make/Taskfile 불필요 |
| **warm 재설치는 멱등**, file-shim은 소폭 오버헤드 | `results.json` → `timings`, `findings[idempotent_reinstall,file_shim_overhead]` | cold 3287ms → warm 110ms; raw node 76ms vs `mise exec` 90ms(~+14ms) |

### 정직하게 측정 안 함

- **exe shim 모드**(Scoop/winget으로 `mise-shim.exe` 동반 설치)는 안 돌렸다 — standalone exe의
  **file-shim 폴백**만 측정. exe 모드 동작은 문서 인용.
- 전부 **Windows 11 한정**. macOS/Linux `activate`(셸 hook) 모드는 이 실행에서 측정 안 함.
- checksum-only vs attestation 격차는 **위협 모델 논증**이지 상류 침해를 실제로 재현한 PoC가 아니다.
- `results.json` → `explicitly_not_verified` 참조.

## 재현

```bash
./run.sh     # PATH에 mise 필요; 모든 상태를 scratch MISE_DATA_DIR로 격리
```

기대: trust 거부, file-shim WARN, `mise.lock`의 플랫폼별 sha256, jq(checksum)↔gh(attestation)
분기, warm << cold. 정확한 ms·패치 버전은 mise가 움직이면서 2026-06-29 스냅샷과 달라진다 —
예상된 정직한 결과다.

## 환경

Windows 11 x64(네이티브, WSL/Docker 없음) · Git Bash · **mise v2026.6.14**(windows-x64 standalone
exe, 2026-06-25) · `MISE_DATA_DIR`/`MISE_CACHE_DIR`/`MISE_STATE_DIR` 전부 tmp로 리다이렉트해
홈 오염 없음 · 설치: node 22.23.1 / `aqua:jqlang/jq` 1.7.1 / `aqua:cli/cli` 2.62.0.
