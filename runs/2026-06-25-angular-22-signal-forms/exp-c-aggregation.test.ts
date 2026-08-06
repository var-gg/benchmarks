import { describe, it, expect } from 'vitest';
import { signal, computed, effect, ApplicationRef, Injector, provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { form, required } from '@angular/forms/signals';
import { record } from './_collect';

interface Model { user: { name: string; email: string }; age: number; }

describe('Experiment C — nested state aggregation bubbles up the graph', () => {
  it('touched buckets up from the deepest leaf; validity aggregates from descendants', () => {
    TestBed.configureTestingModule({ providers: [provideZonelessChangeDetection()] });
    const appRef = TestBed.inject(ApplicationRef);

    TestBed.runInInjectionContext(() => {
      const model = signal<Model>({ user: { name: '', email: 'a@b.com' }, age: 30 });
      const f = form(model, (p) => { required(p.user.name); });

      // ---- touched bubbling ----
      let rootTouchedRecalcs = 0;
      const rootTouched = computed(() => f().touched());
      effect(() => { rootTouched(); rootTouchedRecalcs++; });
      appRef.tick();
      const recalcAfterInit = rootTouchedRecalcs;

      const beforeLeaf = f.user.name().touched();   // false
      const beforeGroup = f.user().touched();       // false
      const beforeRoot = f().touched();             // false

      f.user.name().markAsTouched();                // touch the DEEPEST leaf
      appRef.tick();

      const leafTouched = f.user.name().touched();  // true
      const groupTouched = f.user().touched();      // true (bubbled)
      const rootTouchedVal = f().touched();         // true (bubbled)
      const recalcAfterTouch = rootTouchedRecalcs;  // exactly 1 more

      // ---- validity aggregation ----
      const leafValidEmpty = f.user.name().valid();  // false (required, empty)
      const rootValidEmpty = f().valid();            // false (descendant invalid)

      f.user.name().value.set('Ada');
      appRef.tick();

      const leafValidFilled = f.user.name().valid(); // true
      const rootValidFilled = f().valid();           // true (recovered, no manual revalidate)

      record('C_aggregation', {
        touched_before: { leaf: beforeLeaf, group: beforeGroup, root: beforeRoot },
        touched_after_leaf_markAsTouched: { leaf: leafTouched, group: groupTouched, root: rootTouchedVal },
        root_touched_computed_recalcs_on_that_change: recalcAfterTouch - recalcAfterInit,
        validity_empty_required: { leaf_valid: leafValidEmpty, root_valid: rootValidEmpty },
        validity_after_set_value: { leaf_valid: leafValidFilled, root_valid: rootValidFilled },
      });

      expect(beforeLeaf).toBe(false);
      expect(groupTouched).toBe(true);
      expect(rootTouchedVal).toBe(true);
      expect(recalcAfterTouch - recalcAfterInit).toBe(1);
      expect(leafValidEmpty).toBe(false);
      expect(rootValidEmpty).toBe(false);
      expect(leafValidFilled).toBe(true);
      expect(rootValidFilled).toBe(true);
    });
  });
});
