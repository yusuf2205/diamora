#!/usr/bin/env node
/**
 * Runs the Prisma CLI inside a `pnpm deploy` output directory (Docker build/runtime).
 *   node prisma-deployed.mjs <deploy-dir> generate | migrate deploy | migrate status
 * `pnpm deploy` copies packages but not the generated client, and the CLI must run from the database package's REAL
 * directory so it resolves the same @prisma/client instance the app loads at runtime.
 */
import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const [dir = '.', ...args] = process.argv.slice(2);
if (args.length === 0) {
  console.error('usage: prisma-deployed.mjs <deploy-dir> <prisma args...>');
  process.exit(2);
}
const dbDir = realpathSync(join(resolve(dir), 'node_modules', '@yusmus', 'database'));
const prismaCli = createRequire(join(dbDir, 'package.json')).resolve('prisma/build/index.js');
const res = spawnSync(process.execPath, [prismaCli, ...args], {
  cwd: dbDir,
  stdio: 'inherit',
  env: { ...process.env, DATABASE_URL: process.env.DATABASE_URL ?? 'postgresql://build:build@localhost:5432/build' },
});
process.exit(res.status ?? 1);
