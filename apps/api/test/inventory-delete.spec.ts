import { createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** «Удалить» on the warehouse screen (INVENTORY_DELETE, granted by the SUPER_ADMIN): materials and 9 m kit recipes. */
describe('inventory: delete materials and kit recipes', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('a material never used is erased; one with stock is written off and hidden, its movement trail stays whole', async () => {
    const admin = await superAdminActor(t);
    const plain = await staffActor(t, 'ADMIN'); // INVENTORY_MANAGE by default, but not delete
    const fresh = (await admin.api.post('/v1/admin/materials', { name: `Пустой ${Math.random()}`, unit: 'METER' }).expect(201)).body.id;
    await plain.api.delete(`/v1/admin/materials/${fresh}`).expect(403);
    await admin.api.delete(`/v1/admin/materials/${fresh}`).expect(200);
    expect(await t.prisma.material.findUnique({ where: { id: fresh } })).toBeNull();

    const stocked = (await admin.api.post('/v1/admin/materials', { name: `С остатком ${Math.random()}`, unit: 'METER' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: stocked, quantity: '155' }).expect(201);
    const granted = await staffActor(t, 'ADMIN', ['INVENTORY_DELETE']);
    await granted.api.delete(`/v1/admin/materials/${stocked}`).expect(200);
    const kept = await t.prisma.material.findUniqueOrThrow({ where: { id: stocked }, include: { balance: true } });
    expect(kept.deletedAt).not.toBeNull();
    expect(Number(kept.balance?.quantity)).toBe(0);
    expect(await t.prisma.stockMovement.count({ where: { materialId: stocked, type: 'WRITE_OFF' } })).toBe(1);
    await admin.api.get(`/v1/admin/materials/${stocked}`).expect(404);
    const listed = (await admin.api.get('/v1/admin/materials?limit=100').expect(200)).body.items as { id: string }[];
    expect(listed.map((m) => m.id)).not.toContain(stocked);
  });

  it('a material inside a live kit recipe is refused with IN_USE naming the kit; deleting the recipe frees it', async () => {
    const admin = await superAdminActor(t);
    const m = (await admin.api.post('/v1/admin/materials', { name: `В комплекте ${Math.random()}`, unit: 'METER' }).expect(201)).body.id;
    const name = `Рецепт ${Math.random()}`;
    const kit = (await admin.api.post('/v1/admin/kits', { name, items: [{ materialId: m, requiredQuantity: '9' }] }).expect(201)).body.id;

    const res = await admin.api.delete(`/v1/admin/materials/${m}`).expect(409);
    expect(res.body.error.code).toBe('IN_USE');
    expect(res.body.error.details.kits).toEqual([name]);

    await admin.api.delete(`/v1/admin/kits/${kit}`).expect(200);
    expect(await t.prisma.materialKitTemplate.findUnique({ where: { id: kit } })).toBeNull();
    await admin.api.delete(`/v1/admin/materials/${m}`).expect(200);
  });

  it('a kit recipe with a printed kit QR is hidden (name freed for a new recipe), not erased', async () => {
    const admin = await superAdminActor(t);
    const m = (await admin.api.post('/v1/admin/materials', { name: `Лента ${Math.random()}`, unit: 'METER' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: m, quantity: '9' }).expect(201);
    const name = `Собранный ${Math.random()}`;
    const kit = (await admin.api.post('/v1/admin/kits', { name, items: [{ materialId: m, requiredQuantity: '9' }] }).expect(201)).body.id;
    await admin.api.post(`/v1/admin/kits/${kit}/assemble`, { count: 1 }).expect(201);

    await admin.api.delete(`/v1/admin/kits/${kit}`).expect(200);
    expect((await t.prisma.materialKitTemplate.findUniqueOrThrow({ where: { id: kit } })).deletedAt).not.toBeNull();
    const listed = (await admin.api.get('/v1/admin/kits').expect(200)).body.items as { id: string }[];
    expect(listed.map((k) => k.id)).not.toContain(kit);
    await admin.api.post('/v1/admin/kits', { name, items: [{ materialId: m, requiredQuantity: '9' }] }).expect(201);
  });
});
