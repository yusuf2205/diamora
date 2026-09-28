import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('«Назначить менеджера» for many workers; «Очистить журнал»', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('bulk: several workers move to one manager at once (and back to «Без менеджера»); the manager sees exactly them', async () => {
    const admin = await superAdminActor(t);
    const mgr = await staffActor(t, 'MANAGER');
    const a = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const b = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);

    const res = await admin.api.post('/v1/workers/manager-bulk', { managerId: mgr.user.id, workerIds: [a.workerId, b.workerId] }).expect(200);
    expect(res.body.changed).toBe(2);
    await mgr.api.get(`/v1/workers/${a.workerId}`).expect(200);
    await mgr.api.get(`/v1/workers/${b.workerId}`).expect(200);
    expect(await t.prisma.auditLog.count({ where: { action: 'worker.assign_manager', entityId: { in: [a.workerId, b.workerId] } } })).toBe(2);

    // repeating it changes nothing (no duplicate audit lines)
    expect((await admin.api.post('/v1/workers/manager-bulk', { managerId: mgr.user.id, workerIds: [a.workerId, b.workerId] }).expect(200)).body.changed).toBe(0);

    await admin.api.post('/v1/workers/manager-bulk', { managerId: null, workerIds: [a.workerId] }).expect(200);
    await mgr.api.get(`/v1/workers/${a.workerId}`).expect(404);

    // only an active MANAGER can receive workers; the right is needed
    const other = await staffActor(t, 'ADMIN');
    await admin.api.post('/v1/workers/manager-bulk', { managerId: other.user.id, workerIds: [a.workerId] }).expect(409);
    await mgr.api.post('/v1/workers/manager-bulk', { managerId: mgr.user.id, workerIds: [a.workerId] }).expect(403);
  });

  it('clear: SUPER_ADMIN only; the journal then starts with «журнал очищен», the old rows are kept (append-only)', async () => {
    const admin = await superAdminActor(t);
    await admin.api.post('/v1/admin/materials', { name: `До очистки ${Math.random()}`, unit: 'METER' }).expect(201);
    const plainAdmin = await staffActor(t, 'ADMIN');
    await plainAdmin.api.post('/v1/audit/clear').expect(403);
    const total = await t.prisma.auditLog.count();

    const cleared = await admin.api.post('/v1/audit/clear').expect(200);
    expect(cleared.body.clearedAt).toBeTruthy();
    const list = await admin.api.get('/v1/audit?limit=50').expect(200);
    expect(list.body.items.map((i: { action: string }) => i.action)).toEqual(['audit.clear']);
    expect(list.body.clearedAt).toBe(cleared.body.clearedAt);
    expect(await t.prisma.auditLog.count()).toBe(total + 1); // nothing was deleted

    await admin.api.post('/v1/admin/materials', { name: `После очистки ${Math.random()}`, unit: 'METER' }).expect(201);
    const after = await admin.api.get('/v1/audit?limit=50').expect(200);
    expect(after.body.items[0].action).toBe('material.create');
  });
});
