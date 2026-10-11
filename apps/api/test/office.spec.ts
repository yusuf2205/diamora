import { WorkerDecisions } from '../src/workers/decisions';
import { approveAndLoginWorker, createTestApp, nextTelegramId, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('search, «Деньги», worker notices in Telegram, approving from Telegram (owner, 2026-10-11)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('search finds workers by name / phone / code - a manager only her own; «Деньги» shows what is owed', async () => {
    const admin = await superAdminActor(t);
    const mgr = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t, { name: 'Зухра Поисковая' });
    const { workerId } = await approveAndLoginWorker(t, admin.api, reg.phone);

    const byName = (await admin.api.get('/v1/admin/search?q=Поисков').expect(200)).body;
    expect(byName.workers.map((w: { id: string }) => w.id)).toContain(workerId);
    const byPhone = (await admin.api.get(`/v1/admin/search?q=${reg.phone.slice(-7)}`).expect(200)).body;
    expect(byPhone.workers.map((w: { id: string }) => w.id)).toContain(workerId);
    expect((await mgr.api.get('/v1/admin/search?q=Поисков').expect(200)).body.workers).toHaveLength(0); // not hers
    await admin.api.post(`/v1/workers/${workerId}/manager`, { managerId: mgr.user.id }).expect(201);
    expect((await mgr.api.get('/v1/admin/search?q=Поисков').expect(200)).body.workers).toHaveLength(1);
    expect((await mgr.api.get('/v1/admin/search?q=Поисков').expect(200)).body.staff).toHaveLength(0); // no USER_VIEW_ALL

    const money = (await admin.api.get('/v1/admin/money').expect(200)).body;
    expect(money).toMatchObject({ profitVisible: true, owed: { total: expect.any(String) } });
    expect(money.thisMonth).toHaveProperty('profit');
    await mgr.api.get('/v1/admin/money').expect(403);
  });

  it('a worker\'s notices also go to her Telegram (outbox)', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const { workerId } = await approveAndLoginWorker(t, admin.api, reg.phone);
    await admin.api.post(`/v1/admin/workers/${workerId}/payout`, { amount: '1000', forced: true }).expect(200);
    await new Promise((r) => setTimeout(r, 300)); // the notice is written after the event
    const tg = await t.prisma.notification.findMany({ where: { channel: 'TELEGRAM', workerId, type: 'cash_payment.created' } });
    expect(tg).toHaveLength(1);
    expect(tg[0].body).toContain('Вам выплатили');
  });

  it('a new registration goes to the admin\'s Telegram with buttons; «Одобрить» there approves her', async () => {
    const admin = await superAdminActor(t);
    const chat = BigInt(nextTelegramId());
    await t.prisma.user.update({ where: { id: admin.user.id }, data: { alertChatId: chat } });
    const reg = await registerViaBot(t);
    await new Promise((r) => setTimeout(r, 300));
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone: reg.phone } });
    const card = await t.prisma.notification.findFirst({ where: { channel: 'TELEGRAM', telegramChatId: chat, type: 'worker.approval' } });
    expect(card?.body).toContain(w.fullName);
    expect(JSON.stringify(card?.data)).toContain(`wa:ok:${w.id}`);

    const decisions = t.app.get(WorkerDecisions, { strict: false });
    expect(await decisions.decideFromTelegram(BigInt(nextTelegramId()), 'ok', w.id)).toMatch(/Нет доступа/); // a stranger's chat
    expect(await decisions.decideFromTelegram(chat, 'okc', w.id)).toMatch(/принята, залог получен/);
    expect((await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.id } })).status).toBe('ACTIVE');
    expect(await decisions.decideFromTelegram(chat, 'no', w.id)).toMatch(/уже рассмотрена/); // a second tap does nothing
    const audit = await t.prisma.auditLog.findFirst({ where: { action: 'worker.approve', entityId: w.id } });
    expect(audit?.actorId).toBe(admin.user.id);
  });
});
