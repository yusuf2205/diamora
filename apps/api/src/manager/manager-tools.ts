import { Controller, Delete, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { createWorkerInviteSchema } from '@diamoraa/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { inWorkerScope, workerScope } from '../common/scope';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { AppNotifier } from '../notifications/app-notifier';
import { PrismaService } from '../prisma/prisma.module';
import { WorkersModule, WorkersService } from '../workers/workers.service';

const DAY = 86_400_000;
/** a work still on her hands (anything else: done or cancelled) */
const BUSY = ['DRAFT', 'READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP', 'PICKED_UP', 'UNDER_REVIEW', 'REWORK_REQUIRED'] as const;
const two = (v: number) => String(v).padStart(2, '0');
const TASHKENT_MS = 5 * 3_600_000;
const day = (d: Date) => { const t = new Date(d.getTime() + TASHKENT_MS); return `${two(t.getUTCDate())}.${two(t.getUTCMonth() + 1)}`; };

export const reminderSchema = z.object({
  text: z.string().trim().min(1).max(500),
  dueAt: z.coerce.date(),
  workerId: z.string().uuid().nullish(),
});
export const reminderPatchSchema = z.object({ done: z.boolean().optional(), dueAt: z.coerce.date().optional() });
export const awaySchema = z.object({ substituteId: z.string().uuid(), until: z.coerce.date() });
const managerInviteSchema = createWorkerInviteSchema.omit({ managerId: true });

/** The timed side (worker process): reminders that are due, holidays that ended. Also «Я вернулся» from the app. */
@Injectable()
export class ManagerTicks {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  private async workerNames(ids: (string | null)[]) {
    const list = ids.filter((x): x is string => !!x);
    if (!list.length) return new Map<string, string>();
    return new Map((await this.prisma.workerProfile.findMany({ where: { id: { in: list } }, select: { id: true, fullName: true } })).map((w) => [w.id, w.fullName]));
  }

  /** worker process: the reminders whose time came -> a notification, once */
  async ring(notifier: AppNotifier, now = new Date()) {
    const due = await this.prisma.staffReminder.findMany({ where: { doneAt: null, notifiedAt: null, dueAt: { lte: now } }, take: 200 });
    const names = await this.workerNames(due.map((r) => r.workerId));
    for (const r of due) {
      const who = r.workerId ? names.get(r.workerId) : null;
      await notifier.notify([r.userId], {
        type: 'reminder', title: `⏰ ${who ? `${who}: ` : ''}напоминание`, body: r.text.slice(0, 300),
        link: r.workerId ? `/admin/workers/${r.workerId}` : '/reminders', dedupe: `rem:${r.id}:${r.dueAt.getTime()}`,
      });
      await this.prisma.staffReminder.update({ where: { id: r.id }, data: { notifiedAt: now } });
    }
  }

  /** «Я вернулся» (or the holiday date passed): her workers come back to her */
  async comeBack(userId: string, notifier: AppNotifier) {
    const me = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true, fullName: true, awayUntil: true, awaySubstituteId: true } });
    if (!me?.awayUntil) return;
    const moved = await this.prisma.$transaction(async (tx) => {
      const ws = await tx.workerProfile.findMany({ where: { homeManagerId: userId }, select: { id: true, assignedManagerId: true } });
      await tx.workerProfile.updateMany({ where: { id: { in: ws.map((w) => w.id) } }, data: { assignedManagerId: userId, homeManagerId: null } });
      await tx.user.update({ where: { id: userId }, data: { awayUntil: null, awaySubstituteId: null } });
      await this.audit.record({ action: 'manager.back', entity: 'User', entityId: userId, after: { workers: ws.length } }, tx);
      return ws;
    });
    const back = moved.length;
    // both lists change on the screens at once
    for (const w of moved) await this.events.publish('worker.manager_changed', { workerId: w.id, managerId: userId, previousManagerId: w.assignedManagerId });
    await this.events.publish('user.updated', { userId });
    if (me.awaySubstituteId) {
      await notifier.notify([me.awaySubstituteId], { type: 'manager.cover', title: `${me.fullName} вернулся из отпуска`, body: `Мастерицы (${back}) снова у него. Спасибо!`, link: '/admin/workers' });
    }
    await notifier.notify([userId], { type: 'manager.cover', title: 'С возвращением!', body: `Ваши мастерицы снова у вас: ${back}`, link: '/admin/workers' });
  }

  /** worker process: holidays that ended */
  async endHolidays(notifier: AppNotifier, now = new Date()) {
    for (const u of await this.prisma.user.findMany({ where: { awayUntil: { lte: now } }, select: { id: true } })) await this.comeBack(u.id, notifier);
  }

}

/**
 * Managers' everyday tools (owner, 2026-10-11): «Кто простаивает» (her workers without work, longest first), «Напоминания
 * себе», «Замена на время отпуска» (her workers go to another manager until a date and come back by themselves), and
 * inviting a new worker on the spot (still approved by an admin).
 */
@Injectable()
export class ManagerToolsService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly workers: WorkersService, private readonly ticks: ManagerTicks, private readonly events: EventBus) {}

  // ---- «Кто простаивает» --------------------------------------------------------------------------------------------------
  async idle(actor: AuthUser, now = new Date()) {
    const { where: scope } = workerScope(actor, 'WORKER');
    const workers = await this.prisma.workerProfile.findMany({
      where: { ...scope, status: 'ACTIVE', deletedAt: null },
      select: { id: true, fullName: true, code: true, phone: true, approvedAt: true, createdAt: true },
    });
    if (!workers.length) return { items: [] };
    const ids = workers.map((w) => w.id);
    const [busy, last, quality, asks] = await Promise.all([
      this.prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: ids }, status: { in: [...BUSY] } }, _count: { _all: true } }),
      this.prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: ids } }, _max: { updatedAt: true } }),
      this.prisma.$queryRaw<{ workerId: string; accepted: string; defective: string }[]>`
        SELECT a."workerId", COALESCE(SUM(q."acceptedMeters"), 0)::text AS accepted, COALESCE(SUM(q."defectiveMeters"), 0)::text AS defective
        FROM quality_inspections q JOIN work_assignments a ON a.id = q."assignmentId"
        WHERE q."inspectedAt" >= ${new Date(now.getTime() - 90 * DAY)} AND a."workerId" = ANY(${ids}::uuid[])
        GROUP BY a."workerId"`,
      this.prisma.workerJobRequest.findMany({ where: { workerId: { in: ids }, status: 'PENDING' }, select: { workerId: true } }),
    ]);
    const busyIds = new Set(busy.map((b) => b.workerId));
    const lastAt = new Map(last.map((l) => [l.workerId, l._max.updatedAt]));
    const q = new Map(quality.map((x) => [x.workerId, x]));
    const wants = new Set(asks.map((a) => a.workerId));
    const items = workers.filter((w) => !busyIds.has(w.id)).map((w) => {
      const since = lastAt.get(w.id) ?? w.approvedAt ?? w.createdAt;
      const r = q.get(w.id);
      const acc = Number(r?.accepted ?? 0), def = Number(r?.defective ?? 0);
      return {
        workerId: w.id, fullName: w.fullName, code: w.code, phone: w.phone,
        idleSince: since.toISOString(), idleDays: Math.max(0, Math.floor((now.getTime() - since.getTime()) / DAY)),
        everWorked: lastAt.has(w.id), wantsWork: wants.has(w.id),
        qualityPercent: acc + def > 0 ? Math.round((acc / (acc + def)) * 1000) / 10 : null,
      };
    });
    // the ones asking for work first, then the longest without it
    items.sort((a, b) => Number(b.wantsWork) - Number(a.wantsWork) || b.idleDays - a.idleDays);
    return { items };
  }

  // ---- «Напоминания себе» ------------------------------------------------------------------------------------------------
  async reminders(actor: AuthUser) {
    const rows = await this.prisma.staffReminder.findMany({
      where: { userId: actor.id, OR: [{ doneAt: null }, { doneAt: { gt: new Date(Date.now() - 7 * DAY) } }] }, orderBy: [{ doneAt: { sort: 'asc', nulls: 'first' } }, { dueAt: 'asc' }], take: 200,
    });
    const names = await this.workerNames(rows.map((r) => r.workerId));
    return { items: rows.map((r) => this.reminderDto(r, names)) };
  }

  private async workerNames(ids: (string | null)[]) {
    const list = ids.filter((x): x is string => !!x);
    if (!list.length) return new Map<string, string>();
    return new Map((await this.prisma.workerProfile.findMany({ where: { id: { in: list } }, select: { id: true, fullName: true } })).map((w) => [w.id, w.fullName]));
  }

  private reminderDto(r: { id: string; text: string; dueAt: Date; workerId: string | null; doneAt: Date | null; notifiedAt: Date | null }, names: Map<string, string>) {
    return { id: r.id, text: r.text, dueAt: r.dueAt.toISOString(), done: !!r.doneAt, notified: !!r.notifiedAt, worker: r.workerId ? { id: r.workerId, fullName: names.get(r.workerId) ?? '' } : null };
  }

  async addReminder(actor: AuthUser, b: z.output<typeof reminderSchema>) {
    if (b.workerId) {
      const w = await this.prisma.workerProfile.findFirst({ where: { id: b.workerId, deletedAt: null }, select: { assignedManagerId: true } });
      if (!w || !inWorkerScope(actor, 'WORKER', w)) throw notFound('Worker');
    }
    const r = await this.prisma.staffReminder.create({ data: { userId: actor.id, text: b.text, dueAt: b.dueAt, workerId: b.workerId ?? null } });
    await this.events.publish('reminder.changed', { userId: actor.id });
    return this.reminderDto(r, await this.workerNames([r.workerId]));
  }

  async patchReminder(actor: AuthUser, id: string, b: z.output<typeof reminderPatchSchema>) {
    const r = await this.prisma.staffReminder.findFirst({ where: { id, userId: actor.id } });
    if (!r) throw notFound('Reminder');
    const next = await this.prisma.staffReminder.update({
      where: { id },
      data: {
        ...(b.done === undefined ? {} : { doneAt: b.done ? new Date() : null }),
        // moved to another time: it rings again then
        ...(b.dueAt ? { dueAt: b.dueAt, notifiedAt: null } : {}),
      },
    });
    await this.events.publish('reminder.changed', { userId: actor.id });
    return this.reminderDto(next, await this.workerNames([next.workerId]));
  }

  async deleteReminder(actor: AuthUser, id: string) {
    const r = await this.prisma.staffReminder.deleteMany({ where: { id, userId: actor.id } });
    if (!r.count) throw notFound('Reminder');
    await this.events.publish('reminder.changed', { userId: actor.id });
    return { ok: true };
  }

  // ---- «Замена на время отпуска» -----------------------------------------------------------------------------------------
  async away(actor: AuthUser) {
    const [me, mine, covering, managers] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: actor.id }, select: { awayUntil: true, awaySubstituteId: true } }),
      this.prisma.workerProfile.count({ where: { deletedAt: null, OR: [{ assignedManagerId: actor.id, homeManagerId: null }, { homeManagerId: actor.id }] } }),
      this.prisma.workerProfile.groupBy({ by: ['homeManagerId'], where: { assignedManagerId: actor.id, homeManagerId: { not: null }, deletedAt: null }, _count: { _all: true } }),
      this.prisma.user.findMany({ where: { role: 'MANAGER', status: 'ACTIVE' }, select: { id: true, fullName: true, awayUntil: true }, orderBy: { fullName: 'asc' } }),
    ]);
    const byId = new Map(managers.map((m) => [m.id, m]));
    const sub = me.awaySubstituteId ? await this.prisma.user.findUnique({ where: { id: me.awaySubstituteId }, select: { id: true, fullName: true } }) : null;
    return {
      away: !!me.awayUntil, until: me.awayUntil?.toISOString() ?? null, substitute: sub, myWorkers: mine,
      /** colleagues on holiday whose workers I look after now */
      covering: covering.map((c) => ({ manager: { id: c.homeManagerId!, fullName: byId.get(c.homeManagerId!)?.fullName ?? '' }, until: byId.get(c.homeManagerId!)?.awayUntil?.toISOString() ?? null, workers: c._count._all })),
      substitutes: managers.filter((m) => m.id !== actor.id && !m.awayUntil).map((m) => ({ id: m.id, fullName: m.fullName })),
    };
  }

  async goAway(actor: AuthUser, notifier: AppNotifier, b: z.output<typeof awaySchema>) {
    if (b.until.getTime() <= Date.now()) throw invariant('The holiday must end in the future');
    if (b.until.getTime() > Date.now() + 120 * DAY) throw invariant('At most 120 days');
    const sub = await this.prisma.user.findUnique({ where: { id: b.substituteId }, select: { id: true, role: true, status: true, awayUntil: true, fullName: true } });
    if (!sub || sub.id === actor.id || sub.role !== 'MANAGER' || sub.status !== 'ACTIVE' || sub.awayUntil) throw invariant('Pick an active manager who is not on holiday');
    const movedIds = await this.prisma.$transaction(async (tx) => {
      const me = await tx.user.findUniqueOrThrow({ where: { id: actor.id }, select: { awayUntil: true } });
      if (me.awayUntil) throw invariant('Already on holiday');
      const ws = await tx.workerProfile.findMany({ where: { assignedManagerId: actor.id, homeManagerId: null, deletedAt: null }, select: { id: true } });
      await tx.workerProfile.updateMany({ where: { id: { in: ws.map((w) => w.id) } }, data: { assignedManagerId: sub.id, homeManagerId: actor.id } });
      await tx.user.update({ where: { id: actor.id }, data: { awayUntil: b.until, awaySubstituteId: sub.id } });
      await this.audit.record({ action: 'manager.away', entity: 'User', entityId: actor.id, after: { substituteId: sub.id, until: b.until.toISOString(), workers: ws.length } }, tx);
      return ws.map((w) => w.id);
    });
    for (const id of movedIds) await this.events.publish('worker.manager_changed', { workerId: id, managerId: sub.id, previousManagerId: actor.id });
    await this.events.publish('user.updated', { userId: actor.id });
    const moved = movedIds.length;
    await notifier.notify([sub.id], {
      type: 'manager.cover', title: `Вам переданы мастерицы: ${moved}`, link: '/admin/workers',
      body: `${actor.fullName} в отпуске до ${day(b.until)} — его мастерицы пока у вас. Потом они вернутся сами.`,
    });
    return this.away(actor);
  }

  // ---- a new worker on the spot (MANAGER): the invitation QR on her phone; an admin approves her afterwards -------------
  managerInvites(actor: AuthUser) { return this.workers.listInvites(actor.id); }
  managerInvite(actor: AuthUser, b: z.output<typeof managerInviteSchema>) { return this.workers.createInvite(actor, { ...b, managerId: actor.id }, { needsApproval: true }); }
  managerRevoke(actor: AuthUser, id: string) { return this.workers.revokeInvite(id, actor.id); }
}

@ApiTags('manager')
@ApiBearerAuth()
@Controller()
export class ManagerToolsController {
  constructor(private readonly tools: ManagerToolsService, private readonly ticks: ManagerTicks, private readonly notifier: AppNotifier) {}

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('admin/workers-idle')
  idle(@CurrentUser() u: AuthUser) { return this.tools.idle(u); }

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Get('me/reminders')
  reminders(@CurrentUser() u: AuthUser) { return this.tools.reminders(u); }

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Post('me/reminders')
  addReminder(@CurrentUser() u: AuthUser, @ZodBody(reminderSchema) b: z.output<typeof reminderSchema>) { return this.tools.addReminder(u, b); }

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Patch('me/reminders/:id')
  patchReminder(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(reminderPatchSchema) b: z.output<typeof reminderPatchSchema>) { return this.tools.patchReminder(u, id, b); }

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Delete('me/reminders/:id') @HttpCode(200)
  deleteReminder(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.tools.deleteReminder(u, id); }

  @Roles('MANAGER') @Get('me/away')
  away(@CurrentUser() u: AuthUser) { return this.tools.away(u); }

  @Roles('MANAGER') @Post('me/away') @HttpCode(200)
  goAway(@CurrentUser() u: AuthUser, @ZodBody(awaySchema) b: z.output<typeof awaySchema>) { return this.tools.goAway(u, this.notifier, b); }

  @Roles('MANAGER') @Post('me/back') @HttpCode(200)
  async back(@CurrentUser() u: AuthUser) { await this.ticks.comeBack(u.id, this.notifier); return this.tools.away(u); }

  @Roles('MANAGER') @Get('me/invitations')
  invites(@CurrentUser() u: AuthUser) { return this.tools.managerInvites(u); }

  @Roles('MANAGER') @Post('me/invitations')
  invite(@CurrentUser() u: AuthUser, @ZodBody(managerInviteSchema) b: z.output<typeof managerInviteSchema>) { return this.tools.managerInvite(u, b); }

  @Roles('MANAGER') @Delete('me/invitations/:id') @HttpCode(200)
  revoke(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.tools.managerRevoke(u, id); }
}

@Module({ imports: [WorkersModule], controllers: [ManagerToolsController], providers: [ManagerToolsService, ManagerTicks] })
export class ManagerToolsModule {}

/** Worker process: reminders and holiday ends only. */
@Module({ providers: [ManagerTicks], exports: [ManagerTicks] })
export class ManagerTicksModule {}
