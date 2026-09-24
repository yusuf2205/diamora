import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('dashboard (§31): real numbers only from tables that exist today, honest nulls for M6 finance', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('SUPER_ADMIN sees every section, with real numbers matching the database', async () => {
    const superAdmin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    const model = await t.prisma.productModel.create({ data: { code: `DASH-${Math.random()}`, name: 'X', status: 'PUBLISHED' } });

    const res = await superAdmin.api.get('/v1/dashboard').expect(200);
    expect(res.body.workers.total).toBeGreaterThanOrEqual(1);
    expect(res.body.workers.active).toBeGreaterThanOrEqual(1);
    expect(res.body.workers).toHaveProperty('withActiveAssignment');
    expect(res.body.workers).toHaveProperty('withoutActiveAssignment');
    expect(res.body.users.superAdmins).toBeGreaterThanOrEqual(1);
    expect(res.body.catalog.published).toBeGreaterThanOrEqual(1);
    expect(res.body.work).toMatchObject({ activeAssignments: expect.any(Number), inProgress: expect.any(Number), needsAcceptance: expect.any(Number), completed: expect.any(Number) });
    expect(res.body.finance).toMatchObject({ salesRevenue: null, expenses: null, netProfit: null }); // M6 not built: honest, not fabricated
    expect(typeof res.body.finance.due).toBe('string'); // money as a decimal string
    expect(res.body.materials).toMatchObject({ lowStock: expect.any(Number), outOfStock: expect.any(Number) });

    await t.prisma.productModel.delete({ where: { id: model.id } }); // the test DB is shared across spec files in a run: leave no residue
  });

  it('a plain WORKER cannot read the dashboard', async () => {
    const superAdmin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await worker.api.get('/v1/dashboard').expect(403);
  });

  it('a MANAGER with only the default _ASSIGNED permissions sees a scoped dashboard, not a 403', async () => {
    const manager = await staffActor(t, 'MANAGER');
    const res = await manager.api.get('/v1/dashboard').expect(200);
    // in scope for a MANAGER (WORKER_VIEW_ASSIGNED / ASSIGNMENT_VIEW_ASSIGNED / FINANCE_VIEW_ASSIGNED by default):
    expect(res.body.workers).not.toBeNull();
    expect(res.body.work).not.toBeNull();
    expect(res.body.finance).not.toBeNull();
    // out of scope: no USER_VIEW_ALL / CATALOG_VIEW / INVENTORY_VIEW by default:
    expect(res.body.users).toBeNull();
    expect(res.body.catalog).toBeNull();
    expect(res.body.materials).toBeNull();
  });

  it("a MANAGER's numbers only cover their own workers, never another manager's", async () => {
    const superAdmin = await superAdminActor(t);
    const managerA = await staffActor(t, 'MANAGER');
    const managerB = await staffActor(t, 'MANAGER');
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await t.prisma.workerProfile.update({ where: { id: worker.workerId }, data: { assignedManagerId: managerA.user.id } });

    const [resA, resB] = await Promise.all([managerA.api.get('/v1/dashboard').expect(200), managerB.api.get('/v1/dashboard').expect(200)]);
    expect(resA.body.workers.total).toBeGreaterThanOrEqual(1);
    expect(resB.body.workers.total).toBe(0);
  });

  it('"today" and "attention" numbers come from real rows: a delivery completed today counts, a deadline today counts', async () => {
    const admin = await superAdminActor(t);
    const manager = await staffActor(t, 'MANAGER'); // scoped to exactly one worker -> numbers are isolated from other tests
    const reg = await registerViaBot(t);
    const { workerId } = await approveAndLoginWorker(t, admin.api, reg.phone);
    await admin.api.post(`/v1/workers/${workerId}/manager`, { managerId: manager.user.id }).expect(201);

    const tape = await admin.api.post('/v1/admin/materials', { name: `DashTape ${reg.tgId}`, unit: 'METER', minStock: '0' }).expect(201);
    await admin.api.post('/v1/admin/stock/receipt', { materialId: tape.body.id, quantity: '100', comment: 'setup' }).expect(201);
    const kit = await admin.api.post('/v1/admin/kits', { name: `DashKit ${reg.tgId}`, ribbonMeters: 9, items: [{ materialId: tape.body.id, requiredQuantity: '9' }] }).expect(201);
    const color = await admin.api.post('/v1/admin/colors', { name: `DashColor ${reg.tgId}` }).expect(201);
    const item = await admin.api.post('/v1/admin/catalog', { name: `DashModel ${reg.tgId}` }).expect(201);
    const withVariant = await admin.api.post(`/v1/admin/catalog/${item.body.id}/variants`, { colorId: color.body.id }).expect(201);
    const variant = (withVariant.body.variants as { id: string; color: { id: string } }[]).find((v) => v.color.id === color.body.id)!;

    // a deadline later TODAY in Tashkent time (never tomorrow, even if the suite runs just before midnight)
    const offset = 5 * 3600_000;
    const endOfDay = Math.floor((Date.now() + offset) / 86_400_000) * 86_400_000 + 86_400_000 - offset;
    const dueAt = new Date(Math.min(Date.now() + 3600_000, endOfDay - 60_000)).toISOString();

    const before = (await manager.api.get('/v1/dashboard').expect(200)).body;
    expect(before.today).toMatchObject({ dueToday: 0, deliveredToday: 0, pickedUpToday: 0, paidToday: '0' });
    expect(before.work.reworkRequired).toBe(0);
    expect(before.finance.workersDue).toBe(0);

    const created = await admin.api.post('/v1/admin/assignments', {
      workerId, productModelId: item.body.id, productVariantId: variant.id, colorId: color.body.id, materialKitTemplateId: kit.body.id, kitCount: 1, dueAt,
    }).expect(201);
    await admin.api.post(`/v1/admin/assignments/${created.body.id}/deliver`, {}).expect(200);

    const after = (await manager.api.get('/v1/dashboard').expect(200)).body;
    expect(after.today.dueToday).toBe(1);
    expect(after.today.deliveredToday).toBe(1);
    expect(after.today.pickedUpToday).toBe(0);
  });
});
