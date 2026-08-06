import { FormGroup, FormControl } from '@angular/forms';

// Reactive Forms with a fully typed FormGroup. Angular 14+ typed forms recover
// static typing for STATICALLY-KNOWN literal paths — this experiment targets the
// stringly-typed access surface the post scopes its claim to: group.get('path').
const group = new FormGroup({
  email: new FormControl('a@b.com', { nonNullable: true }),
  age: new FormControl(30, { nonNullable: true }),
});

// BUG 1 — field-name typo. group.get(<unknown key>) is stringly-typed: the return
// is AbstractControl | null regardless of spelling, so 'emial' compiles fine and
// only fails at runtime (null deref on .value). Typed forms cannot catch a typo.
const typo = group.get('emial');
console.log(typo?.value);

// BUG 2 — wrong type written into a number field, via a runtime string path (the
// idiomatic pattern for dynamic / generic / deeply-nested forms). get(<dynamic>)
// returns AbstractControl<any> | null, whose setValue(value: any) accepts anything,
// so this compiles and corrupts the model at runtime.
const fieldName: string = ['age', 'email'][0];
group.get(fieldName)!.setValue('thirty');
