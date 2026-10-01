// The demo stack, fresh every time: an EMPTY local PostgreSQL (its own folder), migrations, the demo API filled with
// made-up data (apps/api/src/cli/demo-server.ts). Stays up until Ctrl+C. Needs `pnpm --filter @diamoraa/api build` once.
//   node demo.mjs            -> API on http://localhost:3000 (the panel: `next start -p 3001` in apps/web)
import { spawn, spawnSync } from 'node:child_process';
import { rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { startEmbeddedPostgres } from '../../infra/scripts/lib/embedded-pg.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const dataDir = resolve(root, '.dev-data/tutorial');
rmSync(dataDir, { recursive: true, force: true });
const db = await startEmbeddedPostgres({ dataDir, port: 54339, database: 'diamoraa_demo' });
console.log('demo db ready');
const env = { ...process.env, DATABASE_URL: db.url };
const mig = spawnSync('npx', ['prisma', 'migrate', 'deploy'], { cwd: resolve(root, 'packages/database'), env, shell: true, stdio: 'inherit' });
if (mig.status !== 0) process.exit(1);
const api = spawn('node', ['dist/cli/demo-server.js'], { cwd: resolve(root, 'apps/api'), env: { ...env, DEMO_SERVER: '1' }, stdio: 'inherit' });
const stop = async () => { api.kill(); await db.stop().catch(() => undefined); process.exit(0); };
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
api.on('exit', async (code) => { await db.stop().catch(() => undefined); process.exit(code ?? 0); });
