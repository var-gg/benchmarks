import { signal } from '@angular/core';
import { form, required } from '@angular/forms/signals';

interface Model { email: string; age: number; }

const model = signal<Model>({ email: 'a@b.com', age: 30 });
const f = form(model, (p) => {
  required(p.email);
});

// BUG 1 — field-name typo. The field tree is derived from Model, so an unknown
// property is a compile error (expect TS2551 "Did you mean 'email'?").
const typo = f.emial().value();
console.log(typo);

// BUG 2 — wrong type written. value is WritableSignal<number>, so a string is a
// compile error (expect TS2345 not assignable to 'number').
f.age().value.set('thirty');
