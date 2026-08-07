import { test, expect } from '@playwright/test';

// Reconstructed from the run's recorded methodology (see manifest.json.backfill_note).
// API ground truth read from @playwright/test 1.61.1 types.d.ts:
//   context.credentials.create(rpId, {id?, privateKey?, publicKey?, userHandle?})
//     -> {id, rpId, userHandle, privateKey, publicKey}   (rpId-only: auto P-256, discoverable)
//   context.credentials.get({id?, rpId?}) -> Array<{...}>  (exports keys, for re-seeding)
//   context.credentials.delete(id)
//   context.credentials.install()  -- MUST precede any navigator.credentials use on the page.

const RP = 'localhost';

test.describe('Playwright 1.61 context.credentials — virtual passkey', () => {
  // 1) Seed a discoverable credential; a usernameless get() on the page resolves it.
  test('seeded passkey resolves a usernameless get()', async ({ context, page }) => {
    const seeded = await context.credentials.create(RP); // rpId only -> auto P-256, discoverable
    await context.credentials.install(); // before the page touches navigator.credentials
    await page.goto('/');
    const assertion = await page.evaluate(() => (window as any).doAuthenticate());
    expect(assertion.rawId).toBe(seeded.id); // rawId matches the seeded credential id
    expect(assertion.userHandle).toBe(seeded.userHandle); // userHandle round-trips
    expect(assertion.signature.length).toBeGreaterThan(0); // an assertion signature exists
  });

  // 2) Register on the page, export the keys via get(), re-seed a fresh context, log in.
  test('register -> export -> re-seed a new context -> login', async ({ browser }) => {
    const ctx1 = await browser.newContext();
    await ctx1.credentials.create(RP);
    await ctx1.credentials.install();
    const p1 = await ctx1.newPage();
    await p1.goto('/');
    await p1.evaluate(() => (window as any).doRegister('alice@example.com'));
    const exported = await ctx1.credentials.get({ rpId: RP }); // keys included, for re-seed
    expect(exported.length).toBeGreaterThan(0);
    await ctx1.close();

    const ctx2 = await browser.newContext();
    await ctx2.credentials.create(RP, {
      id: exported[0].id,
      privateKey: exported[0].privateKey,
      publicKey: exported[0].publicKey,
      userHandle: exported[0].userHandle,
    });
    await ctx2.credentials.install();
    const p2 = await ctx2.newPage();
    await p2.goto('/');
    const assertion = await p2.evaluate(() => (window as any).doAuthenticate());
    expect(assertion.rawId).toBe(exported[0].id); // same credential logs in a fresh context
    await ctx2.close();
  });

  // 3) install() active but nothing seeded -> the page get() rejects with NotAllowedError.
  test('no credential -> get() rejects NotAllowedError', async ({ context, page }) => {
    await context.credentials.install();
    await page.goto('/');
    const errName = await page.evaluate(async () => {
      try { await (window as any).doAuthenticate(); return null; }
      catch (e: any) { return e.name; }
    });
    expect(errName).toBe('NotAllowedError');
  });

  // 4) install() OMITTED -> falls through to each engine's native behavior. The point of
  //    the essay: this is not a clean no-op. We assert the ceremony never silently succeeds.
  //    (chromium: NotSupportedError, firefox: indefinite hang, webkit: TypeError, observed
  //    2026-06-24 — see results.json.install_omitted_native_behavior.)
  test('install() omitted -> native fallback, never a clean success', async ({ context, page }) => {
    await context.credentials.create(RP); // seeded but NOT installed -> invisible to the page
    await page.goto('/');
    const outcome = await page.evaluate(async () => {
      const auth = (window as any)
        .doAuthenticate()
        .then(() => ({ ok: true }))
        .catch((e: any) => ({ err: e.name }));
      // Race a timeout so firefox's indefinite native hang resolves the assertion deterministically.
      const timed = new Promise((res) => setTimeout(() => res({ hang: true }), 4000));
      return Promise.race([auth, timed]);
    });
    expect((outcome as any).ok).toBeFalsy(); // must NOT be a clean success on any engine
  });
});
