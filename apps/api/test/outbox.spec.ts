import { OutboxSender, type TelegramSender } from '../src/worker/outbox';
import { MaintenanceService } from '../src/worker/maintenance';
import { createTestApp, nextTelegramId, TestApp } from './support/app';

describe('Telegram outbox (delivery of notifications by the bot process)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  const enqueue = (type: string, body: string) => t.prisma.notification.create({ data: { channel: 'TELEGRAM', telegramChatId: BigInt(nextTelegramId()), type, body } });
  const fake = (fail = false): TelegramSender & { sent: string[] } => {
    const sent: string[] = [];
    return { sent, async send(_c, text) { if (fail) throw new Error('telegram unreachable'); sent.push(text); } };
  };

  it('delivers pending messages once, marks SENT and wipes login codes from the database', async () => {
    const code = await enqueue('login_code', 'Ваш код входа: 123456');
    const info = await enqueue('worker.approved', 'Вас приняли');
    const sender = fake();
    const res = await t.outbox.tick(sender, 100);
    expect(res.failed).toBe(0);
    expect(sender.sent).toEqual(expect.arrayContaining(['Ваш код входа: 123456', 'Вас приняли']));
    const c = await t.prisma.notification.findUniqueOrThrow({ where: { id: code.id } });
    expect(c).toMatchObject({ status: 'SENT', body: null });
    expect((await t.prisma.notification.findUniqueOrThrow({ where: { id: info.id } })).body).toBe('Вас приняли'); // non-sensitive text stays
    // nothing is sent twice
    const again = fake();
    await t.outbox.tick(again, 100);
    expect(again.sent).not.toContain('Вас приняли');
  });

  it('retries with back-off and gives up (FAILED) after 5 attempts; a failed login code is wiped too', async () => {
    const n = await enqueue('login_code', 'код 654321');
    const sender = fake(true);
    for (let i = 1; i <= 5; i++) {
      await t.prisma.notification.update({ where: { id: n.id }, data: { nextAttemptAt: new Date(Date.now() - 1000) } });
      await t.outbox.tick(sender, 100);
      const row = await t.prisma.notification.findUniqueOrThrow({ where: { id: n.id } });
      expect(row.attempts).toBe(i);
      expect(row.status).toBe(i < 5 ? 'PENDING' : 'FAILED');
      if (i < 5) expect(row.nextAttemptAt.getTime()).toBeGreaterThan(Date.now());
    }
    const done = await t.prisma.notification.findUniqueOrThrow({ where: { id: n.id } });
    expect(done).toMatchObject({ status: 'FAILED', body: null });
    expect(done.lastError).toContain('unreachable');
  });

  it('two bot instances ticking at the same time never send the same message twice (SKIP LOCKED)', async () => {
    await t.prisma.notification.deleteMany({ where: { channel: 'TELEGRAM', status: 'PENDING' } });
    for (let i = 0; i < 10; i++) await enqueue('info', `msg-${i}`);
    const a = fake();
    const b = fake();
    await Promise.all([t.outbox.tick(a, 10), new OutboxSender(t.prisma).tick(b, 10)]);
    const all = [...a.sent, ...b.sent];
    expect(all).toHaveLength(10);
    expect(new Set(all).size).toBe(10);
  });

  it('maintenance: integrity views are clean and housekeeping removes only old rows', async () => {
    const m = new MaintenanceService(t.prisma);
    expect(await m.integrity()).toEqual({ ledgerMismatches: 0, stockMismatches: 0 });
    await t.prisma.loginAttempt.create({ data: { phone: '+998900000001', success: false, createdAt: new Date(Date.now() - 40 * 86_400_000) } });
    await t.prisma.loginAttempt.create({ data: { phone: '+998900000002', success: false } });
    const r = await m.cleanup();
    expect(r.loginAttempts).toBeGreaterThanOrEqual(1);
    expect(await t.prisma.loginAttempt.count({ where: { phone: '+998900000002' } })).toBe(1);
  });
});
