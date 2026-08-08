// Firsthand probe for the essay "GraphQL.js v16 vs v17 — 취소·정리·관측".
//
// Runs, in one process, the four contracts the post claims and writes the
// observed outcomes to probe-result.json. It imports BOTH graphql versions via
// npm aliases (see package.json) so the v16 baseline and the v17 behavior are
// exercised side by side.
//
// The evidence is the *event ordering and contracts* (throw vs resolve, whether
// info.getAbortSignal exists, whether a cooperative signal cancels the child
// work, the shape of error.abortedResult), NOT the millisecond timings — those
// drift per machine and are recorded as context only.
import { writeFileSync } from 'node:fs';
import dc from 'node:diagnostics_channel';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// A fake "slow DB": resolves after `ms`, or aborts early iff a signal is passed
// AND fires. `signal===null` models a resolver that does NOT propagate the abort.
function fakeDb(ms, label, signal, log) {
  log(`db:start:${label}`);
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      log(`db:done:${label}`);
      resolve(`${label}-result`);
    }, ms);
    if (signal) {
      const onAbort = () => {
        clearTimeout(t);
        log(`db:abort:${label}`);
        reject(new Error(`db aborted: ${label}`));
      };
      if (signal.aborted) return onAbort();
      signal.addEventListener('abort', onAbort, { once: true });
    }
  });
}

// ---- Experiment 1: cancel A/B (v16 ignores, v17 throws) --------------------
async function experiment1(g, version) {
  const { buildSchema, parse, execute } = g;
  const schema = buildSchema(`type Query { slow: String, slowCooperative: String }`);
  const document = parse(`{ slow slowCooperative }`);

  const events = [];
  const log = (m) => events.push(m);

  const rootValue = {
    // Non-cooperative: never reads the abort signal, never propagates it.
    slow: async (_args, _ctx, _info) => {
      log('resolver:enter:slow');
      const r = await fakeDb(300, 'slow', null, log);
      log('resolver:exit:slow');
      return r;
    },
    // Cooperative: reads info.getAbortSignal() (v17 only) and forwards it.
    slowCooperative: async (_args, _ctx, info) => {
      const sig = typeof info.getAbortSignal === 'function' ? info.getAbortSignal() : undefined;
      log(sig ? 'getAbortSignal:signal' : 'getAbortSignal:undefined');
      const r = await fakeDb(300, 'coop', sig ?? null, log);
      return r;
    },
  };

  const ac = new AbortController();
  const t0 = performance.now();
  setTimeout(() => ac.abort(new Error('client gone')), 80);

  const args = { schema, document, rootValue };
  // v16 has no abortSignal in its execution args; passing it is a no-op there.
  args.abortSignal = ac.signal;

  let outcome, errorName, data;
  try {
    const res = await execute(args);
    outcome = 'resolved';
    data = res.data ?? null;
  } catch (e) {
    outcome = 'threw';
    errorName = e?.constructor?.name ?? String(e);
  }
  const elapsed_ms = Math.round(performance.now() - t0);
  // Give any orphaned non-cooperative timer time to fire so the event log shows it.
  await sleep(350);

  return { version, outcome, errorName, data, elapsed_ms_context_only: elapsed_ms, events };
}

// ---- Experiment 2: cancel is not rollback (partial mutation write) ---------
async function experiment2(g) {
  const { buildSchema, parse, execute, AbortedGraphQLExecutionError } = g;
  const schema = buildSchema(`type Mutation { stepA: String, stepB: String } type Query { _: String }`);
  const document = parse(`mutation { stepA stepB }`);

  const events = [];
  const log = (m) => events.push(m);
  const step = (name) => async () => {
    log(`${name}:enter`);
    await sleep(60);
    log(`${name}:wrote`); // side effect committed, no signal propagation
    return `${name}-ok`;
  };
  const rootValue = { stepA: step('A'), stepB: step('B') };

  const ac = new AbortController();
  setTimeout(() => ac.abort(new Error('client gone')), 90);

  let outcome, errorName, isAborted;
  try {
    await execute({ schema, document, rootValue, abortSignal: ac.signal });
    outcome = 'resolved';
  } catch (e) {
    outcome = 'threw';
    errorName = e?.constructor?.name ?? String(e);
    isAborted = AbortedGraphQLExecutionError ? e instanceof AbortedGraphQLExecutionError : undefined;
  }
  await sleep(50);
  return { outcome, errorName, isAborted, events };
}

// ---- Experiment 3: diagnostics_channel TracingChannel observability --------
async function experiment3(g) {
  const { buildSchema, parse, execute } = g;
  // Enabling the diagnostics module makes graphql publish to the channels.
  let diagnosticsEnabled = false;
  try {
    await import('graphql-v17/diagnostics');
    diagnosticsEnabled = true;
  } catch {
    // Subpath export may not exist; graphql still publishes to the named
    // channels when they have subscribers, so we subscribe directly below.
  }

  const CHANNELS = [
    'graphql:parse',
    'graphql:validate',
    'graphql:execute',
    'graphql:execute:variableCoercion',
    'graphql:execute:rootSelectionSet',
    'graphql:resolve',
    'graphql:subscribe',
  ];
  const order = [];
  let resolvePayloadKeys = null;
  const subs = [];
  for (const name of CHANNELS) {
    const tc = dc.tracingChannel(name);
    const rec = (phase) => (msg) => {
      order.push(`${name}:${phase}`);
      if (name === 'graphql:resolve' && phase === 'start' && !resolvePayloadKeys && msg) {
        resolvePayloadKeys = Object.keys(msg).sort();
      }
    };
    const handlers = { start: rec('start'), end: rec('end'), asyncStart: rec('asyncStart'), asyncEnd: rec('asyncEnd'), error: rec('error') };
    tc.subscribe(handlers);
    subs.push({ tc, handlers });
  }

  const schema = buildSchema(`type Nested { a: String, b: String } type Query { hello(name: String): String, nested: Nested }`);
  const document = parse(`query Q($n: String){ hello(name:$n) nested { a b } }`);
  const rootValue = {
    hello: (args) => `hi ${args.name}`,
    nested: () => ({
      a: async () => { await sleep(20); return 'A'; }, // async → asyncStart/asyncEnd
      b: () => 'B',
    }),
  };
  await execute({ schema, document, rootValue, variableValues: { n: 'x' } });
  await sleep(60);
  for (const { tc, handlers } of subs) { try { tc.unsubscribe(handlers); } catch {} }

  const observed = order.length > 0;
  return {
    diagnostics_module_import: diagnosticsEnabled,
    observed,
    channel_events: order,
    resolve_payload_keys: resolvePayloadKeys,
    note: observed
      ? 'Channels published in this order; graphql:resolve carried the listed payload keys.'
      : 'No diagnostics channel events observed in this re-run (feature may require explicit enablement in this build); reported honestly rather than fabricated.',
  };
}

// ---- Experiment 4: partial result on abort (error.abortedResult) -----------
async function experiment4(g) {
  const { buildSchema, parse, execute, AbortedGraphQLExecutionError } = g;
  const schema = buildSchema(`type Query { fast: String, slow: String }`);
  const document = parse(`{ fast slow }`);
  const rootValue = {
    fast: () => 'FAST',
    slow: async (_a, _c, info) => {
      const sig = typeof info.getAbortSignal === 'function' ? info.getAbortSignal() : null;
      return fakeDb(300, 'slow', sig, () => {});
    },
  };
  const ac = new AbortController();
  setTimeout(() => ac.abort(new Error('client gone')), 80);

  let caught, isAborted, causeMessage, hasAbortedResult, abortedResult;
  try {
    await execute({ schema, document, rootValue, abortSignal: ac.signal });
    caught = 'none (resolved)';
  } catch (e) {
    caught = e?.constructor?.name ?? String(e);
    isAborted = AbortedGraphQLExecutionError ? e instanceof AbortedGraphQLExecutionError : undefined;
    causeMessage = e?.cause?.message;
    hasAbortedResult = 'abortedResult' in (e ?? {});
    if (hasAbortedResult) {
      try {
        const r = await e.abortedResult;
        abortedResult = { data: r?.data ?? null, errors: (r?.errors ?? []).map((x) => ({ message: x.message, path: x.path })) };
      } catch (inner) {
        abortedResult = { error_awaiting: String(inner) };
      }
    }
  }
  await sleep(350);
  return { caught, isAborted, causeMessage, hasAbortedResult, abortedResult };
}

async function main() {
  const g16 = await import('graphql-v16');
  const g17 = await import('graphql-v17');

  const result = {
    generated_at: new Date().toISOString(),
    node: process.version,
    versions: {
      v16: (g16.version ?? g16.default?.version ?? 'unknown'),
      v17: (g17.version ?? g17.default?.version ?? 'unknown'),
    },
    experiment1_cancel_ab: {
      v16: await experiment1(g16, 'v16'),
      v17: await experiment1(g17, 'v17'),
    },
    experiment2_cancel_not_rollback_v17: await experiment2(g17),
    experiment3_diagnostics_v17: await experiment3(g17),
    experiment4_partial_result_v17: await experiment4(g17),
  };

  writeFileSync(new URL('./probe-result.json', import.meta.url), JSON.stringify(result, null, 2) + '\n');
  console.log('wrote probe-result.json');
  console.log('v16:', result.versions.v16, '| v17:', result.versions.v17);
}

main().catch((e) => { console.error(e); process.exit(1); });
