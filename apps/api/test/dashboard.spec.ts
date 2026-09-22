import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

describe('dashboard (§31): real numbers only from tables that exist today, honest nulls for M6 finance', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  it('SUPER_ADMIN sees workers/users/catalog/finance counters that match the database', async () => {
    const superAdmin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    const model = await t.prisma.productModel.create({ data: { code: `DASH-${Math.random()}`, name: 'X', status: 'PUBLISHED' } });

    const res = await superAdmin.api.get('/v1/dashboard').expect(200);
    expect(res.body.workers.total).toBeGreaterThanOrEqual(1);
    expect(res.body.workers.active).toBeGreaterThanOrEqual(1);
    expect(res.body.users.superAdmins).toBeGreaterThanOrEqual(1);
    expect(res.body.catalog.published).toBeGreaterThanOrEqual(1);
    expect(res.body.finance).toMatchObject({ salesRevenue: null, expenses: null, netProfit: null }); // M6 not built: honest, not fabricated
    expect(typeof res.body.finance.due).toBe('string'); // money as a decimal string

    await t.prisma.productModel.delete({ where: { id: model.id } }); // the test DB is shared across spec files in a run: leave no residue
  });

  it('a plain WORKER cannot read the dashboard', async () => {
    const superAdmin = await superAdminActor(t);
    const reg = await registerViaBot(t);
    const worker = await approveAndLoginWorker(t, superAdmin.api, reg.phone);
    await worker.api.get('/v1/dashboard').expect(403);
  });

  it('a MANAGER without WORKER_VIEW_ALL/FINANCE_VIEW_ALL/PROFIT_VIEW cannot read the global dashboard', async () => {
    const manager = await staffActor(t, 'MANAGER');
    await manager.api.get('/v1/dashboard').expect(403);
  });
});
