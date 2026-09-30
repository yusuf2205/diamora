import { Controller, Get, Injectable, Module, Param, ParseUUIDPipe, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { workerScope } from '../common/scope';
import { ZodBody } from '../common/zod.pipe';
import { AppNotifier } from '../notifications/app-notifier';
import { PrismaService } from '../prisma/prisma.module';
import { periodRange } from '../reports/reports.service';

const metersSchema = z.object({ monthlyMeters: z.coerce.number().int().min(0).max(100_000) });
/** null = back to the common goal */
const workerGoalSchema = z.object({ monthlyMeters: z.coerce.number().int().min(0).max(100_000).nullable() });

export interface Badge { code: string; title: string; hint: string; earned: boolean }

/**
 * «Цель месяца» for workers - NOT money (owner's decision): a goal in metres, how far she is, her place among the others
 * this month, and badges for real milestones. Any cash bonus stays a manual admin action.
 */
@Injectable()
export class GoalsService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  async settings() {
    const s = await this.prisma.goalSettings.findUnique({ where: { id: 1 } });
    return { monthlyMeters: s?.monthlyMeters ?? 0 };
  }

  async setCommon(actor: AuthUser, monthlyMeters: number) {
    const before = await this.settings();
    await this.prisma.goalSettings.upsert({ where: { id: 1 }, create: { id: 1, monthlyMeters, updatedById: actor.id }, update: { monthlyMeters, updatedById: actor.id } });
    await this.audit.record({ action: 'goals.common', entity: 'GoalSettings', entityId: null, before, after: { monthlyMeters } });
    return { monthlyMeters };
  }

  async setForWorker(actor: AuthUser, workerId: string, monthlyMeters: number | null) {
    const { where: scope } = workerScope(actor, 'WORKER');
    const w = await this.prisma.workerProfile.findFirst({ where: { ...scope, id: workerId, deletedAt: null }, select: { id: true, monthlyGoalMeters: true } });
    if (!w) throw notFound('Worker');
    await this.prisma.workerProfile.update({ where: { id: workerId }, data: { monthlyGoalMeters: monthlyMeters } });
    await this.audit.record({ action: 'goals.worker', entity: 'WorkerProfile', entityId: workerId, before: { monthlyGoalMeters: w.monthlyGoalMeters }, after: { monthlyGoalMeters: monthlyMeters } });
    return this.forWorker(workerId);
  }

  /** Accepted metres per worker this month (the same numbers as the rating). */
  private async monthMeters(from: Date) {
    const rows = await this.prisma.$queryRaw<{ workerId: string; accepted: string; defective: string }[]>`
      SELECT a."workerId", COALESCE(SUM(q."acceptedMeters"), 0)::text AS accepted, COALESCE(SUM(q."defectiveMeters"), 0)::text AS defective
      FROM quality_inspections q JOIN work_assignments a ON a.id = q."assignmentId"
      WHERE q."inspectedAt" >= ${from}
      GROUP BY a."workerId"`;
    return new Map(rows.map((r) => [r.workerId, { accepted: Number(r.accepted), defective: Number(r.defective) }]));
  }

  /** What the worker sees on «Главная»: the goal, progress, her place, badges. */
  async forWorker(workerId: string, now = new Date()) {
    const { from, to } = periodRange('month', 0, now);
    const [me, common, month, lifetime, lateRows] = await Promise.all([
      this.prisma.workerProfile.findUniqueOrThrow({ where: { id: workerId }, select: { monthlyGoalMeters: true } }),
      this.settings(),
      this.monthMeters(from),
      this.prisma.$queryRaw<{ accepted: string }[]>`
        SELECT COALESCE(SUM(q."acceptedMeters"), 0)::text AS accepted FROM quality_inspections q JOIN work_assignments a ON a.id = q."assignmentId" WHERE a."workerId" = ${workerId}::uuid`,
      this.prisma.$queryRaw<{ late: bigint; total: bigint }[]>`
        SELECT COUNT(*) FILTER (WHERE r.ready_at > a."dueAt") AS late, COUNT(*) AS total
        FROM work_assignments a
        JOIN LATERAL (SELECT MIN(h."changedAt") AS ready_at FROM work_assignment_status_history h
                      WHERE h."assignmentId" = a.id AND h."toStatus" = 'READY_FOR_PICKUP') r ON r.ready_at IS NOT NULL
        WHERE a."workerId" = ${workerId}::uuid AND a."dueAt" IS NOT NULL AND r.ready_at >= ${from}`,
    ]);
    const goal = me.monthlyGoalMeters ?? common.monthlyMeters;
    const mine = month.get(workerId) ?? { accepted: 0, defective: 0 };
    const done = mine.accepted;
    // her place among the workers who made something this month (1 = the most metres); others' names are never shown
    const ranked = [...month.values()].map((v) => v.accepted).filter((v) => v > 0).sort((a, b) => b - a);
    const place = done > 0 ? ranked.findIndex((v) => v <= done) + 1 : null;
    const total = Number(lifetime[0]?.accepted ?? 0);
    const late = Number(lateRows[0]?.late ?? 0n);
    const onTimeWorks = Number(lateRows[0]?.total ?? 0n);
    const daysLeft = Math.max(0, Math.ceil((to.getTime() - now.getTime()) / 86_400_000));
    const badges: Badge[] = [
      { code: 'first_kit', title: 'Первый комплект', hint: 'Сдать первые 9 м', earned: total >= 9 },
      { code: 'm100', title: '100 метров', hint: `Всего принято ${total} из 100 м`, earned: total >= 100 },
      { code: 'm500', title: '500 метров', hint: `Всего принято ${total} из 500 м`, earned: total >= 500 },
      { code: 'goal', title: 'Цель месяца', hint: goal > 0 ? `${done} из ${goal} м в этом месяце` : 'Цель пока не задана', earned: goal > 0 && done >= goal },
      { code: 'no_defects', title: 'Без брака', hint: 'Месяц без брака (от 9 м)', earned: done >= 9 && mine.defective === 0 },
      { code: 'on_time', title: 'Всё вовремя', hint: 'Все работы месяца готовы к сроку', earned: onTimeWorks > 0 && late === 0 },
    ];
    return {
      month: from.toISOString(), goalMeters: goal, personal: me.monthlyGoalMeters !== null, doneMeters: done,
      leftMeters: goal > 0 ? Math.max(0, goal - done) : null, percent: goal > 0 ? Math.min(100, Math.round((done / goal) * 100)) : null,
      daysLeft, place, of: ranked.length, totalMeters: total, badges,
    };
  }

  /** Staff: a worker's goal card, only for workers this staff member may see. */
  async forStaff(actor: AuthUser, workerId: string) {
    const { where: scope } = workerScope(actor, 'WORKER');
    if (!(await this.prisma.workerProfile.findFirst({ where: { ...scope, id: workerId, deletedAt: null }, select: { id: true } }))) throw notFound('Worker');
    return this.forWorker(workerId);
  }

  /** «Цель месяца выполнена!» once a month per worker (worker process, every few minutes). */
  async congratulate(notifier: AppNotifier, now = new Date()) {
    for (const w of await this.reached(now)) {
      await notifier.notify([w.userId], {
        type: 'goal.reached', title: 'Цель месяца выполнена! 🎉', body: `${w.done} м из ${w.goal} м. Спасибо за работу!`, link: '/worker/home',
        dedupe: `goal:${w.workerId}:${w.month}`,
      });
    }
  }

  /** Workers who reached their goal this month and have not been congratulated yet (the notifier sends it). */
  async reached(now = new Date()) {
    const { from } = periodRange('month', 0, now);
    const [common, month] = await Promise.all([this.settings(), this.monthMeters(from)]);
    if (!month.size) return [];
    const workers = await this.prisma.workerProfile.findMany({ where: { id: { in: [...month.keys()] }, deletedAt: null, userId: { not: null } }, select: { id: true, userId: true, monthlyGoalMeters: true } });
    return workers
      .map((w) => ({ workerId: w.id, userId: w.userId!, goal: w.monthlyGoalMeters ?? common.monthlyMeters, done: month.get(w.id)?.accepted ?? 0, month: from.toISOString().slice(0, 7) }))
      .filter((w) => w.goal > 0 && w.done >= w.goal);
  }
}

@ApiTags('goals')
@ApiBearerAuth()
@Controller()
export class GoalsController {
  constructor(private readonly goals: GoalsService) {}

  @Roles('WORKER') @Get('work/goal')
  mine(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.goals.forWorker(u.workerId);
  }

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('admin/goals')
  settings() { return this.goals.settings(); }

  @Perm('SETTINGS_MANAGE') @Put('admin/goals')
  setCommon(@CurrentUser() u: AuthUser, @ZodBody(metersSchema) b: z.output<typeof metersSchema>) { return this.goals.setCommon(u, b.monthlyMeters); }

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('admin/workers/:id/goal')
  worker(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.goals.forStaff(u, id); }

  @Perm('WORKER_UPDATE') @Put('admin/workers/:id/goal')
  setWorker(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(workerGoalSchema) b: z.output<typeof workerGoalSchema>) {
    return this.goals.setForWorker(u, id, b.monthlyMeters);
  }
}

@Module({ controllers: [GoalsController], providers: [GoalsService], exports: [GoalsService] })
export class GoalsModule {}

/** Worker process: the congratulation check only. */
@Module({ providers: [GoalsService], exports: [GoalsService] })
export class GoalsWorkerModule {}
