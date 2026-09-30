import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { approveAndLoginWorker, createTestApp, registerViaBot, staffActor, superAdminActor, TestApp } from './support/app';

/** Owner's analytics: rating, profit (sales / expenses / materials at purchase price), stock value, system status, map. */
describe('insights', () => {
  let t: TestApp;
  const statusDir = mkdtempSync(join(tmpdir(), 'backup-status-'));
  beforeAll(async () => {
    writeFileSync(join(statusDir, 'pg-dump.status'), `ok ${Math.floor(Date.now() / 1000)} 123456\n`);
    t = await createTestApp({ BACKUP_STATUS_DIR: statusDir, APP_VERSION: '1.0.0-test' });
  });
  afterAll(() => t.close());

  async function workFor(workerId: string, userId: string, opts: { accepted: number; defective: number; dueDaysAgo?: number; status?: string }) {
    const model = await t.prisma.productModel.create({ data: { code: `IN-${Math.random()}`, name: 'Лента' } });
    const color = await t.prisma.color.create({ data: { name: `Цвет ${Math.random()}` } });
    const variant = await t.prisma.productVariant.create({ data: { modelId: model.id, colorId: color.id, sku: `SKU-${Math.random()}` } });
    const a = await t.prisma.workAssignment.create({
      data: {
        code: `ASN-${Math.random()}`, workerId, productModelId: model.id, productVariantId: variant.id, colorId: color.id, kitCount: 1, plannedMeters: 9,
        createdById: userId, status: (opts.status ?? 'COMPLETED') as never, dueAt: opts.dueDaysAgo !== undefined ? new Date(Date.now() - opts.dueDaysAgo * 86_400_000) : null,
      },
    });
    if (opts.accepted + opts.defective > 0) {
      await t.prisma.qualityInspection.create({ data: { assignmentId: a.id, inspectorId: userId, result: 'ACCEPTED', broughtMeters: opts.accepted + opts.defective, acceptedMeters: opts.accepted, defectiveMeters: opts.defective } });
    }
    return a;
  }

  it('rating: more metres and fewer defects rank higher; a missed deadline counts as late', async () => {
    const admin = await superAdminActor(t);
    const good = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const weak = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const staffId = (await t.prisma.user.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } })).id;
    await workFor(good.workerId, staffId, { accepted: 54, defective: 0 });
    await workFor(weak.workerId, staffId, { accepted: 9, defective: 9 });
    await workFor(weak.workerId, staffId, { accepted: 0, defective: 0, dueDaysAgo: 2, status: 'IN_PROGRESS' });

    const res = await admin.api.get('/v1/admin/reports/rating?months=1').expect(200);
    const items = res.body.items as { worker: { id: string }; score: number; defectRate: number; late: number }[];
    const g = items.findIndex((i) => i.worker.id === good.workerId);
    const w = items.findIndex((i) => i.worker.id === weak.workerId);
    expect(g).toBeLessThan(w);
    expect(items[w].defectRate).toBe(50);
    expect(items[w].late).toBe(1);
  });

  it('profit: sales − earnings − materials (purchase price) − expenses; sales and expenses need PROFIT_VIEW', async () => {
    const admin = await superAdminActor(t);
    const before = (await admin.api.get('/v1/admin/finance/profit?months=1').expect(200)).body.items[0];
    await admin.api.post('/v1/admin/finance/sales', { total: '1000000', customer: 'Магазин' }).expect(201);
    await admin.api.post('/v1/admin/finance/expenses', { category: 'DELIVERY_FUEL', amount: '50000' }).expect(201);
    const m = (await admin.api.post('/v1/admin/materials', { name: `Лента цена ${Math.random()}`, unit: 'METER', unitCost: '2000' }).expect(201)).body;
    expect(m.unitCost).toBe('2000');
    await admin.api.post('/v1/admin/stock/receipt', { materialId: m.id, quantity: '10' }).expect(201);
    await admin.api.post('/v1/admin/stock/write-off', { materialId: m.id, quantity: '3', reason: 'брак' }).expect(201);

    const after = (await admin.api.get('/v1/admin/finance/profit?months=1').expect(200)).body.items[0];
    expect(BigInt(after.sales) - BigInt(before.sales)).toBe(1000000n);
    expect(BigInt(after.expenses) - BigInt(before.expenses)).toBe(50000n);
    expect(BigInt(after.materials) - BigInt(before.materials)).toBe(6000n);
    expect(BigInt(after.profit)).toBe(BigInt(after.sales) - BigInt(after.labor) - BigInt(after.materials) - BigInt(after.expenses));

    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.get('/v1/admin/finance/profit').expect(403);
    await mgr.api.post('/v1/admin/finance/sales', { total: '1' }).expect(403);

    const sale = (await admin.api.get('/v1/admin/finance/sales').expect(200)).body.items[0];
    await admin.api.delete(`/v1/admin/finance/sales/${sale.id}`).expect(200);
  });

  it('cost & profit per product: (materials at purchase price + what workers earned) per accepted metre vs the sale price per metre', async () => {
    const admin = await superAdminActor(t);
    const w = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const staffId = (await t.prisma.user.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } })).id;
    const a = await workFor(w.workerId, staffId, { accepted: 18, defective: 0 });
    await t.prisma.workAssignment.update({ where: { id: a.id }, data: { reportedMeters: 18, deliveredMeters: 18, acceptedMeters: 18 } });
    const priced = await t.prisma.material.create({ data: { name: `Лента ${Math.random()}`, unit: 'METER', unitCost: 1000n } });
    const unpriced = await t.prisma.material.create({ data: { name: `Бусины ${Math.random()}`, unit: 'PCS' } });
    await t.prisma.workAssignmentMaterial.createMany({ data: [{ assignmentId: a.id, materialId: priced.id, quantity: 20 }, { assignmentId: a.id, materialId: unpriced.id, quantity: 5 }] });
    // an earning written the way the ledger does it: the row AND the worker's balance (the integrity check compares them)
    const bal = (await t.prisma.workerProfile.findUniqueOrThrow({ where: { id: w.workerId }, select: { balance: true } })).balance + 60000n;
    await t.prisma.workerLedgerTransaction.create({ data: { workerId: w.workerId, assignmentId: a.id, type: 'EARNING', amount: 60000n, balanceAfter: bal, createdById: staffId } });
    await t.prisma.workerProfile.update({ where: { id: w.workerId }, data: { balance: bal } });

    // a sale with what was sold: the total is the sum of the lines
    const sale = (await admin.api.post('/v1/admin/finance/sales', { total: '1', customer: 'Магазин', items: [{ productModelId: a.productModelId, quantity: 18, unitPrice: '10000' }] }).expect(201)).body;
    const listed = (await admin.api.get('/v1/admin/finance/sales').expect(200)).body.items.find((x: { id: string }) => x.id === sale.id);
    expect(listed.total).toBe('180000');
    expect(listed.lines).toEqual([expect.objectContaining({ quantity: 18, unitPrice: '10000', total: '180000' })]);

    const row = (await admin.api.get('/v1/admin/finance/products?months=1').expect(200)).body.items.find((x: { productId: string }) => x.productId === a.productModelId);
    expect(row).toMatchObject({ meters: 18, labor: 60000, materials: 20000, cost: 80000, costPerMeter: 4444, pricePerMeter: 10000, profitPerMeter: 5556, marginPercent: 56, materialsWithoutPrice: 1 });
    const mgr = await staffActor(t, 'MANAGER');
    await mgr.api.get('/v1/admin/finance/products').expect(403);
    await admin.api.post('/v1/admin/finance/sales', { total: '1', items: [{ productModelId: '00000000-0000-4000-8000-000000000000', quantity: 1, unitPrice: '1' }] }).expect(404);
  });

  it('stock value: shelf + at workers, at purchase price; materials without a price are listed', async () => {
    const admin = await superAdminActor(t);
    const before = (await admin.api.get('/v1/admin/stock/value').expect(200)).body;
    const priced = (await admin.api.post('/v1/admin/materials', { name: `Бусины ${Math.random()}`, unit: 'PCS', unitCost: '500' }).expect(201)).body.id;
    await admin.api.post('/v1/admin/stock/receipt', { materialId: priced, quantity: '4' }).expect(201);
    const unpriced = (await admin.api.post('/v1/admin/materials', { name: `Без цены ${Math.random()}`, unit: 'PCS' }).expect(201)).body.id;
    const after = (await admin.api.get('/v1/admin/stock/value').expect(200)).body;
    expect(BigInt(after.warehouse) - BigInt(before.warehouse)).toBe(2000n);
    expect(after.withoutPrice.map((m: { id: string }) => m.id)).toContain(unpriced);
  });

  it('system status: SUPER_ADMIN sees database/redis and when each backup last succeeded; a plain ADMIN does not', async () => {
    const admin = await superAdminActor(t);
    const res = await admin.api.get('/v1/admin/system/status').expect(200);
    expect(res.body.database.ok).toBe(true);
    expect(res.body.version).toBe('1.0.0-test');
    expect(res.body.backupsVisible).toBe(true);
    expect(res.body.backups).toEqual([expect.objectContaining({ job: 'pg-dump', ok: true, bytes: 123456 })]);
    const plain = await staffActor(t, 'ADMIN');
    await plain.api.get('/v1/admin/system/status').expect(403);
  });

  it('map: a worker without a live position shows at her home with what is waiting there (for the filters)', async () => {
    const admin = await superAdminActor(t);
    const w = await approveAndLoginWorker(t, admin.api, (await registerViaBot(t)).phone);
    const staffId = (await t.prisma.user.findFirstOrThrow({ where: { role: 'SUPER_ADMIN' } })).id;
    await workFor(w.workerId, staffId, { accepted: 0, defective: 0, status: 'READY_TO_DELIVER' });
    const res = await admin.api.get('/v1/locations').expect(200);
    const home = (res.body.homes as { worker: { id: string }; work: { toDeliver: boolean } }[]).find((h) => h.worker.id === w.workerId);
    expect(home?.work.toDeliver).toBe(true);
  });
});
