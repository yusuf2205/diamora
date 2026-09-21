#!/usr/bin/env node
/** Runs a command with the repo-root `.env` loaded (already-set variables win). node infra/scripts/with-env.mjs <cmd> [args] */
import { existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const envFile = resolve(root, process.env.ENV_FILE ?? '.env');
if (existsSync(envFile)) process.loadEnvFile(envFile); // does not override existing variables

const [cmd, ...args] = process.argv.slice(2);
if (!cmd) {
  console.error('usage: with-env.mjs <command> [args...]');
  process.exit(2);
}
const res = spawnSync(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', env: process.env });
process.exit(res.status ?? 1);
