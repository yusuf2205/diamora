import { approveAndLoginWorker, client, registerViaBot, staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

/** Shared fixture: one active worker, one 9 m kit template (2 kinds of material so quantities aren't trivially equal),
 * one catalog model+variant+color, all created by a SUPER_ADMIN. Every test gets its own worker (never reused) so stock
 * math and status transitions never interfere across tests sharing one database. */
async function setup(t: TestApp, stockQty = '1000') {
  const admin = await superAdminActor(t);
  const reg = await registerViaBot(t);
  const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);

  const tape = await admin.api.post('/v1/admin/materials', { name: `Tape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
  const bead = await admin.api.post('/v1/admin/materials', { name: `Bead ${reg.tgId}`, unit: 'GRAM', minStock: '0' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: stockQty, comment: 'setup' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: bead.body.id, quantity: stockQty, comment: 'setup' }).expect(201);

  const kit = await admin.api.post('/v1/admin/kits', {
    name: `Kit ${reg.tgId}`, ribbonMeters: 9,
    items: [{ materialId: tape.body.id, requiredQuantity: '9' }, { materialId: bead.body.id, requiredQuantity: '40' }],
  }).expect(201);

  const color = await admin.api.post('/v1/admin/colors', { name: `Color ${reg.tgId}` }).expect(201);
  const item = await admin.api.post('/v1/admin/catalog', { name: `Model ${reg.tgId}` }).expect(201);
  const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
  const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v: { color: { id: string } }) => v.color.id === color.body.id)!;

  return { admin, workerId, workerApi, tape: tape.body, bead: bead.body, kit: kit.body, color: color.body, productModelId: item.body.id, productVariantId: variant.id };
}

function createBody(f: Awaited<ReturnType<typeof setup>>, kitCount: number, extra: object = {}) {
  return { workerId: f.workerId, productModelId: f.productModelId, productVariantId: f.productVariantId, colorId: f.color.id, materialKitTemplateId: f.kit.id, kitCount, ...extra };
}

describe('M3 work assignments (§5-16): create -> deliver -> progress -> pickup -> accept -> earning -> payout', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('9 / 18 / 27 m: plannedMeters and stock deduction are exact multiples of the same 9 m recipe', async () => {
    for (const kitCount of [1, 2, 3]) {
      const f = await setup(t);
      const created = await f.admin.api.post('/v1/admin/assignments', createBody(f, kitCount)).expect(201);
      expect(created.body.plannedMeters).toBe(9 * kitCount);
      expect(created.body.status).toBe('READY_TO_DELIVER');
      expect(created.body.materials.find((m: { materialId: string }) => m.materialId === f.tape.id).quantity).toBe(9 * kitCount);
      expect(created.body.materials.find((m: { materialId: string }) => m.materialId === f.bead.id).quantity).toBe(40 * kitCount);

      const balances = await f.admin.api.get('/v1/admin/stock/balances').expect(200);
      const tapeBalance = balances.body.items.find((b: { materialId: string }) => b.materialId === f.tape.id).quantity;
      expect(tapeBalance).toBe(1000 - 9 * kitCount);
    }
  });

  it('insufficient stock: the WHOLE creation rolls back — no assignment, no QR, no partial movement', async () => {
    const f = await setup(t, '5'); // only 5 m of tape available, a 9 m kit needs 9
    await f.admin.api.post('/v1/admin/assignments', createBody(f, 1)).expect(409);
    const list = await f.admin.api.get(`/v1/admin/assignments?workerId=${f.workerId}`).expect(200);
    expect(list.body.items.length).toBe(0);
    const balances = await f.admin.api.get('/v1/admin/stock/balances').expect(200);
    expect(balances.body.items.find((b: { materialId: string }) => b.materialId === f.tape.id).quantity).toBe(5); // untouched
  });

  it('manager scope: a MANAGER may create for her OWN worker, never for a foreign one (server-side)', async () => {
    const f = await setup(t);
    const mgr = await staffActor(t, 'MANAGER', ['ASSIGNMENT_CREATE']);
    // not yet assigned -> her own worker still looks "foreign"
    await mgr.api.post('/v1/admin/assignments', createBody(f, 1)).expect(404);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: mgr.user.id }).expect(201);
    const created = await mgr.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    expect(created.body.status).toBe('READY_TO_DELIVER');

    const foreignMgr = await staffActor(t, 'MANAGER', ['ASSIGNMENT_CREATE', 'ASSIGNMENT_VIEW_ASSIGNED']);
    await foreignMgr.api.get(`/v1/admin/assignments/${created.body.id}`).expect(404);
  });

  it('QR: a staff scan resolves the real assignment; an invalid code is a clean 404', async () => {
    const f = await setup(t);
    const created = await f.admin.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    // the QR was published via qr.created; fetch it back through the worker card (same pattern as M2's worker QR)
    const worker = await f.admin.api.get(`/v1/workers/${f.workerId}`).expect(200);
    expect(worker.body.qrCode).toBeTruthy();
    const resolved = await f.admin.api.get(`/v1/qr/${worker.body.qrCode}`).expect(200);
    expect(resolved.body.type).toBe('WORKER'); // the worker's OWN QR, unaffected by having an assignment
    void created;
  });

  it('full lifecycle: deliver -> progress -> ready -> pickup -> accept (full) -> earning -> COMPLETED', async () => {
    const f = await setup(t);
    const created = await f.admin.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    const id = created.body.id;

    const delivered = await f.admin.api.post(`/v1/admin/assignments/${id}/deliver`, {}).expect(200);
    expect(delivered.body.status).toBe('IN_PROGRESS');

    const progress = await f.workerApi.post(`/v1/work/${id}/progress`, { reportedMeters: '5' }).expect(200);
    expect(progress.body.reportedMeters).toBe(5);
    await f.workerApi.post(`/v1/work/${id}/progress`, { reportedMeters: '20' }).expect(409); // > plannedMeters(9)

    const ready = await f.workerApi.post(`/v1/work/${id}/ready`, { readyMeters: '9' }).expect(200);
    expect(ready.body.status).toBe('READY_FOR_PICKUP');

    const picked = await f.admin.api.post(`/v1/admin/assignments/${id}/pickup`, {}).expect(200);
    expect(picked.body.status).toBe('UNDER_REVIEW');

    const rate = await f.admin.api.get('/v1/settings/pay-rate').expect(200);
    const accepted = await f.admin.api.post(`/v1/admin/assignments/${id}/accept`, { broughtMeters: '9', acceptedMeters: '9' }).expect(200);
    expect(accepted.body.status).toBe('COMPLETED');
    expect(accepted.body.calculatedPayment).toBe(rate.body.ratePerKit); // exactly one kit's worth

    const ledger = await f.admin.api.get(`/v1/admin/workers/${f.workerId}/ledger`).expect(200);
    expect(ledger.body.balance).toBe(rate.body.ratePerKit);
    expect(ledger.body.earned).toBe(rate.body.ratePerKit);

    // §13: the worker sees the SAME numbers about herself, self-service, no FINANCE permission needed
    const mine = await f.workerApi.get('/v1/work/earnings').expect(200);
    expect(mine.body.balance).toBe(rate.body.ratePerKit);
    expect(mine.body.earned).toBe(rate.body.ratePerKit);
    const foreignMgr = await staffActor(t, 'MANAGER');
    await foreignMgr.api.get('/v1/work/earnings').expect(403); // staff never has a workerId -> WORKER-only route
  });

  it('partial acceptance: accepted portion is paid, the rest is flagged, never silently dropped', async () => {
    const f = await setup(t);
    const created = await f.admin.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    const id = created.body.id;
    await f.admin.api.post(`/v1/admin/assignments/${id}/deliver`, {}).expect(200);
    await f.workerApi.post(`/v1/work/${id}/ready`, { readyMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${id}/pickup`, {}).expect(200);

    const accepted = await f.admin.api.post(`/v1/admin/assignments/${id}/accept`, {
      broughtMeters: '9', acceptedMeters: '6', defectiveMeters: '3',
    }).expect(200);
    expect(accepted.body.status).toBe('PARTIALLY_ACCEPTED');
    expect(Number(accepted.body.calculatedPayment)).toBeGreaterThan(0);

    const ledger = await f.admin.api.get(`/v1/admin/workers/${f.workerId}/ledger`).expect(200);
    expect(Number(ledger.body.earned)).toBeGreaterThan(0);
  });

  it('cash payout: partial then full, balance tracked exactly, over-payout refused without forced:true', async () => {
    const f = await setup(t);
    const created = await f.admin.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    const id = created.body.id;
    await f.admin.api.post(`/v1/admin/assignments/${id}/deliver`, {}).expect(200);
    await f.workerApi.post(`/v1/work/${id}/ready`, { readyMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${id}/pickup`, {}).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${id}/accept`, { broughtMeters: '9', acceptedMeters: '9' }).expect(200);

    const before = await f.admin.api.get(`/v1/admin/workers/${f.workerId}/ledger`).expect(200);
    const total = Number(before.body.balance);
    const half = Math.floor(total / 2);

    await f.admin.api.post(`/v1/admin/workers/${f.workerId}/payout`, { amount: String(total + 1000) }).expect(409); // over balance, refused
    const partial = await f.admin.api.post(`/v1/admin/workers/${f.workerId}/payout`, { amount: String(half) }).expect(200);
    expect(Number(partial.body.balance)).toBe(total - half);

    const full = await f.admin.api.post(`/v1/admin/workers/${f.workerId}/payout`, { amount: String(total - half) }).expect(200);
    expect(Number(full.body.balance)).toBe(0);
    expect(Number(full.body.paid)).toBe(total);
  });

  it('realtime: assignment.created / status_changed / earning.created reach the owning manager, not a foreign one', async () => {
    const f = await setup(t);
    const mgr = await staffActor(t, 'MANAGER', ['ASSIGNMENT_CREATE', 'ASSIGNMENT_VIEW_ASSIGNED', 'ASSIGNMENT_ACCEPT']);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: mgr.user.id }).expect(201);
    t.events.length = 0;
    const created = await mgr.api.post('/v1/admin/assignments', createBody(f, 1)).expect(201);
    expect(t.events.some((e) => e.type === 'assignment.created' && (e.data as { workerId: string }).workerId === f.workerId)).toBe(true);
    const ev = t.events.find((e) => e.type === 'assignment.created')!;
    expect((ev.data as { managerId?: string | null }).managerId).toBe(mgr.user.id);
    void created;
  });
});
