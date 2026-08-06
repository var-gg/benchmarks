import { writeFileSync, existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
const FILE = resolve(process.cwd(), 'probe-result.json');
export function record(key: string, value: unknown) {
  let obj: Record<string, unknown> = {};
  try { if (existsSync(FILE)) obj = JSON.parse(readFileSync(FILE, 'utf8')); } catch {}
  obj[key] = value;
  writeFileSync(FILE, JSON.stringify(obj, null, 2));
}
