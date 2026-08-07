// Minimal static server for the passkey harness page.
// localhost is a secure context, so WebAuthn / the virtual authenticator works
// without HTTPS. Playwright's webServer (see playwright.config.ts) boots this.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, normalize } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, 'public');
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css' };

const server = createServer(async (req, res) => {
  let path = normalize(decodeURIComponent((req.url ?? '/').split('?')[0]));
  if (path === '/' || path === '\\' || path === '.') path = '/index.html';
  try {
    const file = join(ROOT, path);
    if (!file.startsWith(ROOT)) { res.writeHead(403); return res.end('forbidden'); }
    const body = await readFile(file);
    const ext = path.slice(path.lastIndexOf('.'));
    res.writeHead(200, { 'content-type': TYPES[ext] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end('not found');
  }
});

const PORT = process.env.PORT ? Number(process.env.PORT) : 4599;
server.listen(PORT, () => console.log(`passkey harness on http://localhost:${PORT}`));
