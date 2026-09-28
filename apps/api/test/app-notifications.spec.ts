import { AppNotifier } from '../src/notifications/app-notifier';
import { approveAndLoginWorker, createTestApp, handOver, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** Everything arrives in the APP (bell), to exactly the right people, never duplicated. */
async function setup(t: TestApp) {
  const admin = await superAdminActor(t);
  const reg = await registerViaBot(t);
  const { workerId, api: workerApi } = await approveAndLoginWorker(t, admin.api, reg.phone);
  const tape = await admin.api.post('/v1/admin/materials', { name: `NTape ${reg.tgId}`, unit: 'METER', minStock: '50' }).expect(201);
  await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
  const kit = await admin.api.post('/v1/admin/kits', { name: `NKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
  const color = await admin.api.post('/v1/admin/colors', { name: `NColor ${reg.tgId}` }).expect(201);
  const item = await admin.api.post('/v1/admin/catalog', { name: `NModel ${reg.tgId}` }).expect(201);
  const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
  const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v) => v.color.id === color.body.id)!;
  const body = (extra: object = {}) => ({ workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 1, ...extra });
  return { admin, workerId, workerApi, tape: tape.body, body, modelName: item.body.name as string };
}

type Api = { get: (p: string) => { expect: (s: number) => Promise<{ body: { items: { title: string }[] } }> } };
/** notices are written right AFTER the action (never slowing it down): give them a moment to land */
const settle = () => new Promise((r) => setTimeout(r, 300));
const titles = async (api: Api) => {
  await settle();
  return (await api.get('/v1/me/notifications').expect(200)).body.items.map((n) => n.title);
};

describe('in-app notifications (instead of Telegram)', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('worker: new work, handoff, acceptance, payout — in her bell; read marks clear the badge', async () => {
    const f = await setup(t);
    const created = await f.admin.api.post('/v1/admin/assignments', f.body()).expect(201);
    await handOver(f.admin.api, f.workerApi, created.body.id);
    await f.workerApi.post(`/v1/work/${created.body.id}/ready`, { readyMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${created.body.id}/pickup`, {}).expect(200);
    await f.admin.api.post(`/v1/admin/assignments/${created.body.id}/accept`, { broughtMeters: '9', acceptedMeters: '9' }).expect(200);
    await f.admin.api.post(`/v1/admin/workers/${f.workerId}/payout`, { amount: '10000' }).expect(200);

    await settle();
    const bell = await f.workerApi.get('/v1/me/notifications').expect(200);
    const got = bell.body.items.map((n: { title: string }) => n.title);
    expect(got).toEqual(expect.arrayContaining(['Вас ожидает новая работа', 'Сотрудник передаёт вам комплект', 'Работу приняли', 'Вам выплатили 10 000 сум']));
    expect(bell.body.unread).toBe(got.length);
    const read = await f.workerApi.post('/v1/me/notifications/read', { all: true }).expect(200);
    expect(read.body.unread).toBe(0);
    // nothing of this went to Telegram
    expect(await t.prisma.notification.count({ where: { channel: 'TELEGRAM', workerId: f.workerId, type: { not: 'worker.approved' } } })).toBe(0);
  });

  it('staff: «работа готова» reaches her own manager and the admins, never a foreign manager', async () => {
    const f = await setup(t);
    const own = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    const foreign = await staffActor(t, 'MANAGER', ['ASSIGNMENT_VIEW_ASSIGNED']);
    await f.admin.api.post(`/v1/workers/${f.workerId}/manager`, { managerId: own.user.id }).expect(201);
    const created = await f.admin.api.post('/v1/admin/assignments', f.body()).expect(201);
    await handOver(f.admin.api, f.workerApi, created.body.id);
    await f.workerApi.post(`/v1/work/${created.body.id}/ready`, { readyMeters: '9' }).expect(200);

    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: f.workerId } });
    expect(await titles(own.api)).toContain(`${w.fullName}: работа готова`);
    expect(await titles(f.admin.api)).toContain(`${w.fullName}: работа готова`);
    expect((await titles(foreign.api)).some((x) => x.includes(w.fullName))).toBe(false);
    // a worker never sees staff notices
    expect((await titles(f.workerApi)).some((x) => x.includes('работа готова'))).toBe(false);
  });

  it('«материал заканчивается»: inventory people get it once a day per material, workers never', async () => {
    const f = await setup(t);
    await f.admin.api.post('/v1/admin/stock/write-off', { materialId: f.tape.id, quantity: '60', reason: 'test' }).expect(201); // 40 < min 50
    await settle();
    await f.admin.api.post('/v1/admin/stock/write-off', { materialId: f.tape.id, quantity: '1', reason: 'test' }).expect(201); // still low: no second notice today
    const low = (await titles(f.admin.api)).filter((x) => x === `Заканчивается: ${f.tape.name}`);
    expect(low).toHaveLength(1);
    expect((await titles(f.workerApi)).some((x) => x.startsWith('Заканчивается'))).toBe(false);
  });

  it('deadlines (worker, once each), overdue (staff) and the evening summary (owner) come from tick(), idempotent', async () => {
    const f = await setup(t);
    const notifier = t.app.get(AppNotifier);
    const now = new Date('2026-10-10T16:00:00Z'); // 21:00 in Tashkent
    const tomorrowNoon = new Date('2026-10-11T07:00:00Z');
    const a1 = await f.admin.api.post('/v1/admin/assignments', f.body({ dueAt: tomorrowNoon.toISOString() })).expect(201);
    await handOver(f.admin.api, f.workerApi, a1.body.id);
    await notifier.tick(now);
    await notifier.tick(now); // twice: still one notice
    expect((await titles(f.workerApi)).filter((x) => x === 'Завтра срок сдачи')).toHaveLength(1);

    await notifier.tick(new Date('2026-10-11T03:00:00Z')); // 08:00 on the due day
    expect(await titles(f.workerApi)).toContain('Сегодня срок сдачи');

    await notifier.tick(new Date('2026-10-12T05:00:00Z')); // a day late
    const w = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: f.workerId } });
    expect(await titles(f.admin.api)).toContain(`Просрочена работа: ${w.fullName}`);

    expect((await titles(f.admin.api)).filter((x) => x === 'Итоги дня').length).toBeGreaterThanOrEqual(1);
    expect((await titles(f.workerApi)).includes('Итоги дня')).toBe(false);
  });
});
