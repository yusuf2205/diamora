import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { WorkerJobRequest } from '@diamoraa/database';
import { createJobRequestSchema, listJobRequestsSchema, rejectJobRequestSchema } from '@diamoraa/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { conflict, forbidden, invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { assertWorkerInScope, workerScope } from '../common/scope';
import { lockRow } from '../common/sequence';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

const KIT_METERS = 9;

/**
 * «Заказать эту работу»: a worker picks a model + colour + 9/18/27 m in the catalog of her app. Staff sees the request,
 * prepares the assignment from it (the request becomes FULFILLED inside the assignment's own transaction, see
 * AssignmentsService.create) or declines it with a reason. One open request per worker (partial unique index).
 */
@Injectable()
export class JobRequestsService {
  constructor(
    private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus,
  ) {}

  // ---- worker ------------------------------------------------------------------------------------------------------------
  async create(workerId: string, input: z.output<typeof createJobRequestSchema>) {
    const worker = await this.prisma.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
    if (worker.status !== 'ACTIVE') throw forbidden('Worker is not active');
    const variant = await this.prisma.productVariant.findUnique({ where: { id: input.productVariantId }, include: { model: true } });
    if (!variant || !variant.active || variant.model.status !== 'PUBLISHED' || !variant.model.active) throw notFound('Product variant');
    if (variant.model.availability === 'UNAVAILABLE') throw invariant('This work is not available right now');
    if (await this.prisma.workerJobRequest.findFirst({ where: { workerId, status: 'PENDING' }, select: { id: true } })) {
      throw conflict('You already have a request waiting');
    }
    let row: WorkerJobRequest;
    try {
      row = await this.prisma.$transaction(async (tx) => {
        const r = await tx.workerJobRequest.create({
          data: { workerId, kitCount: input.kitCount, note: input.note, productModelId: variant.modelId, productVariantId: variant.id, colorId: variant.colorId },
        });
        await this.audit.record({ action: 'job_request.create', entity: 'WorkerJobRequest', entityId: r.id, actorId: worker.userId, actorRole: 'WORKER', after: { model: variant.model.name, kitCount: input.kitCount } }, tx);
        return r;
      });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') throw conflict('You already have a request waiting'); // concurrent double tap
      throw e;
    }
    await this.events.publish('job_request.created', { requestId: row.id, workerId, kitCount: row.kitCount, managerId: worker.assignedManagerId });
    return this.dtoOf(row.id);
  }

  async mine(workerId: string) {
    const rows = await this.prisma.workerJobRequest.findMany({ where: { workerId }, orderBy: { createdAt: 'desc' }, take: 10, include: this.include() });
    return { items: await Promise.all(rows.map((r) => this.dto(r))) };
  }

  async cancel(workerId: string, id: string) {
    const r = await this.prisma.workerJobRequest.findUnique({ where: { id }, include: { worker: true } });
    if (!r || r.workerId !== workerId) throw notFound('Job request');
    if (r.status !== 'PENDING') throw invariant(`Request is ${r.status}`);
    await this.prisma.$transaction(async (tx) => {
      await tx.workerJobRequest.update({ where: { id }, data: { status: 'CANCELLED', decidedAt: new Date() } });
      await this.audit.record({ action: 'job_request.cancel', entity: 'WorkerJobRequest', entityId: id, actorId: r.worker.userId, actorRole: 'WORKER' }, tx);
    });
    await this.events.publish('job_request.decided', { requestId: id, workerId, status: 'CANCELLED', managerId: r.worker.assignedManagerId });
    return this.dtoOf(id);
  }

  // ---- staff -------------------------------------------------------------------------------------------------------------
  async list(actor: AuthUser, q: z.output<typeof listJobRequestsSchema>) {
    const { where: scopeWhere } = workerScope(actor, 'ASSIGNMENT');
    const rows = await this.prisma.workerJobRequest.findMany({
      where: { status: q.status ?? 'PENDING', worker: scopeWhere }, orderBy: { createdAt: 'asc' }, take: 100, include: this.include(),
    });
    return { items: await Promise.all(rows.map((r) => this.dto(r))) };
  }

  async reject(actor: AuthUser, id: string, input: z.output<typeof rejectJobRequestSchema>) {
    const r = await this.prisma.workerJobRequest.findUnique({ where: { id }, include: { worker: true } });
    if (!r) throw notFound('Job request');
    assertWorkerInScope(actor, 'ASSIGNMENT', r.worker);
    await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_profiles', r.workerId))) throw notFound('Worker');
      const fresh = await tx.workerJobRequest.findUniqueOrThrow({ where: { id } });
      if (fresh.status !== 'PENDING') throw invariant(`Request is ${fresh.status}`);
      await tx.workerJobRequest.update({ where: { id }, data: { status: 'REJECTED', decidedById: actor.id, decidedAt: new Date(), decisionNote: input.note } });
      await this.audit.record({ action: 'job_request.reject', entity: 'WorkerJobRequest', entityId: id, after: { note: input.note ?? null } }, tx);
    });
    await this.events.publish('job_request.decided', { requestId: id, workerId: r.workerId, status: 'REJECTED', managerId: r.worker.assignedManagerId });
    return this.dtoOf(id);
  }

  // ---- internals ---------------------------------------------------------------------------------------------------------
  private include() {
    return {
      worker: { select: { id: true, code: true, fullName: true, phone: true } },
      assignment: { select: { id: true } },
    } as const;
  }
  private async dtoOf(id: string) {
    return this.dto(await this.prisma.workerJobRequest.findUniqueOrThrow({ where: { id }, include: this.include() }));
  }
  private async names(r: WorkerJobRequest) {
    const [model, variant, color] = await Promise.all([
      r.productModelId ? this.prisma.productModel.findUnique({ where: { id: r.productModelId }, select: { id: true, name: true, photoFileId: true } }) : null,
      r.productVariantId ? this.prisma.productVariant.findUnique({ where: { id: r.productVariantId }, select: { id: true, label: true } }) : null,
      r.colorId ? this.prisma.color.findUnique({ where: { id: r.colorId }, select: { id: true, name: true, hex: true } }) : null,
    ]);
    return { model, variant, color };
  }
  private dto(r: WorkerJobRequest & { worker: { id: string; code: string; fullName: string; phone: string }; assignment: { id: string } | null }) {
    return this.names(r).then(({ model, variant, color }) => ({
      id: r.id, status: r.status, kitCount: r.kitCount, meters: r.kitCount * KIT_METERS, note: r.note, decisionNote: r.decisionNote,
      createdAt: r.createdAt.toISOString(), decidedAt: r.decidedAt?.toISOString() ?? null,
      worker: r.worker, product: model ? { id: model.id, name: model.name } : null, variant: variant ? { id: variant.id, label: variant.label } : null,
      color, assignmentId: r.assignment?.id ?? null,
    }));
  }
}

@ApiTags('job-requests')
@ApiBearerAuth()
@Controller()
export class JobRequestsController {
  constructor(private readonly svc: JobRequestsService) {}

  @Roles('WORKER') @Get('work/requests')
  mine(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.svc.mine(u.workerId);
  }

  @Roles('WORKER') @Post('work/requests') @ApiZodBody(createJobRequestSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createJobRequestSchema) b: z.output<typeof createJobRequestSchema>) {
    if (!u.workerId) throw forbidden();
    return this.svc.create(u.workerId, b);
  }

  @Roles('WORKER') @Post('work/requests/:id/cancel') @HttpCode(200)
  cancel(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) {
    if (!u.workerId) throw forbidden();
    return this.svc.cancel(u.workerId, id);
  }

  @Perm('ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED') @Get('admin/job-requests')
  list(@CurrentUser() u: AuthUser, @ZodQuery(listJobRequestsSchema) q: z.output<typeof listJobRequestsSchema>) { return this.svc.list(u, q); }

  @Perm('ASSIGNMENT_CREATE') @Post('admin/job-requests/:id/reject') @HttpCode(200) @ApiZodBody(rejectJobRequestSchema)
  reject(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(rejectJobRequestSchema) b: z.output<typeof rejectJobRequestSchema>) {
    return this.svc.reject(u, id, b);
  }
}

@Module({ controllers: [JobRequestsController], providers: [JobRequestsService], exports: [JobRequestsService] })
export class JobRequestsModule {}
