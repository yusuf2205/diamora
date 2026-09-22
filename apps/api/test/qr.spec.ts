import { approveAndLoginWorker, staffActor, superAdminActor, TestApp, createTestApp, registerViaBot } from './support/app';

describe('QR resolve (M2 §10-13): opaque code only, server-side authorization, never a client-side reveal', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('a WORKER QR is created automatically at approval and resolves to her full staff card', async () => {
    const admin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    const detail = await admin.api.get(`/v1/workers/${worker.workerId}`).expect(200);
    expect(detail.body.qrCode).toMatch(/^YQ1\.[0-9A-HJKMNP-TV-Z]{12}$/);

    const scanned = await admin.api.get(`/v1/qr/${detail.body.qrCode}`).expect(200);
    expect(scanned.body.type).toBe('WORKER');
    expect(scanned.body.worker.id).toBe(worker.workerId);
  });

  it('a MANAGER scanning a WORKER QR outside her scope gets 404, never the data or a 403 that reveals existence', async () => {
    const superAdmin = await superAdminActor(t);
    const mgrA = await staffActor(t, 'MANAGER');
    const mgrB = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await superAdmin.api.post(`/v1/workers/${worker.workerId}/manager`, { managerId: mgrA.user.id }).expect(201);
    const detail = await superAdmin.api.get(`/v1/workers/${worker.workerId}`).expect(200);

    await mgrA.api.get(`/v1/qr/${detail.body.qrCode}`).expect(200);
    await mgrB.api.get(`/v1/qr/${detail.body.qrCode}`).expect(404);
  });

  it('a KIT QR resolves for anyone with INVENTORY_VIEW, with the exact assembled composition', async () => {
    const admin = await superAdminActor(t);
    const ribbon = (await admin.api.post('/v1/admin/materials', { name: 'Лента QR', unit: 'METER' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: ribbon, quantity: '9' }).expect(201);
    const tpl = await admin.api.post('/v1/admin/kits', { name: 'QR — 9m', items: [{ materialId: ribbon, requiredQuantity: '9' }] }).expect(201);
    const assembled = await admin.api.post(`/v1/admin/kits/${tpl.body.id}/assemble`, { count: 1 }).expect(201);

    const scanned = await admin.api.get(`/v1/qr/${assembled.body.qrCode}`).expect(200);
    expect(scanned.body.type).toBe('KIT');
    expect(scanned.body.kit.kitTemplateId).toBe(tpl.body.id);
    expect(scanned.body.kit.totalMeters).toBe(9);

    const viewer = await staffActor(t, 'MANAGER', ['INVENTORY_VIEW']);
    await viewer.api.get(`/v1/qr/${assembled.body.qrCode}`).expect(200);
    const noPerm = await staffActor(t, 'MANAGER');
    await noPerm.api.get(`/v1/qr/${assembled.body.qrCode}`).expect(403);
  });

  it('an invalid, unknown or revoked code is a plain 404; a WORKER role may not scan at all', async () => {
    const admin = await superAdminActor(t);
    await admin.api.get('/v1/qr/not-a-real-code').expect(404);
    await admin.api.get('/v1/qr/YQ1.000000000000').expect(404); // well-formed but never issued

    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, admin.api, reg.phone);
    await worker.api.get('/v1/qr/YQ1.000000000000').expect(403);
  });
});
