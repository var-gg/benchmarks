/*
 * firsthand harness — Vercel AI SDK 6 (ai@6.0.212) agent tool-loop control flow.
 * Model calls = 0. MockLanguageModelV3 (ai/test) makes every run deterministic.
 * Reproduces the API-surface + control-flow assertions recorded in the blog post.
 * Emits probe-result.json (machine-readable evidence).
 */
import {
  generateText, generateObject, tool,
  stepCountIs, hasToolCall,
  Experimental_Agent, ToolLoopAgent,
  NoObjectGeneratedError,
} from 'ai';
import { MockLanguageModelV3 } from 'ai/test';
import { z } from 'zod';
import { writeFileSync } from 'node:fs';

const USAGE = { inputTokens: 10, outputTokens: 5, totalTokens: 15 };

const weather = tool({
  description: 'Get the weather for a city',
  inputSchema: z.object({ city: z.string() }),
  execute: async ({ city }: { city: string }) => ({ city, tempC: 21 }),
});

const toolCallPart = (name: string, args: unknown) => ({
  type: 'tool-call' as const, toolCallId: 'id-' + name, toolName: name, input: JSON.stringify(args),
});
const textPart = (t: string) => ({ type: 'text' as const, text: t });

// A doGenerate that scripts step-by-step content based on call index.
function scripted(scripts: ReturnType<typeof textPart>[][] | any[]) {
  let i = 0;
  return new MockLanguageModelV3({
    doGenerate: async () => {
      const s = scripts[Math.min(i, scripts.length - 1)];
      i++;
      const hasTool = s.some((p: any) => p.type === 'tool-call');
      return { content: s, finishReason: hasTool ? 'tool-calls' : 'stop', usage: USAGE, warnings: [] };
    },
  });
}

const out: any = { meta: {}, experiments: {} };

// --- static API-surface facts ---
out.experiments.api_surface = {
  toolLoopAgent_is_experimental_agent: (ToolLoopAgent as unknown) === (Experimental_Agent as unknown),
  maxSteps_exported: 'maxSteps' in (await import('ai')),
  mock_is_v3: typeof MockLanguageModelV3 === 'function',
};

// A. 2-step tool loop with stopWhen: stepCountIs(5)
{
  const r = await generateText({
    model: scripted([[toolCallPart('weather', { city: 'Seoul' })], [textPart('Seoul is 21C.')]]),
    tools: { weather },
    stopWhen: stepCountIs(5),
    prompt: 'weather in Seoul?',
  });
  out.experiments.A_loop_stepCountIs5 = {
    steps: r.steps.length, text: r.text,
    toolResults: r.steps.flatMap(s => s.toolResults.map((t: any) => t.output)),
  };
}

// B. no stopWhen -> no loop
{
  const r = await generateText({
    model: scripted([[toolCallPart('weather', { city: 'Seoul' })], [textPart('Seoul is 21C.')]]),
    tools: { weather },
    prompt: 'weather in Seoul?',
  });
  out.experiments.B_no_stopWhen = {
    steps: r.steps.length, text: r.text,
    toolResults: r.steps.flatMap(s => s.toolResults.map((t: any) => t.output)),
  };
}

// B2. stopWhen hasToolCall
{
  const r = await generateText({
    model: scripted([[toolCallPart('weather', { city: 'Seoul' })], [textPart('Seoul is 21C.')]]),
    tools: { weather },
    stopWhen: hasToolCall('weather'),
    prompt: 'weather in Seoul?',
  });
  out.experiments.B2_hasToolCall = { steps: r.steps.length, text: r.text };
}

// C. tool execute throws -> tool-error fed back, self-heal
{
  const boom = tool({ description: 'boom', inputSchema: z.object({ city: z.string() }), execute: async () => { throw new Error('TOOL_BOOM'); } });
  let threw = false;
  let r: any;
  try {
    r = await generateText({
      model: scripted([[toolCallPart('boom', { city: 'Seoul' })], [textPart('recovered')]]),
      tools: { boom },
      stopWhen: stepCountIs(5),
      prompt: 'go',
    });
  } catch { threw = true; }
  out.experiments.C_tool_throws = {
    threw, steps: r ? r.steps.length : null, text: r ? r.text : null,
    step0_content_types: r ? r.steps[0].content.map((p: any) => p.type) : null,
  };
}

// C2. model calls a nonexistent tool
{
  let threw = false;
  let r: any;
  try {
    r = await generateText({
      model: scripted([[toolCallPart('ghost', { city: 'X' })], [textPart('ok')]]),
      tools: { weather },
      stopWhen: stepCountIs(5),
      prompt: 'go',
    });
  } catch { threw = true; }
  out.experiments.C2_ghost_tool = {
    threw, steps: r ? r.steps.length : null,
    step0_content_types: r ? r.steps[0].content.map((p: any) => p.type) : null,
  };
}

// D. structured output boundaries
{
  const okModel = new MockLanguageModelV3({ doGenerate: async () => ({ content: [textPart(JSON.stringify({ city: 'Seoul', tempC: 21 }))], finishReason: 'stop', usage: USAGE, warnings: [] }) });
  const r = await generateObject({ model: okModel, schema: z.object({ city: z.string(), tempC: z.number() }), prompt: 'x' });
  out.experiments.D_object_valid = { object: r.object, tempC_times2: (r.object as any).tempC * 2 };

  let violation = 'no-throw';
  try {
    const badModel = new MockLanguageModelV3({ doGenerate: async () => ({ content: [textPart(JSON.stringify({ city: 'Seoul', tempC: 'hot' }))], finishReason: 'stop', usage: USAGE, warnings: [] }) });
    await generateObject({ model: badModel, schema: z.object({ city: z.string(), tempC: z.number() }), prompt: 'x' });
  } catch (e: any) { violation = NoObjectGeneratedError.isInstance(e) ? 'AI_NoObjectGeneratedError' : e?.name || String(e); }
  out.experiments.D_object_schema_violation = { result: violation };

  let nonjson = 'no-throw';
  try {
    const njModel = new MockLanguageModelV3({ doGenerate: async () => ({ content: [textPart('not json at all')], finishReason: 'stop', usage: USAGE, warnings: [] }) });
    await generateObject({ model: njModel, schema: z.object({ city: z.string() }), prompt: 'x' });
  } catch (e: any) { nonjson = NoObjectGeneratedError.isInstance(e) ? 'AI_NoObjectGeneratedError' : e?.name || String(e); }
  out.experiments.D_object_nonjson = { result: nonjson };
}

// F. ToolLoopAgent wrapper
{
  const agent = new ToolLoopAgent({
    model: scripted([[toolCallPart('weather', { city: 'Busan' })], [textPart('Busan 21C.')]]),
    tools: { weather },
    stopWhen: stepCountIs(5),
  });
  const r = await agent.generate({ prompt: 'weather in Busan?' });
  out.experiments.F_agent_wrapper = { steps: r.steps.length, text: r.text };
}

// F2. ToolLoopAgent default stopWhen = stepCountIs(20) vs generateText no loop
{
  const neverEnd = () => new MockLanguageModelV3({ doGenerate: async () => ({ content: [toolCallPart('weather', { city: 'Loop' })], finishReason: 'tool-calls', usage: USAGE, warnings: [] }) });
  const agent = new ToolLoopAgent({ model: neverEnd(), tools: { weather } });
  const ra = await agent.generate({ prompt: 'loop' });
  const rg = await generateText({ model: neverEnd(), tools: { weather }, prompt: 'loop' });
  out.experiments.F2_default_cap = { agent_steps: ra.steps.length, generateText_steps: rg.steps.length };
}

// G. maxSteps removed -> ignored, single step
{
  const r = await generateText({
    // @ts-expect-error maxSteps was removed in v6
    maxSteps: 5,
    model: scripted([[toolCallPart('weather', { city: 'Seoul' })], [textPart('Seoul is 21C.')]]),
    tools: { weather },
    prompt: 'weather?',
  });
  out.experiments.G_maxSteps_ignored = { steps: r.steps.length, text: r.text };
}

out.meta = {
  ai_version: '6.0.212',
  zod_version: '4.4.3',
  node: process.version,
  model_calls: 0,
  determinism: 'MockLanguageModelV3 (ai/test) — no network, no LLM',
};

writeFileSync('probe-result.json', JSON.stringify(out, null, 2));
console.log(JSON.stringify(out.experiments, null, 2));
