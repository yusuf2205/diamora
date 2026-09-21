/* ONE real PostgreSQL 17 for the whole test run, with the production migrations applied. */
const path = require('node:path');
const os = require('node:os');
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');

module.exports = async () => {
  const repoRoot = path.resolve(__dirname, '../../../..');
  const dbPkg = path.join(repoRoot, 'packages/database');
  const { startEmbeddedPostgres } = await import(pathToFileURL(path.join(repoRoot, 'infra/scripts/lib/embedded-pg.mjs')).href);
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'yusmus-test-pg-'));
  const db = await startEmbeddedPostgres({ dataDir, persistent: false, database: 'yusmus_test', quiet: true });
  const prismaCli = require.resolve('prisma/build/index.js', { paths: [dbPkg] });
  execFileSync(process.execPath, [prismaCli, 'migrate', 'deploy'], { cwd: dbPkg, env: { ...process.env, DATABASE_URL: db.url }, stdio: ['ignore', 'ignore', 'inherit'] });
  process.env.TEST_DATABASE_URL = db.url;
  globalThis.__TEST_PG__ = db;
};
