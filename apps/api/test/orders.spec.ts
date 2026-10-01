import { ENV } from '../src/config/env';
import { EventBus } from '../src/events/event-bus';
import { OrdersService } from '../src/orders/orders.service';
import { ShopFlow } from '../src/orders/shop-flow';
import { client, createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** Customer orders: staff write them down; customers order on shop.diamoraa.uz or in the shop bot (owner, 2026-10-01). */
describe('client orders', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  it('staff record an order (any item, even not published), see it and move it along; a guest cannot', async () => {
    const admin = await superAdminActor(t);
    const manager = await staffActor(t, 'MANAGER');
    const model = await t.prisma.productModel.create({ data: { code: `CO-${Math.random()}`, name: 'Kokil lenta', status: 'DRAFT' } });
    const guest = client(t);

    await guest.post('/v1/admin/orders', { name: 'Дилноза', phone: '+998 90 111 22 33' }).expect(401);
    await manager.api.post('/v1/admin/orders', { name: 'Д', phone: '12' }).expect(400);
    const made = (await manager.api.post('/v1/admin/orders', { name: 'Дилноза', phone: '+998 90 111 22 33', productModelId: model.id, colorName: 'Розовый', quantity: 27, comment: 'к пятнице' }).expect(201)).body;
    expect(made.code).toMatch(/^CO-\d{5}$/);

    const list = (await admin.api.get('/v1/admin/orders?status=NEW').expect(200)).body;
    const o = list.items.find((x: { code: string }) => x.code === made.code);
    expect(o).toMatchObject({ name: 'Дилноза', phone: '+998901112233', product: { id: model.id }, colorName: 'Розовый', quantity: 27, comment: 'к пятнице', status: 'NEW', source: 'PANEL', followsInBot: false });

    const upd = (await manager.api.patch(`/v1/admin/orders/${o.id}`, { status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' }).expect(200)).body;
    expect(upd).toMatchObject({ status: 'CONFIRMED', staffNote: 'позвонила, ждёт в пятницу' });
  });

  it('the shop site: published items only, no purchase or worker prices; an order is SITE; a trap field stores nothing', async () => {
    const guest = client(t);
    const draft = await t.prisma.productModel.create({ data: { code: `SH-${Math.random()}`, name: 'Черновик', status: 'DRAFT' } });
    const pub = await t.prisma.productModel.create({ data: { code: `SH-${Math.random()}`, name: `Лента магазин ${Math.random()}`, status: 'PUBLISHED', publishedAt: new Date() } });

    const cat = (await guest.get('/v1/public/catalog').expect(200)).body;
    expect(cat.items.some((i: { id: string }) => i.id === pub.id)).toBe(true);
    expect(cat.items.some((i: { id: string }) => i.id === draft.id)).toBe(false);
    expect(JSON.stringify(cat)).not.toMatch(/unitCost|rate|price/i);
    await guest.get(`/v1/public/catalog/${pub.id}`).expect(200);
    await guest.get(`/v1/public/catalog/${draft.id}`).expect(404);

    await guest.post('/v1/public/orders', { name: 'Нигора', phone: '+998 90 222 33 44', productModelId: draft.id }).expect(404); // not for sale
    const r = (await guest.post('/v1/public/orders', { name: 'Нигора', phone: '+998 90 222 33 44', productModelId: pub.id, quantity: 12 }).expect(201)).body;
    expect(r.code).toMatch(/^CO-\d{5}$/);
    const row = await t.prisma.clientOrder.findUniqueOrThrow({ where: { code: r.code } });
    expect(row).toMatchObject({ source: 'SITE', customerChatId: null });

    const before = await t.prisma.clientOrder.count();
    expect((await guest.post('/v1/public/orders', { name: 'Spam', phone: '+998 90 222 33 45', website: 'http://x' }).expect(201)).body).toMatchObject({ ok: true, code: null });
    expect(await t.prisma.clientOrder.count()).toBe(before);
  });

  it('the shop bot: order step by step, «Мои заказы», news about each step; a site order can be followed', async () => {
    const admin = await superAdminActor(t);
    const flow = new ShopFlow(t.prisma, t.app.get(OrdersService), t.app.get(EventBus), t.app.get(ENV));
    const pub = await t.prisma.productModel.create({ data: { code: `SB-${Math.random()}`, name: `Бот лента ${Math.random()}`, status: 'PUBLISHED', publishedAt: new Date(), sortOrder: -1000 } });
    const chat = BigInt(Math.floor(Math.random() * 1e12));

    expect((await flow.handle(chat, { kind: 'start' })).menu).toBe(true);
    const pick = await flow.handle(chat, { kind: 'text', text: '📝 Заказать' });
    const btn = pick.buttons!.flat().find((b) => b.data === `sh:p:${pub.id}`);
    expect(btn).toBeTruthy();
    expect((await flow.handle(chat, { kind: 'callback', data: btn!.data! })).text).toContain('Сколько метров'); // no colours: straight to metres
    expect((await flow.handle(chat, { kind: 'text', text: 'много' })).text).toContain('число');
    expect((await flow.handle(chat, { kind: 'text', text: '15,5' })).text).toContain('Как вас зовут');
    expect((await flow.handle(chat, { kind: 'text', text: 'Мадина' })).askContact).toBe(true);
    expect((await flow.handle(chat, { kind: 'contact', phone: '12' })).askContact).toBe(true);
    const confirm = await flow.handle(chat, { kind: 'contact', phone: '998905556677' });
    expect(confirm.text).toContain('15.5 м');
    const done = await flow.handle(chat, { kind: 'callback', data: 'sh:ok' });
    const code = /CO-\d{5}/.exec(done.text)![0];
    const row = await t.prisma.clientOrder.findUniqueOrThrow({ where: { code } });
    expect(row).toMatchObject({ source: 'BOT', customerChatId: chat, name: 'Мадина', phone: '+998905556677', productModelId: pub.id });
    expect((await flow.handle(chat, { kind: 'callback', data: 'sh:ok' })).text).toContain('устарел'); // never twice
    expect((await flow.handle(chat, { kind: 'text', text: '📦 Мои заказы' })).text).toContain(code);

    // staff move it: the customer hears about it in the shop bot (not the workers' bot)
    await admin.api.patch(`/v1/admin/orders/${row.id}`, { status: 'IN_WORK', staffNote: 'внутренняя заметка' }).expect(200);
    const news = await t.prisma.notification.findFirstOrThrow({ where: { telegramChatId: chat, type: 'client_order.step' } });
    expect(news.body).toContain('в работе');
    expect(news.body).not.toContain('заметка');
    expect(news.data).toMatchObject({ via: 'shop' });

    // a question outside an order goes to the staff
    expect((await flow.handle(chat, { kind: 'text', text: 'Есть красный?', from: 'Мадина' })).owners).toContain('Есть красный?');

    // a site order, followed in the bot
    const site = (await client(t).post('/v1/public/orders', { name: 'Гуля', phone: '+998 90 777 88 99', productModelId: pub.id }).expect(201)).body;
    const chat2 = chat + 7n;
    const forged = await flow.handle(chat2, { kind: 'start', payload: `o_${'0'.repeat(32)}_${'0'.repeat(16)}` });
    expect(forged.text).not.toContain('CO-');
    const siteRow = await t.prisma.clientOrder.findUniqueOrThrow({ where: { code: site.code } });
    const followed = await flow.handle(chat2, { kind: 'start', payload: t.app.get(OrdersService).followToken(siteRow.id) });
    expect(followed.text).toContain(site.code);
  });
});
