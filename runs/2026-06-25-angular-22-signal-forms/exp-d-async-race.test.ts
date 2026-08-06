import { describe, it, expect } from 'vitest';
import { signal, resource, ApplicationRef, provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { form, validateAsync } from '@angular/forms/signals';
import { record } from './_collect';

interface Model { username: string; }

const tickMicro = () => new Promise<void>((r) => setTimeout(r, 15));

describe('Experiment D — async validation race: stale request aborts, latest wins', () => {
  it('changing the value mid-flight aborts the in-flight request via abortSignal', async () => {
    TestBed.configureTestingModule({ providers: [provideZonelessChangeDetection()] });
    const appRef = TestBed.inject(ApplicationRef);

    const starts: string[] = [];
    const aborted: string[] = [];
    const completed: string[] = [];

    // A gate all loaders await, so both requests are in flight before we release.
    let release!: () => void;
    const gate = new Promise<void>((r) => { release = r; });

    await TestBed.runInInjectionContext(async () => {
      const model = signal<Model>({ username: 'ada' });
      const f = form(model, (p) => {
        validateAsync(p.username, {
          params: (ctx) => ctx.value(),
          factory: (paramsSig) =>
            resource({
              params: paramsSig,
              loader: async ({ params, abortSignal }) => {
                const value = params as string;
                starts.push(value);
                abortSignal.addEventListener('abort', () => aborted.push(value));
                await gate;
                if (abortSignal.aborted) return [] as never[]; // stale: drop
                completed.push(value);
                return [] as never[];
              },
            }),
          onSuccess: () => [],
        });
      });

      // Pull the validity graph so the resource is driven.
      f().valid();

      f.username().value.set('taken'); appRef.tick(); f().valid(); await tickMicro();
      f.username().value.set('free');  appRef.tick(); f().valid(); await tickMicro();

      release();                        // let both in-flight loaders resume
      await tickMicro(); appRef.tick(); await tickMicro();

      record('D_async_race', {
        starts,
        aborted,
        completed,
        stale_taken_aborted: aborted.includes('taken'),
        stale_taken_not_completed: !completed.includes('taken'),
        latest_free_completed: completed.includes('free'),
      });

      expect(starts).toContain('taken');
      expect(starts).toContain('free');
      expect(aborted).toContain('taken');
      expect(completed).not.toContain('taken');
      expect(completed).toContain('free');
    });
  });
});
