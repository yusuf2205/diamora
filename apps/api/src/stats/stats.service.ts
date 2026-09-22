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
  activeAssignments: number;
  metersOnHand: number;
  toDeliver: number;
  toPickup: number;
  overdue: number;
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
    const wa = { workerId: { in: ids } };
    const now = new Date();
    const [meters, active, toDeliver, toPickup, overdue, earned, paid] = await Promise.all([
      this.prisma.workAssignment.aggregate({ _sum: { plannedMeters: true }, where: { ...wa, status: { in: [...ON_HAND_STATUSES] } } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: { in: [...ACTIVE_STATUSES] } } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: 'READY_TO_DELIVER' } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: 'READY_FOR_PICKUP' } }),
      this.prisma.workAssignment.count({ where: { ...wa, status: { in: ['DELIVERED', 'IN_PROGRESS'] }, dueAt: { lt: now } } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { ...wa, type: { in: ['EARNING', 'BONUS'] } } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { ...wa, type: 'PAYOUT_CASH' } }),
    ]);
    const due = workers.reduce((s, w) => s + w.balance, 0n);
    return {
      workers: workers.length,
      activeWorkers: workers.filter((w) => w.status === 'ACTIVE').length,
      activeAssignments: active,
      metersOnHand: Number(meters._sum.plannedMeters ?? 0),
      toDeliver, toPickup, overdue,
      earned: money(earned._sum.amount ?? 0n)!,
      paid: money(-(paid._sum.amount ?? 0n))!,
      due: money(due)!,
    };
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
