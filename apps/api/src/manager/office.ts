import { Controller, Get, Injectable, Module } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { scopeFor } from '@diamoraa/shared';
import { can } from '../common/scope';
import { money } from '../common/serialize';
import { ZodQuery } from '../common/zod.pipe';
import { PrismaService } from '../prisma/prisma.module';
import { periodRange } from '../reports/reports.service';

const searchSchema = z.object({ q: z.string().trim().min(2).max(80) });
const has = (q: string) => ({ contains: q, mode: 'insensitive' as const });
const TASHKENT_MS = 5 * 3_600_000;
const monthKey = (from: Date) => { const l = new Date(from.getTime() + TASHKENT_MS); return `${l.getUTCFullYear()}-${String(l.getUTCMonth() + 1).padStart(2, '0')}`; };

/**
 * «Общий поиск» and «Деньги» (owner, 2026-10-11). Search: one line finds workers, works, customer orders, materials,
 * models and staff - each kind only if the viewer may see it, workers/works only inside a manager's own scope.
 * Money: what is owed to workers, earned / paid / sold / spent this month and last, and the profit (PROFIT_VIEW only).
 */
@Injectable()
export class OfficeService {
  constructor(private readonly prisma: PrismaService) {}

  async search(actor: AuthUser, q: string) {
    const workerScope = scopeFor(actor.permissions, 'WORKER');
    const workScope = scopeFor(actor.permissions, 'ASSIGNMENT');
    const mine = (s: 'all' | 'assigned' | 'none') => (s === 'all' ? {} : { assignedManagerId: actor.id });
    const digits = q.replace(/\D/g, '');
    const [workers, works, orders, materials, models, staff] = await Promise.all([
      workerScope === 'none' ? [] : this.prisma.workerProfile.findMany({
        where: { ...mine(workerScope), deletedAt: null, OR: [{ fullName: has(q) }, { code: has(q) }, ...(digits.length >= 3 ? [{ phone: { contains: digits } }] : [])] },
        select: { id: true, fullName: true, code: true, phone: true, status: true }, take: 8, orderBy: { fullName: 'asc' },
      }),
      workScope === 'none' ? [] : this.prisma.workAssignment.findMany({
        where: { worker: mine(workScope), OR: [{ code: has(q) }, { worker: { fullName: has(q) } }, { productModel: { name: has(q) } }] },
        select: { id: true, code: true, status: true, plannedMeters: true, worker: { select: { fullName: true } }, productModel: { select: { name: true } } },
        take: 8, orderBy: { createdAt: 'desc' },
      }),
      actor.role === 'WORKER' ? [] : this.prisma.clientOrder.findMany({
        where: { OR: [{ code: has(q) }, { name: has(q) }, ...(digits.length >= 3 ? [{ phone: { contains: digits } }] : [])] },
        select: { id: true, code: true, name: true, phone: true, status: true }, take: 6, orderBy: { createdAt: 'desc' },
      }),
      can(actor, 'INVENTORY_VIEW') ? this.prisma.material.findMany({ where: { name: has(q), deletedAt: null }, select: { id: true, name: true }, take: 6 }) : [],
      can(actor, 'CATALOG_VIEW') || can(actor, 'CATALOG_MANAGE')
        ? this.prisma.productModel.findMany({ where: { name: has(q), deletedAt: null }, select: { id: true, name: true, code: true }, take: 6 }) : [],
      can(actor, 'USER_VIEW_ALL')
        ? this.prisma.user.findMany({ where: { role: { not: 'WORKER' }, OR: [{ fullName: has(q) }, ...(digits.length >= 3 ? [{ phone: { contains: digits } }] : [])] }, select: { id: true, fullName: true, role: true, phone: true }, take: 6 })
        : [],
    ]);
    return {
      workers, orders, materials, models, staff,
      works: works.map((a) => ({ id: a.id, code: a.code, status: a.status, plannedMeters: Number(a.plannedMeters), worker: a.worker.fullName, product: a.productModel.name })),
    };
  }

  async money(actor: AuthUser, now = new Date()) {
    const profitToo = can(actor, 'PROFIT_VIEW');
    const owedRows = await this.prisma.workerProfile.findMany({
      where: { deletedAt: null, balance: { gt: 0 } }, select: { id: true, fullName: true, code: true, balance: true }, orderBy: { balance: 'desc' },
    });
    const months = [];
    for (const offset of [0, -1]) {
      const { from, to } = periodRange('month', offset, now);
      const [earned, bonus, paid, sales, expenses, materials] = await Promise.all([
        this.prisma.workerLedgerTransaction.aggregate({ where: { type: 'EARNING', createdAt: { gte: from, lt: to } }, _sum: { amount: true } }),
        this.prisma.workerLedgerTransaction.aggregate({ where: { type: 'BONUS', createdAt: { gte: from, lt: to } }, _sum: { amount: true } }),
        this.prisma.workerLedgerTransaction.aggregate({ where: { type: 'PAYOUT_CASH', createdAt: { gte: from, lt: to } }, _sum: { amount: true } }),
        profitToo ? this.prisma.sale.aggregate({ where: { date: { gte: from, lt: to } }, _sum: { total: true } }) : null,
        profitToo ? this.prisma.expense.aggregate({ where: { date: { gte: from, lt: to } }, _sum: { amount: true } }) : null,
        profitToo ? this.prisma.$queryRaw<{ cost: string | null }[]>`
          SELECT SUM(ABS(s."warehouseDelta") * m."unitCost")::text AS cost FROM stock_movements s JOIN materials m ON m.id = s."materialId"
          WHERE s."createdAt" >= ${from} AND s."createdAt" < ${to} AND s.type IN ('ISSUE_TO_KIT', 'WRITE_OFF') AND s."warehouseDelta" < 0` : null,
      ]);
      const labor = (earned._sum.amount ?? 0n) + (bonus._sum.amount ?? 0n);
      const row: Record<string, string | null> = {
        month: monthKey(from), earned: money(earned._sum.amount ?? 0n)!, bonus: money(bonus._sum.amount ?? 0n)!, paid: money(-(paid._sum.amount ?? 0n))!,
      };
      if (profitToo) {
        const s = sales?._sum.total ?? 0n, e = expenses?._sum.amount ?? 0n, m = BigInt(Math.round(Number(materials?.[0]?.cost ?? 0)));
        Object.assign(row, { sales: money(s)!, expenses: money(e)!, materials: money(m)!, profit: money(s - labor - m - e)! });
      }
      months.push(row);
    }
    return {
      owed: { total: money(owedRows.reduce((s, w) => s + w.balance, 0n))!, workers: owedRows.length, top: owedRows.slice(0, 5).map((w) => ({ ...w, balance: money(w.balance)! })) },
      thisMonth: months[0], lastMonth: months[1], profitVisible: profitToo,
    };
  }
}

@ApiTags('office')
@ApiBearerAuth()
@Controller()
export class OfficeController {
  constructor(private readonly office: OfficeService) {}

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Get('admin/search')
  search(@CurrentUser() u: AuthUser, @ZodQuery(searchSchema) q: z.output<typeof searchSchema>) { return this.office.search(u, q.q); }

  @Perm('FINANCE_VIEW_ALL', 'PROFIT_VIEW') @Get('admin/money')
  money(@CurrentUser() u: AuthUser) {
    if (!can(u, 'FINANCE_VIEW_ALL') && !can(u, 'PROFIT_VIEW')) throw forbidden();
    return this.office.money(u);
  }
}

@Module({ controllers: [OfficeController], providers: [OfficeService] })
export class OfficeModule {}
