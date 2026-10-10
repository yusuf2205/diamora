import { AppNotifier } from '../src/notifications/app-notifier';
import { ManagerTicks } from '../src/manager/manager-tools';
import { approveAndLoginWorker, createTestApp, nextTelegramId, registerViaBot, staffActor, superAdminActor, TestApp, uniquePhone } from './support/app';

describe('managers\' tools: «Кто простаивает», reminders, holiday cover, a new worker on the spot (owner, 2026-10-11)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  async function workerOf(admin: Awaited<ReturnType<typeof superAdminActor>>, managerId: string) {
    const reg = await registerViaBot(t);
    const w = await approveAndLoginWorker(t, admin.api, reg.phone);
    await admin.api.post(`/v1/workers/${w.workerId}/manager`, { managerId }).expect(201);
    return w;
  }

  it('«Кто простаивает»: only her own workers without work, and the worker can show her own QR', async () => {
    const admin = await superAdminActor(t);
    const mgr = await staffActor(t, 'MANAGER');
    const other = await staffActor(t, 'MANAGER');
    const idleOne = await workerOf(admin, mgr.user.id);
    const stranger = await workerOf(admin, other.user.id);

    const list = (await mgr.api.get('/v1/admin/workers-idle').expect(200)).body.items as { workerId: string; idleDays: number; everWorked: boolean }[];
    expect(list.find((x) => x.workerId === idleOne.workerId)).toMatchObject({ idleDays: 0, everWorked: false });
    expect(list.some((x) => x.workerId === stranger.workerId)).toBe(false);

    const me = (await idleOne.api.get('/v1/workers/me').expect(200)).body;
    expect(me.qrCode).toMatch(/^YQ1\./);
    const scanned = (await mgr.api.get(`/v1/qr/${encodeURIComponent(me.qrCode)}`).expect(200)).body;
    expect(scanned).toMatchObject({ type: 'WORKER', worker: { id: idleOne.workerId } });
  });

  it('reminders: added, ring once when due, done, deleted; never about someone else\'s worker', async () => {
    const admin = await superAdminActor(t);
    const mgr = await staffActor(t, 'MANAGER');
    const mine = await workerOf(admin, mgr.user.id);
    const stranger = await workerOf(admin, (await staffActor(t, 'MANAGER')).user.id);

    const r = (await mgr.api.post('/v1/me/reminders', { text: 'Позвонить насчёт ленты', dueAt: new Date(Date.now() - 60_000).toISOString(), workerId: mine.workerId }).expect(201)).body;
    expect(r).toMatchObject({ done: false, notified: false, worker: { id: mine.workerId } });
    await mgr.api.post('/v1/me/reminders', { text: 'x', dueAt: new Date().toISOString(), workerId: stranger.workerId }).expect(404);

    const ticks = t.app.get(ManagerTicks, { strict: false });
    const notifier = t.app.get(AppNotifier, { strict: false });
    await ticks.ring(notifier);
    await ticks.ring(notifier);
    const notes = await t.prisma.notification.findMany({ where: { userId: mgr.user.id, type: 'reminder' } });
    expect(notes).toHaveLength(1);
    expect(notes[0].body).toBe('Позвонить насчёт ленты');
    expect(notes[0].link).toBe(`/admin/workers/${mine.workerId}`);

    expect((await mgr.api.patch(`/v1/me/reminders/${r.id}`, { done: true }).expect(200)).body.done).toBe(true);
    const other = await staffActor(t, 'MANAGER');
    await other.api.delete(`/v1/me/reminders/${r.id}`).expect(404); // not hers
    await mgr.api.delete(`/v1/me/reminders/${r.id}`).expect(200);
    expect((await mgr.api.get('/v1/me/reminders').expect(200)).body.items).toHaveLength(0);
  });

  it('holiday: her workers go to the substitute and come back by themselves when the date passes', async () => {
    const admin = await superAdminActor(t);
    const a = await staffActor(t, 'MANAGER');
    const b = await staffActor(t, 'MANAGER');
    const w = await workerOf(admin, a.user.id);

    const state = (await a.api.get('/v1/me/away').expect(200)).body;
    expect(state).toMatchObject({ away: false, myWorkers: 1 });
    expect(state.substitutes.some((s: { id: string }) => s.id === b.user.id)).toBe(true);

    await a.api.post('/v1/me/away', { substituteId: a.user.id, until: new Date(Date.now() + 3 * 86_400_000).toISOString() }).expect(409); // not to herself
    const until = new Date(Date.now() + 3 * 86_400_000);
    const away = (await a.api.post('/v1/me/away', { substituteId: b.user.id, until: until.toISOString() }).expect(200)).body;
    expect(away).toMatchObject({ away: true, substitute: { id: b.user.id }, myWorkers: 1 });
    expect(await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).toMatchObject({ assignedManagerId: b.user.id, homeManagerId: a.user.id });
    // the substitute sees and works with her now; the one on holiday does not
    await b.api.get(`/v1/workers/${w.workerId}`).expect(200);
    await a.api.get(`/v1/workers/${w.workerId}`).expect(404);
    expect((await b.api.get('/v1/me/away').expect(200)).body.covering[0]).toMatchObject({ manager: { id: a.user.id }, workers: 1 });
    expect(await t.prisma.notification.count({ where: { userId: b.user.id, type: 'manager.cover' } })).toBe(1);

    await t.app.get(ManagerTicks, { strict: false }).endHolidays(t.app.get(AppNotifier, { strict: false }), new Date(until.getTime() + 1000));
    expect(await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId } })).toMatchObject({ assignedManagerId: a.user.id, homeManagerId: null });
    expect((await a.api.get('/v1/me/away').expect(200)).body.away).toBe(false);
  });

  it('a new worker on the spot: the manager\'s invitation makes her his worker, waiting for an admin\'s approval', async () => {
    const mgr = await staffActor(t, 'MANAGER');
    const phone = uniquePhone();
    const inv = (await mgr.api.post('/v1/me/invitations', { fullName: 'Новая Мастерица', phone, managerId: 'ignored' }).expect(201)).body;
    expect(inv.url).toMatch(/start=inv_/);
    expect((await mgr.api.get('/v1/me/invitations').expect(200)).body.items).toHaveLength(1);
    await mgr.api.get('/v1/workers/invitations').expect(403); // the admins' list stays theirs

    const tgId = nextTelegramId();
    const reply = await t.registration.process({ telegramUserId: BigInt(tgId), chatId: BigInt(tgId) }, { kind: 'command', command: 'start', payload: new URL(inv.url).searchParams.get('start')! });
    expect(reply.prompt).toBe('STATUS_PENDING');
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { phone } });
    expect(w).toMatchObject({ status: 'PENDING_APPROVAL', assignedManagerId: mgr.user.id, approvedAt: null });
  });
});
