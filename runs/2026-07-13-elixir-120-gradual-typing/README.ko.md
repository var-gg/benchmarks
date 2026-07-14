# Elixir 1.20 gradual 타입 체커 — 추론만으로 무엇을 잡고, 언제 빌드를 깨뜨리나

📝 글: [KO](https://var.gg/ko/blog/elixir-120-gradual-typing) *(한국어 전용; 영어 글 없음)*
🗓 실행: 2026-07-13 · 🤖 실행 주체: **agent** · 👤 운영: curioustore · **⏪ 백필**
🌐 English: [README.md](./README.md)

> **백필 안내.** 이 실행은 2026-07-13에 이뤄졌다. 원시 산출물(모듈별 컴파일 로그, `.beam` 출력)은
> 디스크 정책상 폐기됐으므로, `run.sh` + `fixture/`(7개 `.ex` 데모 모듈 + 최소 mix 프로젝트)를 커밋해
> **방법**을 재구성했다. 이 레포의 advisory-DB 실행들과 달리 컴파일러의 타입 출력은 핀 고정된 Elixir에
> 대해 **결정론적**이다: Elixir 1.20.x에서 다시 돌리면 같은 경고가 **그대로(verbatim)** 나오고 —
> 아무것도 드리프트하지 않는다. 그래서 `results.json`은 시점 스냅샷이 아니라 정성적 **capability
> matrix + exit code**다. 산출물 해시는 당시 기록하지 않았으므로 **지어내지 않는다**.

## 주장 ↔ 근거

아래 모든 경고는 **추론만으로** 나온다 — fixture 어디에도 **`@spec`도 타입 어노테이션도 없다**.

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 체커가 **분리형 타입**(disjoint) 오용을 잡음 (`integer\|binary` 값을 `Map.fetch!`에 넘김) | `results.json` → `support_matrix[disjoint_map_fetch]` | WARN: given `dynamic(binary() or integer())`, expected `map()` |
| **명백히 없는 map key**를 잡음 | `results.json` → `support_matrix[missing_map_key]` | WARN: given `empty_map()`, expected `%{..., name: term()}` |
| narrowing이 내부적으로 일관되면 **false positive를 회피** | `results.json` → `support_matrix[narrowing_ok]` | `data.a + data.b` → **경고 없음** |
| **narrowing 오용**을 잡음 — map으로 좁혔다가 숫자로 사용 | `results.json` → `support_matrix[narrowing_misuse]` | WARN: `data`가 `%{..., a: float() or integer()}`로 좁혀진 뒤 숫자로 사용됨 |
| **dead / 도달 불가 clause**를 잡음 | `results.json` → `support_matrix[dead_clause]` | **경고 2개**: `is_integer/1` always match + `is_binary/1` never match (`is_integer` 가드 하에서) |
| **완전 dynamic** 파라미터는 **경고 없음** (gradual escape) | `results.json` → `support_matrix[gradual_escape]` | 제약 없는 `x`에 `Map.fetch!(x, :any_key)` → **경고 없음** (정직한 한계) |
| 이것들은 error가 아니라 **warning** — `mix compile --warnings-as-errors`만 빌드를 깨뜨림 | `results.json` → `exit_code_semantics` | `elixirc --warnings-as-errors` **exit 0** · `mix compile` **exit 0** · `mix compile --warnings-as-errors` **exit 1** |

### exit code 뉘앙스 (건너뛰지 말 것)

체커가 버그를 잡았다고 해서 그 자체로 빌드나 배포가 멈추는 게 **아니다**. 명령 3개, 결과 3개 —
CI를 게이트하는 건 마지막 하나뿐이다:

| 명령 | Exit | 이유 |
|---|---|---|
| `elixirc --warnings-as-errors -o out src/unused.ex` | **0** | `--warnings-as-errors`는 *mix* 개념이라 `elixirc`는 무시한다 — 단순 unused-variable 경고조차도. |
| `mix compile` | **0** | 타입 경고는 출력되지만 일반 compile은 빌드를 실패시키지 않는다. |
| `mix compile --warnings-as-errors` | **1** | 셋 중 타입 경고가 물게 만드는 유일한 것. CI 잡이 반드시 이걸 돌려야 한다. |

### 정직하게 검증 안 함 / 정직한 한계

- **경고 ≠ 강제.** 기본값은 경고라서 알려줄 뿐 게이트하지 않는다 — `--warnings-as-errors`로
  옵트인하지 않는 한. `results.json` → `caveats` 참조.
- **경고 부재는 정확성의 증거가 아니다.** `gradual_escape`가 조용한 건 완전 `dynamic()` 파라미터라
  체커가 좁힐 정보가 없었기 때문이지 코드가 안전하다고 검증돼서가 아니다.
- **추론 전용.** `@spec`/어노테이션을 쓰지 않았으므로 더 강한 신호를 주는 어노테이션 경로는
  실험하지 않았다. `@spec`을 붙이면 체커가 활용할 정보가 늘어난다.
- **대형 코드베이스 컴파일 시간 비용은 측정 안 함** — 여기 fixture는 단일 모듈 수준이다.
- **버전 스윕 없음** — Elixir 1.20.2만 돌렸다; 이전 버전은 이 경고 집합이 다르게(대체로 더 적게)
  나온다. `results.json` → `explicitly_not_verified` 참조.

## fixture

`fixture/src/*.ex`는 독립 모듈 7개다. 6개는 위 행과 1:1 대응(`elixirc`로 컴파일)하고,
`unused.ex`는 `elixirc --warnings-as-errors` exit-code 데모용 단순 unused-variable 컨트롤이다.
`fixture/typedemo/`는 **최소 mix 프로젝트**(의존성 없음, 오프라인)로 `lib/typedemo.ex`가 missing-key
경고를 재현한다 — 이건 오직 bare `elixirc`가 못 보여주는 `mix compile` vs
`mix compile --warnings-as-errors` exit code를 `run.sh`가 시연하기 위해 존재한다. 이게 재현
입력이고, Elixir 1.20.x에서 드리프트하지 않는다.

컴파일 출력(`.beam`, `_build/`)은 **절대 커밋하지 않는다** — `run.sh`는 temp 디렉터리에 컴파일하고
종료 시 정리한다.

## 재현

```bash
./run.sh          # Elixir 1.20.x 필요 (elixir + elixirc + mix, 함께 설치됨)
```

`run.sh`는 Elixir 버전을 핀/가드하고(1.20.x가 아니면 크게 경고), 각 `fixture/src/*.ex`를 컴파일해
컴파일러 타입 출력을 **그대로** 캡처하고, 기록된 matrix 대비 **warned/quiet**로 분류한 뒤 위 세 exit-code
동작을 시연한다. Elixir 1.20.x에서는 **4 warned / 2 quiet**와 exit code **0 / 0 / 1**이 보여야 한다.

## 환경

Windows 11 (win32) · Elixir **1.20.2**(Erlang/OTP 27로 컴파일) · 런타임 Erlang/OTP **29**
[erts-17.0.3, jit] · **scoop**로 설치. 타입 검사는 컴파일 타임이라 OS 독립적이다 — 경고는 Elixir
1.20.x를 돌리는 어느 플랫폼에서도 재현된다. **Elixir 버전이 load-bearing 변수**이지 OS가 아니다.
