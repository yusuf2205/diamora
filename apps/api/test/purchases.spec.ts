import { AuditService } from '../src/audit/audit.service';
import { EventBus } from '../src/events/event-bus';
import { SupplierBot } from '../src/purchases/supplier-bot';
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
  it('a supplier links the bot once; an order goes to their chat with buttons; the answer comes back', async () => {
    const admin = await superAdminActor(t);
    const bot = new SupplierBot(t.prisma, t.app.get(AuditService), t.app.get(EventBus));
    const sup = (await admin.api.post('/v1/admin/suppliers', { name: `Нитки ${Math.random()}` }).expect(201)).body;
    const mat = (await admin.api.post('/v1/admin/materials', { name: `Нить бот ${Math.random()}`, unit: 'PCS', minStock: '0' }).expect(201)).body.id;
    // any order, not only what is suggested
    const po = (await admin.api.post('/v1/admin/purchases', { supplierId: sup.id, note: 'к пятнице', items: [{ materialId: mat, quantity: '20' }] }).expect(201)).body;
    expect(po.supplier.botLinked).toBe(false);
    await admin.api.post(`/v1/admin/purchases/${po.id}/send`).expect(409); // not linked yet

    const { url } = (await admin.api.post(`/v1/admin/suppliers/${sup.id}/bot-link`).expect(200)).body;
    const token = new URL(url).searchParams.get('start')!.replace(/^sup_/, '');
    const chat = BigInt(Math.floor(Math.random() * 1e12));
    expect(await bot.completeLink('wrong', chat)).toContain('устарела');
    expect(await bot.completeLink(token, chat)).toContain('Теперь заказы Diamoraa');
    expect(await bot.completeLink(token, chat)).toContain('устарела'); // one-time
    expect((await admin.api.get('/v1/admin/suppliers').expect(200)).body.items.find((x: { id: string }) => x.id === sup.id).botLinked).toBe(true);

    const sent = (await admin.api.post(`/v1/admin/purchases/${po.id}/send`).expect(200)).body;
    expect(sent).toMatchObject({ status: 'ORDERED', supplierReply: null });
    expect(sent.sentByBotAt).toBeTruthy();
    const msg = await t.prisma.notification.findFirstOrThrow({ where: { telegramChatId: chat, type: 'purchase.order' } });
    expect(msg.body).toContain('— 20 шт');
    expect(msg.body).toContain('к пятнице');
    expect((msg.data as { buttons: { data: string }[][] }).buttons[0].map((b) => b.data)).toEqual([`po:ok:${po.id}`, `po:no:${po.id}`]);

    expect(await bot.reply(chat + 1n, po.id, 'ACCEPTED')).toBeNull(); // someone else's chat
    const r = await bot.reply(chat, po.id, 'ACCEPTED');
    expect(r).toMatchObject({ changed: true });
    expect(r!.owners).toContain('принял заказ');
    expect((await admin.api.get(`/v1/admin/purchases/${po.id}`).expect(200)).body.supplierReply).toBe('ACCEPTED');
    expect((await bot.reply(chat, po.id, 'ACCEPTED'))!.changed).toBe(false); // pressed twice
    expect(await bot.message(chat, 'Привезу в пятницу')).toMatchObject({ reply: 'Спасибо, передали Diamoraa.' });
    expect(await bot.message(chat + 1n, 'кто это')).toBeNull();

    await admin.api.delete(`/v1/admin/suppliers/${sup.id}/bot-link`).expect(200);
    expect(await bot.isSupplierChat(chat)).toBe(false);
  });
});
