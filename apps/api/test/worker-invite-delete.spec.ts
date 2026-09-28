import { render } from '../src/registration/texts';
import {
  approveAndLoginWorker, createTestApp, nextTelegramId, registerViaBot, staffActor, superAdminActor, telegramLoginTicket, TestApp, uniquePhone,
} from './support/app';
import request from 'supertest';
import { randomUUID } from 'node:crypto';

/** «Добавить мастерицу» (invitation link -> active at once) and «Удалить мастерицу» (full erase only without history). */
describe('workers: add by invitation, delete for good', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  const tokenOf = (url: string) => url.split('start=inv_')[1];
  const openLink = (url: string, tgId = nextTelegramId()) => {
    const ctx = { telegramUserId: BigInt(tgId), chatId: BigInt(tgId) };
    return { ctx, reply: t.registration.process(ctx, { kind: 'command', command: 'start', payload: `inv_${tokenOf(url)}` }) };
  };

  it('invite: staff gets a t.me link; she opens it -> ACTIVE at once, no questions, manager set, can log in via Telegram', async () => {
    const admin = await superAdminActor(t);
    const mgr = await staffActor(t, 'MANAGER');
    const phone = uniquePhone();
    const inv = await admin.api.post('/v1/workers/invitations', { fullName: 'Нигора Алиева', phone, managerId: mgr.user.id }).expect(201);
    expect(inv.body.url).toMatch(/^https:\/\/t\.me\/[A-Za-z0-9_]+\?start=inv_[A-Za-z0-9_-]+$/);
    expect((await admin.api.get('/v1/workers/invitations').expect(200)).body.items.some((i: { id: string }) => i.id === inv.body.id)).toBe(true);

    const { ctx, reply } = openLink(inv.body.url);
    const r = await reply;
    expect(r.prompt).toBe('INVITE_ACCEPTED');
    const text = render(r).text;
    expect(text).toContain('Нигора Алиева');
    expect(text).toContain('/download');

    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { telegramUserId: ctx.telegramUserId } });
    expect(w).toMatchObject({ status: 'ACTIVE', phone, fullName: 'Нигора Алиева', assignedManagerId: mgr.user.id });
    expect(w.userId).toBeTruthy();
    // her manager sees her; she can sign in with Telegram right away
    const mine = await mgr.api.get('/v1/workers').expect(200);
    expect(mine.body.items.some((x: { id: string }) => x.id === w.id)).toBe(true);
    const { ticket } = await telegramLoginTicket(t, w.telegramUserId, w.telegramChatId);
    const login = await request(t.app.getHttpServer()).post('/v1/auth/telegram/exchange').send({ ticket, device: { installId: randomUUID(), platform: 'ANDROID', name: 'Test phone', appVersion: '1.0.0' } });
    expect(login.status).toBe(200);
    // the link works ONCE
    expect((await openLink(inv.body.url).reply).prompt).toBe('INVITE_INVALID');
    expect((await admin.api.get('/v1/workers/invitations').expect(200)).body.items.some((i: { id: string }) => i.id === inv.body.id)).toBe(false);
  });

  it('invite: a phone that is already a worker/staff is refused; a revoked or replaced link does nothing; MANAGER cannot invite', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    await admin.api.post('/v1/workers/invitations', { fullName: 'Дубль', phone: reg.phone }).expect(409);
    await admin.api.post('/v1/workers/invitations', { fullName: 'Сотрудник', phone: admin.user.phone }).expect(409);

    const phone = uniquePhone();
    const first = await admin.api.post('/v1/workers/invitations', { fullName: 'Зарина', phone }).expect(201);
    const second = await admin.api.post('/v1/workers/invitations', { fullName: 'Зарина', phone }).expect(201);
    expect((await openLink(first.body.url).reply).prompt).toBe('INVITE_INVALID'); // replaced by the second
    await admin.api.delete(`/v1/workers/invitations/${second.body.id}`).expect(200);
    expect((await openLink(second.body.url).reply).prompt).toBe('INVITE_INVALID');
    expect(await t.prisma.workerProfile.count({ where: { phone } })).toBe(0);

    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.post('/v1/workers/invitations', { fullName: 'Хилола', phone: uniquePhone() }).expect(403);
    const plainAdmin = await staffActor(t, 'ADMIN');
    await plainAdmin.api.post('/v1/workers/invitations', { fullName: 'Юлдуз', phone: uniquePhone() }).expect(201);
  });

  it('delete: a worker without history is erased completely (collateral trail, login, QR) and the audit keeps who/what', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t, { type: 'ITEM' }); // declared collateral WITH a photo, never received
    const { workerId } = await approveAndLoginWorker(t, admin.api, reg.phone, false);
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: workerId } });

    await admin.api.delete(`/v1/workers/${workerId}`).expect(200);
    expect(await t.prisma.workerProfile.findUnique({ where: { id: workerId } })).toBeNull();
    expect(await t.prisma.user.findUnique({ where: { id: w.userId! } })).toBeNull();
    expect(await t.prisma.workerCollateral.count({ where: { workerId } })).toBe(0);
    expect(await t.prisma.qrEntity.count({ where: { workerId } })).toBe(0);
    const audit = await t.prisma.auditLog.findFirstOrThrow({ where: { action: 'worker.delete', entityId: workerId } });
    expect(audit.before).toMatchObject({ fullName: w.fullName, phone: w.phone });
    await admin.api.get(`/v1/workers/${workerId}`).expect(404);
    // the same Telegram account can register again from scratch
    expect((await reg.send({ kind: 'command', command: 'start' })).prompt).toBe('WELCOME');
    // the append-only guard is still on outside the erase transaction
    const other = await registerViaBot(t);
    const col = await t.prisma.workerCollateral.findFirstOrThrow({ where: { worker: { phone: other.phone } } });
    await expect(t.prisma.collateralHistory.deleteMany({ where: { collateralId: col.id } })).rejects.toThrow(/append-only/);
  });

  it('delete: refused with HAS_HISTORY when she has work (or received collateral); needs WORKER_DELETE (ADMIN only if granted)', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const list = await admin.api.get(`/v1/workers?q=${reg.phone.slice(-7)}`).expect(200);
    const workerId = list.body.items[0].id;
    await admin.api.post(`/v1/workers/${workerId}/approve`, { collateralReceived: true }).expect(201);
    const res = await admin.api.delete(`/v1/workers/${workerId}`).expect(409);
    expect(res.body.error.code).toBe('HAS_HISTORY');
    expect(res.body.error.details.reasons).toContain('COLLATERAL');
    expect(await t.prisma.workerProfile.count({ where: { id: workerId } })).toBe(1);

    const plainAdmin = await staffActor(t, 'ADMIN');
    await plainAdmin.api.delete(`/v1/workers/${workerId}`).expect(403);
    const granted = await staffActor(t, 'ADMIN', ['WORKER_DELETE']);
    await granted.api.delete(`/v1/workers/${workerId}`).expect(409); // allowed to try, still protected by history
  });
});
