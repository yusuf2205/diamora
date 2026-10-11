import { Injectable, Module } from '@nestjs/common';
import {
  COLLATERAL_MACHINE, WORKER_MACHINE, assertTransition, effectivePermissions, type CollateralStatus, type Role, type WorkerStatus,
  type approveWorkerSchema, type rejectWorkerSchema,
} from '@diamoraa/shared';
import type { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { conflict, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { assertWorkerInScope } from '../common/scope';
import { generateQrCode, lockRow } from '../common/sequence';
import { money } from '../common/serialize';
import { EventBus } from '../events/event-bus';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.module';
import { appDownloadUrl } from '../registration/texts';

export const APPROVE_CALLBACK = /^wa:(ok|okc|no):([0-9a-f-]{36})$/;

/**
 * «Одобрить» / «Отклонить» a registration - ONE implementation for the panel, the app and the admin's Telegram buttons
 * (owner, 2026-10-11). The actor's scope and the status machine are checked the same way everywhere.
 */
@Injectable()
export class WorkerDecisions {
  constructor(
    private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus, private readonly notifications: NotificationsService,
  ) {}

  async approve(actor: AuthUser, id: string, input: z.output<typeof approveWorkerSchema>) {
    const events: Array<() => Promise<void>> = [];
    const who = { actorId: actor.id, actorRole: actor.role };
    await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_profiles', id))) throw notFound('Worker');
      const w = await tx.workerProfile.findUniqueOrThrow({ where: { id } });
      assertWorkerInScope(actor, 'WORKER', w);
      assertTransition('Worker', WORKER_MACHINE, w.status as WorkerStatus, 'ACTIVE', actor.role);
      if (await tx.user.findUnique({ where: { phone: w.phone }, select: { id: true } })) throw conflict('A user with this phone already exists');

      const user = await tx.user.create({ data: { phone: w.phone, fullName: w.fullName, role: 'WORKER' } });
      const now = new Date();
      await tx.workerProfile.update({ where: { id }, data: { userId: user.id, status: 'ACTIVE', approvedAt: now, approvedById: actor.id } });
      await tx.qrEntity.create({ data: { code: generateQrCode(), type: 'WORKER', workerId: id } });

      if (input.collateralReceived) {
        const pending = await tx.workerCollateral.findMany({ where: { workerId: id, status: 'PENDING' } });
        for (const c of pending) {
          assertTransition('Collateral', COLLATERAL_MACHINE, c.status as CollateralStatus, 'HELD', actor.role);
          const held = await tx.workerCollateral.update({ where: { id: c.id }, data: { status: 'HELD', receivedAt: now, receivedById: actor.id } });
          await tx.collateralHistory.create({ data: { collateralId: c.id, type: 'RECEIVED', actorId: actor.id, actorLabel: actor.fullName, note: input.note ?? 'Принят при подтверждении регистрации', snapshot: { status: 'HELD', type: held.type, amount: money(held.amount) } } });
          events.push(() => this.events.publish('collateral.updated', { collateralId: c.id, workerId: id, type: c.type, status: 'HELD', managerId: w.assignedManagerId }));
        }
      }
      await this.audit.record({ ...who, action: 'worker.approve', entity: 'WorkerProfile', entityId: id, before: { status: w.status }, after: { status: 'ACTIVE', collateralReceived: input.collateralReceived } }, tx);
      await this.notifications.telegram({ workerId: id, chatId: w.telegramChatId, type: 'worker.approved', body: `✅ Вас приняли! Откройте Diamoraa и нажмите «Войти через Telegram».\n\nНет приложения? Скачайте: ${appDownloadUrl()}` }, tx);
      events.push(() => this.events.publish('worker.approved', { workerId: id, managerId: w.assignedManagerId }));
    });
    for (const e of events) await e();
  }

  async reject(actor: AuthUser, id: string, input: z.output<typeof rejectWorkerSchema>) {
    let managerId: string | null = null;
    await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_profiles', id))) throw notFound('Worker');
      const w = await tx.workerProfile.findUniqueOrThrow({ where: { id } });
      assertWorkerInScope(actor, 'WORKER', w);
      assertTransition('Worker', WORKER_MACHINE, w.status as WorkerStatus, 'REJECTED', actor.role);
      managerId = w.assignedManagerId;
      await tx.workerProfile.update({ where: { id }, data: { status: 'REJECTED', rejectedReason: input.reason } });
      await this.audit.record({ actorId: actor.id, actorRole: actor.role, action: 'worker.reject', entity: 'WorkerProfile', entityId: id, before: { status: w.status }, after: { status: 'REJECTED', reason: input.reason } }, tx);
      await this.notifications.telegram({ workerId: id, chatId: w.telegramChatId, type: 'worker.rejected', body: `К сожалению, заявка отклонена.\nПричина: ${input.reason}` }, tx);
    });
    await this.events.publish('worker.rejected', { workerId: id, managerId });
  }

  /** the staff member behind an admin's Telegram chat, if (s)he may approve registrations */
  async approverOfChat(chatId: bigint): Promise<AuthUser | null> {
    const u = await this.prisma.user.findFirst({
      where: { status: 'ACTIVE', role: { not: 'WORKER' }, OR: [{ alertChatId: chatId }, { telegramUserId: chatId }] }, include: { permissions: true },
    });
    if (!u) return null;
    const permissions = effectivePermissions(u.role as Role, u.permissions);
    if (!permissions.includes('WORKER_APPROVE')) return null;
    return { id: u.id, role: u.role as Role, fullName: u.fullName, sessionId: 'telegram', workerId: null, permissions };
  }

  /** the admin's buttons under a new registration: one tap */
  async decideFromTelegram(chatId: bigint, action: string, workerId: string): Promise<string> {
    const actor = await this.approverOfChat(chatId);
    if (!actor) return 'Нет доступа: одобрять заявки может только админ.';
    const w = await this.prisma.workerProfile.findUnique({ where: { id: workerId }, select: { fullName: true, status: true } });
    if (!w) return 'Заявка не найдена.';
    if (w.status !== 'PENDING_APPROVAL') return `${w.fullName}: заявка уже рассмотрена.`;
    try {
      if (action === 'no') {
        await this.reject(actor, workerId, { reason: 'Отклонено администратором' });
        return `❌ ${w.fullName}: заявка отклонена.`;
      }
      await this.approve(actor, workerId, { collateralReceived: action === 'okc' });
      return `✅ ${w.fullName} принята${action === 'okc' ? ', залог получен' : ''}.`;
    } catch (e) {
      return `Не получилось: ${(e as Error).message}`;
    }
  }
}

@Module({ providers: [WorkerDecisions], exports: [WorkerDecisions] })
export class WorkerDecisionsModule {}
