import { staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

describe('colors (M3 tech-debt closeout, D-039): CATALOG_VIEW / CATALOG_MANAGE, shared by Materials/Variants/Assignments', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('create/update a color; deactivate keeps the row (no hard delete); duplicate name is rejected', async () => {
    const admin = await superAdminActor(t);
    const created = await admin.api.post('/v1/admin/colors', { name: 'Rose Gold', hex: '#B76E79' }).expect(201);
    expect(created.body.isActive).toBe(true);
    expect(created.body.hex).toBe('#B76E79');

    await admin.api.post('/v1/admin/colors', { name: 'Rose Gold', hex: '#000000' }).expect(409);

    const updated = await admin.api.patch(`/v1/admin/colors/${created.body.id}`, { hex: '#C08497' }).expect(200);
    expect(updated.body.hex).toBe('#C08497');

    const deactivated = await admin.api.post(`/v1/admin/colors/${created.body.id}/deactivate`).expect(200);
    expect(deactivated.body.isActive).toBe(false);
    const stillThere = await admin.api.get(`/v1/admin/colors/${created.body.id}`).expect(200);
    expect(stillThere.body.id).toBe(created.body.id);
  });

  it('list filters by isActive; rejects a malformed hex', async () => {
    const admin = await superAdminActor(t);
    await admin.api.post('/v1/admin/colors', { name: 'Emerald' }).expect(201); // hex optional
    await admin.api.post('/v1/admin/colors', { name: 'Bad Hex', hex: 'not-a-hex' }).expect(400);
    const active = await admin.api.get('/v1/admin/colors?isActive=true').expect(200);
    expect((active.body.items as { name: string }[]).some((c) => c.name === 'Emerald')).toBe(true);
  });

  it('a ProductVariant can be created with a real colorId (Catalog + Colors wired together)', async () => {
    const admin = await superAdminActor(t);
    const color = await admin.api.post('/v1/admin/colors', { name: 'Sapphire Blue' }).expect(201);
    const item = await admin.api.post('/v1/admin/catalog', { name: 'Colour-wired test item' }).expect(201);
    const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id, label: 'Sapphire, long' }).expect(201);
    expect((withVariant.body.variants as { color: { id: string }; label: string | null }[]).some((v) => v.color?.id === color.body.id && v.label === 'Sapphire, long')).toBe(true);
  });

  it('permission boundary: CATALOG_VIEW can read, only CATALOG_MANAGE can write', async () => {
    const viewer = await staffActor(t, 'MANAGER', ['CATALOG_VIEW']);
    await viewer.api.get('/v1/admin/colors').expect(200);
    await viewer.api.post('/v1/admin/colors', { name: 'Should be denied' }).expect(403);
    const plain = await staffActor(t, 'MANAGER');
    await plain.api.get('/v1/admin/colors').expect(403);
  });

  it('realtime: color.created / color.updated reach staff with CATALOG_VIEW', async () => {
    const admin = await superAdminActor(t);
    t.events.length = 0;
    const created = await admin.api.post('/v1/admin/colors', { name: 'Realtime Test Color' }).expect(201);
    await admin.api.patch(`/v1/admin/colors/${created.body.id}`, { hex: '#123456' }).expect(200);
    expect(t.events.some((e) => e.type === 'color.created')).toBe(true);
    expect(t.events.some((e) => e.type === 'color.updated')).toBe(true);
  });
});
