# npm 툴체인으로서의 Deno 2.8 — 더 빠른 install, 더 엄격한 resolution, 같은 advisory

📝 글: [KO](https://var.gg/ko/blog/deno-28-npm-toolchain) · [EN](https://var.gg/en/blog/deno-28-npm-toolchain)
🗓 실행: 2026-06-26 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-06-26에 이뤄졌고(레포 생성 전), 원시 산출물(스탠드얼론 `deno.exe`,
> 양쪽 `node_modules` 트리, DENO_DIR/npm 캐시)은 디스크 정책상 폐기됐다. `run.sh` +
> `fixture/package.json`은 기록된 방법론에서 **재구성**해 **방법**을 재현할 수 있게 했다.
> `results.json`의 수치는 2026-06-26 스냅샷이다: install 시간은 **머신/캐시 의존**이고, audit 수는
> advisory DB 갱신에 따라 **드리프트**한다. 지속되는 주장은 install **속도 배수**와 정성적 동작
> (레이아웃, phantom-dep, pack=트랜스파일, Node-API 동등성)이다. 산출물 해시는 당시 기록하지
> 않았으므로 **지어내지 않는다**.

## 주장 ↔ 근거

| 글의 주장 | 근거 | 값 |
|---|---|---|
| `deno install`이 `npm install`보다 **~3.1× 빠름** | `results.json` → `metrics[cold_install_speed]` | 559ms(deno cold) vs 1744ms(npm warm) ≈ **3.1×**; 2차 131ms vs 452ms |
| 공식 **"3.66×"는 npm 대비가 아님** | `results.json` → `metrics[cold_install_speed].caveat` | 3.66× = Deno **2.7→2.8** 자체 개선(Linux; React/Vite/Babel/ESLint) |
| deno는 node_modules를 pnpm식 **격리**, npm은 **flat hoist** | `results.json` → `findings[layout]` | npm 최상위 **8**개 vs deno **4** junction + `node_modules/.deno/` |
| deno는 **phantom**(미선언 전이) 의존을 차단 | `results.json` → `findings[phantom_dep]` | `require("has-flag")`: node **OK** / deno **Cannot find module** |
| npm/deno audit은 **같은 advisory**, 다른 단위로 셈 | `results.json` → `findings[audit_granularity]` | 같은 GHSA id; npm **2**(패키지 단위) vs deno **7**(advisory 단위), exit 1 |
| **ci/frozen** 둘 다 lock 불일치 거부; deno는 정밀 diff | `results.json` → `findings[ci_frozen]` | 둘 다 **exit 1**; deno는 integrity old/new 출력 |
| deno **pack은 트랜스파일**, npm은 **소스 zip** | `results.json` → `findings[pack_transpile]` | npm 944B 소스 zip vs deno 680B 트랜스파일 + `.d.ts` 생성 |
| Node CJS 엔트리포인트가 deno에서 **바이트 동일** | `results.json` → `findings[nodeapi_parity]` | 기록된 sha256 prefix `7a97f5f99f54`; 까다로운 builtin 7종 OK |
| deno는 lifecycle **postinstall을 건너뜀** | `results.json` → `findings[lifecycle_scripts]` | npm은 실행 / deno는 미실행 — 보안 이점 **이자** 빌드 함정 |
| deno의 `require`는 **컨텍스트 의존** | `results.json` → `findings[require_context]` | `type:commonjs` 스코프 밖 → `require is not defined` |

### 정직하게 검증 안 함

**네이티브 애드온**(node-gyp로 빌드하는 `.node` 바이너리)은 Deno가 문서상 호환 경계로 명시하지만,
이번엔 **probe 하지 않았다** — fixture는 의도적으로 순수 JS이고 애드온 패키지를 설치해 케이스를
강제하지 않았다. 이 경계는 Deno 문서의 권위로만 보고하며 여기서 재현하지 않았다. `results.json` →
`explicitly_not_verified` 참조. 글도 "문서상 경계" ≠ "우리가 테스트함" 구분을 동일하게 지킨다.

audit에 대한 정직 플래그 하나 더: 경험적 주장은 npm과 deno가 **같은 GHSA id**를 띄웠다는 것뿐이다.
출처가 OSV라고 **단정하지 않는다** — Deno 문서 자체가 명칭을 뒤섞어 쓰므로(GitHub CVE / vulnerability
databases / npm advisory), 글은 "같은 GHSA"까지만 말하고 멈춘다.

## fixture

`fixture/package.json`은 의도적으로 오래된 순수 JS 릴리스 3개(`lodash@4.17.15`·`minimist@1.2.5`·
`chalk@4.1.2`)를 핀 고정한다. 그래서: audit이 찾을 게 있고, `chalk`가 **미선언 전이 의존**(`has-flag`)을
끌고 와 phantom-dep 검사를 가능케 하며, 어떤 것도 네이티브 애드온이 필요 없다. `type`은 `commonjs`라
Node-API/require 실험이 의도한 스코프에서 돈다. 이게 재현 입력이자 **드리프트 안 하는** 유일한 것.

## 재현

```bash
./run.sh          # node/npm + deno 2.8.x 필요; fixture 설치, npm vs deno 시간 측정, 양쪽 audit
```

기대: `deno install`(cold)이 `npm install`(warm)을 여전히 이기고; npm은 flat 8개를 hoist하는데 deno는
~4 junction + `node_modules/.deno/`를 유지하며; `require("has-flag")`가 node에선 resolve, deno에선 실패;
양쪽 audit이 **같은 GHSA id**를 다른 수로 보고. install ms와 audit 수는 2026-06-26 스냅샷과 달라진다 —
예상된 정직한 결과이고, **배수**와 동작은 유지된다.

## 환경

Windows 11 x64(네이티브) · Node **v24.15.0** / npm **11.12.1** · deno **2.8.0**(standalone zip) ·
audit 데이터 = GitHub Advisory(경험적, 두 도구에서 같은 GHSA id).
