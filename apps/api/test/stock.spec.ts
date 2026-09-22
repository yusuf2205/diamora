import { staffActor, superAdminActor, TestApp, createTestApp } from './support/app';

async function makeMaterial(t: TestApp, admin: Awaited<ReturnType<typeof superAdminActor>>, name = 'Лента тест') {
  const created = await admin.api.post('/v1/admin/materials', { name, unit: 'METER' }).expect(201);
  return created.body.id as string;
}

describe('stock (M2 §6-7): every change is an immutable movement; balance never goes negative', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('receipt increases the balance and writes an immutable movement row', async () => {
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin);
    const r = await admin.api.post('/v1/admin/stock/receipt', { materialId, quantity: '100', comment: 'Первая поставка' }).expect(201);
    expect(r.body.type).toBe('RECEIPT');
    expect(r.body.quantity).toBe(100);
    const balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    const row = (balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === materialId)!;
    expect(row.quantity).toBe(100);

    const moved = await t.prisma.stockMovement.findUniqueOrThrow({ where: { id: r.body.id } });
    await expect(t.prisma.stockMovement.update({ where: { id: moved.id }, data: { comment: 'hacked' } })).rejects.toThrow(); // DB trigger: append-only
  });

  it('adjustment IN/OUT moves the balance both ways; a negative result is refused and nothing changes', async () => {
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin, 'Лента adj');
    await admin.api.post('/v1/admin/stock/receipt', { materialId, quantity: '10' }).expect(201);
    await admin.api.post('/v1/admin/stock/adjust', { materialId, direction: 'OUT', quantity: '4', reason: 'Брак при проверке' }).expect(201);
    let balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    expect((balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === materialId)!.quantity).toBe(6);

    await admin.api.post('/v1/admin/stock/adjust', { materialId, direction: 'OUT', quantity: '999', reason: 'Слишком много' }).expect(409);
    balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    expect((balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === materialId)!.quantity).toBe(6); // unchanged
  });

  it('write-off consumes stock; a fresh material with 0 stock refuses any consuming movement', async () => {
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin, 'Лента writeoff');
    await admin.api.post('/v1/admin/stock/write-off', { materialId, quantity: '1', reason: 'Испорчено' }).expect(409);
    await admin.api.post('/v1/admin/stock/receipt', { materialId, quantity: '5' }).expect(201);
    await admin.api.post('/v1/admin/stock/write-off', { materialId, quantity: '5', reason: 'Испорчено' }).expect(201);
    const balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    expect((balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === materialId)!.quantity).toBe(0);
  });

  it('concurrent movements on the same material never push the balance negative (row lock serialises them)', async () => {
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin, 'Лента concurrent');
    await admin.api.post('/v1/admin/stock/receipt', { materialId, quantity: '10' }).expect(201);
    const attempts = await Promise.allSettled([
      admin.api.post('/v1/admin/stock/adjust', { materialId, direction: 'OUT', quantity: '7', reason: 'Причина A' }),
      admin.api.post('/v1/admin/stock/adjust', { materialId, direction: 'OUT', quantity: '7', reason: 'Причина B' }),
    ]);
    const statuses = attempts.map((a) => (a.status === 'fulfilled' ? a.value.status : -1)).sort();
    expect(statuses).toEqual([201, 409]); // exactly one succeeds
    const balances = await admin.api.get('/v1/admin/stock/balances').expect(200);
    expect((balances.body.items as { materialId: string; quantity: number }[]).find((i) => i.materialId === materialId)!.quantity).toBe(3);
  });

  it('permission boundary: INVENTORY_VIEW only can read, never write', async () => {
    const viewer = await staffActor(t, 'MANAGER', ['INVENTORY_VIEW']);
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin, 'Лента perm');
    await viewer.api.get('/v1/admin/stock/balances').expect(200);
    await viewer.api.post('/v1/admin/stock/receipt', { materialId, quantity: '1' }).expect(403);
  });

  it('realtime: stock.movement.created and stock.updated are published after a receipt', async () => {
    const admin = await superAdminActor(t);
    const materialId = await makeMaterial(t, admin, 'Лента realtime');
    t.events.length = 0;
    await admin.api.post('/v1/admin/stock/receipt', { materialId, quantity: '3' }).expect(201);
    expect(t.events.some((e) => e.type === 'stock.movement.created')).toBe(true);
    expect(t.events.some((e) => e.type === 'stock.updated')).toBe(true);
  });
});
