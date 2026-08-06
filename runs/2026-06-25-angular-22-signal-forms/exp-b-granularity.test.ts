import { describe, it, expect } from 'vitest';
import { signal, computed, effect, ApplicationRef, Injector } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { form } from '@angular/forms/signals';
import { FormGroup, FormControl } from '@angular/forms';
import { map } from 'rxjs/operators';
import { record } from './_collect';

interface Model { email: string; age: number; }

describe('Experiment B — reactivity granularity', () => {
  it('Signal Forms: a consumer of one field does NOT re-run when an unrelated field changes', () => {
    TestBed.configureTestingModule({ providers: [provideZonelessChangeDetection()] });
    const injector = TestBed.inject(Injector);
    const appRef = TestBed.inject(ApplicationRef);

    let runs = 0;
    TestBed.runInInjectionContext(() => {
      const model = signal<Model>({ email: 'a@b.com', age: 30 });
      const f = form(model);
      // consumer reads ONLY email
      const upper = computed(() => f.email().value().toUpperCase());
      effect(() => { upper(); runs++; });

      appRef.tick();                       // initial run
      const afterInit = runs;              // 1

      for (let i = 0; i < 5; i++) { f.age().value.set(30 + i + 1); appRef.tick(); }
      const afterUnrelated = runs;         // still 1 (email untouched)

      f.email().value.set('c@d.com'); appRef.tick();
      const afterOwn = runs;               // 2

      record('B_signal', {
        consumer_reads: 'email only',
        runs_after_init: afterInit,
        extra_runs_on_5_unrelated_changes: afterUnrelated - afterInit,
        runs_on_own_field_change: afterOwn - afterUnrelated,
      });
      expect(afterInit).toBe(1);
      expect(afterUnrelated - afterInit).toBe(0);
      expect(afterOwn - afterUnrelated).toBe(1);
    });
  });

  it('Reactive Forms: group.valueChanges fires the map for ANY child change', () => {
    const group = new FormGroup({
      email: new FormControl('a@b.com', { nonNullable: true }),
      age: new FormControl(30, { nonNullable: true }),
    });
    let mapRuns = 0;
    const sub = group.valueChanges.pipe(map(v => { mapRuns++; return v.email; })).subscribe();

    for (let i = 0; i < 5; i++) group.controls.age.setValue(30 + i + 1);
    const afterUnrelated = mapRuns;        // 5 — every unrelated change ran the map
    sub.unsubscribe();

    record('B_reactive', {
      consumer: 'group.valueChanges.pipe(map -> v.email))',
      map_runs_on_5_unrelated_changes: afterUnrelated,
    });
    expect(afterUnrelated).toBe(5);
  });
});
