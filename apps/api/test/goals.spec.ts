import { GoalsService } from '../src/goals/goals.service';
import { AppNotifier } from '../src/notifications/app-notifier';
import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** «Цель месяца» (no money): the goal, progress, her place and badges; a personal goal overrides the common one. */
describe('goals', () => {
  let t: TestApp;
  beforeAll(async () => { t = await createTestApp(); });
  afterAll(async () => { await t.close(); });

  async function accepted(workerId: string, staffId: string, meters: number, defective = 0) {
    const model = await t.prisma.productModel.create({ data: { code: `G-${Math.random()}`, name: 'Лента' } });
    const color = await t.prisma.color.create({ data: { name: `Цвет ${Math.random()}` } });
    const variant = await t.prisma.productVariant.create({ data: { modelId: model.id, colorId: color.id, sku: `SKU-${Math.random()}` } });
    const a = await t.prisma.workAssignment.create({
      data: { code: `ASN-${Math.random()}`, workerId, productModelId: model.id, productVariantId: variant.id, colorId: color.id, kitCount: 1, plannedMeters: meters + defective, createdById: staffId, status: 'COMPLETED' },
    });
    await t.prisma.qualityInspection.create({ data: { assignmentId: a.id, inspectorId: staffId, result: 'ACCEPTED', broughtMeters: meters + defective, acceptedMeters: meters, defectiveMeters: defective } });
  }

  it('the worker sees her goal, what is left, her place and badges; a personal goal wins; managers cannot change the common goal', async () => {
    const admin = await superAdminActor(t);
    const staffId = (await t.prisma.user.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } })).id;
    const a = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const b = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);

    // no goal yet: progress and badges still work
    const none = (await a.api.get('/v1/work/goal').expect(200)).body;
    expect(none).toMatchObject({ goalMeters: 0, leftMeters: null, percent: null, doneMeters: 0, place: null });

    await admin.api.put('/v1/admin/goals', { monthlyMeters: 90 }).expect(200);
    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.put('/v1/admin/goals', { monthlyMeters: 1 }).expect(403);

    await accepted(a.workerId, staffId, 27);
    await accepted(b.workerId, staffId, 99, 0);
    const g = (await a.api.get('/v1/work/goal').expect(200)).body;
    expect(g).toMatchObject({ goalMeters: 90, personal: false, doneMeters: 27, leftMeters: 63, percent: 30 });
    expect(g.place).toBeGreaterThan(1); // b made more
    expect(g.badges.find((x: { code: string }) => x.code === 'first_kit').earned).toBe(true);
    expect(g.badges.find((x: { code: string }) => x.code === 'm100').earned).toBe(false);
    expect(g.badges.find((x: { code: string }) => x.code === 'no_defects').earned).toBe(true);

    // a personal goal for her; null brings back the common one
    await admin.api.put(`/v1/admin/workers/${a.workerId}/goal`, { monthlyMeters: 27 }).expect(200);
    const mine = (await a.api.get('/v1/work/goal').expect(200)).body;
    expect(mine).toMatchObject({ goalMeters: 27, personal: true, leftMeters: 0, percent: 100 });
    expect(mine.badges.find((x: { code: string }) => x.code === 'goal').earned).toBe(true);

    // «Цель месяца выполнена!» - once
    const notifier = t.app.get(AppNotifier);
    const svc = t.app.get(GoalsService);
    await svc.congratulate(notifier);
    await svc.congratulate(notifier);
    const user = await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: a.workerId }, select: { userId: true } });
    expect(await t.prisma.notification.count({ where: { userId: user.userId!, type: 'goal.reached' } })).toBe(1);

    await admin.api.put(`/v1/admin/workers/${a.workerId}/goal`, { monthlyMeters: null }).expect(200);
    expect((await a.api.get('/v1/work/goal').expect(200)).body).toMatchObject({ goalMeters: 90, personal: false });
    await a.api.get('/v1/admin/goals').expect(403); // a worker never reads staff settings
  });
});
