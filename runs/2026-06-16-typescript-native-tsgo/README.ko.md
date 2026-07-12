# tsc vs tsgo (TypeScript 네이티브 프리뷰) — 여기선 약 3× 빠름, 그리고 진단이 갈렸다

📝 글: [KO](https://var.gg/ko/blog/typescript-native-tsgo) · [EN](https://var.gg/en/blog/typescript-native-tsgo)
🗓 실행: 2026-06-16 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-06-16에 이뤄졌고(레포 생성 전), 원시 타이밍/진단 로그는
> 디스크 정책상 폐기됐다(게다가 private 소스 경로가 박혀 있어 커밋 자체가 불가). fixture 기반
> 실행과 달리 **공유 가능한 입력이 없다** — 대상 코드베이스가 private이기 때문. 그래서 `run.sh`는
> 독자가 **자기 repo**에 돌리는 **범용** 하네스다. `results.json`의 수치는 2026-06-16에 우리
> 모노레포에서 측정한 값이다. 산출물 해시는 캡처하지 않았고, 지어내지도 않았다.

## 재현성 (먼저 읽을 것)

여기 절대 수치는 **var.gg의 private `apps/frontend` 모노레포**에서 측정했다 — **728개 `.ts`/`.tsx`**
파일의 Next.js App Router 프로젝트(`tsconfig`: `noEmit`, `incremental`, `skipLibCheck`, `strict`).
**이 코드베이스는 공유 불가**이므로:

- **우리 정확한 초·진단 개수는 재현할 수 없다** — 독자에겐 우리 소스가 없다. 공유할 게 없으니
  이 디렉터리엔 **fixture가 없다.**
- **방법은 완전히 재현 가능하다.** `run.sh`는 repo 경로를 `$1`로 받아(기본값: 현재 디렉터리)
  `tsc --noEmit` vs `npx @typescript/native-preview --noEmit`를 cold+warm으로 재고, 진단을
  diff한다 — **독자가 가리키는 어떤 TypeScript repo에서든.**
- **지속되는 주장은 두 발견**이지 원시 초가 아니다: (1) tsgo는 유의미하게 빠르나 "10×"는
  규모 의존적 — 우리는 **728파일에서 ~3×, 10× 아님**; (2) tsc와 tsgo-preview 진단은 **갈릴 수
  있다** — 자기 repo에서 확인하라.

한 줄로: **방법은 재현 가능, 우리 수치는 private.**

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| tsgo가 tsc보다 **빠름**(cold) | `results.json` → `metrics[typecheck_speed]` | 6.7s → 2.1s ≈ **~3.2×** (private repo) |
| tsgo가 tsc보다 **빠름**(warm) | `results.json` → `metrics[typecheck_speed]` | 1.9s → 0.7s ≈ **~2.7×** (private repo) |
| 공식 **"10×"는 규모 의존적**, 우리 실측과 다름 | `results.json` → `metrics[typecheck_speed].caveat` | 728파일·skipLibCheck에서 **~3×, 10× 아님** |
| tsc는 **에러 3개, 전부 stale 생성물 참조**(소스 버그 아님) | `results.json` → `findings[diagnostics_divergence]` | `.next/types/**`의 dangling `nf404probe` TS2307 × 3 |
| tsgo는 **4개** = 동일 3개 **+ 추가 1개** | `results.json` → `findings[diagnostics_divergence]` | `useInfiniteAbbreviations.ts(82,9)` TS2769 +1 |
| tsc·tsgo 진단은 **bit-identical 아님** | `results.json` → `findings[diagnostics_divergence]` | 우리 repo에서 divergence 확인 |
| 추가 에러의 **원인은 미확정** | `results.json` → `explicitly_not_verified[divergence_cause]` | 강화 vs preview 버그 vs 6.0→7.0 오버로드 차이 — **여기선 단정 불가** |

### 정직하게 검증 안 함

- **divergence의 원인.** tsc 6.0.3과 tsgo 7.0-dev는 *다른 타입 체커 버전*이다. 추가 `TS2769`가
  7.0의 의도된 강화인지, preview 버그인지, 6.0→7.0 오버로드 선택 차이인지는 **단정하지 않았다** —
  버전 bisect / 업스트림 repro가 필요하다. `results.json` → `explicitly_not_verified[divergence_cause]`.
- **규모에서의 "10×".** 우리는 728파일 repo(~3×)만 측정했다. 10×가 성립한다고 주장되는 대형
  (10만+ 파일) 코드베이스는 **돌리지 않았으므로** 거기선 확인도 반박도 하지 않는다.
  `results.json` → `explicitly_not_verified[ten_x_at_scale]`.

## 재현 (독자 자신의 repo에서)

```bash
./run.sh /path/to/your/typescript/repo    # 기본값: 현재 디렉터리
```

Node + `npx` 필요. cold 패스용으로 incremental 캐시를 지우고, 두 컴파일러를 cold+warm으로 잰 뒤,
속도 표 **와** `tsc`-vs-`tsgo` 진단 diff를 출력한다. 독자의 초는 우리와 다르다(다른 코드베이스) —
예상된 정직한 결과다. 신호는 **배수**와 **독자 repo에서 진단이 갈리는지** 여부다.

## 환경

Windows 11 x64 · Node **v24.15.0** · 베이스라인 **tsc 6.0.3**(JS 자기호스팅) · 대상 **tsgo
= @typescript/native-preview 7.0.0-dev.20260616.1**(Go 네이티브) · 타이밍은 PowerShell
`Measure-Command`.

## 파일

| 파일 | 설명 |
|---|---|
| `run.sh` | 범용 하네스 — **독자 repo**에 겨눠 tsc vs tsgo를 cold+warm으로 재고 진단을 diff. |
| `results.json` | 주장 대면 요약: 속도 metric + 진단 divergence finding + caveats. 원시 배열 없음. |
| `manifest.json` | 환경·버전·`executed_by`·`reproducibility` 블록·보존 정책. |
| `checksums.txt` | 커밋된 하네스+근거의 sha256 (`scripts/add-run.sh`가 생성). |
