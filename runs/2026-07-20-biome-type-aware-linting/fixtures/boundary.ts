// CASE A — native Promise-returning function (should be flagged)
async function nativeP(): Promise<void> {}
nativeP();

// CASE B — custom PromiseLike / thenable (typescript-eslint flags; does Biome?)
interface Thenable { then(onF: (v: number) => void): void; }
function customThenable(): Thenable { return { then() {} }; }
customThenable();

// CASE C — Promise.all array (aggregate promise)
Promise.all([nativeP(), nativeP()]);
