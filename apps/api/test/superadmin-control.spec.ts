import { approveAndLoginWorker, createTestApp, handOver, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** SUPER_ADMIN controls everything: cancel/edit any work, delete staff accounts without history. */
async function setup(t: TestApp) {
  const admin = await superAdminActor(t);
  const reg = await registerViaBot(t);
  const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);
  const tape = await admin.api.post('/v1/admin/materials', { name: `CTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
  const kit = await admin.api.post('/v1/admin/kits', { name: `CKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
  const color = await admin.api.post('/v1/admin/colors', { name: `CColor ${reg.tgId}` }).expect(201);
  const item = await admin.api.post('/v1/admin/catalog', { name: `CModel ${reg.tgId}` }).expect(201);
  const v = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
  const variant = (v.body.variants as { id: string; color: { id: string } }[]).find((x) => x.color.id === color.body.id)!;
  const create = () => admin.api.post('/v1/admin/assignments', { workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 1 }).expect(201);
  const stock = async () => (await admin.api.get('/v1/admin/stock/balances').expect(200)).body.items.find((b: { materialId: string }) => b.materialId === tape.body.id).quantity as number;
  return { admin, workerId, workerApi, tape: tape.body, create, stock };
}

describe('SUPER_ADMIN full control', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('cancel prepared work: the kit goes back on the shelf; her QR stops working', async () => {
    const f = await setup(t);
    const a = await f.create();
    expect(await f.stock()).toBe(91);
    const c = await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/cancel`, { reason: 'ошибка в цвете' }).expect(200);
    expect(c.body.status).toBe('CANCELLED');
    expect(await f.stock()).toBe(100);
    await f.workerApi.post('/v1/work/handoff/scan', { code: a.body.qrCode }).expect(404);
    await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/cancel`, { reason: 'ещё раз' }).expect(409);
  });

  it('cancel work at the worker: returned -> back to stock and off her balance; not returned -> written off', async () => {
    const f = await setup(t);
    const a = await f.create();
    await handOver(f.admin.api, f.workerApi, a.body.id);
    await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/cancel`, { reason: 'мастерица заболела', materialsReturned: true }).expect(200);
    expect(await f.stock()).toBe(100);
    const held = await t.prisma.workerMaterialBalance.findFirst({ where: { workerId: f.workerId, materialId: f.tape.id } });
    expect(held?.quantity.toString()).toBe('0');

    const b = await f.create();
    await handOver(f.admin.api, f.workerApi, b.body.id);
    await f.admin.api.post(`/v1/admin/assignments/${b.body.id}/cancel`, { reason: 'материал испорчен', materialsReturned: false }).expect(200);
    expect(await f.stock()).toBe(91); // written off, not back on the shelf
    expect((await t.prisma.workerMaterialBalance.findFirst({ where: { workerId: f.workerId, materialId: f.tape.id } }))?.quantity.toString()).toBe('0');
  });

  it('change the deadline and comment; accepted work cannot be cancelled; a MANAGER without the right cannot', async () => {
    const f = await setup(t);
    const a = await f.create();
    const due = '2026-12-01T09:00:00.000Z';
    const u = await f.admin.api.patch(`/v1/admin/assignments/${a.body.id}`, { dueAt: due, notes: 'срочно' }).expect(200);
    expect(u.body).toMatchObject({ dueAt: due, notes: 'срочно' });
    const mgr = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    await mgr.api.post(`/v1/admin/assignments/${a.body.id}/cancel`, { reason: 'x y' }).expect(403);

    await handOver(f.admin.api, f.workerApi, a.body.id);
    await f.workerApi.post(`/v1/work/${a.body.id}/ready`, { readyMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/pickup`, {}).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/accept`, { broughtMeters: '9', acceptedMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${a.body.id}/cancel`, { reason: 'поздно' }).expect(409);
  });

  it('delete a staff account without history; one with history is refused (deactivate instead); only SUPER_ADMIN', async () => {
    const owner = await superAdminActor(t);
    const fresh = await staffActor(t, 'MANAGER');
    const admin = await staffActor(t, 'ADMIN', ['USER_DEACTIVATE']);
    await admin.api.delete(`/v1/users/${fresh.user.id}`).expect(403);
    await owner.api.delete(`/v1/users/${fresh.user.id}`).expect(200);
    expect(await t.prisma.user.findUnique({ where: { id: fresh.user.id } })).toBeNull();
    await owner.api.delete(`/v1/users/${owner.user.id}`).expect(403); // never yourself

    const f = await setup(t); // f.admin created work -> has history
    const res = await owner.api.delete(`/v1/users/${f.admin.user.id}`).expect(409);
    expect(res.body.error.code).toBe('HAS_HISTORY');
    await f.create(); // still works
  });
});
