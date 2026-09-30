import { createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** «Закупки»: what to buy, an order to a supplier as a message, and receiving it onto the shelf with its price. */
describe('purchases', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('a low material is suggested; the order is sent as text; receiving adds stock and sets the purchase price once', async () => {
    const admin = await superAdminActor(t);
    const sup = (await admin.api.post('/v1/admin/suppliers', { name: 'Бусы Чорсу', phone: '+998901112233', telegram: '@busy_chorsu' }).expect(201)).body;
    expect(sup.telegram).toBe('busy_chorsu');
    const mat = (await admin.api.post('/v1/admin/materials', { name: `Лента закуп ${Math.random()}`, unit: 'METER', minStock: '50' }).expect(201)).body.id;
    await admin.api.patch(`/v1/admin/materials/${mat}`, { supplierId: sup.id }).expect(200);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: mat, quantity: '10' }).expect(201);

    const sug = (await admin.api.get('/v1/admin/purchases/suggest').expect(200)).body.items.find((x: { materialId: string }) => x.materialId === mat);
    expect(sug).toMatchObject({ left: 10, quantity: 90, supplier: { id: sup.id }, reason: 'ниже минимума (50)' }); // back to twice the minimum

    const po = (await admin.api.post('/v1/admin/purchases', { supplierId: sup.id, items: [{ materialId: mat, quantity: '90', unitPrice: '1200' }] }).expect(201)).body;
    expect(po).toMatchObject({ status: 'DRAFT', total: '108000', priced: true });
    expect(po.code).toMatch(/^ЗК-\d{4}$/);
    // already on its way: not suggested again
    expect((await admin.api.get('/v1/admin/purchases/suggest').expect(200)).body.items.some((x: { materialId: string }) => x.materialId === mat)).toBe(false);

    const txt = (await admin.api.get(`/v1/admin/purchases/${po.id}/text`).expect(200)).body;
    expect(txt.text).toContain('Бусы Чорсу');
    expect(txt.text).toContain('— 90 м');
    expect(txt.telegram).toBe('busy_chorsu');

    await admin.api.patch(`/v1/admin/purchases/${po.id}`, { status: 'ORDERED' }).expect(200);
    await admin.api.patch(`/v1/admin/purchases/${po.id}`, { items: [{ materialId: mat, quantity: '1' }] }).expect(409); // lines are fixed once sent

    // 85 m came, at 1 250 each
    const got = (await admin.api.post(`/v1/admin/purchases/${po.id}/receive`, { items: [{ itemId: po.items[0].id, quantity: '85', unitPrice: '1250' }] }).expect(200)).body;
    expect(got.status).toBe('RECEIVED');
    const m = (await admin.api.get(`/v1/admin/materials/${mat}`).expect(200)).body;
    expect(m).toMatchObject({ balance: 95, unitCost: '1250', supplierId: sup.id });
    await admin.api.post(`/v1/admin/purchases/${po.id}/receive`, { items: [{ itemId: po.items[0].id, quantity: '85' }] }).expect(409); // never twice

    const viewer = await staffActor(t, 'MANAGER', ['INVENTORY_VIEW']);
    await viewer.api.get('/v1/admin/purchases').expect(200);
    await viewer.api.post('/v1/admin/purchases', { items: [{ materialId: mat, quantity: '1' }] }).expect(403);
  });
});
