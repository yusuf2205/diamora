/** Real PostgreSQL 17 binaries as an OS process — dev machines without Docker and integration tests. NOT for production. */
import EmbeddedPostgres from 'embedded-postgres';
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import net from 'node:net';

export function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

export async function startEmbeddedPostgres(opts) {
  const user = opts.user ?? 'yusmus';
  const password = opts.password ?? 'yusmus_dev';
  const database = opts.database ?? 'yusmus_dev';
  const port = opts.port ?? (await freePort());
  const persistent = opts.persistent ?? true;

  mkdirSync(opts.dataDir, { recursive: true });
  const pg = new EmbeddedPostgres({
    databaseDir: opts.dataDir,
    user,
    password,
    port,
    persistent,
    // same collation setup as production (docker-compose POSTGRES_INITDB_ARGS): UTF-8 + ICU ru-RU. Without this initdb
    // follows the OS locale (WIN1251 on a Russian Windows) and cannot store emoji.
    initdbFlags: ['--encoding=UTF8', '--locale=C', '--locale-provider=icu', '--icu-locale=ru-RU'],
    onLog: opts.quiet ? () => {} : (m) => process.stdout.write(`[pg] ${m}`),
    onError: opts.quiet ? () => {} : (m) => process.stderr.write(`[pg] ${m}`),
  });
  if (!existsSync(join(opts.dataDir, 'PG_VERSION'))) await pg.initialise();
  await pg.start();
  try {
    await pg.createDatabase(database);
  } catch (err) {
    if (!/already exists/i.test(String(err?.message ?? err))) throw err;
  }
  const url = `postgresql://${user}:${encodeURIComponent(password)}@127.0.0.1:${port}/${database}?schema=public`;
  return {
    url,
    port,
    async stop() {
      await pg.stop();
      if (!persistent) rmSync(opts.dataDir, { recursive: true, force: true, maxRetries: 5 });
    },
  };
}
