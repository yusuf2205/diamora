import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** «Система → Внешний диск»: only SUPER_ADMIN sees it and may remove old database copies; nothing else is touchable. */
describe('external drive copies', () => {
  let t: TestApp;
  const usb = mkdtempSync(join(tmpdir(), 'usb-'));
  const dir = join(usb, 'sdd1', 'diamoraa-backup');
  beforeAll(async () => {
    mkdirSync(join(dir, 'postgres', 'daily'), { recursive: true });
    mkdirSync(join(dir, 'minio', 'products'), { recursive: true });
    writeFileSync(join(dir, '.diamoraa-offsite'), 'marker');
    writeFileSync(join(dir, 'ПРОЧТИ.txt'), 'Последнее обновление: 2026-10-01 23:00 (UTC)');
    writeFileSync(join(dir, 'postgres', 'daily', 'yusmus-20260920-210000.dump'), 'x'.repeat(100));
    writeFileSync(join(dir, 'postgres', 'daily', 'yusmus-20260920-210000.dump.sha256'), 'sum');
    writeFileSync(join(dir, 'postgres', 'daily', 'yusmus-20260930-210000.dump'), 'y'.repeat(200));
    writeFileSync(join(dir, 'minio', 'products', 'p.jpg'), 'z'.repeat(50));
    writeFileSync(join(usb, 'sdd1', 'owner-photo.jpg'), 'not ours');
    t = await createTestApp({ OFFSITE_USB_ROOT: usb });
  });
  afterAll(() => t.close());

  it('lists the copies (newest first), sizes and the last update; removes one for good; never anything else', async () => {
    const sa = await superAdminActor(t);
    const list = (await sa.api.get('/v1/admin/backups/offsite').expect(200)).body;
    expect(list).toMatchObject({ found: true, drive: 'sdd1', updated: '2026-10-01 23:00', photosBytes: 50 });
    expect(list.copies.map((c: { name: string }) => c.name)).toEqual(['yusmus-20260930-210000.dump', 'yusmus-20260920-210000.dump']);
    expect(list.copies[1]).toMatchObject({ kind: 'daily', at: '2026-09-20T21:00:00Z', bytes: 100 });

    const admin = await staffActor(t, 'ADMIN');
    await admin.api.get('/v1/admin/backups/offsite').expect(403); // SUPER_ADMIN only
    await admin.api.delete('/v1/admin/backups/offsite?path=postgres/daily/yusmus-20260920-210000.dump').expect(403);

    // only whole database copies, only inside diamoraa-backup
    await sa.api.delete('/v1/admin/backups/offsite?path=../owner-photo.jpg').expect(409);
    await sa.api.delete('/v1/admin/backups/offsite?path=minio/products/p.jpg').expect(409);
    await sa.api.delete('/v1/admin/backups/offsite?path=.diamoraa-offsite').expect(409);
    expect(existsSync(join(usb, 'sdd1', 'owner-photo.jpg'))).toBe(true);

    await sa.api.delete('/v1/admin/backups/offsite?path=postgres/daily/yusmus-20260920-210000.dump').expect(200);
    expect(existsSync(join(dir, 'postgres', 'daily', 'yusmus-20260920-210000.dump'))).toBe(false);
    expect(existsSync(join(dir, 'postgres', 'daily', 'yusmus-20260920-210000.dump.sha256'))).toBe(false);
    expect(readFileSync(join(dir, '.deleted'), 'utf8')).toContain('yusmus-20260920-210000.dump'); // never copied back
    const after = (await sa.api.get('/v1/admin/backups/offsite').expect(200)).body;
    expect(after.copies).toHaveLength(1);
  });
});
