# 단명 TLS 인증서 갱신 — 만료 의미론 + ACME ARI

📝 글: https://var.gg/ko/blog/short-lived-tls-renewal
🗓 실행: 2026-06-23 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"로컬에 진짜 ACME 인증기관을 띄워 직접 손으로 돌렸다 — 짧은 인증서가 TLS 핸드셰이크를
> 깨뜨리는 정확한 순간을 봤고, CA에게 언제 갱신하면 되는지 직접 물어봤다"*고 주장한다. 이
> 디렉터리가 바로 그 실행이다 — 두 개의 하네스·환경·캡처 로그를 그대로 담아, 주장을 그냥 믿지
> 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다(Part A는 OpenSSL만, Part B는 pebble용
> Docker 필요).

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`과 두 캡처 로그의 한 줄로 추적된다. 외부
자료에서 인용한 주장은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도 동일하게 구분했다.

### Firsthand — Part A: 만료는 유예 없는 하드 데드라인 (결정적, 네트워크 없음)

OpenSSL 3.5.6, 로컬 EC P-256 루트 CA, **수명 20초** leaf, 그리고 까다로운 Python `ssl`
클라이언트(`CERT_REQUIRED` + 호스트명 확인 — 실제 브라우저/curl처럼).

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 신선한 단명 인증서는 핸드셰이크가 성립한다 | `partA/probe-result.txt` → `[valid]` | `HANDSHAKE OK` |
| `NotAfter`가 지나고 갱신이 멈춘 순간 핸드셰이크가 깨진다 — **유예 없음**, 앱 코드 실행조차 안 됨 | `partA/probe-result.txt` → `[expired]` | `verify_code=10` (`X509_V_ERR_CERT_HAS_EXPIRED`) |

### Firsthand — Part B: CA가 갱신 시간창을 돌려준다 (pebble에 실제 ACME)

외부 ACME 라이브러리 없이 직접 구현한 순수 Python ACME 클라이언트(ES256 JWS, `cryptography`만)가
pebble의 `shortlived` 프로필로 주문 상태머신을 끝까지 걸고, ARI를 조회한다.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 수명을 **클라이언트가 아니라 CA**가 정한다 | `partB/acme-ari-result.txt` → `[cert] Lifetime` | `144.0 hours` (pebble 기본값) |
| ARI는 한 시각이 아니라 갱신 **시간창** + `Retry-After`를 돌려준다 | `partB/acme-ari-result.txt` → `[ARI] HTTP 200` | 창 `[NotAfter−72h .. NotAfter−24h]`, `Retry-After 21600` |
| ARI 경로(CertID)는 **인증서로부터 파생**(AKI + 일련번호)되어 인증서마다 고유 | `partB/acme_ari.py` (CertID 계산) | `3GDLB8LPWmGDwp_DBKNDj7uiI2Q.BSs2vQAelpg` |
| pebble는 ARI를 **드래프트 경로**로 노출 — 하드코딩 말고 디렉터리에서 읽어야 | `directory.renewalInfo` | `.../draft-ietf-acme-ari-03/renewalInfo` |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 인증서 최대 수명이 2026-03부터 줄어 2029년 47일까지 | CA/Browser Forum SC-081 / Let's Encrypt 공지 |
| ARI는 **RFC 9773**으로 확정(드래프트 졸업) | [RFC 9773](https://www.rfc-editor.org/rfc/rfc9773) |
| 실제 Let's Encrypt 단명 프로필 수명/창 ≠ pebble의 144h 기본값 | Let's Encrypt 문서 (pebble은 테스트 CA) |
| ARI 클라이언트 지원(Certbot 4.1.0+ 등) | 각 클라이언트 changelog |
| 짧은 수명이 대량 폐기를 만료로 흡수해 OCSP/CRL 의존을 줄임 | ARI 설계 근거 (추론) |

### 명시적으로 검증 안 함

- **실제 운영 CA 수치.** pebble 기본값 144h + 창만 관측했다. 2026→2029 업계 타임라인과 실제
  Let's Encrypt 프로필은 인용이고 firsthand로 제시하지 않는다.
- **DCV 실패 시나리오.** Part B는 pebble를 `PEBBLE_VA_ALWAYS_VALID=1`로 돌려 도메인 검증을
  자동 통과시켰다. 실제 DCV 실패는 Part A의 *갱신 멈춤* 케이스로 추상화된다 — 원인이 무엇이든
  `NotAfter`가 지나면 결말은 같다.
- **pebble 버전.** 최초 실행에서도 `:latest`(핀 미고정)로 받았다. 재실행 시 더 새로운 pebble가
  다른 수치를 낼 수 있다 — 이식 가능한 신호는 *메커니즘*이지 정확한 144h가 아니다.

## 환경

Windows 11 (Git Bash) · OpenSSL **3.5.6** · Python 3.11 (`cryptography` 48) · Docker(pebble,
Part B 전용). 타이밍 벤치가 아니라 동작/프로토콜 검증이므로 하드웨어는 무관하다.

## 재현

```bash
./run.sh          # Part A: OpenSSL + Python ssl 프로브;  Part B: docker pebble + ACME 클라이언트
```

Part A는 OpenSSL만으로 돈다. Docker가 없으면 Part B는 자동으로 건너뛴다.

## 원시 데이터

실행마다 생성되는 키·인증서(`ca.key`, `leaf.*`)는 **커밋하지 않는다** — 매 실행 새로 만들어져(새
키 + 벽시계 유효기간) 해시가 안 맞기 때문이며, 비결정적 스크린샷과 같은 이유다. 커밋된 증거는 두
하네스 + 2026-06-23 캡처 로그(`partA/probe-result.txt`, `partB/acme-ari-result.txt`)다. 커밋된
파일의 무결성 해시는 `checksums.txt`.

## 파일

| 파일 | 무엇인가 |
|---|---|
| `partA/run.sh` | OpenSSL로 로컬 EC 루트 CA + 단명 leaf 발급. |
| `partA/tls_probe.py` | 단명 인증서로 TLS 서버를 띄우고 만료 전/후 핸드셰이크 프로브. |
| `partA/leaf.ext` | leaf의 SAN/keyUsage 확장. |
| `partA/probe-result.txt` | Part A 캡처 로그(결정적: `[valid]` 후 `verify_code=10`). |
| `partB/acme_ari.py` | 직접 구현한 순수 Python ACME 클라이언트; `shortlived`로 주문, ARI 조회. |
| `partB/acme-ari-result.txt` | Part B 캡처 로그(144h 인증서 + ARI 창). |
| `run.sh` / `requirements.txt` | 재현(Part A는 항상, Part B는 Docker 있을 때). |
| `results.json` | 주장 대면 요약: 관측 + 인용 vs 실측 구분. |
| `manifest.json` | 환경·버전·`executed_by`·보존 정책·드리프트 경고. |
| `checksums.txt` | 커밋된 하네스·증거의 sha256. |
