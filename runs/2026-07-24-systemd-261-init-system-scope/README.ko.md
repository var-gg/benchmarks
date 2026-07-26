# systemd 261 — 업스트림과 `docker pull` 사이의 "배포판 갭"

📝 글: https://var.gg/ko/blog/systemd-261-init-system-scope
🗓 실행: 2026-07-24 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"systemd 261이 OS 설치·클라우드 메타데이터·스토리지 바이너리를 실었지만, 오늘 손에 쥔
> 사람은 롤링 배포판 사용자뿐"*이라고 주장한다. 이 디렉터리가 바로 그 실행이다 — 두 개의 bash
> 프로브·환경·원시 JSON을 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다. `git clone` 후
> `./run.sh`로 재현된다(Docker 필요).

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `probe-result.json` / `probe-pkg-result.json`의 한 줄로
추적된다. v261가 *무엇을 담았는가*는 업스트림 NEWS 인용이라 *인용(실측 아님)*으로 따로 표기한다 —
글에서도 동일하게 구분했다.

### Firsthand (Docker 29.4.3, 2026-07-24 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| Arch는 이미 베이스 이미지에서 **systemd 261**을 돌린다 | `probe-result.json` → `archlinux:latest.systemctl_version` | `systemd 261 (261.1-1-arch)` |
| v261 신규 바이너리(`systemd-imdsd`·`systemd-imds`·`systemd-sysinstall`·`storagectl`·`systemd-tpm2-swtpm.service` 등)가 **Arch에 전부 존재** | `probe-result.json` → `archlinux:latest.present` | 8 / 8 `true` |
| 안정 배포판은 **뒤처짐**: Fedora −2, Debian −4, Ubuntu LTS −6 | `probe-pkg-result.json` → `distros[].packaged_systemd` | 259.7 / 257.13 / 255.4 |
| 최소 fedora/ubuntu/debian 이미지의 `systemctl --version`이 비는 건 배포판에 없어서가 아니라 **그 이미지가 systemd를 안 깔아서** | `probe-result.json`(부재) → `probe-pkg-result.json`으로 교정 | 측정 편향 자가 발견 |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| v261 코드명 Edinburgh, 2026-06-19 릴리스 | [systemd v261 NEWS](https://github.com/systemd/systemd) |
| 각 신규 바이너리의 역할(IMDS·스토리지·OS 설치·소프트웨어 TPM·dlopen 전환) | systemd v261 NEWS (업스트림) |

### 명시적으로 검증 안 함

- **바이너리 존재 ≠ 동작 검증.** Arch에서 `storagectl`·`systemd-imdsd`가 파일로 존재함만 확인했고,
  실제 클라우드 IMDS 질의나 OS 설치 end-to-end는 **미실행**(컨테이너 PID1·클라우드 메타데이터 부재).
- **소프트웨어 TPM·LUO·BPF LSM 정책**은 유닛파일/소스 존재까지만, 런타임 미검증.
- **컨테이너 이미지는 안정 채널 스냅샷**이지 배포판 전체가 아니다(backports/PPA/rawhide는 더 최신일 수 있음).

## 환경

Windows 11 x64 · Docker **29.4.3**(Linux 컨테이너) · bash 하네스. 하드웨어는 무관하다 —
타이밍 벤치가 아니라 버전/기능 존재 감지다.

## 재현

```bash
./run.sh          # probe.sh(바이너리 존재) + probe-pkg.sh(패키징된 버전)
```

이후 재생성된 `probe-result.json` / `probe-pkg-result.json`을 커밋된 `results.json`과 대조한다.
**주의:** 배포판 이미지 태그는 가변이라 나중에 재실행하면 그때 배포판이 주는 버전을 받는다 — 그
드리프트가 바로 요지다. 커밋된 JSON은 2026-07-24 스냅샷이다.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다 — 근거는 작은 결정적 JSON 두 개(버전 문자열 + 존재
불리언)다. 프로브 실행에 받은 컨테이너 이미지 4개는 실행 후 삭제했다(소유권 기반 정리, `run.sh`가
다시 받는다). 커밋된 하네스·증거의 무결성 해시는 `checksums.txt`.
