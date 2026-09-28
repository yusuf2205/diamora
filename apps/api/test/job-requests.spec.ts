import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** «Заказать эту работу»: worker asks from the catalog -> staff prepares the assignment from it, or declines. */
async function setup(t: TestApp) {
  const admin = await superAdminActor(t);
  const reg = await registerViaBot(t);
  const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);
  const tape = await admin.api.post('/v1/admin/materials', { name: `JTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
  const kit = await admin.api.post('/v1/admin/kits', { name: `JKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
  const color = await admin.api.post('/v1/admin/colors', { name: `JColor ${reg.tgId}` }).expect(201);
  const item = await admin.api.post('/v1/admin/catalog', { name: `JModel ${reg.tgId}` }).expect(201);
  const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
  const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v) => v.color.id === color.body.id)!;
  await t.prisma.productModel.update({ where: { id: item.body.id }, data: { status: 'PUBLISHED', publishedAt: new Date() } }); // publishing needs a photo upload; not what this test is about
  return { admin, workerId, workerApi, kit: kit.body, color: color.body, modelId: item.body.id as string, variantId: variant.id };
}

describe('job requests («Заказать эту работу»)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(async () => {
    // leave no published items behind: the catalog suite expects an empty worker catalog in the shared test database
    await t.prisma.productModel.updateMany({ where: { name: { startsWith: 'JModel' } }, data: { status: 'HIDDEN' } });
    await t.close();
  });

  it('worker orders 18 m of a published colour; staff sees it and prepares the assignment from it -> FULFILLED, linked', async () => {
    const f = await setup(t);
    const req = await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 2, note: 'к пятнице' }).expect(201);
    expect(req.body).toMatchObject({ status: 'PENDING', kitCount: 2, meters: 18, note: 'к пятнице', product: { id: f.modelId }, color: { id: f.color.id } });
    await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(409); // one open request at a time

    const pending = await f.admin.api.get('/v1/admin/job-requests').expect(200);
    const mine = pending.body.items.find((r: { id: string }) => r.id === req.body.id);
    expect(mine.worker.id).toBe(f.workerId);

    const created = await f.admin.api.post('/v1/admin/assignments', {
      workerId: f.workerId, productModelId: f.modelId, productVariantId: f.variantId, colorId: f.color.id, materialKitTemplateId: f.kit.id, kitCount: 2,
      jobRequestId: req.body.id,
    }).expect(201);
    const after = await f.workerApi.get('/v1/work/requests').expect(200);
    expect(after.body.items[0]).toMatchObject({ id: req.body.id, status: 'FULFILLED', assignmentId: created.body.id });
    // the same request can never be used twice
    await f.admin.api.post('/v1/admin/assignments', {
      workerId: f.workerId, productModelId: f.modelId, productVariantId: f.variantId, colorId: f.color.id, materialKitTemplateId: f.kit.id, kitCount: 1,
      jobRequestId: req.body.id,
    }).expect(409);
    // and she can order again now
    await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(201);
  });

  it('staff declines with a reason (in-app notice); worker can withdraw her own; hidden work cannot be ordered', async () => {
    const f = await setup(t);
    const req = await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(201);
    const rej = await f.admin.api.post(`/v1/admin/job-requests/${req.body.id}/reject`, { note: 'нет бисера' }).expect(200);
    expect(rej.body).toMatchObject({ status: 'REJECTED', decisionNote: 'нет бисера' });
    const wu = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: f.workerId } });
    expect(await t.prisma.notification.count({ where: { channel: 'APP', userId: wu.userId!, type: 'job_request.decided' } })).toBe(1); // in the app, not Telegram
    expect(await t.prisma.notification.count({ where: { channel: 'TELEGRAM', workerId: f.workerId, type: 'job_request.rejected' } })).toBe(0);
    await f.admin.api.post(`/v1/admin/job-requests/${req.body.id}/reject`, {}).expect(409);

    const second = await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 3 }).expect(201);
    expect(second.body.meters).toBe(27);
    const cancelled = await f.workerApi.post(`/v1/work/requests/${second.body.id}/cancel`, {}).expect(200);
    expect(cancelled.body.status).toBe('CANCELLED');

    await t.prisma.productModel.update({ where: { id: f.modelId }, data: { status: 'HIDDEN' } });
    await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(404);
    await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 4 }).expect(400);
  });

  it('scope: a foreign manager sees nothing and cannot decline; a worker cannot touch another worker\'s request', async () => {
    const f = await setup(t);
    const other = await setup(t);
    const req = await f.workerApi.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(201);
    const own = await staffActor(t, 'MANAGER', ['ASSIGNMENT_CREATE']);
    const foreign = await staffActor(t, 'MANAGER', ['ASSIGNMENT_CREATE']);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: own.user.id }).expect(201);
    expect((await foreign.api.get('/v1/admin/job-requests').expect(200)).body.items).toEqual([]);
    expect((await own.api.get('/v1/admin/job-requests').expect(200)).body.items.map((r: { id: string }) => r.id)).toEqual([req.body.id]);
    await foreign.api.post(`/v1/admin/job-requests/${req.body.id}/reject`, {}).expect(404);
    await other.workerApi.post(`/v1/work/requests/${req.body.id}/cancel`, {}).expect(404);
    await own.api.post('/v1/work/requests', { productVariantId: f.variantId, kitCount: 1 }).expect(403);
  });
});
