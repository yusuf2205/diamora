import { Controller, Delete, Get, HttpCode, Inject, Injectable, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { createExpenseSchema, createSaleSchema, insightsMonthsSchema } from '@diamoraa/shared';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, Authenticated, CurrentUser, Perm } from '../common/decorators';
import { forbidden, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { can, workerScope } from '../common/scope';
import { nextCode } from '../common/sequence';
import { money } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { ENV, type Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { RedisService } from '../redis/redis.module';
import { periodRange } from '../reports/reports.service';

const TASHKENT_MS = 5 * 3600_000;
const monthKey = (from: Date) => { const d = new Date(from.getTime() + TASHKENT_MS); return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`; };
const OPEN = ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'REWORK_REQUIRED'] as const;

/**
 * Owner's analytics: «Рейтинг мастериц», «Прибыль» (with the sales and expenses it needs), «Стоимость склада» and
 * «Состояние системы». Everything is computed in PostgreSQL (aggregates / one grouped SQL), never row by row in Node.
 */
@Injectable()
export class InsightsService {
  constructor(
    private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly redis: RedisService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // ---- «Рейтинг мастериц» ---------------------------------------------------------------------------------------------
  /** Per worker, for the last N months: metres accepted, defect %, finished works, how many were late. Best first. */
  async rating(actor: AuthUser, months: number) {
    const { where: scope } = workerScope(actor, 'WORKER');
    const from = periodRange('month', -(months - 1)).from;
    const workers = await this.prisma.workerProfile.findMany({ where: { ...scope, deletedAt: null, status: { in: ['ACTIVE', 'PAUSED'] } }, select: { id: true, code: true, fullName: true } });
    if (!workers.length) return { months, from: from.toISOString(), items: [] };
    const ids = workers.map((w) => w.id);
    const [quality, late] = await Promise.all([
      this.prisma.$queryRaw<{ workerId: string; accepted: string; defective: string; works: bigint }[]>`
        SELECT a."workerId", COALESCE(SUM(q."acceptedMeters"), 0)::text AS accepted, COALESCE(SUM(q."defectiveMeters"), 0)::text AS defective,
               COUNT(DISTINCT q."assignmentId") AS works
        FROM quality_inspections q JOIN work_assignments a ON a.id = q."assignmentId"
        WHERE q."inspectedAt" >= ${from} AND a."workerId" = ANY(${ids}::uuid[])
        GROUP BY a."workerId"`,
      // late = ready after the deadline, or still not ready and the deadline has passed
      this.prisma.$queryRaw<{ workerId: string; late: bigint; withDeadline: bigint }[]>`
        SELECT a."workerId",
               COUNT(*) FILTER (WHERE COALESCE(r.ready_at, CASE WHEN a.status::text = ANY(${[...OPEN]}::text[]) THEN now() END) > a."dueAt") AS late,
               COUNT(*) AS "withDeadline"
        FROM work_assignments a
        LEFT JOIN LATERAL (SELECT MIN(h."changedAt") AS ready_at FROM work_assignment_status_history h
                           WHERE h."assignmentId" = a.id AND h."toStatus" = 'READY_FOR_PICKUP') r ON true
        WHERE a."dueAt" IS NOT NULL AND a."createdAt" >= ${from} AND a.status <> 'CANCELLED' AND a."workerId" = ANY(${ids}::uuid[])
        GROUP BY a."workerId"`,
    ]);
    const q = new Map(quality.map((r) => [r.workerId, r]));
    const l = new Map(late.map((r) => [r.workerId, r]));
    const items = workers.map((w) => {
      const accepted = Number(q.get(w.id)?.accepted ?? 0);
      const defective = Number(q.get(w.id)?.defective ?? 0);
      const lateCount = Number(l.get(w.id)?.late ?? 0);
      const withDeadline = Number(l.get(w.id)?.withDeadline ?? 0);
      const defectRate = accepted + defective > 0 ? defective / (accepted + defective) : 0;
      const onTimeRate = withDeadline > 0 ? 1 - lateCount / withDeadline : 1;
      // one simple, explainable score (0–100): volume matters, but defects and lateness cost points
      const volume = Math.min(1, accepted / (54 * months)); // ~6 kits (54 m) a month = full marks for volume
      const score = Math.round(100 * (0.4 * volume + 0.35 * (1 - defectRate) + 0.25 * onTimeRate) * (accepted > 0 ? 1 : 0.5));
      return {
        worker: w, acceptedMeters: accepted, defectiveMeters: defective, defectRate: Math.round(defectRate * 1000) / 10,
        works: Number(q.get(w.id)?.works ?? 0n), late: lateCount, withDeadline, score,
      };
    }).sort((a, b) => b.score - a.score || b.acceptedMeters - a.acceptedMeters);
    return { months, from: from.toISOString(), items };
  }

  // ---- «Прибыль» ----------------------------------------------------------------------------------------------------------
  /**
   * Per month: sales − work paid for (accrued earnings) − materials used (at purchase price) − expenses = profit.
   * Materials used = what left the warehouse for work (ISSUE_TO_KIT) and write-offs, valued at the material's price.
   */
  async profit(months: number) {
    const out = [];
    for (let i = 0; i > -months; i--) {
      const { from, to } = periodRange('month', i);
      const [sales, labor, materials, expenses, noCost] = await Promise.all([
        this.prisma.sale.aggregate({ where: { date: { gte: from, lt: to } }, _sum: { total: true } }),
        this.prisma.workerLedgerTransaction.aggregate({ where: { type: 'EARNING', createdAt: { gte: from, lt: to } }, _sum: { amount: true } }),
        this.prisma.$queryRaw<{ cost: string | null }[]>`
          SELECT SUM(ABS(s."warehouseDelta") * m."unitCost")::text AS cost FROM stock_movements s JOIN materials m ON m.id = s."materialId"
          WHERE s."createdAt" >= ${from} AND s."createdAt" < ${to} AND s.type IN ('ISSUE_TO_KIT', 'WRITE_OFF') AND s."warehouseDelta" < 0`,
        this.prisma.expense.aggregate({ where: { date: { gte: from, lt: to } }, _sum: { amount: true } }),
        this.prisma.$queryRaw<{ n: bigint }[]>`
          SELECT COUNT(DISTINCT s."materialId") AS n FROM stock_movements s JOIN materials m ON m.id = s."materialId"
          WHERE s."createdAt" >= ${from} AND s."createdAt" < ${to} AND s.type IN ('ISSUE_TO_KIT', 'WRITE_OFF') AND m."unitCost" IS NULL`,
      ]);
      const s = sales._sum.total ?? 0n;
      const w = labor._sum.amount ?? 0n;
      const m = BigInt(Math.round(Number(materials[0]?.cost ?? 0)));
      const e = expenses._sum.amount ?? 0n;
      out.push({
        month: monthKey(from), sales: money(s)!, labor: money(w)!, materials: money(m)!, expenses: money(e)!, profit: money(s - w - m - e)!,
        materialsWithoutPrice: Number(noCost[0]?.n ?? 0n),
      });
    }
    return { items: out };
  }

  /**
   * «Себестоимость и прибыль по изделиям», computed from what really happened (no typing): for work accepted in the last
   * N months - its materials at purchase price + what the workers earned for it, per accepted metre; against the average
   * price per metre of that product in the sales of the same period. «Цена материалов не указана» when some materials of
   * that work have no purchase price (the cost is then too low).
   */
  async products(months: number) {
    const { from } = periodRange('month', -(months - 1));
    const rows = await this.prisma.$queryRaw<{ id: string; name: string; meters: string | null; labor: string | null; materials: string | null; noPrice: bigint | null; soldQty: string | null; revenue: string | null }[]>`
      WITH acc AS (
        SELECT DISTINCT l."assignmentId" AS id FROM worker_ledger_transactions l
        WHERE l.type = 'EARNING' AND l."assignmentId" IS NOT NULL AND l."createdAt" >= ${from}
      ),
      met AS (SELECT w."productModelId" AS pm, SUM(w."acceptedMeters") AS meters FROM work_assignments w JOIN acc ON acc.id = w.id GROUP BY 1),
      lab AS (
        SELECT w."productModelId" AS pm, SUM(l.amount) AS labor FROM worker_ledger_transactions l JOIN work_assignments w ON w.id = l."assignmentId"
        WHERE l.type = 'EARNING' AND l."createdAt" >= ${from} GROUP BY 1
      ),
      mat AS (
        SELECT w."productModelId" AS pm, SUM(x.quantity * m."unitCost") AS cost, COUNT(*) FILTER (WHERE m."unitCost" IS NULL) AS "noPrice"
        FROM work_assignment_materials x JOIN acc ON acc.id = x."assignmentId" JOIN work_assignments w ON w.id = x."assignmentId" JOIN materials m ON m.id = x."materialId"
        GROUP BY 1
      ),
      sold AS (
        SELECT si."productModelId" AS pm, SUM(si.quantity) AS qty, SUM(si."totalPrice") AS revenue FROM sale_items si JOIN sales s ON s.id = si."saleId"
        WHERE s.date >= ${from} AND si."productModelId" IS NOT NULL GROUP BY 1
      )
      SELECT p.id, p.name, met.meters::text AS meters, lab.labor::text AS labor, mat.cost::text AS materials, mat."noPrice" AS "noPrice",
             sold.qty::text AS "soldQty", sold.revenue::text AS revenue
      FROM product_models p LEFT JOIN met ON met.pm = p.id LEFT JOIN lab ON lab.pm = p.id LEFT JOIN mat ON mat.pm = p.id LEFT JOIN sold ON sold.pm = p.id
      WHERE met.meters IS NOT NULL OR sold.qty IS NOT NULL
      ORDER BY p.name`;
    const n = (v: string | null) => (v === null ? 0 : Number(v));
    const items = rows.map((r) => {
      const meters = n(r.meters);
      const labor = Math.round(n(r.labor));
      const materials = Math.round(n(r.materials));
      const cost = labor + materials;
      const costPerMeter = meters > 0 ? Math.round(cost / meters) : null;
      const soldQty = n(r.soldQty);
      const revenue = Math.round(n(r.revenue));
      const pricePerMeter = soldQty > 0 ? Math.round(revenue / soldQty) : null;
      const profitPerMeter = pricePerMeter !== null && costPerMeter !== null ? pricePerMeter - costPerMeter : null;
      return {
        productId: r.id, name: r.name, meters, labor, materials, cost, costPerMeter,
        soldQuantity: soldQty, revenue, pricePerMeter, profitPerMeter,
        marginPercent: profitPerMeter !== null && pricePerMeter ? Math.round((profitPerMeter / pricePerMeter) * 100) : null,
        materialsWithoutPrice: Number(r.noPrice ?? 0n),
      };
    });
    return { from: from.toISOString(), months, items };
  }

  async sales(q: { limit: number }) {
    const rows = await this.prisma.sale.findMany({ orderBy: { date: 'desc' }, take: q.limit, include: { items: true } });
    return {
      items: rows.map((r) => ({
        id: r.id, code: r.code, date: r.date.toISOString(), customer: r.customer, total: money(r.total)!, notes: r.notes,
        lines: r.items.map((i) => ({ productModelId: i.productModelId, name: i.description, quantity: Number(i.quantity), unitPrice: money(i.unitPrice)!, total: money(i.totalPrice)! })),
      })),
    };
  }

  async addSale(actor: AuthUser, input: z.output<typeof createSaleSchema>) {
    const row = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'sale_code', 'SL-', 5);
      const lines = input.items ?? [];
      const products = lines.length ? await tx.productModel.findMany({ where: { id: { in: lines.map((l) => l.productModelId) } }, select: { id: true, name: true } }) : [];
      const names = new Map(products.map((p) => [p.id, p.name]));
      if (lines.some((l) => !names.has(l.productModelId))) throw notFound('ProductModel');
      const lineTotal = (l: { quantity: number; unitPrice: bigint }) => BigInt(Math.round(l.quantity * Number(l.unitPrice)));
      // the lines are what was sold: their sum IS the total (never two numbers that disagree)
      const total = lines.length ? lines.reduce((a, l) => a + lineTotal(l), 0n) : BigInt(input.total);
      const s = await tx.sale.create({
        data: {
          code, date: input.date ?? new Date(), customer: input.customer, total, notes: input.notes, createdById: actor.id,
          items: lines.length ? { create: lines.map((l) => ({ productModelId: l.productModelId, description: names.get(l.productModelId)!, quantity: l.quantity, unitPrice: BigInt(l.unitPrice), totalPrice: lineTotal(l) })) } : undefined,
        },
      });
      await this.audit.record({ action: 'sale.create', entity: 'Sale', entityId: s.id, after: { total: input.total, customer: input.customer } }, tx);
      return s;
    });
    return { id: row.id, code: row.code };
  }

  async removeSale(id: string) {
    const s = await this.prisma.sale.findUnique({ where: { id } });
    if (!s) throw notFound('Sale');
    await this.prisma.$transaction(async (tx) => {
      await tx.sale.delete({ where: { id } });
      await this.audit.record({ action: 'sale.delete', entity: 'Sale', entityId: id, before: { total: s.total.toString(), customer: s.customer } }, tx);
    });
    return { deleted: true };
  }

  async expenses(q: { limit: number }) {
    const rows = await this.prisma.expense.findMany({ orderBy: { date: 'desc' }, take: q.limit });
    return { items: rows.map((r) => ({ id: r.id, category: r.category, date: r.date.toISOString(), amount: money(r.amount)!, comment: r.comment })) };
  }

  async addExpense(actor: AuthUser, input: z.output<typeof createExpenseSchema>) {
    const row = await this.prisma.$transaction(async (tx) => {
      const e = await tx.expense.create({ data: { category: input.category, amount: BigInt(input.amount), date: input.date ?? new Date(), comment: input.comment, createdById: actor.id } });
      await this.audit.record({ action: 'expense.create', entity: 'Expense', entityId: e.id, after: { amount: input.amount, category: input.category } }, tx);
      return e;
    });
    return { id: row.id };
  }

  async removeExpense(id: string) {
    const e = await this.prisma.expense.findUnique({ where: { id } });
    if (!e) throw notFound('Expense');
    await this.prisma.$transaction(async (tx) => {
      await tx.expense.delete({ where: { id } });
      await this.audit.record({ action: 'expense.delete', entity: 'Expense', entityId: id, before: { amount: e.amount.toString(), category: e.category } }, tx);
    });
    return { deleted: true };
  }

  // ---- «Стоимость склада» ------------------------------------------------------------------------------------------------
  /** What the materials are worth at purchase price: on the shelf + at workers' homes; which materials have no price. */
  async stockValue() {
    const [shelf, homes, noPrice] = await Promise.all([
      this.prisma.$queryRaw<{ v: string | null }[]>`SELECT SUM(b.quantity * m."unitCost")::text AS v FROM stock_balances b JOIN materials m ON m.id = b."materialId" WHERE m."deletedAt" IS NULL`,
      this.prisma.$queryRaw<{ v: string | null }[]>`SELECT SUM(w.quantity * m."unitCost")::text AS v FROM worker_material_balances w JOIN materials m ON m.id = w."materialId" WHERE m."deletedAt" IS NULL`,
      this.prisma.material.findMany({ where: { deletedAt: null, isActive: true, unitCost: null }, select: { id: true, name: true }, orderBy: { name: 'asc' } }),
    ]);
    const a = BigInt(Math.round(Number(shelf[0]?.v ?? 0)));
    const b = BigInt(Math.round(Number(homes[0]?.v ?? 0)));
    return { warehouse: money(a)!, withWorkers: money(b)!, total: money(a + b)!, withoutPrice: noPrice };
  }

  // ---- «Состояние системы» -----------------------------------------------------------------------------------------------
  /** Is everything up, and when did each backup last succeed (read from the backup job's status files, read-only mount). */
  async systemStatus() {
    const t0 = Date.now();
    const db = await this.prisma.$queryRaw`SELECT 1`.then(() => ({ ok: true, ms: Date.now() - t0 })).catch(() => ({ ok: false, ms: null }));
    const t1 = Date.now();
    const redis = !this.redis.client ? { ok: false, ms: null } : await this.redis.client.ping().then(() => ({ ok: true, ms: Date.now() - t1 })).catch(() => ({ ok: false, ms: null }));
    const dir = this.env.BACKUP_STATUS_DIR;
    const backups: { job: string; ok: boolean; at: string | null; bytes: number | null }[] = [];
    let backupsVisible = false;
    if (dir) {
      try {
        for (const f of (await readdir(dir)).filter((x) => x.endsWith('.status')).sort()) {
          const [state, epoch, size] = (await readFile(join(dir, f), 'utf8')).trim().split(/\s+/);
          backups.push({ job: f.replace(/\.status$/, ''), ok: state === 'ok', at: Number(epoch) ? new Date(Number(epoch) * 1000).toISOString() : null, bytes: Number(size) || null });
        }
        backupsVisible = true;
      } catch { /* the directory is not mounted here: say so instead of pretending */ }
    }
    const [dbSize] = await this.prisma.$queryRaw<{ size: string }[]>`SELECT pg_size_pretty(pg_database_size(current_database())) AS size`.catch(() => [{ size: '—' }]);
    return {
      now: new Date().toISOString(), version: this.env.APP_VERSION ?? null, uptimeSeconds: Math.round(process.uptime()),
      database: { ...db, size: dbSize?.size ?? null }, redis, backupsVisible, backups,
    };
  }
}

const listSchema = z.object({ limit: z.coerce.number().int().min(1).max(200).default(50) });

@ApiTags('insights')
@ApiBearerAuth()
@Controller('admin')
export class InsightsController {
  constructor(private readonly insights: InsightsService) {}

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('reports/rating')
  rating(@CurrentUser() u: AuthUser, @ZodQuery(insightsMonthsSchema) q: z.output<typeof insightsMonthsSchema>) { return this.insights.rating(u, q.months); }

  @Perm('PROFIT_VIEW') @Get('finance/profit')
  profit(@ZodQuery(insightsMonthsSchema) q: z.output<typeof insightsMonthsSchema>) { return this.insights.profit(q.months); }

  @Perm('PROFIT_VIEW') @Get('finance/products')
  products(@ZodQuery(insightsMonthsSchema) q: z.output<typeof insightsMonthsSchema>) { return this.insights.products(q.months); }

  @Perm('PROFIT_VIEW') @Get('finance/sales')
  sales(@ZodQuery(listSchema) q: z.output<typeof listSchema>) { return this.insights.sales(q); }

  @Perm('PROFIT_VIEW') @Post('finance/sales') @ApiZodBody(createSaleSchema)
  addSale(@CurrentUser() u: AuthUser, @ZodBody(createSaleSchema) b: z.output<typeof createSaleSchema>) { return this.insights.addSale(u, b); }

  @Perm('PROFIT_VIEW') @Delete('finance/sales/:id') @HttpCode(200)
  removeSale(@Param('id', new ParseUUIDPipe()) id: string) { return this.insights.removeSale(id); }

  @Perm('PROFIT_VIEW') @Get('finance/expenses')
  expenses(@ZodQuery(listSchema) q: z.output<typeof listSchema>) { return this.insights.expenses(q); }

  @Perm('PROFIT_VIEW') @Post('finance/expenses') @ApiZodBody(createExpenseSchema)
  addExpense(@CurrentUser() u: AuthUser, @ZodBody(createExpenseSchema) b: z.output<typeof createExpenseSchema>) { return this.insights.addExpense(u, b); }

  @Perm('PROFIT_VIEW') @Delete('finance/expenses/:id') @HttpCode(200)
  removeExpense(@Param('id', new ParseUUIDPipe()) id: string) { return this.insights.removeExpense(id); }

  @Perm('PROFIT_VIEW') @Get('stock/value')
  stockValue() { return this.insights.stockValue(); }

  /** The SUPER_ADMIN, or whoever manages company settings. */
  @Authenticated() @Get('system/status')
  status(@CurrentUser() u: AuthUser) {
    if (u.role !== 'SUPER_ADMIN' && !can(u, 'SETTINGS_MANAGE')) throw forbidden();
    return this.insights.systemStatus();
  }
}

@Module({ controllers: [InsightsController], providers: [InsightsService] })
export class InsightsModule {}

