import { Controller, Delete, Get, Inject, Injectable, Module, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { appendFile, readdir, readFile, stat, statfs, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import { AuditService } from '../audit/audit.service';
import { Roles } from '../common/decorators';
import { invariant, notFound } from '../common/errors';
import { ENV, Env } from '../config/env';

const MARKER = '.diamoraa-offsite';
const KINDS = ['daily', 'weekly', 'monthly'] as const;
/** only whole database copies may be removed, by name: `postgres/<kind>/yusmus-20260930-210000.dump` */
const DUMP = /^postgres\/(daily|weekly|monthly)\/[A-Za-z0-9._-]+\.dump$/;

async function dirSize(p: string): Promise<number> {
  let n = 0;
  for (const e of await readdir(p, { withFileTypes: true }).catch(() => [])) {
    const f = join(p, e.name);
    n += e.isDirectory() ? await dirSize(f) : (await stat(f).catch(() => ({ size: 0 }))).size;
  }
  return n;
}
/** yusmus-20260930-210000.dump -> 2026-09-30T21:00:00Z */
const dumpDate = (name: string) => {
  const m = /(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/.exec(name);
  return m ? `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}Z` : null;
};

/**
 * «Система → Внешний диск» (SUPER_ADMIN only): what the external drive holds and how much space is left; old database
 * copies can be removed there (and are never copied back). Only the folder with the marker file is ever read or touched.
 */
@Injectable()
export class OffsiteService {
  constructor(@Inject(ENV) private readonly env: Env, private readonly audit: AuditService) {}

  private async target(): Promise<{ dir: string; drive: string } | null> {
    const root = this.env.OFFSITE_USB_ROOT;
    if (!root) return null;
    for (const drive of await readdir(root).catch(() => [] as string[])) {
      const dir = join(root, drive, 'diamoraa-backup');
      if (await stat(join(dir, MARKER)).then(() => true, () => false)) return { dir, drive };
    }
    return null;
  }

  async list() {
    const t = await this.target();
    if (!t) return { found: false as const };
    const fs = await statfs(t.dir).catch(() => null);
    const copies = [];
    for (const kind of KINDS) {
      for (const f of (await readdir(join(t.dir, 'postgres', kind)).catch(() => [] as string[])).filter((x) => x.endsWith('.dump')).sort().reverse()) {
        copies.push({ path: `postgres/${kind}/${f}`, kind, name: f, at: dumpDate(f), bytes: (await stat(join(t.dir, 'postgres', kind, f))).size });
      }
    }
    const readme = await readFile(join(t.dir, 'ПРОЧТИ.txt'), 'utf8').catch(() => '');
    return {
      found: true as const,
      drive: t.drive,
      freeBytes: fs ? fs.bavail * fs.bsize : null,
      totalBytes: fs ? fs.blocks * fs.bsize : null,
      updated: /(\d{4}-\d{2}-\d{2} \d{2}:\d{2})/.exec(readme)?.[1] ?? null,
      copies,
      photosBytes: await dirSize(join(t.dir, 'minio')),
      baseBytes: await dirSize(join(t.dir, 'postgres', 'base')),
      usedBytes: await dirSize(t.dir),
    };
  }

  async remove(path: string) {
    if (!DUMP.test(path) || path.includes('..')) throw invariant('Only a database copy can be removed');
    const t = await this.target();
    if (!t) throw notFound('External drive');
    const file = join(t.dir, ...path.split('/'));
    if (!(await stat(file).then((s) => s.isFile(), () => false))) throw notFound('Copy');
    await unlink(file);
    await unlink(`${file}.sha256`).catch(() => undefined);
    // never copied back by the nightly job
    await appendFile(join(t.dir, '.deleted'), `${path.split('/').pop()}\n`);
    await this.audit.record({ action: 'backup.offsite_delete', entity: 'Backup', entityId: null, before: { path } });
    return { deleted: true };
  }
}

@ApiTags('insights')
@ApiBearerAuth()
@Controller('admin/backups/offsite')
export class OffsiteController {
  constructor(private readonly offsite: OffsiteService) {}

  @Roles('SUPER_ADMIN') @Get()
  list() { return this.offsite.list(); }

  @Roles('SUPER_ADMIN') @Delete()
  remove(@Query('path') path: string) { return this.offsite.remove(String(path ?? '')); }
}

@Module({ controllers: [OffsiteController], providers: [OffsiteService] })
export class OffsiteModule {}
