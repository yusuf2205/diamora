import { Controller, Delete, Get, Global, HttpCode, Injectable, Logger, Module, OnModuleInit, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import {
  effectivePermissions, listNotificationsSchema, markNotificationsReadSchema, pushTokenSchema, scopeFor,
  type Permission, type RealtimeEnvelope, type Role, type WorkerCategory,
} from '@diamoraa/shared';
import { z } from 'zod';
import { ApiZodBody, Authenticated, CurrentUser } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import { PushService } from './push.service';
import { materialUsage, RUNOUT_WARN_DAYS } from '../stock/forecast';

interface Notice { type: string; title: string; body?: string | null; link?: string | null; dedupe?: string }

const TASHKENT_MS = 5 * 3600_000;
const sum = (v: bigint | string | number) => String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
/** Start of the Tashkent calendar day that contains `d`, as a UTC instant. */
const dayStart = (d: Date) => new Date(Math.floor((d.getTime() + TASHKENT_MS) / 86_400_000) * 86_400_000 - TASHKENT_MS);
const dayKey = (d: Date) => new Date(d.getTime() + TASHKENT_MS).toISOString().slice(0, 10);
const REASON: Record<string, string> = {
  SHORTAGE: 'не хватает материала', WRONG_COLOR: 'неправильный цвет', WRONG_MODEL: 'неправильная модель',
  WRONG_METERS: 'неправильный метраж', DAMAGED: 'повреждение', OTHER: 'другое',
};
const ACTIVE = ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS'] as const;

/**
 * Everything people must know arrives IN THE APP (bell + Android notification), not in Telegram: one `notifications` row
 * (channel APP) per recipient, then `notification.created` to exactly that user. Recipients follow the same rules as the
 * data itself: a worker only about her own work, a MANAGER only about her own workers, inventory/finance notices only
 * to people holding those permissions. Event-driven notices hook into EventBus.publish (after COMMIT, in whichever
 * process published); time-driven ones (deadlines, overdue, the evening summary, weekly/monthly reports) come from
 * `tick()`, run by the worker process every few minutes and made idempotent by `dedupeKey`.
 */
@Injectable()
export class AppNotifier implements OnModuleInit {
  private readonly log = new Logger('AppNotifier');
  constructor(private readonly prisma: PrismaService, private readonly bus: EventBus, private readonly push: PushService) {}

  onModuleInit() { this.bus.onPublished((e) => this.handle(e)); }

  // ---- delivery --------------------------------------------------------------------------------------------------------
  async notify(userIds: (string | null | undefined)[], n: Notice) {
    for (const userId of new Set(userIds.filter((x): x is string => !!x))) {
      try {
        const row = await this.prisma.notification.create({
          data: {
            channel: 'APP', status: 'SENT', sentAt: new Date(), userId, type: n.type, title: n.title, body: n.body ?? null, link: n.link ?? null,
            dedupeKey: n.dedupe ? `${n.dedupe}:${userId}` : null,
          },
        });
        await this.bus.publish('notification.created', { userId, notificationId: row.id, title: n.title, body: n.body ?? null, link: n.link ?? null });
        // instantly to her phone too, even with the app closed (no-op without Firebase credentials)
        void this.push.send(userId, { id: row.id, title: n.title, body: n.body, link: n.link });
      } catch (e) {
        if ((e as { code?: string }).code !== 'P2002') this.log.warn(`notify ${n.type}: ${(e as Error).message}`); // P2002 = already sent (dedupe)
      }
    }
  }

  /** Active staff who may see this worker's data of `cat` (all of it, or she is their own worker). */
  async staffFor(cat: WorkerCategory, managerId: string | null | undefined) {
    return (await this.staff()).filter((u) => {
      const s = scopeFor(u.perms, cat);
      return s === 'all' || (s === 'assigned' && u.id === managerId);
    }).map((u) => u.id);
  }
  async staffWith(perms: Permission[]) {
    return (await this.staff()).filter((u) => perms.some((p) => u.perms.includes(p))).map((u) => u.id);
  }
  private async staff() {
    const rows = await this.prisma.user.findMany({ where: { status: 'ACTIVE', role: { in: ['SUPER_ADMIN', 'ADMIN', 'MANAGER'] } }, include: { permissions: true } });
    return rows.map((u) => ({ id: u.id, perms: effectivePermissions(u.role as Role, u.permissions) }));
  }
  private async workerUser(workerId: string) {
    return (await this.prisma.workerProfile.findUnique({ where: { id: workerId }, select: { userId: true, fullName: true, assignedManagerId: true } })) ?? null;
  }
  private async assignment(id: string) {
    return this.prisma.workAssignment.findUnique({
      where: { id },
      include: { productModel: { select: { name: true } }, color: { select: { name: true } }, worker: { select: { userId: true, fullName: true, assignedManagerId: true } } },
    });
  }

  // ---- event-driven ----------------------------------------------------------------------------------------------------
  async handle(e: RealtimeEnvelope) {
    if (e.type === 'notification.created') return;
    try {
      await this.route(e);
    } catch (err) {
      this.log.warn(`${e.type}: ${(err as Error).message}`); // a notice must never break the business action that caused it
    }
  }

  private async route(e: RealtimeEnvelope) {
    const d = e.data as Record<string, unknown>;
    switch (e.type) {
      case 'assignment.created': {
        const a = await this.assignment(d.assignmentId as string);
        if (a) await this.notify([a.worker.userId], { type: e.type, title: 'Вас ожидает новая работа', body: `${a.productModel.name} · ${a.color.name} · ${Number(a.plannedMeters)} м`, link: '/worker/home' });
        return;
      }
      case 'handoff.started': {
        const w = await this.workerUser(d.workerId as string);
        await this.notify([w?.userId], { type: e.type, title: 'Сотрудник передаёт вам комплект', body: 'Откройте Diamoraa и отсканируйте QR на комплекте', link: '/worker/home' });
        return;
      }
      case 'handoff.confirmed': case 'handoff.problem': case 'work.ready_for_pickup': {
        const a = await this.assignment(d.assignmentId as string);
        if (!a) return;
        const who = a.worker.fullName;
        const n: Notice = e.type === 'handoff.confirmed'
          ? { type: e.type, title: `${who} получила комплект`, body: `${a.productModel.name} · ${Number(a.plannedMeters)} м`, link: `/admin/assignments/${a.id}` }
          : e.type === 'handoff.problem'
            ? { type: e.type, title: `${who}: проблема при получении`, body: REASON[d.reason as string] ?? '', link: `/admin/assignments/${a.id}` }
            : { type: e.type, title: `${who}: работа готова`, body: `${a.productModel.name} · ${d.meters} м — можно забирать`, link: `/admin/assignments/${a.id}` };
        await this.notify(await this.staffFor('ASSIGNMENT', a.worker.assignedManagerId), n);
        return;
      }
      case 'quality.completed': {
        if (d.result === 'ACCEPTED') return; // the earning notice says it all
        const w = await this.workerUser(d.workerId as string);
        await this.notify([w?.userId], {
          type: e.type, link: '/worker/home',
          title: d.result === 'REWORK_REQUIRED' ? 'Работу нужно доработать' : 'Работа принята частично',
          body: d.result === 'REWORK_REQUIRED' ? 'Сотрудник вернул работу на доработку' : `Принято ${d.acceptedMeters} м`,
        });
        return;
      }
      case 'earning.created': {
        const w = await this.workerUser(d.workerId as string);
        await this.notify([w?.userId], { type: e.type, title: 'Работу приняли', body: `Начислено ${sum(d.amount as string)} сум`, link: '/worker/home' });
        return;
      }
      case 'cash_payment.created': {
        const w = await this.workerUser(d.workerId as string);
        await this.notify([w?.userId], { type: e.type, title: `Вам выплатили ${sum(d.amount as string)} сум`, body: 'Наличными', link: '/worker/home' });
        return;
      }
      case 'job_request.created': {
        const r = await this.prisma.workerJobRequest.findUnique({ where: { id: d.requestId as string }, include: { worker: true } });
        if (!r) return;
        const model = r.productModelId ? await this.prisma.productModel.findUnique({ where: { id: r.productModelId }, select: { name: true } }) : null;
        await this.notify(await this.staffFor('ASSIGNMENT', r.worker.assignedManagerId), {
          type: e.type, title: 'Новая заявка на работу', body: `${r.worker.fullName}: ${model?.name ?? 'работа'} · ${r.kitCount * 9} м`, link: '/admin/job-requests',
        });
        return;
      }
      case 'job_request.decided': {
        if (d.status !== 'REJECTED') return;
        const r = await this.prisma.workerJobRequest.findUnique({ where: { id: d.requestId as string }, include: { worker: { select: { userId: true } } } });
        if (r) await this.notify([r.worker.userId], { type: e.type, title: 'Заявка на работу не принята', body: r.decisionNote ?? 'Выберите другую работу', link: '/worker/home' });
        return;
      }
      case 'worker.created': {
        const w = await this.workerUser(d.workerId as string);
        const invited = d.status === 'ACTIVE';
        await this.notify(await this.staffFor('WORKER', w?.assignedManagerId), {
          type: e.type, title: invited ? `${d.fullName} пришла по приглашению` : 'Новая регистрация мастерицы', body: invited ? 'Уже в команде' : `${d.fullName} ждёт одобрения`,
          link: `/admin/workers/${d.workerId}`,
        });
        return;
      }
      case 'stock.updated': {
        if (!d.low) return;
        const m = await this.prisma.material.findUnique({ where: { id: d.materialId as string } });
        if (!m) return;
        await this.notify(await this.staffWith(['INVENTORY_MANAGE', 'INVENTORY_VIEW']), {
          type: 'stock.low', title: `Заканчивается: ${m.name}`, body: `Осталось ${Number(d.quantity)} (минимум ${Number(m.minStock)})`, link: '/admin/inventory',
          dedupe: `lowstock:${m.id}:${dayKey(new Date())}`,
        });
        return;
      }
      default:
        return;
    }
  }

  /**
   * «Скоро закончится»: a material that, at the pace of the last 30 days, lasts a week or less - even when its minimum is 0
   * (the «ниже минимума» notice alone never fired then). Once a week per material.
   */
  async runningOut(now = new Date()) {
    const mats = await this.prisma.material.findMany({ where: { isActive: true, deletedAt: null }, include: { balance: true } });
    if (!mats.length) return;
    const qty = new Map(mats.map((m) => [m.id, Number(m.balance?.quantity ?? 0)]));
    const usage = await materialUsage(this.prisma, qty, now);
    const week = Math.floor(new Date(dayKey(now)).getTime() / (7 * 86_400_000));
    let staff: string[] | null = null;
    for (const m of mats) {
      const u = usage.get(m.id);
      const left = qty.get(m.id) ?? 0;
      if (!u || u.daysLeft === null || u.daysLeft > RUNOUT_WARN_DAYS) continue;
      if (left < Number(m.minStock)) continue; // «Заканчивается (ниже минимума)» already covers it
      staff ??= await this.staffWith(['INVENTORY_MANAGE', 'INVENTORY_VIEW']);
      const unit = ({ METER: 'м', GRAM: 'г', PCS: 'шт', SET: 'компл.', ROLL: 'рул.', PACKAGE: 'уп.' } as Record<string, string>)[m.unit] ?? '';
      await this.notify(staff, left <= 0
        ? { type: 'stock.runout', title: `Закончился: ${m.name}`, body: 'Его берут в работу каждый день — пора закупить', link: '/admin/inventory', dedupe: `runout:${m.id}:${week}` }
        : { type: 'stock.runout', title: `Скоро закончится: ${m.name}`, body: `Осталось ${left} ${unit} — хватит примерно на ${u.daysLeft} дн.`, link: '/admin/inventory', dedupe: `runout:${m.id}:${week}` });
    }
  }

  // ---- time-driven (worker process, every few minutes) -----------------------------------------------------------------
  async tick(now = new Date()) {
    await this.runningOut(now);
    const today = dayStart(now);
    const tomorrow = new Date(today.getTime() + 86_400_000);
    const after = new Date(tomorrow.getTime() + 86_400_000);
    const open = await this.prisma.workAssignment.findMany({
      where: { status: { in: [...ACTIVE] }, dueAt: { not: null, lt: after } },
      include: { productModel: { select: { name: true } }, worker: { select: { userId: true, fullName: true, assignedManagerId: true } } },
    });
    for (const a of open) {
      const due = a.dueAt!;
      const what = `${a.productModel.name} · готово ${Number(a.reportedMeters)} из ${Number(a.plannedMeters)} м`;
      if (due >= tomorrow) {
        await this.notify([a.worker.userId], { type: 'due.tomorrow', title: 'Завтра срок сдачи', body: what, link: '/worker/home', dedupe: `due1:${a.id}` });
      } else if (due >= today) {
        await this.notify([a.worker.userId], { type: 'due.today', title: 'Сегодня срок сдачи', body: what, link: '/worker/home', dedupe: `due0:${a.id}` });
      } else {
        await this.notify(await this.staffFor('ASSIGNMENT', a.worker.assignedManagerId), {
          type: 'assignment.overdue', title: `Просрочена работа: ${a.worker.fullName}`, body: what, link: `/admin/assignments/${a.id}`, dedupe: `overdue:${a.id}`,
        });
      }
    }

    const local = new Date(now.getTime() + TASHKENT_MS);
    const owners = () => this.staffWith(['PROFIT_VIEW', 'FINANCE_VIEW_ALL']);
    if (local.getUTCHours() >= 20) {
      const s = await this.daySummary(today, tomorrow);
      await this.notify(await owners(), {
        type: 'summary.daily', title: 'Итоги дня', link: '/admin/reports?period=day',
        body: `Выдано ${s.issued} (${s.issuedMeters} м) · сдано ${s.accepted} (${s.acceptedMeters} м) · выплачено ${sum(s.paid)} сум`,
        dedupe: `summary:${dayKey(now)}`,
      });
    }
    if (local.getUTCHours() >= 9 && local.getUTCDay() === 1) {
      await this.notify(await owners(), { type: 'report.weekly', title: 'Отчёт за неделю готов', body: 'Выпуск, выплаты и остатки за прошлую неделю', link: '/admin/reports?period=week&offset=-1', dedupe: `weekly:${dayKey(now)}` });
    }
    if (local.getUTCHours() >= 9 && local.getUTCDate() === 1) {
      await this.notify(await owners(), { type: 'report.monthly', title: 'Отчёт за месяц готов', body: 'Выпуск, выплаты и остатки за прошлый месяц', link: '/admin/reports?period=month&offset=-1', dedupe: `monthly:${dayKey(now)}` });
    }
  }

  private async daySummary(from: Date, to: Date) {
    const [issued, accepted, paid] = await Promise.all([
      this.prisma.workAssignment.findMany({ where: { createdAt: { gte: from, lt: to } }, select: { plannedMeters: true } }),
      this.prisma.qualityInspection.findMany({ where: { inspectedAt: { gte: from, lt: to } }, select: { acceptedMeters: true } }),
      this.prisma.workerLedgerTransaction.aggregate({ _sum: { amount: true }, where: { type: 'PAYOUT_CASH', createdAt: { gte: from, lt: to } } }),
    ]);
    return {
      issued: issued.length, issuedMeters: issued.reduce((s, a) => s + Number(a.plannedMeters), 0),
      accepted: accepted.length, acceptedMeters: accepted.reduce((s, a) => s + Number(a.acceptedMeters), 0),
      paid: -(paid._sum.amount ?? 0n),
    };
  }

  // ---- the bell ----------------------------------------------------------------------------------------------------------
  async list(user: AuthUser, q: z.output<typeof listNotificationsSchema>) {
    const [items, unread] = await Promise.all([
      this.prisma.notification.findMany({
        where: { channel: 'APP', userId: user.id, createdAt: q.since ? { gt: q.since } : undefined }, orderBy: { createdAt: 'desc' }, take: q.limit,
      }),
      this.prisma.notification.count({ where: { channel: 'APP', userId: user.id, readAt: null } }),
    ]);
    return {
      unread,
      items: items.map((n) => ({ id: n.id, type: n.type, title: n.title, body: n.body, link: n.link, read: n.readAt != null, createdAt: n.createdAt.toISOString() })),
    };
  }

  async markRead(user: AuthUser, b: z.output<typeof markNotificationsReadSchema>) {
    await this.prisma.notification.updateMany({
      where: { channel: 'APP', userId: user.id, readAt: null, ...(b.all ? {} : { id: { in: b.ids ?? [] } }) },
      data: { readAt: new Date() },
    });
    return { unread: await this.prisma.notification.count({ where: { channel: 'APP', userId: user.id, readAt: null } }) };
  }
}

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('me/notifications')
export class AppNotificationsController {
  constructor(private readonly notifier: AppNotifier) {}

  @Authenticated() @Get()
  list(@CurrentUser() u: AuthUser, @ZodQuery(listNotificationsSchema) q: z.output<typeof listNotificationsSchema>) { return this.notifier.list(u, q); }

  @Authenticated() @Post('read') @HttpCode(200) @ApiZodBody(markNotificationsReadSchema)
  read(@CurrentUser() u: AuthUser, @ZodBody(markNotificationsReadSchema) b: z.output<typeof markNotificationsReadSchema>) { return this.notifier.markRead(u, b); }
}

/** «This phone gets instant notifications»: the app registers its Firebase token after sign-in, removes it on sign-out. */
@ApiTags('notifications')
@ApiBearerAuth()
@Controller('me/push-token')
export class PushTokenController {
  constructor(private readonly push: PushService) {}

  @Authenticated() @Post() @HttpCode(200) @ApiZodBody(pushTokenSchema)
  register(@CurrentUser() u: AuthUser, @ZodBody(pushTokenSchema) b: z.output<typeof pushTokenSchema>) { return this.push.register(u.id, b.token, b.platform); }

  @Authenticated() @Delete() @HttpCode(200) @ApiZodBody(pushTokenSchema)
  unregister(@CurrentUser() u: AuthUser, @ZodBody(pushTokenSchema) b: z.output<typeof pushTokenSchema>) { return this.push.unregister(u.id, b.token); }
}

/** The notifier itself runs in every process that publishes events (API and bot worker). */
@Global()
@Module({ providers: [AppNotifier, PushService], exports: [AppNotifier, PushService] })
export class AppNotifierModule {}

/** The bell endpoints (API process only). */
@Module({ controllers: [AppNotificationsController, PushTokenController] })
export class AppNotificationsApiModule {}

