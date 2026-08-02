# Vercel AI SDK 6 agent tool loop — verified with a zero-model-call mock

📝 Post (KO): https://var.gg/ko/blog/vercel-ai-sdk-6-agent-loop
📝 Post (EN): https://var.gg/en/blog/vercel-ai-sdk-6-agent-loop
🗓 Run: 2026-06-30 (harness re-run live 2026-08-03) · 🤖 Executed by: **agent** · 👤 Operator: curioustore
🌐 한국어: [README.ko.md](./README.ko.md)

> The post argues that an "agent" in Vercel AI SDK 6 is not magic — it is a `while` loop that
> re-calls the model, and **whether it loops at all is decided entirely by `stopWhen`**. Instead
> of re-narrating the docs, this run drives the SDK's real agent loop with a **scripted
> `MockLanguageModelV3` (zero model calls)** and reads back concrete fields: step counts, the
> content-part types the SDK emits, the error class it throws, and the `ToolLoopAgent` default
> cap. `git clone` + `./run.sh` reproduces it against the **pinned** `ai@6.0.212`.

## What is checked

`exp.ts` runs 13 experiments in 5 groups against `ai@6.0.212`. The model is a hand-scripted mock,
so **no LLM is called** and every value below is pinned by the SDK version, not by hardware or a
provider. Source of truth: `probe-result.json`.

## Claim ↔ evidence

Every **firsthand** claim in the post maps to a field in `probe-result.json`. Claims sourced from
the SDK's type declarations are listed separately as *cited, not measured*.

### Firsthand (SDK runtime behavior — deterministic)

| Claim in the post | Evidence (`probe-result.json`) | Value |
|---|---|---|
| The v6 agent class has **two names for one class** | `api_surface.toolLoopAgent_is_experimental_agent` | `ToolLoopAgent === Experimental_Agent` → **true** |
| **`maxSteps` was removed** from the v6 surface | `api_surface.maxSteps_exported` | **false** (not exported) |
| With `stopWhen: stepCountIs(5)`, a tool-call→text script **loops twice** | `A_loop_stepCountIs5` | steps=**2**, tool ran, text `"Seoul is 21C."` |
| **Without `stopWhen` there is no loop** — the tool runs but the answer is empty | `B_no_stopWhen` | steps=**1**, text `""`, yet `toolResults=[{city:Seoul,tempC:21}]` |
| `stopWhen: hasToolCall('weather')` stops right after that call | `B2_hasToolCall` | steps=**1** |
| A throwing tool is **caught and fed back as `tool-error`** (self-heal, no crash) | `C_tool_throws` | threw=**false**, steps=2, step0=`['tool-call','tool-error']`, text `"recovered"` |
| A **nonexistent tool** call also surfaces as `tool-error`, loop continues | `C2_ghost_tool` | threw=**false**, step0=`['tool-call','tool-error']` |
| Structured output: valid JSON is **typed at runtime** | `D_object_valid` | `object={city,tempC}`, `tempC*2=42` |
| Schema violation / non-JSON **throws `AI_NoObjectGeneratedError`** | `D_object_schema_violation`, `D_object_nonjson` | both → **AI_NoObjectGeneratedError** |
| `ToolLoopAgent` is a **thin wrapper** over the same loop | `F_agent_wrapper` | steps=2, text `"Busan 21C."` |
| The agent class **default `stopWhen` is `stepCountIs(20)`** — a never-ending model silently burns 20 calls; bare `generateText` does not loop | `F2_default_cap` | agent steps=**20**, `generateText` steps=**1** |
| v5's `maxSteps` is **ignored** in v6 (loop silently collapses to one step) | `G_maxSteps_ignored` | steps=**1**, text `""` |

### Cited, not measured (the post flags these the same way)

| Claim | Source |
|---|---|
| `generateObject` is `@deprecated` in 6.0.212; recommended path is `generateText({ output: Output.object(...) })` (still experimental) | `ai@6.0.212` type declarations (`node_modules/ai/dist/*.d.ts`) |
| Agent system prompt renamed `system` → `instructions` in v6 | `ai@6.0.212` `ToolLoopAgent` options |

### Explicitly NOT verified

- **Real-provider behavior.** The mock scripts `doGenerate` by hand. Real-LLM nondeterminism
  (malformed tool arguments, runaway tool loops, provider-native structured output) is **not**
  reproduced — this checks the SDK's **contract and control flow**, not model behavior.
- **Tool-error override.** The self-heal is the **default**; `onError` / tool options can change it.
- **Streaming part order.** The `fullStream` emission order was seen in the original firsthand run
  but is not re-asserted in this committed harness (it is an order of emission, not a scalar) —
  cited, not re-measured.
- **`usage` tokens** are mock-filled placeholders, not real counts.

## Environment

Windows 11 x64 · native (no Docker) · Node v24.15.0 · `ai@6.0.212`, `zod@4.4.3` (pinned), `tsx`.
Hardware is irrelevant — the harness makes **0 model calls** and observes SDK control flow, not timing.

## Reproduce

```bash
./run.sh                       # npm install pinned deps, run the 0-model-call mock harness
git diff -- probe-result.json  # should be empty except meta.node (your local Node)
```

## Honest note on the date

The post published **2026-06-30**. The original ad-hoc harness lived in a gitignored `tmp/`
scratch dir and was cleaned up after publication; the firsthand **record** was preserved.
`exp.ts` is reconstructed from that record and **re-run live on 2026-08-03** against the same
pinned `ai@6.0.212`. Because the harness makes zero model calls, the result is deterministic and
every recorded assertion reproduced exactly — so this is a genuine live run (`backfilled:false`),
not a paper reconstruction.

## Files

| File | What it is |
|---|---|
| `exp.ts` | The harness. 13 experiments driving the SDK's agent loop with a scripted mock. Zero model calls. |
| `probe-result.json` | Committed evidence: the 13-experiment matrix (step counts, content-part types, error classes). |
| `results.json` | Claim-facing summary grouped by API surface / loop control / self-heal / structured output / agent class / migration trap, with not-measured and cited-vs-measured splits. |
| `manifest.json` | Environment, pinned versions, `executed_by`, reconstruction note, retention policy. |
| `package.json` | Pins `ai@6.0.212` + `zod@4.4.3` so `run.sh` installs the exact subject. |
| `run.sh` | Reproduction entry point (install → probe). |
| `checksums.txt` | sha256 of the committed harness + evidence. |
