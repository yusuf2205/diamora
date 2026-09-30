import { client, createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** Customer orders are taken by staff in the panel (SUPER_ADMIN / ADMIN / MANAGER); nothing public on diamoraa.uz. */
describe('client orders', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('staff record an order (any item, even not published), see it and move it along; no public endpoint; a worker cannot', async () => {
    const admin = await superAdminActor(t);
    const manager = await staffActor(t, 'MANAGER');
    const model = await t.prisma.productModel.create({ data: { code: `CO-${Math.random()}`, name: 'Kokil lenta', status: 'DRAFT' } });
    const guest = client(t);

    await guest.post('/v1/public/orders', { name: 'Бот', phone: '+998 90 111 22 34' }).expect(404); // removed from the site
    await guest.get('/v1/public/catalog').expect(404);
    await guest.post('/v1/admin/orders', { name: 'Дилноза', phone: '+998 90 111 22 33' }).expect(401);

    await manager.api.post('/v1/admin/orders', { name: 'Д', phone: '12' }).expect(400);
    const made = (await manager.api.post('/v1/admin/orders', { name: 'Дилноза', phone: '+998 90 111 22 33', productModelId: model.id, colorName: 'Розовый', quantity: 27, comment: 'к пятнице' }).expect(201)).body;
    expect(made.code).toMatch(/^CO-\d{5}$/);

    const list = (await admin.api.get('/v1/admin/orders?status=NEW').expect(200)).body;
    const o = list.items.find((x: { code: string }) => x.code === made.code);
    expect(o).toMatchObject({ name: 'Дилноза', phone: '+998901112233', product: { id: model.id }, colorName: 'Розовый', quantity: 27, comment: 'к пятнице', status: 'NEW' });

    const upd = (await manager.api.patch(`/v1/admin/orders/${o.id}`, { status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' }).expect(200)).body;
    expect(upd).toMatchObject({ status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' });
  });
});
