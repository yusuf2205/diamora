import * as db from '@yusmus/database';
import {
  ASSIGNMENT_STATUSES, COLLATERAL_STATUSES, COLLATERAL_TYPES, DELIVERY_STATUSES, DELIVERY_TYPES, JOB_REQUEST_STATUSES,
  LEDGER_TYPES, MATERIAL_UNITS, ROLES, STOCK_MOVEMENT_TYPES, WORKER_STATUSES,
} from '@yusmus/shared';
import { createTestApp, TestApp, uniquePhone, nextTelegramId } from './support/app';

describe('database guards: business invariants enforced by PostgreSQL itself', () => {
  let t: TestApp;
  beforeAll(async () => (t = await createTestApp()));
  afterAll(() => t.close());

  const worker = () =>
    t.prisma.workerProfile.create({ data: { telegramUserId: BigInt(nextTelegramId()), telegramChatId: 1n, code: `W-${Math.random().toString(36).slice(2, 8)}`, fullName: 'Guard Worker', phone: uniquePhone() } });
  const material = () => t.prisma.material.create({ data: { name: `Лента ${Math.random()}`, unit: 'METER' } });

  it('shared enums equal the Prisma enums (no drift between code and schema)', () => {
    const same = (p: Record<string, string>, s: readonly string[]) => expect(Object.values(p).sort()).toEqual([...s].sort());
    same(db.Role, ROLES);
    same(db.WorkerStatus, WORKER_STATUSES);
    same(db.CollateralType, COLLATERAL_TYPES);
    same(db.CollateralStatus, COLLATERAL_STATUSES);
    same(db.AssignmentStatus, ASSIGNMENT_STATUSES);
    same(db.DeliveryType, DELIVERY_TYPES);
    same(db.DeliveryStatus, DELIVERY_STATUSES);
    same(db.JobRequestStatus, JOB_REQUEST_STATUSES);
    same(db.LedgerType, LEDGER_TYPES);
    same(db.MaterialUnit, MATERIAL_UNITS);
    same(db.StockMovementType, STOCK_MOVEMENT_TYPES);
  });

  it('the cash ledger is append-only; corrections are CORRECTION rows; each row can be reversed once; zero rows are meaningless', async () => {
    const w = await worker();
    const earning = await t.prisma.workerLedgerTransaction.create({ data: { workerId: w.id, type: 'EARNING', amount: 450_000n, balanceAfter: 450_000n, createdById: w.id } });
    await expect(t.prisma.workerLedgerTransaction.update({ where: { id: earning.id }, data: { amount: 1n } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.workerLedgerTransaction.delete({ where: { id: earning.id } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.$executeRawUnsafe('TRUNCATE worker_ledger_transactions')).rejects.toThrow(/append-only/);
    await t.prisma.workerLedgerTransaction.create({ data: { workerId: w.id, type: 'CORRECTION', amount: -450_000n, balanceAfter: 0n, reversalOfId: earning.id, createdById: w.id } });
    await expect(t.prisma.workerLedgerTransaction.create({ data: { workerId: w.id, type: 'CORRECTION', amount: -450_000n, balanceAfter: -450_000n, reversalOfId: earning.id, createdById: w.id } })).rejects.toThrow(/Unique constraint/);
    await expect(t.prisma.workerLedgerTransaction.create({ data: { workerId: w.id, type: 'BONUS', amount: 0n, balanceAfter: 0n, createdById: w.id } })).rejects.toThrow();
    await expect(t.prisma.cashPayment.create({ data: { workerId: w.id, amount: 0n, paidById: w.id } })).rejects.toThrow();
  });

  it('ledger self-check: the materialised balance must equal Σ ledger', async () => {
    const w = await worker();
    await t.prisma.workerProfile.update({ where: { id: w.id }, data: { balance: 100n } });
    const q = () => t.prisma.$queryRaw<{ workerId: string }[]>`SELECT "workerId" FROM ledger_balance_mismatches WHERE "workerId" = ${w.id}::uuid`;
    expect(await q()).toHaveLength(1);
    await t.prisma.workerLedgerTransaction.create({ data: { workerId: w.id, type: 'EARNING', amount: 100n, balanceAfter: 100n, createdById: w.id } });
    expect(await q()).toHaveLength(0);
  });

  it('stock: never negative, movements are immutable, and worker holdings are derived from movements', async () => {
    const w = await worker();
    const m = await material();
    const bal = await t.prisma.stockBalance.create({ data: { materialId: m.id, quantity: 18 } });
    await expect(t.prisma.stockBalance.update({ where: { materialId: m.id }, data: { quantity: -1 } })).rejects.toThrow(/nonneg/);
    await expect(t.prisma.$executeRaw`UPDATE stock_balances SET quantity = quantity - 18.001 WHERE "materialId" = ${m.id}::uuid`).rejects.toThrow(/nonneg/);

    const group = crypto.randomUUID();
    const mv = await t.prisma.stockMovement.create({ data: { groupId: group, type: 'RECEIPT', materialId: m.id, quantity: 18, warehouseDelta: 18, performedById: w.id } });
    await expect(t.prisma.stockMovement.update({ where: { id: mv.id }, data: { quantity: 1 } })).rejects.toThrow(/append-only/);
    await expect(t.prisma.stockMovement.create({ data: { groupId: group, type: 'ADJUSTMENT_OUT', materialId: m.id, quantity: 0, warehouseDelta: 0, performedById: w.id } })).rejects.toThrow();
    // balance says 18, movements say 18 -> consistent; issue 9 to the worker
    await t.prisma.stockMovement.create({ data: { groupId: group, type: 'ISSUE_TO_WORKER', materialId: m.id, quantity: 9, warehouseDelta: 0, workerDelta: 9, workerId: w.id, performedById: w.id } });
    const holding = await t.prisma.$queryRaw<{ quantity: string }[]>`SELECT quantity FROM worker_material_holdings WHERE "workerId" = ${w.id}::uuid AND "materialId" = ${m.id}::uuid`;
    expect(Number(holding[0].quantity)).toBe(9);
    expect(bal.quantity.toNumber()).toBe(18);
    const mismatch = await t.prisma.$queryRaw<{ materialId: string }[]>`SELECT "materialId" FROM stock_balance_mismatches WHERE "materialId" = ${m.id}::uuid`;
    expect(mismatch).toHaveLength(0);
    await t.prisma.$executeRaw`UPDATE stock_balances SET quantity = 17 WHERE "materialId" = ${m.id}::uuid`;
    expect(await t.prisma.$queryRaw`SELECT 1 FROM stock_balance_mismatches WHERE "materialId" = ${m.id}::uuid`).toHaveLength(1);
    await t.prisma.$executeRaw`UPDATE stock_balances SET quantity = 18 WHERE "materialId" = ${m.id}::uuid`; // repair: the DB is shared with the integrity-job test
  });

  it('acceptedMeters + defectiveMeters can never exceed deliveredMeters; status history and audit log are immutable', async () => {
    const w = await worker();
    const model = await t.prisma.productModel.create({ data: { code: `ROSE-${Math.random()}`, name: 'Rose' } });
    const color = await t.prisma.color.create({ data: { name: `Gold ${Math.random()}` } });
    const variant = await t.prisma.productVariant.create({ data: { modelId: model.id, colorId: color.id, sku: `SKU-${Math.random()}` } });
    const a = await t.prisma.workAssignment.create({
      data: { code: `ASN-${Math.random()}`, workerId: w.id, productModelId: model.id, productVariantId: variant.id, colorId: color.id, kitCount: 2, plannedMeters: 18, createdById: w.id },
    });
    expect(a.settledRatePerKit).toBeNull(); // open work has no settled rate: it is paid at the current global rate (D-027)
    await expect(t.prisma.workAssignment.update({ where: { id: a.id }, data: { settledRatePerKit: 0n } })).rejects.toThrow(/money_sane/);
    await expect(t.prisma.workAssignment.update({ where: { id: a.id }, data: { deliveredMeters: 5, acceptedMeters: 6 } })).rejects.toThrow(/meters_consistent/);
    await expect(t.prisma.workAssignment.update({ where: { id: a.id }, data: { deliveredMeters: 5, acceptedMeters: 4, defectiveMeters: 2 } })).rejects.toThrow(/meters_consistent/);
    const ok = await t.prisma.workAssignment.update({ where: { id: a.id }, data: { deliveredMeters: 18, acceptedMeters: 16.5, defectiveMeters: 1.5 } });
    expect(ok.acceptedMeters.toString()).toBe('16.5');
    await expect(t.prisma.workAssignment.create({ data: { code: `ASN-${Math.random()}`, workerId: w.id, productModelId: model.id, productVariantId: variant.id, colorId: color.id, kitCount: 4, plannedMeters: 36, createdById: w.id } })).rejects.toThrow(/kit_count/);
    const h = await t.prisma.workAssignmentStatusHistory.create({ data: { assignmentId: a.id, toStatus: 'DRAFT', actor: 'ADMIN' } });
    await expect(t.prisma.workAssignmentStatusHistory.update({ where: { id: h.id }, data: { toStatus: 'COMPLETED' } })).rejects.toThrow(/append-only/);
    const log = await t.prisma.auditLog.create({ data: { action: 'test', entity: 'Test' } });
    await expect(t.prisma.auditLog.delete({ where: { id: log.id } })).rejects.toThrow(/append-only/);
  });

  it('unique identities: one phone, one Telegram account, one worker code', async () => {
    const w = await worker();
    await expect(t.prisma.workerProfile.create({ data: { telegramUserId: BigInt(nextTelegramId()), telegramChatId: 1n, code: 'W-X1', fullName: 'Dup', phone: w.phone } })).rejects.toThrow(/Unique constraint/);
    await expect(t.prisma.workerProfile.create({ data: { telegramUserId: w.telegramUserId, telegramChatId: 1n, code: 'W-X2', fullName: 'Dup', phone: uniquePhone() } })).rejects.toThrow(/Unique constraint/);
    await expect(t.prisma.workerProfile.update({ where: { id: w.id }, data: { latitude: 123 } })).rejects.toThrow(/gps_range|out of range|overflow/i);
  });
});
