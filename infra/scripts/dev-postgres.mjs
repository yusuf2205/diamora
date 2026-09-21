#!/usr/bin/env node
/** Local PostgreSQL 17 for development (no Docker): `pnpm dev:db` -> .dev-data/pg17u, port 54329. Prints DATABASE_URL. */
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { startEmbeddedPostgres } from './lib/embedded-pg.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};
const db = await startEmbeddedPostgres({
  dataDir: resolve(root, opt('data', '.dev-data/pg17u')),
  port: Number(opt('port', '54329')),
  database: opt('db', 'yusmus_dev'),
});
console.log(`\nPostgreSQL ready.\nDATABASE_URL=${db.url}\nCtrl+C to stop (data kept in .dev-data/).`);
const shutdown = async () => {
  await db.stop().catch(() => {});
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
setInterval(() => {}, 1 << 30);
