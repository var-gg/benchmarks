async function save(): Promise<void> {}

// FLOATING: return value (a Promise) is discarded, no await/catch/void
save();

// HANDLED: awaited inside an async wrapper
async function ok() {
  await save();
}
