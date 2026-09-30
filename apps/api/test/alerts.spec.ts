import { AlertsService } from '../src/alerts/alerts.service';
import { createTestApp, staffActor, TestApp } from './support/app';

/** Owner alerts in Telegram: an admin links a chat through the bot; the NAS says when it is back and when the disk fills up. */
describe('owner alerts', () => {
  let t: TestApp;
  let svc: AlertsService;
  const sent: { chat: bigint; text: string }[] = [];
  const sender = { send: async (chat: bigint, text: string) => void sent.push({ chat, text }) };
  beforeAll(async () => { t = await createTestApp(); svc = t.app.get(AlertsService); });
  afterAll(async () => { await t.close(); });
  beforeEach(() => { sent.length = 0; });

  it('an admin links a chat with the bot link; a manager cannot; a used or foreign token does nothing', async () => {
    const admin = await staffActor(t, 'ADMIN');
    const manager = await staffActor(t, 'MANAGER');
    await manager.api.post('/v1/me/telegram-alerts/link', {}).expect(403);
    expect((await admin.api.get('/v1/me/telegram-alerts').expect(200)).body).toEqual({ linked: false });

    const { url } = (await admin.api.post('/v1/me/telegram-alerts/link', {}).expect(200)).body;
    expect(url).toMatch(/^https:\/\/t\.me\/\w+\?start=alr_[\w-]+$/);
    const token = url.split('start=alr_')[1];
    expect(await svc.completeLink(token, 777n)).toContain('Готово');
    expect((await admin.api.get('/v1/me/telegram-alerts').expect(200)).body).toEqual({ linked: true });
    expect(await svc.completeLink(token, 888n)).toContain('устарела'); // one use only
    expect(await svc.completeLink('made-up', 888n)).toContain('устарела');

    await svc.notifyOwners(sender, 'проверка');
    expect(sent.filter((s) => s.chat === 777n).map((s) => s.text)).toEqual(['проверка']);
    expect(sent.some((s) => s.chat === 888n)).toBe(false);

    await admin.api.delete('/v1/me/telegram-alerts').expect(200);
    sent.length = 0;
    await svc.notifyOwners(sender, 'после отключения');
    expect(sent.some((s) => s.chat === 777n)).toBe(false);
  });

  it('«снова работает, был недоступен N мин» only after a real down time, not after a quick restart', async () => {
    const admin = await staffActor(t, 'SUPER_ADMIN');
    const { url } = (await admin.api.post('/v1/me/telegram-alerts/link', {}).expect(200)).body;
    await svc.completeLink(url.split('start=alr_')[1], 555n);

    const t0 = new Date('2026-10-01T05:00:00Z');
    await svc.beat(t0);
    expect(await svc.onStart(sender, new Date(t0.getTime() + 60_000))).toBeNull(); // a deploy restart
    const back = await svc.onStart(sender, new Date(t0.getTime() + 60_000 + 25 * 60_000));
    expect(back).toContain('был недоступен примерно 25 мин');
    expect(back).toContain('(с 10:01 до 10:26)'); // Tashkent time
    expect(sent.some((s) => s.chat === 555n && s.text === back)).toBe(true);
  });

  it('disk: warns under 10 % free, once a day', async () => {
    const now = new Date('2026-10-01T06:00:00Z');
    expect(await svc.checkDisk(sender, now, async () => ({ free: 500, total: 1000 }))).toBeNull();
    const low = await svc.checkDisk(sender, now, async () => ({ free: 50 * 1024 ** 3, total: 1000 * 1024 ** 3 }));
    expect(low).toContain('заканчивается место');
    expect(await svc.checkDisk(sender, now, async () => ({ free: 1, total: 1000 }))).toBeNull(); // already told today
  });

  it('backups: a failed copy, a stale one or a missing external drive -> told once a day, in words', async () => {
    const now = new Date('2026-10-02T06:00:00Z');
    const fresh = now.getTime() - 3600_000;
    expect(await svc.checkBackups(sender, now, async () => [{ job: 'pg_dump', state: 'ok', at: fresh }, { job: 'offsite', state: 'ok', at: fresh }])).toBeNull();
    const bad = await svc.checkBackups(sender, now, async () => [
      { job: 'pg_dump', state: 'ok', at: now.getTime() - 3 * 86_400_000 },
      { job: 'offsite', state: 'nodrive', at: fresh },
      { job: 'minio_mirror', state: 'failed', at: fresh },
    ]);
    expect(bad).toContain('копия базы: давно не обновлялась');
    expect(bad).toContain('внешний диск не найден');
    expect(bad).toContain('копия фото и файлов: не получилась');
    expect(await svc.checkBackups(sender, now, async () => [{ job: 'offsite', state: 'nodrive', at: fresh }])).toBeNull(); // once a day
  });
});
