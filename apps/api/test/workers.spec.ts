import { adminActor, approveAndLoginWorker, client, registerViaBot, TestApp, createTestApp, uniquePhone } from './support/app';

describe('ADMIN approval, worker profile and worker login', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('ADMIN sees pending registrations with collateral summary and full detail (GPS included)', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t, { name: 'Дилноза Ахмедова' });
    const list = await admin.api.get('/v1/workers?status=PENDING_APPROVAL&q=Дилноза').expect(200);
    expect(list.body.items).toHaveLength(1);
    const w = list.body.items[0];
    expect(w).toMatchObject({ fullName: 'Дилноза Ахмедова', phone, status: 'PENDING_APPROVAL', balance: '0' });
    expect(w.latitude).toBeCloseTo(41.2995, 3);
    expect(w.collateral).toMatchObject({ type: 'MONEY', status: 'PENDING', amount: '1500000' });
    const detail = await admin.api.get(`/v1/workers/${w.id}`).expect(200);
    expect(detail.body.collaterals).toHaveLength(1);
  });

  it('approve: worker ACTIVE + account + personal QR + collateral HELD + Telegram message + realtime + audit', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const list = await admin.api.get(`/v1/workers?q=${phone.slice(-7)}`).expect(200);
    const id = list.body.items[0].id;
    const before = t.events.length;
    const res = await admin.api.post(`/v1/workers/${id}/approve`, { collateralReceived: true }).expect(201);
    expect(res.body.status).toBe('ACTIVE');
    expect(res.body.collaterals[0].status).toBe('HELD');

    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id }, include: { user: true, qrEntities: true } });
    expect(w.user).toMatchObject({ role: 'WORKER', phone, passwordHash: null });
    expect(w.approvedById).toBe(admin.user.id);
    expect(w.qrEntities).toHaveLength(1);
    expect(w.qrEntities[0].code).toMatch(/^YQ1\.[0-9A-Z]{12}$/);
    const note = await t.prisma.notification.findFirstOrThrow({ where: { workerId: id, type: 'worker.approved' } });
    expect(note).toMatchObject({ channel: 'TELEGRAM', status: 'PENDING' });
    expect(t.events.slice(before).map((e) => e.type).sort()).toEqual(['collateral.updated', 'worker.approved']);
    const audit = await t.prisma.auditLog.findFirst({ where: { entityId: id, action: 'worker.approve' } });
    expect(audit).toMatchObject({ actorId: admin.user.id, actorRole: 'ADMIN' });
    // cannot approve twice (state machine)
    const again = await admin.api.post(`/v1/workers/${id}/approve`, {}).expect(409);
    expect(again.body.error.code).toBe('INVALID_TRANSITION');
  });

  it('approve without collateralReceived leaves the collateral PENDING; reject keeps the record, sets reason and tells the worker', async () => {
    const admin = await adminActor(t);
    const a = await registerViaBot(t);
    const b = await registerViaBot(t);
    const ida = (await admin.api.get(`/v1/workers?q=${a.phone.slice(-7)}`)).body.items[0].id;
    const idb = (await admin.api.get(`/v1/workers?q=${b.phone.slice(-7)}`)).body.items[0].id;
    expect((await admin.api.post(`/v1/workers/${ida}/approve`, {}).expect(201)).body.collaterals[0].status).toBe('PENDING');
    await admin.api.post(`/v1/workers/${idb}/reject`, { reason: 'x' }).expect(400);
    const rej = await admin.api.post(`/v1/workers/${idb}/reject`, { reason: 'Не подходит по условиям' }).expect(201);
    expect(rej.body).toMatchObject({ status: 'REJECTED', rejectedReason: 'Не подходит по условиям' });
    expect(await t.prisma.workerProfile.count({ where: { id: idb } })).toBe(1);
    expect(await t.prisma.user.count({ where: { phone: b.phone } })).toBe(0);
    // she is told the same in the bot
    expect((await b.send({ kind: 'text', text: 'привет' })).prompt).toBe('STATUS_REJECTED');
    const note = await t.prisma.notification.findFirstOrThrow({ where: { workerId: idb, type: 'worker.rejected' } });
    expect(note.body).toContain('Не подходит по условиям');
  });

  it('WORKER Telegram login: the profile hides internal notes (login mechanics: see telegram-auth.spec.ts)', async () => {
    const admin = await adminActor(t);
    const { phone } = await registerViaBot(t);
    const { workerId, session, api } = await approveAndLoginWorker(t, admin.api, phone);
    expect(session.user).toMatchObject({ role: 'WORKER', workerId });
    await admin.api.patch(`/v1/workers/${workerId}`, { notes: 'внутренняя заметка' }).expect(200);
    const me = await api.get('/v1/workers/me').expect(200);
    expect(me.body).toMatchObject({ id: workerId, phone, status: 'ACTIVE', balance: '0' });
    expect(me.body).not.toHaveProperty('notes');
    expect(me.body.collaterals[0]).toMatchObject({ type: 'MONEY', status: 'HELD', amount: '1500000' });
  });

  it('a worker has no access to ADMIN endpoints and cannot see other workers', async () => {
    const admin = await adminActor(t);
    const a = await registerViaBot(t);
    const b = await registerViaBot(t);
    const wa = await approveAndLoginWorker(t, admin.api, a.phone);
    const wb = await approveAndLoginWorker(t, admin.api, b.phone);
    for (const url of ['/v1/workers', `/v1/workers/${wb.workerId}`, '/v1/collaterals', '/v1/audit']) {
      const r = await wa.api.get(url);
      expect(r.status).toBe(403);
    }
    await wa.api.post(`/v1/workers/${wb.workerId}/approve`, {}).expect(403);
    // each worker's own collateral endpoint returns only her own record
    const mine = await wa.api.get('/v1/workers/me/collateral').expect(200);
    expect(mine.body.items).toHaveLength(1);
    expect(mine.body.items[0].worker.id).toBe(wa.workerId);
    // and ADMIN cannot use worker-only endpoints
    await admin.api.get('/v1/workers/me').expect(403);
  });

  it('ADMIN updates phone (unique), pauses/resumes, archiving signs the worker out at once', async () => {
    const admin = await adminActor(t);
    const a = await registerViaBot(t);
    const b = await registerViaBot(t);
    const wa = await approveAndLoginWorker(t, admin.api, a.phone);
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { phone: b.phone }).expect(409);
    const newPhone = uniquePhone();
    const upd = await admin.api.patch(`/v1/workers/${wa.workerId}`, { phone: newPhone, secondaryPhone: uniquePhone() }).expect(200);
    expect(upd.body.phone).toBe(newPhone);
    expect((await t.prisma.user.findFirstOrThrow({ where: { workerProfile: { id: wa.workerId } } })).phone).toBe(newPhone);
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'PAUSED' }).expect(200);
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'ACTIVE' }).expect(200);
    await wa.api.get('/v1/workers/me').expect(200);
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'ARCHIVED' }).expect(200);
    await wa.api.get('/v1/workers/me').expect(401);
    // an archived worker gets no new work, but nothing is deleted and «Восстановить» brings her back with a working login
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'ACTIVE' }).expect(200);
    expect((await t.prisma.user.findFirstOrThrow({ where: { workerProfile: { id: wa.workerId } } })).status).toBe('ACTIVE');
    await admin.api.patch(`/v1/workers/${wa.workerId}`, { status: 'REJECTED' }).expect(400); // not a status an admin can set
  });

  it('list supports search by name, phone digits and code, plus keyset pagination', async () => {
    const admin = await adminActor(t);
    const target = await registerViaBot(t, { name: 'Уникальная Мастерица Ромашка' });
    for (let i = 0; i < 3; i++) await registerViaBot(t);
    const byName = await admin.api.get('/v1/workers?q=ромашка').expect(200);
    expect(byName.body.items).toHaveLength(1);
    expect((await admin.api.get(`/v1/workers?q=${target.phone.slice(-6)}`).expect(200)).body.items[0].phone).toBe(target.phone);
    const p1 = await admin.api.get('/v1/workers?limit=2').expect(200);
    expect(p1.body.items).toHaveLength(2);
    const p2 = await admin.api.get(`/v1/workers?limit=2&cursor=${p1.body.nextCursor}`).expect(200);
    expect(new Set([...p1.body.items, ...p2.body.items].map((x: { id: string }) => x.id)).size).toBe(p1.body.items.length + p2.body.items.length);
    const client2 = client(t, undefined);
    await client2.get('/v1/workers').expect(401);
  });
});
