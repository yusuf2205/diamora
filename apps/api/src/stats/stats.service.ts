import { Injectable, Module } from '@nestjs/common';
import type { Prisma } from '@yusmus/database';
import { money } from '../common/serialize';
import { PrismaService } from '../prisma/prisma.module';

/** Assignments a worker is physically holding / working on right now. */
const ACTIVE_STATUSES = ['DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'REWORK_REQUIRED'] as const;
/** Metres are "on hand" from delivery until the work is picked up. */
const ON_HAND_STATUSES = ['DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP'] as const;

export interface GroupStats {
  workers: number;
  activeWorkers: number;
  workersWithActiveAssignment: number;
  workersWithoutActiveAssignment: number;
  activeAssignments: number;
  inProgress: number;
  needsAcceptance: number;
  completed: number;
  metersOnHand: number;
  toDeliver: number;
  toPickup: number;
  overdue: number;
  /** assignments sent back after acceptance - the only "problem" state the data model actually has */
  reworkRequired: number;
  /** workers owed money right now (balance > 0) */
  workersDue: number;
  /** UZS as decimal strings */
  earned: string;
  paid: string;
  due: string;
}

/**
 * Numbers for the dashboards of SUPER_ADMIN / ADMIN (all workers) and MANAGER (their own workers). Computed from the real tables
 * on every call (the volume of a home business is tiny), so they can never drift from the ledger.
 */
@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService) {}

  /** `where` selects the workers (e.g. {} for everybody, { assignedManagerId } for one manager). */
  async forWorkers(where: Prisma.WorkerProfileWhereInput = {}): Promise<GroupStats> {
    const workers = await this.prisma.workerProfile.findMany({ where, select: { id: true, status: true, balance: true } });
    const ids = workers.map((w) => w.id);
    const activeIds = workers.filter((w) => w.status === 'ACTIVE').map((w) => w.id);
    const wa = { workerId: { in: ids } };
    const now = new Date();
    const [meters, active, toDeliver, toPickup, overdue, earned, paid, statusRows, holding] = await Promise.all([
      this.prisma.workAssignment.aggregate({ _sum: { plannedMeters: true }, where: { ...wa, status: { in: [...ON_HAND_STATUSES] } } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: { in: [...ACTIVE_STATUSES] } } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: 'READY_TO_DELIVER' } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: 'READY_FOR_PICKUP' } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: { in: ['DELIVERED', 'IN_PROGRESS'] }, dueAt: { lt: now } } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { ...wa, type: { in: ['EARNING', 'BONUS'] } } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { ...wa, type: 'PAYOUT_CASH' } }),
      this.prisma.workAssignment.groupBy({ by: ['status'], where: wa, _count: true }),
      this.prisma.workAssignment.findMany({
        where: { workerId: { in: activeIds }, status: { in: [...ACTIVE_STATUSES] } }, select: { workerId: true }, distinct: ['workerId'],
      }),
    ]);
    const due = workers.reduce((s, w) => s + w.balance, 0n);
    const byStatus = Object.fromEntries(statusRows.map((r) => [r.status, r._count]));
    return {
      workers: workers.length,
      activeWorkers: activeIds.length,
      workersWithActiveAssignment: holding.length,
      workersWithoutActiveAssignment: activeIds.length - holding.length,
      activeAssignments: active,
      inProgress: byStatus.IN_PROGRESS ?? 0,
      needsAcceptance: (byStatus.PICKED_UP ?? 0) + (byStatus.UNDER_REVIEW ?? 0),
      completed: byStatus.COMPLETED ?? 0,
      metersOnHand: Number(meters._sum.plannedMeters ?? 0),
      toDeliver, toPickup, overdue,
      reworkRequired: byStatus.REWORK_REQUIRED ?? 0,
      workersDue: workers.filter((w) => w.balance > 0n).length,
      earned: money(earned._sum.amount ?? 0n)!,
      paid: money(-(paid._sum.amount ?? 0n))!,
      due: money(due)!,
    };
  }

  /**
   * What happened / is due TODAY in the business's own time zone (Tashkent, UTC+5, no DST). Only facts the tables
   * record: there is no planned delivery date in the model, so "delivered/picked up today" are completed deliveries.
   */
  async today(where: Prisma.WorkerProfileWhereInput = {}, now = new Date()) {
    const offset = 5 * 3600_000;
    const start = new Date(Math.floor((now.getTime() + offset) / 86_400_000) * 86_400_000 - offset);
    const end = new Date(start.getTime() + 86_400_000);
    const ids = (await this.prisma.workerProfile.findMany({ where, select: { id: true } })).map((w) => w.id);
    const wa = { workerId: { in: ids } };
    const [dueToday, deliveredToday, pickedUpToday, paid] = await Promise.all([
      this.prisma.workAssignment.count({ where: { ...wa, status: { in: [...ACTIVE_STATUSES, 'READY_TO_DELIVER'] }, dueAt: { gte: start, lt: end } } }),
      this.prisma.delivery.count({ where: { ...wa, type: 'DELIVERY_TO_WORKER', status: 'COMPLETED', completedAt: { gte: start, lt: end } } }),
      this.prisma.delivery.count({ where: { ...wa, type: 'PICKUP_FROM_WORKER', status: 'COMPLETED', completedAt: { gte: start, lt: end } } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { ...wa, type: 'PAYOUT_CASH', createdAt: { gte: start, lt: end } } }),
    ]);
    return { dueToday, deliveredToday, pickedUpToday, paidToday: money(-(paid._sum.amount ?? 0n))! };
  }

  /** Per-worker figures for tables (workers list of the web panel, manager detail). */
  async perWorker(workerIds: string[]) {
    if (!workerIds.length) return new Map<string, { activeAssignments: number; metersOnHand: number; earned: string; paid: string; due: string; nextDueAt: string | null }>();
    const [assignments, ledger, workers] = await Promise.all([
      this.prisma.workAssignment.findMany({
        where: { workerId: { in: workerIds }, status: { in: [...ACTIVE_STATUSES] } },
        select: { workerId: true, status: true, plannedMeters: true, dueAt: true },
      }),
      this.prisma.workerLedgerTransaction.groupBy({ by: ['workerId', 'type'], _sum: { amount: true }, where: { workerId: { in: workerIds } } }),
      this.prisma.workerProfile.findMany({ where: { id: { in: workerIds } }, select: { id: true, balance: true } }),
    ]);
    const out = new Map<string, { activeAssignments: number; metersOnHand: number; earned: string; paid: string; due: string; nextDueAt: string | null }>();
    for (const w of workers) {
      const mine = assignments.filter((a) => a.workerId === w.id);
      const sum = (types: string[]) => ledger.filter((l) => l.workerId === w.id && types.includes(l.type)).reduce((s, l) => s + (l._sum.amount ?? 0n), 0n);
      const due = mine.map((a) => a.dueAt).filter((d): d is Date => !!d).sort((a, b) => a.getTime() - b.getTime())[0];
      out.set(w.id, {
        activeAssignments: mine.length,
        metersOnHand: mine.filter((a) => (ON_HAND_STATUSES as readonly string[]).includes(a.status)).reduce((s, a) => s + Number(a.plannedMeters), 0),
        earned: money(sum(['EARNING', 'BONUS']))!, paid: money(-sum(['PAYOUT_CASH']))!, due: money(w.balance)!,
        nextDueAt: due?.toISOString() ?? null,
      });
    }
    return out;
  }
}

@Module({ providers: [StatsService], exports: [StatsService] })
export class StatsModule {}
