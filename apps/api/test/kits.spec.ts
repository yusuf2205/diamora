import { staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

async function makeMaterial(admin: Awaited<ReturnType<typeof superAdminActor>>, name: string, unit = 'METER') {
  return (await admin.api.post('/v1/admin/materials', { name, unit }).expect(201)).body.id as string;
}

describe('material kit templates (M2 §8-9): the 9 m recipe; 18/27 m are the SAME items × kitCount, never separate templates', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('9 m is the base; requesting × 2 / × 3 on assembly multiplies every ingredient, no separate 18m/27m template exists', async () => {
    const admin = await superAdminActor(t);
    const ribbon = await makeMaterial(admin, 'Лента Rose Gold');
    const bead = await makeMaterial(admin, 'Бисер Rose Gold', 'GRAM');
    await admin.api.post('/v1/admin/stock/receipt', { materialId: ribbon, quantity: '100' }).expect(201);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: bead, quantity: '500' }).expect(201);

    const tpl = await admin.api.post('/v1/admin/kits', {
      name: 'Rose Gold — 9m', ribbonMeters: 9,
      items: [{ materialId: ribbon, requiredQuantity: '9' }, { materialId: bead, requiredQuantity: '20' }],
    }).expect(201);
    expect(tpl.body.baseMeters).toBe(9);
    expect(tpl.body.items).toHaveLength(2);

    // assemble 2 copies (= what an 18 m assignment would need): every ingredient × 2
    const assembled = await admin.api.post(`/v1/admin/kits/${tpl.body.id}/assemble`, { count: 2 }).expect(201);
    expect(assembled.body.totalMeters).toBe(18);
    expect(assembled.body.qrCode).toMatch(/^YQ1\./);

    const balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    const items = balances.body.items as { materialId: string; quantity: number }[];
    expect(items.find((i) => i.materialId === ribbon)!.quantity).toBe(100 - 9 * 2);
    expect(items.find((i) => i.materialId === bead)!.quantity).toBe(500 - 20 * 2);

    const ribbonMoves = await admin.api.get(`/v1/admin/stock/movements?materialId=${ribbon}`).expect(200);
    const beadMoves = await admin.api.get(`/v1/admin/stock/movements?materialId=${bead}`).expect(200);
    const groupIds = new Set([
      ...(ribbonMoves.body.items as { groupId: string; type: string }[]).filter((m) => m.type === 'ISSUE_TO_KIT').map((m) => m.groupId),
      ...(beadMoves.body.items as { groupId: string; type: string }[]).filter((m) => m.type === 'ISSUE_TO_KIT').map((m) => m.groupId),
    ]);
    expect(groupIds.size).toBe(1); // both ingredient movements share ONE group (one physical batch)
  });

  it('assembly refuses when the warehouse does not have enough of an ingredient (never partially consumes)', async () => {
    const admin = await superAdminActor(t);
    const ribbon = await makeMaterial(admin, 'Лента shortage');
    await admin.api.post('/v1/admin/stock/receipt', { materialId: ribbon, quantity: '5' }).expect(201);
    const tpl = await admin.api.post('/v1/admin/kits', { name: 'Shortage — 9m', items: [{ materialId: ribbon, requiredQuantity: '9' }] }).expect(201);
    await admin.api.post(`/v1/admin/kits/${tpl.body.id}/assemble`, { count: 1 }).expect(409);
    const balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    expect((balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === ribbon)!.quantity).toBe(5); // untouched
  });

  it('permission boundary: INVENTORY_VIEW can read templates, never create/assemble', async () => {
    const viewer = await staffActor(t, 'MANAGER', ['INVENTORY_VIEW']);
    await viewer.api.get('/v1/admin/kits').expect(200);
    await viewer.api.post('/v1/admin/kits', { name: 'Тест — 9m', items: [] }).expect(403); // permission (guard) is checked before body validation
  });

  it('realtime: kit.created on template create, kit.assembled + qr.created on assembly', async () => {
    const admin = await superAdminActor(t);
    const ribbon = await makeMaterial(admin, 'Лента rt');
    await admin.api.post('/v1/admin/stock/receipt', { materialId: ribbon, quantity: '9' }).expect(201);
    t.events.length = 0;
    const tpl = await admin.api.post('/v1/admin/kits', { name: 'RT — 9m', items: [{ materialId: ribbon, requiredQuantity: '9' }] }).expect(201);
    expect(t.events.some((e) => e.type === 'kit.created')).toBe(true);
    t.events.length = 0;
    await admin.api.post(`/v1/admin/kits/${tpl.body.id}/assemble`, { count: 1 }).expect(201);
    expect(t.events.some((e) => e.type === 'kit.assembled')).toBe(true);
    expect(t.events.some((e) => e.type === 'qr.created')).toBe(true);
  });
});
