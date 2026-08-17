# cosign v3.1.1 — Sigstore 번들 형태: 기본(공개 로그) vs 오프라인

📝 글: https://var.gg/ko/blog/cosign-v3-sigstore-bundle
🗓 실행: 2026-06-17 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · ♻️ **backfilled(사후 포장)**
🌐 English: [README.md](./README.md)

> 글은 *"cosign v3.1.1로 blob에 서명하고 번들을 뜯어봤다 — 키 기반 `sign-blob`도 기본은 공개
> 투명성 로그에 올라간다"*고 주장한다. 이 디렉터리가 바로 그 실행이다: 명령 시퀀스·환경·살아남은
> 리댁트 번들. `git clone` 후 `./run.sh`로 **방법**을 재현한다(cosign v3.1.1을 새로 내려받는다).

## 사후 포장(backfilled) — 먼저 읽기

원래 2026-06-17 세션은 ~198 MB cosign 바이너리와 로컬 `registry:2` 컨테이너를 썼고, 유한 디스크
정리 정책에 따라 실행 후 삭제됐다. `run.sh`는 기록된 명령 시퀀스로 **재구성**했고 cosign v3.1.1을
다시 내려받아 방법을 처음부터 끝까지 재현한다. `bundle-default-redacted.json`은 그 실행에서 유일하게
남긴 구조적 아티팩트로, 암호값은 전부 리댁트했다. 원본 바이너리 해시는 실행 시점에 캡처하지 않았고 —
지어내는 대신 그 사실을 그대로 밝힌다. `manifest.json.backfill_note` 참조.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json`의 한 줄로 추적된다. 외부 사실(스펙 버전, 최신
릴리스)은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도 동일하게 구분했다.

### Firsthand (cosign v3.1.1, windows/amd64에서 관찰)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 키 기반 `sign-blob`도 **기본은 공개 Rekor에 업로드** — 번들에 `tlogEntries`(rekor.sigstore.dev, hashedrekord) **와** RFC3161 TSA 타임스탬프가 들어있다 | `bundle-default-redacted.json` → `verificationMaterial` 키 · `results.json` → `behaviors_verified[default_uploads_to_public_rekor]` | `publicKey` + `tlogEntries` + `timestampVerificationData` |
| `--tlog-upload=false`는 v3에서 **deprecated**; 오프라인 경로는 `--signing-config` 파일 | `results.json` → `behaviors_verified[tlog_upload_false_deprecated]` · `run.sh` step 3 | 확인 |
| 오프라인 signing-config 번들은 **같은 `bundle.v0.3+json` 포맷인데 자기완결형** — `verificationMaterial` = `['publicKey']` 만 | `results.json` → `bundle_shape_matrix.offline_signing` · `run.sh` step 3 단언 | `publicKey` 만 |
| `cosign triangulate`는 **deprecated, v4에서 제거**(`oras discover`/`cosign tree` 사용) 경고; 서명은 legacy `.sig` 태그 **와** OCI referrer 양쪽에 붙음 | `results.json` → `behaviors_verified[triangulate_deprecated_for_v4]` · `run.sh` step 4 | 확인(Docker) |
| 오프라인 검증은 `--insecure-ignore-tlog=true`가 필요하고 cosign이 **직접 "안전하지 않다" 경고** | `results.json` → `behaviors_verified[offline_verify_warns_insecure]` | 확인 |

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 번들 스펙 v0.3 / signing-config v0.2 미디어타입 | [sigstore/protobuf-specs](https://github.com/sigstore/protobuf-specs) |
| 최신 cosign은 v3.1.2 (2026-07-17); v4가 deprecated 플래그 제거 | [sigstore/cosign releases](https://github.com/sigstore/cosign/releases) |

### 명시적으로 검증 안 함

**windows/amd64**만 실행했다. **keyless(Fulcio OIDC)** 흐름과 **Rekor v2 스토리지 내부**는 글에서
개념적으로만 다뤘고 firsthand로 뜯어보지 않았다. 실측이 아니라 한계로 명시한다.

## 드리프트

**cosign v3.1.1**(2026-06-09 빌드)에 고정. 2026-07-17 기준 최신은 v3.1.2. `bundle-default-redacted.json`
안의 tlog 엔트리 값(logIndex, integratedTime, merkle proof)은 라이브 `rekor.sigstore.dev` 로그의
특정 시점 스냅샷이라 새 실행과 **일치하지 않는다** — 재현 가능한 신호는 값이 아니라 *형태*(어떤 키가
있는가)다. `manifest.json.drift_warning` 참조.

## 환경

Windows 11 x64 · cosign **v3.1.1**(go1.26.3, windows/amd64) · Docker 29.4.3(로컬 `registry:2` 만,
프로덕션 미접촉). 하드웨어는 무관하다 — 타이밍 벤치가 아니라 서명 동작·번들 형태 검증이다.

## 재현

```bash
./run.sh          # cosign v3.1.1 다운로드 → 키페어 → 기본 vs 오프라인 sign-blob → 두 번들 형태 단언
```

step 1–3은 cosign만 있으면 되고 핵심 발견을 재현한다. step 4(OCI 서명 + `triangulate`)는 로컬 Docker
데몬이 추가로 필요하며 Docker가 없으면 자동으로 건너뛴다.
