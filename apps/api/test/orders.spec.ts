import { client, createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** Customer orders from the form on diamoraa.uz: no account, only published items; staff see and handle them. */
describe('client orders', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('a customer orders a published item (no account); staff get a notice, see it and move it along; a manager without catalog rights cannot', async () => {
    const admin = await superAdminActor(t);
    const pub = await t.prisma.productModel.create({ data: { code: `CO-${Math.random()}`, name: 'Коkil lenta', status: 'PUBLISHED' } });
    const draft = await t.prisma.productModel.create({ data: { code: `CO-${Math.random()}`, name: 'Черновик', status: 'DRAFT' } });
    const guest = client(t);

    const cat = (await guest.get('/v1/public/catalog').expect(200)).body.items;
    expect(cat.some((i: { id: string }) => i.id === pub.id)).toBe(true);
    expect(cat.some((i: { id: string }) => i.id === draft.id)).toBe(false);
    expect(JSON.stringify(cat)).not.toMatch(/unitCost|price/i);

    await guest.post('/v1/public/orders', { name: 'Дилноза', phone: '+998 90 111 22 33', productModelId: draft.id }).expect(404); // not for sale
    await guest.post('/v1/public/orders', { name: 'Д', phone: '12' }).expect(400);
    const made = (await guest.post('/v1/public/orders', { name: 'Дилноза', phone: '+998 90 111 22 33', productModelId: pub.id, colorName: 'Розовый', quantity: 27, comment: 'к пятнице' }).expect(201)).body;
    expect(made.code).toMatch(/^CO-\d{5}$/);
    // a bot filling the hidden field is told «ok» and nothing is stored
    const bot = (await guest.post('/v1/public/orders', { name: 'Bot', phone: '+998 90 111 22 34', website: 'http://spam.example' }).expect(201)).body;
    expect(bot.ok).toBe(true);
    expect(await t.prisma.clientOrder.count({ where: { name: 'Bot' } })).toBe(0);

    const list = (await admin.api.get('/v1/admin/orders?status=NEW').expect(200)).body;
    const o = list.items.find((x: { code: string }) => x.code === made.code);
    expect(o).toMatchObject({ name: 'Дилноза', phone: '+998901112233', product: { id: pub.id }, colorName: 'Розовый', quantity: 27, comment: 'к пятнице', status: 'NEW' });
    expect(list.counts.NEW).toBeGreaterThan(0);
    const adminUser = await t.prisma.user.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } });
    expect(await t.prisma.notification.count({ where: { userId: adminUser.id, type: 'client_order.created' } })).toBeGreaterThan(0);

    const upd = (await admin.api.patch(`/v1/admin/orders/${o.id}`, { status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' }).expect(200)).body;
    expect(upd).toMatchObject({ status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' });

    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.patch(`/v1/admin/orders/${o.id}`, { status: 'DONE' }).expect(403);
    await guest.get('/v1/admin/orders').expect(401);
    // leave the shared test database as other suites expect it (their «nothing published yet» checks)
    await t.prisma.productModel.update({ where: { id: pub.id }, data: { status: 'DRAFT' } });
  });
});
