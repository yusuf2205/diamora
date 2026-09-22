import { staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

describe('materials reference book (M2 §5): fixed categories, INVENTORY_VIEW / INVENTORY_MANAGE', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('the 5 fixed categories are seeded (TAPE/BEAD/THREAD/ACCESSORY/OTHER)', async () => {
    const admin = await superAdminActor(t);
    const res = await admin.api.get('/v1/admin/materials/categories').expect(200);
    const codes = (res.body as { code: string | null }[]).map((c) => c.code).sort();
    expect(codes).toEqual(['ACCESSORY', 'BEAD', 'OTHER', 'TAPE', 'THREAD']);
  });

  it('create/update a material; balance starts at 0; never a financial field for a WORKER (there is no worker route at all)', async () => {
    const admin = await superAdminActor(t);
    const cats = await admin.api.get('/v1/admin/materials/categories').expect(200);
    const tape = (cats.body as { id: string; code: string }[]).find((c) => c.code === 'TAPE')!;

    const created = await admin.api.post('/v1/admin/materials', { name: 'Лента Rose Gold 25мм', categoryId: tape.id, unit: 'METER', minStock: '50' }).expect(201);
    expect(created.body.balance).toBe(0);
    expect(created.body.low).toBe(true); // 0 < minStock(50)
    expect(created.body.category.code).toBe('TAPE');

    const updated = await admin.api.patch(`/v1/admin/materials/${created.body.id}`, { minStock: '0' }).expect(200);
    expect(updated.body.low).toBe(false);

    const list = await admin.api.get('/v1/admin/materials').expect(200);
    expect((list.body.items as { id: string }[]).some((m) => m.id === created.body.id)).toBe(true);
  });

  it('rejects an unknown category; deactivate keeps the row (no hard delete)', async () => {
    const admin = await superAdminActor(t);
    await admin.api.post('/v1/admin/materials', { name: 'Неизвестная категория', categoryId: '00000000-0000-7000-8000-000000000000', unit: 'PCS' }).expect(409);
    const created = await admin.api.post('/v1/admin/materials', { name: 'Бусина стекло 4мм', unit: 'GRAM' }).expect(201);
    const deactivated = await admin.api.post(`/v1/admin/materials/${created.body.id}/deactivate`).expect(200);
    expect(deactivated.body.isActive).toBe(false);
    const stillThere = await admin.api.get(`/v1/admin/materials/${created.body.id}`).expect(200);
    expect(stillThere.body.id).toBe(created.body.id);
  });

  it('permission boundary: a plain MANAGER (no grant) is refused; a granted MANAGER can only view', async () => {
    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.get('/v1/admin/materials').expect(403);
    const viewer = await staffActor(t, 'MANAGER', ['INVENTORY_VIEW']);
    await viewer.api.get('/v1/admin/materials').expect(200);
    await viewer.api.post('/v1/admin/materials', { name: 'X', unit: 'PCS' }).expect(403); // view only, not manage
  });

  it('realtime: material.created / material.updated reach staff with INVENTORY_VIEW', async () => {
    const admin = await superAdminActor(t);
    t.events.length = 0;
    const created = await admin.api.post('/v1/admin/materials', { name: 'Нить полиэстер', unit: 'ROLL' }).expect(201);
    await admin.api.patch(`/v1/admin/materials/${created.body.id}`, { article: 'ART-1' }).expect(200);
    expect(t.events.some((e) => e.type === 'material.created')).toBe(true);
    expect(t.events.some((e) => e.type === 'material.updated')).toBe(true);
  });
});
