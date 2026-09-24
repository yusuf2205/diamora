import {
  Controller, Get, Injectable, Module, Param, ParseUUIDPipe, Patch, Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { CollateralPhoto, WorkerCollateral, WorkerProfile } from '@yusmus/database';
import {
  WORKER_MACHINE, approveWorkerSchema, assertTransition, assignManagerSchema, listWorkersSchema, rejectWorkerSchema, updateWorkerSchema,
  COLLATERAL_MACHINE, type CollateralStatus, type WorkerStatus,
} from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { AuthService } from '../auth/auth.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { conflict, invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { generateQrCode, lockRow } from '../common/sequence';
import { money, num } from '../common/serialize';
import { assertWorkerInScope, workerScope } from '../common/scope';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { FilesService } from '../files/files.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.module';

type WorkerWithCollateral = WorkerProfile & { collaterals: (WorkerCollateral & { photos: CollateralPhoto[] })[] };

/**
 * A MANAGER never sees another manager's workers: every read is filtered SERVER-SIDE by `workerScope` (WORKER_VIEW_ALL vs
 * WORKER_VIEW_ASSIGNED, D-028). A worker outside the caller's scope answers 404, never 403 (existence is not revealed either).
 */
@Injectable()
export class WorkersService {
  constructor(
    private readonly prisma: PrismaService, private readonly files: FilesService, private readonly audit: AuditService,
    private readonly events: EventBus, private readonly notifications: NotificationsService, private readonly auth: AuthService,
  ) {}

  // ---- staff reads -------------------------------------------------------------------------------------------------
  async list(actor: AuthUser, q: z.output<typeof listWorkersSchema>) {
    const { where: scopeWhere } = workerScope(actor, 'WORKER');
    const text = q.q?.trim();
    const digits = text?.replace(/\D/g, '');
    const rows = await this.prisma.workerProfile.findMany({
      where: {
        ...scopeWhere,
        status: q.status,
        updatedAt: q.updatedSince ? { gt: q.updatedSince } : undefined,
        OR: text ? [
          { fullName: { contains: text, mode: 'insensitive' } }, { code: { contains: text, mode: 'insensitive' } },
          ...(digits && digits.length >= 3 ? [{ phone: { contains: digits } }, { secondaryPhone: { contains: digits } }] : []),
        ] : undefined,
      },
      include: { collaterals: { orderBy: { createdAt: 'desc' }, take: 1, include: { photos: { take: 0 } } }, assignedManager: { select: { id: true, fullName: true } } },
      orderBy: { id: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((w) => this.adminDto(w)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(actor: AuthUser, id: string) {
    const w = await this.load(id);
    assertWorkerInScope(actor, 'WORKER', w);
    // her personal QR (M2 §13): opaque code only, so staff can show/print it — resolving it is scope-checked exactly like this route.
    const qr = await this.prisma.qrEntity.findFirst({ where: { workerId: id, type: 'WORKER', revokedAt: null }, orderBy: { createdAt: 'desc' } });
    return {
      ...this.adminDto(w), collaterals: w.collaterals.map((c) => this.collateralBrief(c)), notes: w.notes,
      approvedAt: w.approvedAt?.toISOString() ?? null, rejectedReason: w.rejectedReason, telegramLinked: true, qrCode: qr?.code ?? null,
    };
  }

  /** The worker's own view: no internal notes, only what she needs (brief §41). */
  async me(user: AuthUser) {
    if (!user.workerId) throw notFound('Worker profile');
    const w = await this.load(user.workerId);
    return {
      id: w.id, code: w.code, fullName: w.fullName, phone: w.phone, secondaryPhone: w.secondaryPhone, status: w.status,
      balance: money(w.balance), collaterals: w.collaterals.map((c) => this.collateralBrief(c)),
    };
  }

  // ---- staff actions -----------------------------------------------------------------------------------------------------
  async approve(actor: AuthUser, id: string, input: z.output<typeof approveWorkerSchema>) {
    const events: Array<() => Promise<void>> = [];
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
      await this.audit.record({ action: 'worker.approve', entity: 'WorkerProfile', entityId: id, before: { status: w.status }, after: { status: 'ACTIVE', collateralReceived: input.collateralReceived } }, tx);
      await this.notifications.telegram({ workerId: id, chatId: w.telegramChatId, type: 'worker.approved', body: '✅ Вас приняли! Откройте Diamoraa и нажмите «Войти через Telegram».' }, tx);
      events.push(() => this.events.publish('worker.approved', { workerId: id, managerId: w.assignedManagerId }));
    });
    for (const e of events) await e();
    return this.get(actor, id);
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
      await this.audit.record({ action: 'worker.reject', entity: 'WorkerProfile', entityId: id, before: { status: w.status }, after: { status: 'REJECTED', reason: input.reason } }, tx);
      await this.notifications.telegram({ workerId: id, chatId: w.telegramChatId, type: 'worker.rejected', body: `К сожалению, заявка отклонена.\nПричина: ${input.reason}` }, tx);
    });
    await this.events.publish('worker.rejected', { workerId: id, managerId });
    return this.get(actor, id);
  }

  async update(actor: AuthUser, id: string, patch: z.output<typeof updateWorkerSchema>) {
    const before = await this.load(id);
    assertWorkerInScope(actor, 'WORKER', before);
    if (patch.phone && patch.phone !== before.phone) {
      if (await this.prisma.workerProfile.findFirst({ where: { phone: patch.phone, id: { not: id } }, select: { id: true } })) throw conflict('Another worker already has this phone number');
      if (before.userId && (await this.prisma.user.findFirst({ where: { phone: patch.phone, id: { not: before.userId } }, select: { id: true } }))) throw conflict('This phone number already has a login');
    }
    if (patch.status) assertTransition('Worker', WORKER_MACHINE, before.status as WorkerStatus, patch.status, actor.role);
    await this.prisma.$transaction(async (tx) => {
      await tx.workerProfile.update({ where: { id }, data: patch });
      if (before.userId) {
        await tx.user.update({ where: { id: before.userId }, data: {
          phone: patch.phone,
          ...(patch.status === 'ARCHIVED' ? { status: 'SUSPENDED' as const } : {}),
          ...(before.status === 'ARCHIVED' && patch.status === 'ACTIVE' ? { status: 'ACTIVE' as const } : {}),
        } });
      }
      await this.audit.record({ action: 'worker.update', entity: 'WorkerProfile', entityId: id, before: { phone: before.phone, secondaryPhone: before.secondaryPhone, notes: before.notes, status: before.status }, after: patch }, tx);
    });
    if (patch.status === 'ARCHIVED' && before.userId) await this.auth.revokeAllOf(before.userId, 'worker_archived');
    await this.events.publish('worker.updated', { workerId: id, status: patch.status ?? before.status, managerId: before.assignedManagerId });
    return this.get(actor, id);
  }

  /** Assign or clear the MANAGER responsible for a worker (WORKER_ASSIGN_MANAGER; a MANAGER cannot reassign, only SUPER_ADMIN/ADMIN). */
  async assignManager(actor: AuthUser, id: string, input: z.output<typeof assignManagerSchema>) {
    const before = await this.load(id);
    let managerName: string | null = null;
    if (input.managerId) {
      const m = await this.prisma.user.findUnique({ where: { id: input.managerId }, select: { id: true, role: true, fullName: true, status: true } });
      if (!m || m.role !== 'MANAGER') throw invariant('managerId must be an active user with role MANAGER');
      if (m.status !== 'ACTIVE') throw invariant('This manager is deactivated');
      managerName = m.fullName;
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.workerProfile.update({ where: { id }, data: { assignedManagerId: input.managerId } });
      await this.audit.record({ action: 'worker.assign_manager', entity: 'WorkerProfile', entityId: id, before: { managerId: before.assignedManagerId }, after: { managerId: input.managerId, managerName } }, tx);
    });
    await this.events.publish('worker.manager_changed', { workerId: id, managerId: input.managerId, previousManagerId: before.assignedManagerId });
    return this.get(actor, id);
  }

  // ---- internals -----------------------------------------------------------------------------------------------------------
  private async load(id: string): Promise<WorkerWithCollateral & { assignedManager?: { id: string; fullName: string } | null }> {
    const w = await this.prisma.workerProfile.findUnique({
      where: { id },
      include: { collaterals: { orderBy: { createdAt: 'desc' }, include: { photos: { orderBy: { createdAt: 'asc' } } } }, assignedManager: { select: { id: true, fullName: true } } },
    });
    if (!w) throw notFound('Worker');
    return w;
  }

  private collateralBrief(c: WorkerCollateral & { photos: CollateralPhoto[] }) {
    return {
      id: c.id, code: c.code, type: c.type, status: c.status, amount: money(c.amount), description: c.description,
      estimatedValue: money(c.estimatedValue), storageLocation: c.storageLocation, declaredAt: c.declaredAt.toISOString(), receivedAt: c.receivedAt?.toISOString() ?? null,
      photos: c.photos.map((p) => ({ id: p.id, file: this.files.ref(p.fileId) })),
    };
  }

  private adminDto(w: WorkerProfile & { collaterals?: (WorkerCollateral & { photos: CollateralPhoto[] })[]; assignedManager?: { id: string; fullName: string } | null }) {
    const c = w.collaterals?.[0];
    return {
      id: w.id, code: w.code, fullName: w.fullName, phone: w.phone, secondaryPhone: w.secondaryPhone, status: w.status,
      latitude: num(w.latitude), longitude: num(w.longitude), locationReceivedAt: w.locationReceivedAt?.toISOString() ?? null,
      balance: money(w.balance), createdAt: w.createdAt.toISOString(), updatedAt: w.updatedAt.toISOString(),
      manager: w.assignedManager ? { id: w.assignedManager.id, fullName: w.assignedManager.fullName } : null,
      collateral: c ? { id: c.id, type: c.type, status: c.status, amount: money(c.amount), description: c.description } : null,
    };
  }
}

@ApiTags('workers')
@ApiBearerAuth()
@Controller('workers')
export class WorkersController {
  constructor(private readonly workers: WorkersService) {}

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get()
  list(@CurrentUser() u: AuthUser, @ZodQuery(listWorkersSchema) q: z.output<typeof listWorkersSchema>) { return this.workers.list(u, q); }

  /** Declared before ':id' so "me" is not parsed as an id. */
  @Roles('WORKER') @Get('me')
  me(@CurrentUser() u: AuthUser) { return this.workers.me(u); }

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get(':id')
  get(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.workers.get(u, id); }

  @Perm('WORKER_UPDATE') @Patch(':id') @ApiZodBody(updateWorkerSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateWorkerSchema) b: z.output<typeof updateWorkerSchema>) { return this.workers.update(u, id, b); }

  @Perm('WORKER_APPROVE') @Post(':id/approve') @ApiZodBody(approveWorkerSchema)
  approve(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(approveWorkerSchema) b: z.output<typeof approveWorkerSchema>) { return this.workers.approve(u, id, b); }

  @Perm('WORKER_APPROVE') @Post(':id/reject') @ApiZodBody(rejectWorkerSchema)
  reject(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(rejectWorkerSchema) b: z.output<typeof rejectWorkerSchema>) { return this.workers.reject(u, id, b); }

  @Perm('WORKER_ASSIGN_MANAGER') @Post(':id/manager') @ApiZodBody(assignManagerSchema)
  assignManager(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(assignManagerSchema) b: z.output<typeof assignManagerSchema>) { return this.workers.assignManager(u, id, b); }
}

@Module({ controllers: [WorkersController], providers: [WorkersService], exports: [WorkersService] })
export class WorkersModule {}
