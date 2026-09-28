import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type {
  AssignmentHandoff, AssignmentStatus, Delivery, QualityResult, StockMovement, WorkAssignment, WorkAssignmentMaterial, WorkAssignmentStatusHistory, WorkProgress,
} from '@diamoraa/database';
import {
  HANDOFF_TTL_MINUTES, acceptanceSchema, completeDeliverySchema, completePickupSchema, createAssignmentSchema, earningFor,
  handoffConfirmSchema, handoffProblemSchema, handoffScanSchema, listAssignmentsSchema, metersToCm, parseQrCode,
  readyForPickupSchema, reportProgressSchema,
} from '@diamoraa/shared';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { AppError, forbidden, invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { assertWorkerInScope, workerScope } from '../common/scope';
import { generateQrCode, lockRow, nextCode, type Tx } from '../common/sequence';
import { money, num } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { LedgerModule, LedgerService } from '../ledger/ledger.service';
import { PrismaService } from '../prisma/prisma.module';
import { PayRateModule, PayRateService } from '../settings/pay-rate.service';
import { StockModule, StockService } from '../stock/stock.service';

type AssignmentFull = WorkAssignment & {
  materials: (WorkAssignmentMaterial & { material?: { name: string; unit: string } })[];
  statusHistory: WorkAssignmentStatusHistory[];
  progress: WorkProgress[];
  deliveries: Delivery[];
  worker: { id: string; code: string; fullName: string; phone: string; assignedManagerId: string | null };
  productModel: { id: string; name: string };
  productVariant: { id: string; label: string | null };
  color: { id: string; name: string; hex: string | null };
  qrEntities: { code: string }[];
  handoffs: (AssignmentHandoff & { staffUser: { id: string; fullName: string; role: string } })[];
};

const foreignKit = () => new AppError('FOREIGN_KIT', 'This kit is meant for another worker', 403);
const handoffNotStarted = () => new AppError('HANDOFF_NOT_STARTED', 'Staff has not started the handoff yet', 409);
const handoffExpired = () => new AppError('HANDOFF_EXPIRED', 'The handoff has expired, staff must scan again', 409);

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
    private readonly events: EventBus, private readonly ledger: LedgerService, private readonly payRate: PayRateService,
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
    if (input.jobRequestId) {
      const jr = await this.prisma.workerJobRequest.findUnique({ where: { id: input.jobRequestId } });
      if (!jr || jr.workerId !== worker.id) throw notFound('Job request');
      if (jr.status !== 'PENDING') throw invariant(`Request is ${jr.status}`);
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'assignment_code', 'A-', 5);
      const assignment = await tx.workAssignment.create({
        data: {
          code, workerId: worker.id, productModelId: input.productModelId, productVariantId: input.productVariantId,
          colorId: input.colorId, materialKitTemplateId: kit.id, kitCount: input.kitCount, plannedMeters,
          dueAt: input.dueAt, notes: input.notes, createdById: actor.id, status: 'DRAFT', issuedAt: new Date(),
          jobRequestId: input.jobRequestId ?? null,
        },
      });
      if (input.jobRequestId) {
        // her «Заказать эту работу» is answered by this very assignment (a second preparation cannot reuse it)
        const done = await tx.workerJobRequest.updateMany({ where: { id: input.jobRequestId, status: 'PENDING' }, data: { status: 'FULFILLED', decidedById: actor.id, decidedAt: new Date() } });
        if (done.count !== 1) throw invariant('Request was already handled');
      }

      const movements: StockMovement[] = [];
      for (const item of kit.items) {
        const needed = item.requiredQuantity.times(input.kitCount).toFixed(3);
        movements.push(await this.stock.recordMovement(tx, actor, {
          // prepared = taken off the shelf into this work's kit; custody moves to the worker only when SHE confirms (Phase 5)
          type: 'ISSUE_TO_KIT', materialId: item.materialId, quantity: needed, warehouseDelta: `-${needed}`,
          workerId: worker.id, assignmentId: assignment.id, groupId, comment: `Задание ${code}: подготовлено`,
        }));
        await tx.workAssignmentMaterial.create({ data: { assignmentId: assignment.id, materialId: item.materialId, quantity: needed } });
      }

      const qrCode = generateQrCode();
      await tx.qrEntity.create({ data: { code: qrCode, type: 'ASSIGNMENT', assignmentId: assignment.id, workerId: worker.id } });

      await this.transition(tx, assignment.id, null, 'READY_TO_DELIVER', actor, 'Работа подготовлена, ожидает получения мастерицей');
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
    if (input.jobRequestId) await this.events.publish('job_request.decided', { requestId: input.jobRequestId, workerId: worker.id, status: 'FULFILLED', managerId: result.managerId });
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
    const rate = await this.rate();
    return { items: items.map((a) => this.dto(a, rate)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(actor: AuthUser, id: string) {
    const a = await this.load(id);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    return this.dto(a, await this.rate());
  }

  /** The worker's own current (not-yet-completed) work, for her home screen (§8). `{}` (never `null`) when idle: the
   * wire response is always a JSON object, so clients can do `res.data as Map` without a null-check special case. */
  async currentForWorker(workerId: string): Promise<Record<string, never> | ReturnType<AssignmentsService['dto']>> {
    const a = await this.prisma.workAssignment.findFirst({
      where: { workerId, status: { notIn: ['COMPLETED', 'CANCELLED'] } },
      include: this.includeFull(), orderBy: { createdAt: 'desc' },
    });
    return a ? this.dto(a, await this.rate()) : {};
  }

  // ---- two-sided QR handoff (Phase 5) ------------------------------------------------------------------------------------
  // 1) staff scans the assignment QR at the worker's door and taps «Начать передачу» -> AWAITING_WORKER (nothing moves yet)
  // 2) the worker scans the SAME QR in her app -> sees exactly what she gets
  // 3) she taps «Подтвердить получение» -> ONE transaction: custody to her, delivery closed, IN_PROGRESS
  //    or «Есть проблема» -> PROBLEM, nothing moves, staff is told in realtime and may scan again.
  // `POST /admin/assignments/:id/deliver` (old apps) is an alias of step 1: it can no longer finish a delivery on its own.
  async startHandoff(actor: AuthUser, assignmentId: string, _input?: z.output<typeof completeDeliverySchema>) {
    const a = await this.load(assignmentId);
    assertWorkerInScope(actor, 'ASSIGNMENT', a.worker);
    const qr = await this.prisma.qrEntity.findFirst({ where: { assignmentId, type: 'ASSIGNMENT', revokedAt: null }, orderBy: { createdAt: 'desc' } });
    if (!qr) throw notFound('QR code');

    const { handoff, created } = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'work_assignments', assignmentId))) throw notFound('Assignment');
      const fresh = await tx.workAssignment.findUniqueOrThrow({ where: { id: assignmentId } });
      if (fresh.status !== 'READY_TO_DELIVER') throw invariant(`Cannot hand over from status ${fresh.status}`);
      const worker = await tx.workerProfile.findUniqueOrThrow({ where: { id: fresh.workerId } });
      if (worker.status !== 'ACTIVE') throw invariant('Worker is not active');
      const open = await tx.assignmentHandoff.findFirst({ where: { assignmentId, status: 'AWAITING_WORKER' } });
      if (open && open.expiresAt > new Date()) return { handoff: open, created: false }; // a repeated scan is the same handoff
      if (open) await tx.assignmentHandoff.update({ where: { id: open.id }, data: { status: 'EXPIRED', resolvedAt: new Date() } });
      const h = await tx.assignmentHandoff.create({
        data: {
          assignmentId, workerId: fresh.workerId, staffUserId: actor.id, qrEntityId: qr.id, kitCount: fresh.kitCount, meters: fresh.plannedMeters,
          expiresAt: new Date(Date.now() + HANDOFF_TTL_MINUTES * 60_000),
        },
      });
      await this.audit.record({ action: 'handoff.started', entity: 'WorkAssignment', entityId: assignmentId, after: { handoffId: h.id, staffUserId: actor.id, qrEntityId: qr.id } }, tx);
      return { handoff: h, created: true };
    });
    if (created) {
      await this.events.publish('handoff.started', { handoffId: handoff.id, assignmentId, workerId: a.workerId, staffUserId: actor.id, managerId: a.worker.assignedManagerId });
    }
    return this.get(actor, assignmentId);
  }

  /** Worker scanned a QR with her own app. Returns the receipt to review - never data about a foreign worker's kit. */
  async scanHandoff(workerId: string, input: z.output<typeof handoffScanSchema>) {
    const code = parseQrCode(input.code);
    if (!code) throw notFound('QR code');
    const qr = await this.prisma.qrEntity.findUnique({ where: { code } });
    if (!qr || qr.revokedAt || qr.type !== 'ASSIGNMENT' || !qr.assignmentId) throw notFound('QR code');
    if (qr.workerId !== workerId) throw foreignKit();
    const worker = await this.prisma.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
    if (worker.status !== 'ACTIVE') throw forbidden('Worker is not active');

    const a = await this.load(qr.assignmentId);
    if (a.workerId !== workerId) throw foreignKit();
    if (a.status === 'CANCELLED') throw invariant('This work was cancelled');
    const confirmed = a.handoffs.find((h) => h.status === 'CONFIRMED');
    if (confirmed) return { handoffId: confirmed.id, state: 'CONFIRMED' as const, assignment: this.dto(a, await this.rate()) };
    if (a.status !== 'READY_TO_DELIVER') throw invariant(`Cannot receive from status ${a.status}`);
    const open = a.handoffs.find((h) => h.status === 'AWAITING_WORKER');
    if (!open) throw handoffNotStarted();
    if (open.expiresAt <= new Date()) throw handoffExpired();

    if (!open.workerScannedAt) {
      await this.prisma.$transaction(async (tx) => {
        await tx.assignmentHandoff.update({ where: { id: open.id }, data: { workerScannedAt: new Date() } });
        await this.audit.record({ action: 'handoff.worker_scanned', entity: 'WorkAssignment', entityId: a.id, after: { handoffId: open.id } }, tx);
      });
      await this.events.publish('handoff.scanned', { handoffId: open.id, assignmentId: a.id, workerId, staffUserId: open.staffUserId, managerId: a.worker.assignedManagerId });
    }
    return { handoffId: open.id, state: 'AWAITING_WORKER' as const, assignment: await this.getOwn(workerId, a.id) };
  }

  /** «Подтвердить получение»: the ONLY place where material custody moves to the worker. Replay / double-tap safe. */
  async confirmHandoff(workerActor: AuthUser, handoffId: string, input: z.output<typeof handoffConfirmSchema>) {
    const workerId = workerActor.workerId;
    if (!workerId) throw forbidden();
    const h0 = await this.prisma.assignmentHandoff.findUnique({ where: { id: handoffId } });
    if (!h0 || h0.workerId !== workerId) throw notFound('Handoff');

    const out = await this.prisma.$transaction(async (tx) => {
      // the assignment row lock serialises concurrent confirms: the second one waits, then sees CONFIRMED and replays
      if (!(await lockRow(tx, 'work_assignments', h0.assignmentId))) throw notFound('Assignment');
      const h = await tx.assignmentHandoff.findUniqueOrThrow({ where: { id: handoffId } });
      if (h.status === 'CONFIRMED') return { replay: true, movements: [] as StockMovement[], deliveryId: null as string | null };
      if (h.status !== 'AWAITING_WORKER') throw invariant(`Handoff is ${h.status}`);
      if (h.expiresAt <= new Date()) throw handoffExpired();
      const a = await tx.workAssignment.findUniqueOrThrow({ where: { id: h.assignmentId }, include: { materials: { include: { material: true } }, deliveries: true } });
      if (a.workerId !== workerId) throw notFound('Handoff');
      if (a.status !== 'READY_TO_DELIVER') throw invariant(`Cannot receive from status ${a.status}`);
      const worker = await tx.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
      if (worker.status !== 'ACTIVE') throw forbidden('Worker is not active');
      const qr = await tx.qrEntity.findUnique({ where: { id: h.qrEntityId } });
      if (!qr || qr.revokedAt) throw notFound('QR code');

      const groupId = randomUUID();
      const movements: StockMovement[] = [];
      for (const m of a.materials) {
        const q = m.quantity.toFixed(3);
        movements.push(await this.stock.recordMovement(tx, workerActor, {
          type: 'ISSUE_TO_WORKER', materialId: m.materialId, quantity: q, warehouseDelta: '0', workerDelta: q,
          workerId, assignmentId: a.id, groupId, comment: `Задание ${a.code}: мастерица подтвердила получение`,
        }));
      }
      const now = new Date();
      const snapshot = a.materials.map((m) => ({ materialId: m.materialId, name: m.material.name, unit: m.material.unit, quantity: m.quantity.toString() }));
      await tx.assignmentHandoff.update({
        where: { id: h.id },
        data: {
          status: 'CONFIRMED', workerScannedAt: h.workerScannedAt ?? now, workerAcceptedAt: now, resolvedAt: now, materialSnapshot: snapshot,
          latitude: input.latitude, longitude: input.longitude, accuracyM: input.accuracyM,
        },
      });
      const delivery = a.deliveries.find((d) => d.type === 'DELIVERY_TO_WORKER' && d.status === 'PENDING');
      if (delivery) await tx.delivery.update({ where: { id: delivery.id }, data: { status: 'COMPLETED', completedAt: now, completedById: h.staffUserId } });
      await this.transition(tx, a.id, 'READY_TO_DELIVER', 'DELIVERED', workerActor, 'Мастерица подтвердила получение');
      await this.transition(tx, a.id, 'DELIVERED', 'IN_PROGRESS', workerActor, 'Работа начата');
      await tx.workAssignment.update({ where: { id: a.id }, data: { status: 'IN_PROGRESS', issuedAt: now } });
      await this.audit.record({
        action: 'handoff.confirmed', entity: 'WorkAssignment', entityId: a.id,
        after: { handoffId: h.id, staffUserId: h.staffUserId, kitCount: a.kitCount, meters: a.plannedMeters.toString(), materials: snapshot, hasLocation: input.latitude != null },
      }, tx);
      return { replay: false, movements, deliveryId: delivery?.id ?? null };
    });

    const a = await this.load(h0.assignmentId);
    if (!out.replay) {
      for (const m of out.movements) await this.stock.publish(m);
      const managerId = a.worker.assignedManagerId;
      await this.events.publish('handoff.confirmed', { handoffId, assignmentId: a.id, workerId, staffUserId: h0.staffUserId, managerId });
      if (out.deliveryId) await this.events.publish('delivery.completed', { deliveryId: out.deliveryId, workerId, type: 'DELIVERY_TO_WORKER', assignmentId: a.id, managerId });
      await this.events.publish('assignment.status_changed', { assignmentId: a.id, workerId, from: 'READY_TO_DELIVER', to: 'IN_PROGRESS', managerId });
    }
    return this.dto(a, await this.rate());
  }

  /** «Есть проблема»: nothing moves, the work stays waiting, staff sees why in realtime and can scan again. */
  async reportHandoffProblem(workerId: string, handoffId: string, input: z.output<typeof handoffProblemSchema>) {
    const h0 = await this.prisma.assignmentHandoff.findUnique({ where: { id: handoffId } });
    if (!h0 || h0.workerId !== workerId) throw notFound('Handoff');
    await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'work_assignments', h0.assignmentId))) throw notFound('Assignment');
      const h = await tx.assignmentHandoff.findUniqueOrThrow({ where: { id: handoffId } });
      if (h.status !== 'AWAITING_WORKER') throw invariant(`Handoff is ${h.status}`);
      await tx.assignmentHandoff.update({
        where: { id: h.id }, data: { status: 'PROBLEM', problemReason: input.reason, problemComment: input.comment, workerScannedAt: h.workerScannedAt ?? new Date(), resolvedAt: new Date() },
      });
      await this.audit.record({ action: 'handoff.problem', entity: 'WorkAssignment', entityId: h.assignmentId, after: { handoffId: h.id, reason: input.reason, comment: input.comment ?? null } }, tx);
    });
    const a = await this.load(h0.assignmentId);
    await this.events.publish('handoff.problem', { handoffId, assignmentId: a.id, workerId, staffUserId: h0.staffUserId, reason: input.reason, managerId: a.worker.assignedManagerId });
    return this.dto(a, await this.rate());
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

    const consumed = await this.prisma.$transaction(async (tx) => {
      await tx.delivery.update({ where: { id: delivery.id }, data: { status: 'COMPLETED', completedAt: new Date(), completedById: actor.id } });
      await tx.workAssignment.update({ where: { id: assignmentId }, data: { status: 'UNDER_REVIEW', deliveredMeters: a.reportedMeters } });
      // custody: the materials she held for THIS work turned into the finished work she handed back
      const held = await tx.stockMovement.groupBy({ by: ['materialId'], where: { assignmentId, workerId: a.workerId }, _sum: { workerDelta: true } });
      const groupId = randomUUID();
      const moves: StockMovement[] = [];
      for (const row of held) {
        const q = row._sum.workerDelta;
        if (!q || !q.isPositive()) continue;
        moves.push(await this.stock.recordMovement(tx, actor, {
          type: 'CONSUMPTION', materialId: row.materialId, quantity: q.toFixed(3), warehouseDelta: '0', workerDelta: `-${q.toFixed(3)}`,
          workerId: a.workerId, assignmentId, groupId, comment: `Задание ${a.code}: работа сдана`,
        }));
      }
      await this.transition(tx, assignmentId, 'READY_FOR_PICKUP', 'PICKED_UP', actor, 'Забрано у мастерицы');
      await this.transition(tx, assignmentId, 'PICKED_UP', 'UNDER_REVIEW', actor, 'Ожидает приёмки');
      await this.audit.record({ action: 'delivery.pickup', entity: 'Delivery', entityId: delivery.id, after: { assignmentId, handledBy: actor.id } }, tx);
      return moves;
    });
    for (const m of consumed) await this.stock.publish(m);
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
      materials: { include: { material: { select: { name: true, unit: true } } } }, statusHistory: { orderBy: { changedAt: 'asc' as const } }, progress: { orderBy: { createdAt: 'desc' as const }, take: 20 },
      deliveries: { orderBy: { createdAt: 'desc' as const } },
      worker: { select: { id: true, code: true, fullName: true, phone: true, assignedManagerId: true } },
      productModel: { select: { id: true, name: true } }, productVariant: { select: { id: true, label: true } }, color: { select: { id: true, name: true, hex: true } },
      qrEntities: { where: { type: 'ASSIGNMENT' as const, revokedAt: null }, orderBy: { createdAt: 'desc' as const }, take: 1, select: { code: true } },
      handoffs: { orderBy: { startedAt: 'desc' as const }, take: 10, include: { staffUser: { select: { id: true, fullName: true, role: true } } } },
    };
  }
  /** A worker reading her OWN assignment: no staff permission/scope check applies, self-ownership was already verified. */
  private async getOwn(workerId: string, id: string) {
    const a = await this.load(id);
    if (a.workerId !== workerId) throw notFound('Assignment');
    return this.dto(a, await this.rate());
  }
  private async rate() { return (await this.payRate.current()).ratePerKit; }
  private async load(id: string): Promise<AssignmentFull> {
    const a = await this.prisma.workAssignment.findUnique({ where: { id }, include: this.includeFull() });
    if (!a) throw notFound('Assignment');
    return a as AssignmentFull;
  }
  private dto(a: AssignmentFull, ratePerKit: bigint) {
    const h = a.handoffs[0];
    return {
      id: a.id, code: a.code, status: a.status, kitCount: a.kitCount, plannedMeters: num(a.plannedMeters),
      reportedMeters: num(a.reportedMeters), deliveredMeters: num(a.deliveredMeters), acceptedMeters: num(a.acceptedMeters),
      defectiveMeters: num(a.defectiveMeters), calculatedPayment: money(a.calculatedPayment), settledRatePerKit: money(a.settledRatePerKit),
      dueAt: a.dueAt?.toISOString() ?? null, notes: a.notes, issuedAt: a.issuedAt?.toISOString() ?? null,
      qrCode: a.qrEntities[0]?.code ?? null,
      /** what she will earn if everything is accepted: the settled amount once accepted, else the CURRENT global rate (D-027) */
      expectedPayment: a.settledRatePerKit != null ? money(a.calculatedPayment) : money(earningFor(ratePerKit, metersToCm(a.plannedMeters.toString()))),
      /** the latest QR handoff (Phase 5); null until staff scans */
      handoff: h ? {
        id: h.id, status: h.status, startedAt: h.startedAt.toISOString(), expiresAt: h.expiresAt.toISOString(),
        expired: h.status === 'AWAITING_WORKER' && h.expiresAt <= new Date(),
        staff: h.staffUser, workerScannedAt: h.workerScannedAt?.toISOString() ?? null, workerAcceptedAt: h.workerAcceptedAt?.toISOString() ?? null,
        problemReason: h.problemReason, problemComment: h.problemComment, materialSnapshot: h.materialSnapshot ?? null,
        hasLocation: h.latitude != null,
      } : null,
      /** human timeline of the handoff, oldest first; clients translate `kind` */
      handoffTimeline: [...a.handoffs].reverse().flatMap((x) => [
        { kind: 'HANDOFF_STARTED', at: x.startedAt.toISOString(), by: x.staffUser.fullName },
        ...(x.workerScannedAt ? [{ kind: 'WORKER_SCANNED', at: x.workerScannedAt.toISOString(), by: a.worker.fullName }] : []),
        ...(x.status === 'CONFIRMED' && x.workerAcceptedAt ? [{ kind: 'WORKER_CONFIRMED', at: x.workerAcceptedAt.toISOString(), by: a.worker.fullName }] : []),
        ...(x.status === 'PROBLEM' && x.resolvedAt ? [{ kind: 'WORKER_PROBLEM', at: x.resolvedAt.toISOString(), by: a.worker.fullName, reason: x.problemReason }] : []),
      ]),
      worker: a.worker, product: a.productModel, variant: a.productVariant, color: a.color,
      materials: a.materials.map((m) => ({ materialId: m.materialId, quantity: num(m.quantity), name: m.material?.name ?? null, unit: m.material?.unit ?? null })),
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
    return this.assignments.startHandoff(u, id, b); // old apps: «Доставлено» now only STARTS the two-sided handoff
  }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Post('admin/assignments/:id/handoff') @HttpCode(200)
  handoff(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.assignments.startHandoff(u, id);
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

  @Roles('WORKER') @Post('work/handoff/scan') @HttpCode(200) @ApiZodBody(handoffScanSchema)
  handoffScan(@CurrentUser() u: AuthUser, @ZodBody(handoffScanSchema) b: z.output<typeof handoffScanSchema>) {
    if (!u.workerId) throw forbidden();
    return this.assignments.scanHandoff(u.workerId, b);
  }

  @Roles('WORKER') @Post('work/handoff/:id/confirm') @HttpCode(200) @ApiZodBody(handoffConfirmSchema)
  handoffConfirm(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(handoffConfirmSchema) b: z.output<typeof handoffConfirmSchema>) {
    if (!u.workerId) throw forbidden();
    return this.assignments.confirmHandoff(u, id, b);
  }

  @Roles('WORKER') @Post('work/handoff/:id/problem') @HttpCode(200) @ApiZodBody(handoffProblemSchema)
  handoffProblem(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(handoffProblemSchema) b: z.output<typeof handoffProblemSchema>) {
    if (!u.workerId) throw forbidden();
    return this.assignments.reportHandoffProblem(u.workerId, id, b);
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

@Module({ imports: [StockModule, LedgerModule, PayRateModule], controllers: [AssignmentsController], providers: [AssignmentsService], exports: [AssignmentsService] })
export class AssignmentsModule {}
