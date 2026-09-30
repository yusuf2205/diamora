import { AdminBot } from '../src/alerts/admin-bot';
import { AlertsService } from '../src/alerts/alerts.service';
import { PrismaService } from '../src/prisma/prisma.module';
import { createTestApp, staffActor, superAdminActor, TestApp } from './support/app';

/** The owner's bot menu: only a linked, active admin chat gets it; every button answers in plain words. */
describe('admin bot menu', () => {
  let t: TestApp;
  let bot: AdminBot;
  beforeAll(async () => { t = await createTestApp(); bot = new AdminBot(t.app.get(PrismaService), {} as never); }); // the bot lives in the worker process
  afterAll(async () => { await t.close(); });

  it('only a linked admin chat is an admin chat', async () => {
    const admin = await staffActor(t, 'ADMIN');
    const { url } = (await admin.api.post('/v1/me/telegram-alerts/link', {}).expect(200)).body;
    await t.app.get(AlertsService).completeLink(url.split('start=alr_')[1], 424242n);
    expect(await bot.isAdminChat(424242n)).toBe(true);
    expect(await bot.isAdminChat(1n)).toBe(false); // a worker's / stranger's chat: registration as before
  });

  it('every button answers; unknown text = null (the menu is shown again)', async () => {
    const admin = await superAdminActor(t);
    const mat = (await admin.api.post('/v1/admin/materials', { name: `Лента бот ${Math.random()}`, unit: 'METER', minStock: '10' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: mat, quantity: '2' }).expect(201);
    const pub = await t.prisma.productModel.create({ data: { code: `B-${Math.random()}`, name: 'Лента для бота' } });
    await admin.api.post('/v1/admin/orders', { name: 'Камола', phone: '+998 90 555 44 33', productModelId: pub.id, quantity: 9 }).expect(201);

    expect(await bot.answer('📊 Итоги дня')).toContain('Заказов с сайта: ');
    const orders = await bot.answer('🛒 Заказы');
    expect(orders).toContain('Камола');
    expect(orders).toContain('+998905554433');
    expect(await bot.answer('📦 Склад')).toContain('Лента бот');
    expect(await bot.answer('💰 К выплате')).toMatch(/К выплате|никому/);
    expect(await bot.answer('🧵 Работы')).toMatch(/работ/);
    expect(await bot.answer('🖥 Сервер')).toContain('База данных: работает');
    expect(await bot.answer('привет')).toBeNull();
  });
});
