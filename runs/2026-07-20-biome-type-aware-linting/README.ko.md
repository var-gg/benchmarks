# Biome 2.5.4 타입 인지 린팅 — typescript 없이 어디까지 잡나

📝 글: https://var.gg/ko/blog/biome-type-aware-linting
🗓 실행: 2026-07-20 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"typescript를 안 깐 프로젝트에서 Biome의 타입 인지 규칙을 돌렸는데도 진단이 떴다"*고
> 주장한다. 이 디렉터리가 바로 그 실행이다 — fixture·설정·하네스와 네 개의 pass/fail 진단을
> 그대로 담아, 주장을 그냥 믿지 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `probe-result.json`의 boolean 한 줄로 추적된다. 결정적
전제는 **`typescript` 미설치** — 타입 인지 규칙이 타입을 스스로 추론해야 한다. 속도와
typescript-eslint 대비 커버리지는 Biome 공식 문서 인용이라 *인용(실측 아님)*으로 따로 표기한다.

### Firsthand (@biomejs/biome 2.5.4에서 실측, typescript 없음)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 타입 인지 규칙(`noFloatingPromises`)이 **tsc 없이** 버려진 Promise와 await된 Promise를 구분 | `probe-result.json` → `exp1_floating_flagged_no_tsc` | `true` (bare `save()` 플래그, `await save()` 미플래그) |
| **크로스 파일** — import로만 알 수 있는 Promise 반환 타입도 프로젝트 스캐너가 해결 | `probe-result.json` → `exp2_cross_file_flagged` | `true` (`mod-b.ts` bare 호출 플래그) |
| Biome 추론은 **완전한 타입 시스템이 아니다** — typescript-eslint가 잡는 손수 만든 thenable을 놓침 | `probe-result.json` → `exp3_boundary_flagged_lines` | 플래그 `{3, 11}`, 8번(custom thenable) **미플래그** |
| **`.grit` 쿼리 한 파일**(컴파일 코드 0)로 작성한 커스텀 규칙이 category `plugin`으로 동작 | `probe-result.json` → `exp4_gritql_plugin_flagged` | `true` |

### 인용 (실측 아님 — 글에서도 동일하게 표기)

| 주장 | 출처 |
|---|---|
| 타입 인지 규칙이 typescript-eslint 타입 규칙의 ~75% 커버 | [Biome v2 발표](https://biomejs.dev/blog/biome-v2/) |
| ESLint 대비 ~10-20배 빠름 | Biome 문서 (머신 의존, 여기선 미측정) |
| `noFloatingPromises`는 2.5.4에서도 nursery(opt-in) | [Biome 2.5 릴리스 노트](https://biomejs.dev/blog/biome-v2-5/) |

### 명시적으로 검증 안 함

속도는 **측정하지 않았다** — 타이밍은 머신 의존이라 pass/fail 동작 확인의 범위 밖이다.
typescript-eslint 비교는 공식 커버리지 프레이밍 + firsthand 한 조각(thenable 미검출)이지, 두
린터를 나란히 돌린 게 아니다. 한계를 그대로 밝힌다.

## 환경

Windows 11 · Node **v24.15.0** · npm · `@biomejs/biome` **2.5.4** · **typescript 미설치** ·
Docker 미사용. 하드웨어는 무관하다 — 타이밍 벤치가 아니라 진단 유무 감지다.

## 재현

```bash
./run.sh          # node/npm 확인 → probe.sh → biome 설치(tsc 없음) → 4개 실험
```

`probe.sh`가 throwaway `work/`를 만들어 `@biomejs/biome`만(약 2 패키지) 설치하고, fixture와
`biome.json`·`.grit` 플러그인을 넣은 뒤 네 실험을 돌려 `probe-result.json`을 쓴다. 이후 커밋된
`results.json`과 대조한다.

## 원시 데이터

폐기한 것 없음. 이 런이 만드는 유일한 대용량은 `work/node_modules`(약 2 패키지)인데 `run.sh`가
재생성하고 `.gitignore`로 커밋 제외다. 결정적 증거인 `probe-result.json`은 커밋한다. 커밋된
하네스·증거의 무결성 해시는 `checksums.txt`.
