# Zig 0.16 "Writergate" / I/O as an Interface — zig 0.16.0

📝 글: https://var.gg/ko/blog/zig-016-writergate-io-interface
🗓 실행: 2026-07-26 · 🤖 실행 주체: **agent** · 👤 운영: curioustore
🌐 English: [README.md](./README.md)

> 글은 *"작은 프로그램 네 개를 zig 0.16.0으로 직접 컴파일해 pass/fail을 관측했다"*고 주장한다.
> 이 디렉터리가 바로 그 실행이다 — 소스 넷·하네스·결정적 판정을 그대로 담아, 주장을 그냥 믿지
> 않아도 되게 한다. `git clone` 후 `./run.sh`로 재현된다.

## 무엇을 검증하나

Zig 0.16.0(2026-04-14 릴리스)은 0.15.1에서 시작한 표준 라이브러리 I/O 재설계 — 별명 **"Writergate"**,
완성형 이름 **"I/O as an Interface"** — 를 마무리했다. 검증 가치가 있는(반증 가능한) 지점은 세 가지다:
새 `std.Io` 쓰기 경로의 정확한 형태, flush를 빠뜨렸을 때의 *조용한* footgun, 그리고 어떤 0.15 관용구가
아예 제거됐는가. 전부 **결정적** 컴파일 pass/fail 또는 stdout 바이트 수다 — 같은 소스 + 핀 고정 컴파일러
→ 같은 판정.

## 주장 ↔ 근거

글의 **firsthand(실측)** 주장은 전부 `results.json` / `probe-result.json`의 한 줄로 추적된다.
릴리스 노트에서 인용한 주장은 *인용(실측 아님)*으로 따로 표기한다 — 글에서도 동일하게 구분했다.

### Firsthand (zig 0.16.0, Windows x86_64 Threaded 백엔드에서 실측)

| 글의 주장 | 근거 | 값 |
|---|---|---|
| 0.16 정식 쓰기(`std.Io.File.stdout().writer(io,&buf)` → `interface.print` → `interface.flush`, `init.io`를 주입하는 Juicy Main)는 컴파일·실행·출력 OK | `hello_flush.zig` → `probe-result.json.with_flush` | `"hello, writergate"`, **17 bytes** |
| **한 줄만 다르게** `flush()`를 빼면 **아무것도 안 찍힌다** — 새 writer는 기본이 버퍼링이라 종료 시 출력이 사라진다 | `hello_noflush.zig` → `probe-result.json.without_flush` | `""`, **0 bytes** |
| 옛 `std.io.getStdOut()`은 **네임스페이스 단계**에서 깨진다 — 소문자 `std.io`가 사라짐(→ `std.Io`) | `old_api.zig` → `probe-result.json.old_api_error` | 컴파일 에러: `has no member named 'io'` |
| `std.Thread.Pool` **제거**(→ `std.Io` async 프리미티브 대체) — Writergate는 미관이 아니라 async를 위한 것 | `threadpool.zig` → `probe-result.json.thread_pool_error` | 컴파일 에러: `has no member named 'Pool'` |

핵심은 flush footgun이다: **17 bytes vs 0 bytes**, 딱 한 줄 차이.

### 인용 (실측 아님 — 글에서도 정직하게 표기)

| 주장 | 출처 |
|---|---|
| 0.16.0은 ~8개월 릴리스: 244 contributors, 1,183 commits | [Zig 0.16.0 릴리스 노트](https://ziglang.org/download/0.16.0/release-notes.html) |
| `std.Io`는 threaded + evented 백엔드(Linux io_uring, macOS GCD) 위 콜리스 async가 목표 | Zig 0.16.0 릴리스 노트 |
| `std.Io.async` / `std.Io.Group`가 std 소스에 존재 | 핀 고정 0.16.0 툴체인에서 관측(io.zig) |

### 명시적으로 검증 안 함

Linux **io_uring**·macOS **GCD** evented 백엔드는 이 하네스에서 **실행하지 않았다** — 네 프로브 전부
Windows x86_64 **Threaded** 백엔드에서만 돌았다. 두 백엔드의 성능·동작은 릴리스 노트 인용이며 firsthand로
제시하지 않는다. 실제 async 처리량과 0.15→0.16 마이그레이션 규모도 정성/인용이지 실측이 아니다. 이건
컴파일+stdout 프로브라 **속도 벤치가 아니다** — 결과는 머신 무관이다.

## 환경

Windows 11 x86_64 · 네이티브 zig **0.16.0** (Docker 미사용) · `builtin.zig_version`으로 0.16.0 확인.
하드웨어는 무관하다 — 타이밍이 아니라 컴파일러 동작 + 심볼 존재/부재 검증이다.

## 재현

```bash
./run.sh          # 핀 고정 zig 0.16.0 받기 → probe.sh가 네 프로그램 컴파일
# 이미 있으면:
ZIG=/path/to/zig-0.16.0/zig ./run.sh
```

이후 재생성된 `probe-result.gen.json`을 커밋된 `probe-result.json`과 대조한다.

## 원시 데이터

폐기한 것 없음. 대용량 산출물이 없는 런이다. 97 MB 핀 고정 zig 툴체인은 받아서 실행 후 firsthand 정리
정책대로 삭제했고, `run.sh`가 같은 핀 고정 0.16.0을 다시 받아 재현한다. 결정적 증거인 `probe-result.json`은
커밋한다. 커밋된 하네스·증거의 무결성 해시는 `checksums.txt`.
