import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type {
  AssignmentStatus, Delivery, QualityResult, StockMovement, WorkAssignment, WorkAssignmentMaterial, WorkAssignmentStatusHistory, WorkProgress,
} from '@yusmus/database';
import {
  acceptanceSchema, completeDeliverySchema, completePickupSchema, createAssignmentSchema, listAssignmentsSchema,
  metersToCm, readyForPickupSchema, reportProgressSchema,
} from '@yusmus/shared';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden, invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { assertWorkerInScope, workerScope } from '../common/scope';
import { generateQrCode, lockRow, nextCode, type Tx } from '../common/sequence';
import { money, num } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { LedgerModule, LedgerService } from '../ledger/ledger.service';
import { PrismaService } from '../prisma/prisma.module';
import { StockModule, StockService } from '../stock/stock.service';

type AssignmentFull = WorkAssignment & {
  materials: WorkAssignmentMaterial[];
  statusHistory: WorkAssignmentStatusHistory[];
  progress: WorkProgress[];
  deliveries: Delivery[];
  worker: { id: string; code: string; fullName: string; phone: string; assignedManagerId: string | null };
  productModel: { id: string; name: string };
  productVariant: { id: string; label: string | null };
  color: { id: string; name: string; hex: string | null };
  qrEntities: { code: string }[];
};

/**
 * M3: the full work-order lifecycle (§5-14). WorkAssignment/Delivery/WorkProgress/QualityInspection/QrEntity.ASSIGNMENT
 * all existed unused since M0 (same "schema was ready, nothing built on it" pattern as M2's materials/stock/kit). One
 * assignment = one 9 m kit recipe × kitCount (1/2/3 = 9/18/27 m, D-035, same rule as kit assembly) — never a separate
 * per-length template. Every state change is DB-transactional; realtime events are only published AFTER commit.
 */
@Injectable()
export class AssignmentsService {
  constructor(
    private readonly prisma: PrismaService, private readonly stock: StockService, private readonly audit: AuditService,
    private readonly events: EventBus, private readonly ledger: LedgerService,
  ) {}

  // ---- create (§6): one atomic transaction — validate, deduct stock, snapshot materials, QR, delivery, or full rollback ----
  async create(actor: AuthUser, input: z.output<typeof createAssignmentSchema>) {
    const worker = await this.prisma.workerProfile.findUnique({ where: { id: input.workerId } });
    if (!worker) throw notFound('Worker');
    assertWorkerInScope(actor, 'ASSIGNMENT', worker); // a MANAGER may only assign her OWN worker (§25), server-side
    if (worker.status !== 'ACTIVE') throw invariant('Worker is not active');

    const variant = await this.prisma.productVariant.findUnique({ where: { id: input.productVariantId } });
    if (!variant || variant.modelId !== input.productModelId) throw notFound('Product variant');
    if (variant.colorId !== input.colorId) throw invariant('Color does not match the chosen variant');
    if (!variant.active) throw invariant('This variant is inactive');

    const kit = await this.prisma.materialKitTemplate.findUnique({ where: { id: input.materialKitTemplateId }, include: { items: true } });
    if (!kit || !kit.active) throw notFound('Kit template');
    if (kit.items.length === 0) throw invariant('This kit template has no materials yet');

    const plannedMeters = num(kit.ribbonMeters)! * input.kitCount;
    const groupId = randomUUID();

    const result = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'assignment_code', 'A-', 5);
      const assignment = await tx.workAssignment.create({
        data: {
          code, workerId: worker.id, productModelId: input.productModelId, productVariantId: input.productVariantId,
          colorId: input.colorId, materialKitTemplateId: kit.id, kitCount: input.kitCount, plannedMeters,
          dueAt: input.dueAt, notes: input.notes, createdById: actor.id, status: 'DRAFT', issuedAt: new Date(),
        },
      });

      const movements: StockMovement[] = [];
      for (const item of kit.items) {
        const needed = item.requiredQuantity.times(input.kitCount).toFixed(3);
        movements.push(await this.stock.recordMovement(tx, actor, {
          type: 'ISSUE_TO_WORKER', materialId: item.materialId, quantity: needed, warehouseDelta: `-${needed}`,
          workerId: worker.id, assignmentId: assignment.id, groupId, comment: `Задание ${code}`,
        }));
        await tx.workAssignmentMaterial.create({ data: { assignmentId: assignment.id, materialId: item.materialId, quantity: needed } });
      }

      const qrCode = generateQrCode();
      await tx.qrEntity.create({ data: { code: qrCode, type: 'ASSIGNMENT', assignmentId: assignment.id, workerId: worker.id } });

      await this.transition(tx, assignment.id, null, 'READY_TO_DELIVER', actor, 'Задание создано, материалы выданы со склада');
      await tx.workAssignment.update({ where: { id: assignment.id }, data: { status: 'READY_TO_DELIVER' } });

      const deliveryCode = await nextCode(tx, 'delivery_code', 'D-', 5);
      const delivery = await tx.delivery.create({
        data: { code: deliveryCode, workerId: worker.id, assignmentId: assignment.id, type: 'DELIVERY_TO_WORKER', status: 'PENDING', createdById: actor.id },
      });
      for (const item of kit.items) {
        const needed = item.requiredQuantity.times(input.kitCount).toFixed(3);
        await tx.deliveryItem.create({ data: { deliveryId: delivery.id, materialId: item.materialId, description: '', quantity: needed, assignmentId: assignment.id } });
      }

      await this.audit.record({
        action: 'assignment.create', entity: 'WorkAssignment', entityId: assignment.id,
        after: { code, workerId: worker.id, kitCount: input.kitCount, plannedMeters, qrCode },
      }, tx);

      return { assignment, movements, qrCode, deliveryId: delivery.id, managerId: worker.assignedManagerId };
    });

    for (const m of result.movements) await this.stock.publish(m);
    await this.events.publish('assignment.created', { assignmentId: result.assignment.id, workerId: worker.id, managerId: result.managerId });
    await this.events.publish('qr.created', { code: result.qrCode, type: 'ASSIGNMENT', workerId: worker.id });
    await this.events.publish('delivery.created', { deliveryId: result.deliveryId, workerId: worker.id, type: 'DELIVERY_TO_WORKER', assignmentId: result.assignment.id, managerId: result.managerId });
    return this.get(actor, result.assignment.id);
  }

  async list(actor: AuthUser, q: z.output<typeof listAssignmentsSchema>) {
    const { where: scopeWhere } = workerScope(actor, 'ASSIGNMENT');
    const rows = await this.prisma.workAssignment.findMany({
      where: { status: q.status, workerId: q.workerId, worker: scopeWhere },
      include: this.includeFull(),
      orderBy: { createdAt: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((a) => this.dto(a)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(actor: AuthUser, id: string) {
    const a = await this.load(id);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    return this.dto(a);
  }

  /** The worker's own current (not-yet-completed) work, for her home screen (§8). `{}` (never `null`) when idle: the
   * wire response is always a JSON object, so clients can do `res.data as Map` without a null-check special case. */
  async currentForWorker(workerId: string): Promise<Record<string, never> | ReturnType<AssignmentsService['dto']>> {
    const a = await this.prisma.workAssignment.findFirst({
      where: { workerId, status: { notIn: ['COMPLETED', 'CANCELLED'] } },
      include: this.includeFull(), orderBy: { createdAt: 'desc' },
    });
    return a ? this.dto(a) : {};
  }

  // ---- delivery (§9): staff marks "Доставлено" -> DELIVERED then straight to IN_PROGRESS -------------------------------
  async completeDelivery(actor: AuthUser, assignmentId: string, _input: z.output<typeof completeDeliverySchema>) {
    const a = await this.load(assignmentId);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    if (a.status !== 'READY_TO_DELIVER') throw invariant(`Cannot deliver from status ${a.status}`);
    const delivery = a.deliveries.find((d) => d.type === 'DELIVERY_TO_WORKER' && d.status === 'PENDING');
    if (!delivery) throw notFound('Pending delivery');

    await this.prisma.$transaction(async (tx) => {
      await tx.delivery.update({ where: { id: delivery.id }, data: { status: 'COMPLETED', completedAt: new Date(), completedById: actor.id } });
      await this.transition(tx, assignmentId, 'READY_TO_DELIVER', 'DELIVERED', actor, 'Материалы доставлены мастерице');
      await this.transition(tx, assignmentId, 'DELIVERED', 'IN_PROGRESS', actor, 'Работа начата');
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { status: 'IN_PROGRESS' } });
      await this.audit.record({ action: 'delivery.complete', entity: 'Delivery', entityId: delivery.id, after: { assignmentId } }, tx);
    });
    await this.events.publish('delivery.completed', { deliveryId: delivery.id, workerId: a.workerId, type: 'DELIVERY_TO_WORKER', assignmentId, managerId: a.worker.assignedManagerId });
    await this.events.publish('assignment.status_changed', { assignmentId, workerId: a.workerId, from: 'READY_TO_DELIVER', to: 'IN_PROGRESS', managerId: a.worker.assignedManagerId });
    return this.get(actor, assignmentId);
  }

  // ---- worker progress (§10, §27): 0 <= reportedMeters <= plannedMeters, immutable history, idempotent by clientId -----
  async reportProgress(workerId: string, assignmentId: string, input: z.output<typeof reportProgressSchema>) {
    const a = await this.load(assignmentId);
    if (a.workerId !== workerId) throw notFound('Assignment'); // never leak a foreign assignment to a worker
    if (a.status !== 'IN_PROGRESS') throw invariant(`Cannot report progress from status ${a.status}`);
    const meters = Number(input.reportedMeters);
    const planned = num(a.plannedMeters)!;
    if (meters < 0 || meters > planned) throw invariant(`Reported metres must be between 0 and ${planned}`);

    if (input.clientId) {
      const existing = await this.prisma.workProgress.findUnique({ where: { assignmentId_clientId: { assignmentId, clientId: input.clientId } } });
      if (existing) return this.getOwn(workerId, assignmentId);
    }
    const percent = planned > 0 ? Math.min(100, (meters / planned) * 100) : 0;
    await this.prisma.$transaction(async (tx) => {
      await tx.workProgress.create({ data: { assignmentId, workerId, reportedMeters: input.reportedMeters, percent: percent.toFixed(2), comment: input.comment, clientId: input.clientId } });
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { reportedMeters: input.reportedMeters } });
      await this.audit.record({ action: 'work.progress', entity: 'WorkAssignment', entityId: assignmentId, after: { reportedMeters: input.reportedMeters, percent } }, tx);
    });
    await this.events.publish('work.progress_updated', { assignmentId, workerId, reportedMeters: meters, percent, managerId: a.worker.assignedManagerId });
    return this.getOwn(workerId, assignmentId);
  }

  // ---- ready for pickup (§11): worker says "Работа готова" -> a PICKUP_FROM_WORKER delivery appears on the map --------
  async readyForPickup(workerId: string, assignmentId: string, input: z.output<typeof readyForPickupSchema>) {
    const a = await this.load(assignmentId);
    if (a.workerId !== workerId) throw notFound('Assignment');
    if (a.status !== 'IN_PROGRESS') throw invariant(`Cannot mark ready from status ${a.status}`);
    const meters = Number(input.readyMeters);
    const planned = num(a.plannedMeters)!;
    if (meters < 0 || meters > planned) throw invariant(`Ready metres must be between 0 and ${planned}`);

    const deliveryId = await this.prisma.$transaction(async (tx) => {
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { reportedMeters: input.readyMeters, status: 'READY_FOR_PICKUP' } });
      await this.transition(tx, assignmentId, 'IN_PROGRESS', 'READY_FOR_PICKUP', { id: workerId, role: 'WORKER' }, input.comment ?? 'Работа готова к сдаче');
      const code = await nextCode(tx, 'delivery_code', 'D-', 5);
      const delivery = await tx.delivery.create({
        data: { code, workerId, assignmentId, type: 'PICKUP_FROM_WORKER', status: 'PENDING', notes: input.comment, createdById: workerId },
      });
      await this.audit.record({ action: 'work.ready_for_pickup', entity: 'WorkAssignment', entityId: assignmentId, after: { readyMeters: input.readyMeters } }, tx);
      return delivery.id;
    });
    await this.events.publish('work.ready_for_pickup', { assignmentId, workerId, meters, managerId: a.worker.assignedManagerId });
    await this.events.publish('delivery.created', { deliveryId, workerId, type: 'PICKUP_FROM_WORKER', assignmentId, managerId: a.worker.assignedManagerId });
    return this.currentForWorker(workerId);
  }

  // ---- pickup (§12): staff scans QR / opens the assignment, confirms "Забрал" -> UNDER_REVIEW ---------------------------
  async completePickup(actor: AuthUser, assignmentId: string, _input: z.output<typeof completePickupSchema>) {
    const a = await this.load(assignmentId);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    if (a.status !== 'READY_FOR_PICKUP') throw invariant(`Cannot pick up from status ${a.status}`);
    const delivery = a.deliveries.find((d) => d.type === 'PICKUP_FROM_WORKER' && d.status === 'PENDING');
    if (!delivery) throw notFound('Pending pickup');

    await this.prisma.$transaction(async (tx) => {
      await tx.delivery.update({ where: { id: delivery.id }, data: { status: 'COMPLETED', completedAt: new Date(), completedById: actor.id } });
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { status: 'UNDER_REVIEW', deliveredMeters: a.reportedMeters } });
      await this.transition(tx, assignmentId, 'READY_FOR_PICKUP', 'PICKED_UP', actor, 'Забрано у мастерицы');
      await this.transition(tx, assignmentId, 'PICKED_UP', 'UNDER_REVIEW', actor, 'Ожидает приёмки');
      await this.audit.record({ action: 'delivery.pickup', entity: 'Delivery', entityId: delivery.id, after: { assignmentId, handledBy: actor.id } }, tx);
    });
    await this.events.publish('delivery.completed', { deliveryId: delivery.id, workerId: a.workerId, type: 'PICKUP_FROM_WORKER', assignmentId, managerId: a.worker.assignedManagerId });
    await this.events.publish('assignment.status_changed', { assignmentId, workerId: a.workerId, from: 'READY_FOR_PICKUP', to: 'UNDER_REVIEW', managerId: a.worker.assignedManagerId });
    return this.get(actor, assignmentId);
  }

  // ---- acceptance (§13-14): quality check -> earning at the CURRENT global rate, never recalculated later --------------
  async accept(actor: AuthUser, assignmentId: string, input: z.output<typeof acceptanceSchema>) {
    const a = await this.load(assignmentId);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    if (a.status !== 'UNDER_REVIEW') throw invariant(`Cannot accept from status ${a.status}`);
    const brought = Number(input.broughtMeters), accepted = Number(input.acceptedMeters);
    const defective = Number(input.defectiveMeters ?? '0'), rework = Number(input.reworkMeters ?? '0');
    if (Math.abs(accepted + defective + rework - brought) > 0.01) throw invariant('accepted + defective + rework must equal brought metres');
    if (accepted < 0 || accepted > brought) throw invariant('acceptedMeters out of range');

    const result: QualityResult = accepted >= brought - 0.001 ? 'ACCEPTED' : accepted > 0 ? 'PARTIALLY_ACCEPTED' : 'REWORK_REQUIRED';
    const nextStatus: AssignmentStatus = result === 'ACCEPTED' ? 'COMPLETED' : result === 'PARTIALLY_ACCEPTED' ? 'PARTIALLY_ACCEPTED' : 'REWORK_REQUIRED';

    const out = await this.prisma.$transaction(async (tx) => {
      const inspection = await tx.qualityInspection.create({
        data: {
          assignmentId, inspectorId: actor.id, result, broughtMeters: input.broughtMeters, acceptedMeters: input.acceptedMeters,
          defectiveMeters: input.defectiveMeters ?? '0', reworkMeters: input.reworkMeters ?? '0', comment: input.comment,
          photoFileIds: input.photoFileIds ?? [],
        },
      });

      let earningAmount = 0n;
      if (accepted > 0) {
        const acceptedCm = metersToCm(input.acceptedMeters);
        const { amount, ratePerKit } = await this.ledger.earnFor(tx, a.workerId, assignmentId, acceptedCm);
        earningAmount = amount;
        await tx.workAssignment.update({ where: { id: assignmentId }, data: { settledRatePerKit: ratePerKit, calculatedPayment: amount } });
      }
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { acceptedMeters: input.acceptedMeters, defectiveMeters: input.defectiveMeters ?? '0', status: nextStatus } });
      await this.transition(tx, assignmentId, 'UNDER_REVIEW', result === 'ACCEPTED' ? 'ACCEPTED' : nextStatus, actor, input.comment ?? `Приёмка: ${result}`);
      if (result === 'ACCEPTED') await this.transition(tx, assignmentId, 'ACCEPTED', 'COMPLETED', actor, 'Работа полностью принята и оплачена');

      await this.audit.record({
        action: 'quality.inspect', entity: 'WorkAssignment', entityId: assignmentId,
        after: { result, brought, accepted, defective, rework, earningAmount: earningAmount.toString() },
      }, tx);
      return { inspection, earningAmount };
    });

    await this.events.publish('quality.completed', { assignmentId, workerId: a.workerId, result, acceptedMeters: accepted, managerId: a.worker.assignedManagerId });
    await this.events.publish('assignment.status_changed', { assignmentId, workerId: a.workerId, from: 'UNDER_REVIEW', to: nextStatus, managerId: a.worker.assignedManagerId });
    if (out.earningAmount > 0n) {
      await this.events.publish('earning.created', { workerId: a.workerId, assignmentId, amount: money(out.earningAmount)!, managerId: a.worker.assignedManagerId });
      const balance = await this.ledger.summary(actor, a.workerId);
      await this.events.publish('worker.balance_updated', { workerId: a.workerId, balance: balance.balance, earned: balance.earned, paid: balance.paid, managerId: a.worker.assignedManagerId });
    }
    return this.get(actor, assignmentId);
  }

  // ---- internals -------------------------------------------------------------------------------------------------------
  /** Appends an immutable status-history row and locks the assignment row first (concurrency-safe status transitions,
   * matching `stock_balances`' row-lock pattern — two staff members can never both "complete" the same pickup). */
  private async transition(tx: Tx, assignmentId: string, from: AssignmentStatus | null, to: AssignmentStatus, actor: AuthUser | { id: string; role: string }, comment?: string) {
    if (!(await lockRow(tx, 'work_assignments', assignmentId))) throw notFound('Assignment');
    await tx.workAssignmentStatusHistory.create({ data: { assignmentId, fromStatus: from, toStatus: to, changedById: actor.id, actor: actor.role, comment } });
  }

  private includeFull() {
    return {
      materials: true, statusHistory: { orderBy: { changedAt: 'asc' as const } }, progress: { orderBy: { createdAt: 'desc' as const }, take: 20 },
      deliveries: { orderBy: { createdAt: 'desc' as const } },
      worker: { select: { id: true, code: true, fullName: true, phone: true, assignedManagerId: true } },
      productModel: { select: { id: true, name: true } }, productVariant: { select: { id: true, label: true } }, color: { select: { id: true, name: true, hex: true } },
      qrEntities: { where: { type: 'ASSIGNMENT' as const, revokedAt: null }, orderBy: { createdAt: 'desc' as const }, take: 1, select: { code: true } },
    };
  }
  /** A worker reading her OWN assignment: no staff permission/scope check applies, self-ownership was already verified. */
  private async getOwn(workerId: string, id: string) {
    const a = await this.load(id);
    if (a.workerId !== workerId) throw notFound('Assignment');
    return this.dto(a);
  }
  private async load(id: string): Promise<AssignmentFull> {
    const a = await this.prisma.workAssignment.findUnique({ where: { id }, include: this.includeFull() });
    if (!a) throw notFound('Assignment');
    return a as AssignmentFull;
  }
  private dto(a: AssignmentFull) {
    return {
      id: a.id, code: a.code, status: a.status, kitCount: a.kitCount, plannedMeters: num(a.plannedMeters),
      reportedMeters: num(a.reportedMeters), deliveredMeters: num(a.deliveredMeters), acceptedMeters: num(a.acceptedMeters),
      defectiveMeters: num(a.defectiveMeters), calculatedPayment: money(a.calculatedPayment), settledRatePerKit: money(a.settledRatePerKit),
      dueAt: a.dueAt?.toISOString() ?? null, notes: a.notes, issuedAt: a.issuedAt?.toISOString() ?? null,
      qrCode: a.qrEntities[0]?.code ?? null,
      worker: a.worker, product: a.productModel, variant: a.productVariant, color: a.color,
      materials: a.materials.map((m) => ({ materialId: m.materialId, quantity: num(m.quantity) })),
      statusHistory: a.statusHistory.map((h) => ({ from: h.fromStatus, to: h.toStatus, actor: h.actor, comment: h.comment, changedAt: h.changedAt.toISOString() })),
      progress: a.progress.map((p) => ({ id: p.id, reportedMeters: num(p.reportedMeters), percent: num(p.percent), comment: p.comment, createdAt: p.createdAt.toISOString() })),
      deliveries: a.deliveries.map((d) => ({ id: d.id, code: d.code, type: d.type, status: d.status, completedAt: d.completedAt?.toISOString() ?? null })),
      createdAt: a.createdAt.toISOString(), updatedAt: a.updatedAt.toISOString(),
    };
  }
}

@ApiTags('assignments')
@ApiBearerAuth()
@Controller()
export class AssignmentsController {
  constructor(private readonly assignments: AssignmentsService) {}

  @Perm('ASSIGNMENT_CREATE') @Post('admin/assignments') @ApiZodBody(createAssignmentSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createAssignmentSchema) b: z.output<typeof createAssignmentSchema>) { return this.assignments.create(u, b); }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Get('admin/assignments')
  list(@CurrentUser() u: AuthUser, @ZodQuery(listAssignmentsSchema) q: z.output<typeof listAssignmentsSchema>) { return this.assignments.list(u, q); }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Get('admin/assignments/:id')
  get(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.assignments.get(u, id); }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Post('admin/assignments/:id/deliver') @HttpCode(200) @ApiZodBody(completeDeliverySchema)
  deliver(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(completeDeliverySchema) b: z.output<typeof completeDeliverySchema>) {
    return this.assignments.completeDelivery(u, id, b);
  }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Post('admin/assignments/:id/pickup') @HttpCode(200) @ApiZodBody(completePickupSchema)
  pickup(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(completePickupSchema) b: z.output<typeof completePickupSchema>) {
    return this.assignments.completePickup(u, id, b);
  }

  @Perm('ASSIGNMENT_ACCEPT') @Post('admin/assignments/:id/accept') @HttpCode(200) @ApiZodBody(acceptanceSchema)
  accept(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(acceptanceSchema) b: z.output<typeof acceptanceSchema>) {
    return this.assignments.accept(u, id, b);
  }

  // ---- worker self-service: no ASSIGNMENT_* permission needed, scoped to the caller's own workerId from the JWT --------
  @Roles('WORKER') @Get('work/current')
  current(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.assignments.currentForWorker(u.workerId);
  }

  @Roles('WORKER') @Post('work/:id/progress') @HttpCode(200) @ApiZodBody(reportProgressSchema)
  progress(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(reportProgressSchema) b: z.output<typeof reportProgressSchema>) {
    if (!u.workerId) throw forbidden();
    return this.assignments.reportProgress(u.workerId, id, b);
  }

  @Roles('WORKER') @Post('work/:id/ready') @HttpCode(200) @ApiZodBody(readyForPickupSchema)
  ready(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(readyForPickupSchema) b: z.output<typeof readyForPickupSchema>) {
    if (!u.workerId) throw forbidden();
    return this.assignments.readyForPickup(u.workerId, id, b);
  }
}

@Module({ imports: [StockModule, LedgerModule], controllers: [AssignmentsController], providers: [AssignmentsService], exports: [AssignmentsService] })
export class AssignmentsModule {}
