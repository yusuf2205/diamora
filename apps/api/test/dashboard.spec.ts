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
});
