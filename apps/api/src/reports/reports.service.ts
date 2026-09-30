import { Controller, Get, Header, Injectable, Module, Res, StreamableFile } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { z } from 'zod';
import ExcelJS from 'exceljs';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { can, workerScope } from '../common/scope';
import { money } from '../common/serialize';
import { ZodQuery } from '../common/zod.pipe';
import { PrismaService } from '../prisma/prisma.module';

const TASHKENT_MS = 5 * 3600_000;
export const reportQuerySchema = z.object({
  period: z.enum(['day', 'week', 'month']).default('week'),
  /** 0 = the current period, -1 = the previous one, ... */
  offset: z.coerce.number().int().min(-60).max(0).default(0),
});

/** [from, to) of a Tashkent day / Monday-based week / calendar month, as UTC instants. */
export function periodRange(period: 'day' | 'week' | 'month', offset: number, now = new Date()) {
  const local = new Date(now.getTime() + TASHKENT_MS);
  let from: Date; let to: Date;
  if (period === 'month') {
    from = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + offset, 1));
    to = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + offset + 1, 1));
  } else {
    const day = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()));
    if (period === 'day') {
      from = new Date(day.getTime() + offset * 86_400_000);
      to = new Date(from.getTime() + 86_400_000);
    } else {
      const monday = new Date(day.getTime() - ((day.getUTCDay() + 6) % 7) * 86_400_000);
      from = new Date(monday.getTime() + offset * 7 * 86_400_000);
      to = new Date(from.getTime() + 7 * 86_400_000);
    }
  }
  return { from: new Date(from.getTime() - TASHKENT_MS), to: new Date(to.getTime() - TASHKENT_MS) };
}

/**
 * «Отчёт»: what was issued, accepted, earned and paid, per worker, for a day / week / month — in the app and the web
 * panel (and as a CSV that Excel opens). Scoped like finance everywhere: a MANAGER sees only her own workers.
 */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async report(actor: AuthUser, q: z.output<typeof reportQuerySchema>) {
    const { from, to } = periodRange(q.period, q.offset);
    const { where: scope } = workerScope(actor, 'FINANCE');
    const workers = await this.prisma.workerProfile.findMany({ where: { ...scope, status: { not: 'REJECTED' }, deletedAt: null }, select: { id: true, code: true, fullName: true } });
    const ids = workers.map((w) => w.id);
    const [issued, inspections, ledger, overdue] = await Promise.all([
      // aggregated in PostgreSQL, not loaded row by row: stays fast with thousands of workers
      this.prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: ids }, createdAt: { gte: from, lt: to } }, _count: { _all: true }, _sum: { plannedMeters: true } }),
      this.prisma.qualityInspection.findMany({ where: { assignment: { workerId: { in: ids } }, inspectedAt: { gte: from, lt: to } }, select: { acceptedMeters: true, defectiveMeters: true, assignment: { select: { workerId: true } } } }),
      this.prisma.workerLedgerTransaction.groupBy({ by: ['workerId', 'type'], where: { workerId: { in: ids }, createdAt: { gte: from, lt: to }, type: { in: ['EARNING', 'PAYOUT_CASH'] } }, _sum: { amount: true } }),
      this.prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: ids }, status: { in: ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS'] }, dueAt: { lt: new Date() } }, _count: { _all: true } }),
    ]);
    const iss = new Map(issued.map((g) => [g.workerId, g]));
    const due = new Map(overdue.map((g) => [g.workerId, g._count._all]));
    const acc = new Map<string, { a: number; d: number }>();
    for (const i of inspections) {
      const x = acc.get(i.assignment.workerId) ?? { a: 0, d: 0 };
      x.a += Number(i.acceptedMeters); x.d += Number(i.defectiveMeters);
      acc.set(i.assignment.workerId, x);
    }
    const sumOf = (workerId: string, type: 'EARNING' | 'PAYOUT_CASH') => ledger.find((l) => l.workerId === workerId && l.type === type)?._sum.amount ?? 0n;
    const rows = workers.map((w) => ({
      worker: w, issuedCount: iss.get(w.id)?._count._all ?? 0, issuedMeters: Number(iss.get(w.id)?._sum.plannedMeters ?? 0),
      acceptedMeters: acc.get(w.id)?.a ?? 0, defectiveMeters: acc.get(w.id)?.d ?? 0,
      earned: sumOf(w.id, 'EARNING'), paid: -sumOf(w.id, 'PAYOUT_CASH'), overdue: due.get(w.id) ?? 0,
    })).filter((r) => r.issuedCount || r.acceptedMeters || r.earned || r.paid || r.overdue)
      .sort((a, b) => b.acceptedMeters - a.acceptedMeters || a.worker.fullName.localeCompare(b.worker.fullName));

    const total = rows.reduce((t, r) => ({
      issuedCount: t.issuedCount + r.issuedCount, issuedMeters: t.issuedMeters + r.issuedMeters, acceptedMeters: t.acceptedMeters + r.acceptedMeters,
      defectiveMeters: t.defectiveMeters + r.defectiveMeters, earned: t.earned + r.earned, paid: t.paid + r.paid, overdue: t.overdue + r.overdue,
    }), { issuedCount: 0, issuedMeters: 0, acceptedMeters: 0, defectiveMeters: 0, earned: 0n, paid: 0n, overdue: 0 });

    const lowStock = can(actor, 'INVENTORY_VIEW') || can(actor, 'INVENTORY_MANAGE')
      ? (await this.prisma.material.findMany({ where: { isActive: true, deletedAt: null }, include: { balance: true }, orderBy: { name: 'asc' } }))
          .filter((m) => Number(m.balance?.quantity ?? 0) < Number(m.minStock))
          .map((m) => ({ materialId: m.id, name: m.name, unit: m.unit, quantity: Number(m.balance?.quantity ?? 0), minStock: Number(m.minStock) }))
      : null;

    return {
      period: q.period, offset: q.offset, from: from.toISOString(), to: to.toISOString(),
      total: { ...total, earned: money(total.earned)!, paid: money(total.paid)! },
      rows: rows.map((r) => ({ ...r, earned: money(r.earned)!, paid: money(r.paid)! })),
      lowStock,
    };
  }

  async csv(actor: AuthUser, q: z.output<typeof reportQuerySchema>) {
    const r = await this.report(actor, q);
    const cell = (v: unknown) => `"${String(v).replace(/"/g, '""')}"`;
    const day = (iso: string) => new Date(new Date(iso).getTime() + TASHKENT_MS).toISOString().slice(0, 10);
    const lines = [
      [`Diamoraa — отчёт ${day(r.from)} … ${day(new Date(new Date(r.to).getTime() - 1).toISOString())}`],
      ['Мастерица', 'Код', 'Выдано работ', 'Выдано, м', 'Принято, м', 'Брак, м', 'Начислено, сум', 'Выплачено, сум', 'Просрочено'],
      ...r.rows.map((x) => [x.worker.fullName, x.worker.code, x.issuedCount, x.issuedMeters, x.acceptedMeters, x.defectiveMeters, x.earned, x.paid, x.overdue]),
      ['Итого', '', r.total.issuedCount, r.total.issuedMeters, r.total.acceptedMeters, r.total.defectiveMeters, r.total.earned, r.total.paid, r.total.overdue],
    ];
    // BOM + ';' = Excel (ru/uz locale) opens it straight into columns with Cyrillic intact
    return '﻿' + lines.map((l) => l.map(cell).join(';')).join('\r\n');
  }

  /** The same report as a real Excel file: a header, bold totals, money as numbers (so Excel can sum them), frozen header row. */
  async xlsx(actor: AuthUser, q: z.output<typeof reportQuerySchema>): Promise<Buffer> {
    const r = await this.report(actor, q);
    const day = (iso: string) => new Date(new Date(iso).getTime() + TASHKENT_MS).toISOString().slice(0, 10).split('-').reverse().join('.');
    const title = `Diamoraa — отчёт за ${day(r.from)} – ${day(new Date(new Date(r.to).getTime() - 1).toISOString())}`;
    const wb = new ExcelJS.Workbook();
    wb.creator = 'Diamoraa';
    const ws = wb.addWorksheet('Мастерицы', { views: [{ state: 'frozen', ySplit: 3 }] });
    ws.columns = [
      { key: 'name', width: 28 }, { key: 'code', width: 10 }, { key: 'issuedCount', width: 12 }, { key: 'issuedMeters', width: 12 },
      { key: 'acceptedMeters', width: 12 }, { key: 'defectiveMeters', width: 10 }, { key: 'earned', width: 16 }, { key: 'paid', width: 16 }, { key: 'overdue', width: 12 },
    ];
    ws.mergeCells('A1:I1');
    ws.getCell('A1').value = title;
    ws.getCell('A1').font = { bold: true, size: 14 };
    const head = ws.getRow(3);
    head.values = ['Мастерица', 'Код', 'Выдано работ', 'Выдано, м', 'Принято, м', 'Брак, м', 'Начислено, сум', 'Выплачено, сум', 'Просрочено'];
    head.font = { bold: true };
    head.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF3E8EC' } };
    for (const x of r.rows) {
      ws.addRow([x.worker.fullName, x.worker.code, x.issuedCount, x.issuedMeters, x.acceptedMeters, x.defectiveMeters, Number(x.earned), Number(x.paid), x.overdue]);
    }
    const t = ws.addRow(['Итого', '', r.total.issuedCount, r.total.issuedMeters, r.total.acceptedMeters, r.total.defectiveMeters, Number(r.total.earned), Number(r.total.paid), r.total.overdue]);
    t.font = { bold: true };
    t.border = { top: { style: 'thin' } };
    for (const c of ['G', 'H']) ws.getColumn(c).numFmt = '# ##0';
    if (r.lowStock?.length) {
      const st = wb.addWorksheet('Склад: мало');
      st.columns = [{ header: 'Материал', key: 'n', width: 30 }, { header: 'Осталось', key: 'q', width: 12 }, { header: 'Минимум', key: 'm', width: 12 }];
      st.getRow(1).font = { bold: true };
      for (const m of r.lowStock) st.addRow([m.name, m.quantity, m.minStock]);
    }
    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  /** «Мои заработки по месяцам» (worker, self only): accepted metres, earned, paid — the last 6 months. */
  async myMonths(workerId: string) {
    const out = [];
    for (let i = 0; i > -6; i--) {
      const { from, to } = periodRange('month', i);
      const [ins, led] = await Promise.all([
        this.prisma.qualityInspection.findMany({ where: { assignment: { workerId }, inspectedAt: { gte: from, lt: to } }, select: { acceptedMeters: true } }),
        this.prisma.workerLedgerTransaction.findMany({ where: { workerId, createdAt: { gte: from, lt: to }, type: { in: ['EARNING', 'PAYOUT_CASH'] } }, select: { type: true, amount: true } }),
      ]);
      const local = new Date(from.getTime() + TASHKENT_MS);
      out.push({
        month: `${local.getUTCFullYear()}-${String(local.getUTCMonth() + 1).padStart(2, '0')}`,
        acceptedMeters: ins.reduce((s, x) => s + Number(x.acceptedMeters), 0),
        earned: money(led.filter((l) => l.type === 'EARNING').reduce((s, l) => s + l.amount, 0n))!,
        paid: money(-led.filter((l) => l.type === 'PAYOUT_CASH').reduce((s, l) => s + l.amount, 0n))!,
      });
    }
    return { items: out };
  }
}

@ApiTags('reports')
@ApiBearerAuth()
@Controller()
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Perm('FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'PROFIT_VIEW') @Get('admin/reports')
  report(@CurrentUser() u: AuthUser, @ZodQuery(reportQuerySchema) q: z.output<typeof reportQuerySchema>) { return this.reports.report(u, q); }

  @Perm('FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'PROFIT_VIEW') @Get('admin/reports/export') @Header('Content-Type', 'text/csv; charset=utf-8')
  async export(@CurrentUser() u: AuthUser, @ZodQuery(reportQuerySchema) q: z.output<typeof reportQuerySchema>, @Res({ passthrough: true }) res: Response) {
    res.setHeader('Content-Disposition', `attachment; filename="diamoraa-report-${q.period}.csv"`);
    return this.reports.csv(u, q);
  }

  @Perm('FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'PROFIT_VIEW') @Get('admin/reports/export.xlsx')
  async exportXlsx(@CurrentUser() u: AuthUser, @ZodQuery(reportQuerySchema) q: z.output<typeof reportQuerySchema>, @Res({ passthrough: true }) res: Response) {
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="diamoraa-report-${q.period}.xlsx"`);
    return new StreamableFile(await this.reports.xlsx(u, q));
  }

  @Roles('WORKER') @Get('work/earnings/monthly')
  myMonths(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.reports.myMonths(u.workerId);
  }
}

@Module({ controllers: [ReportsController], providers: [ReportsService] })
export class ReportsModule {}
