import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import type { CollateralHistory, CollateralPhoto, WorkerCollateral } from '@yusmus/database';
import {
  COLLATERAL_MACHINE, assertTransition, listCollateralSchema, receiveCollateralSchema, returnCollateralSchema, type CollateralStatus,
} from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { fileRejected, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { lockRow, type Tx } from '../common/sequence';
import { money } from '../common/serialize';
import { assertWorkerInScope, workerScope } from '../common/scope';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { FilesService } from '../files/files.service';
import { PrismaService } from '../prisma/prisma.module';

type WorkerBrief = { id: string; code: string; fullName: string; assignedManagerId: string | null };
type Full = WorkerCollateral & { worker: WorkerBrief; photos: CollateralPhoto[]; history: CollateralHistory[] };
const WORKER_SELECT = { id: true, code: true, fullName: true, assignedManagerId: true } as const;

/**
 * Collateral is a critical record: every step is a DB transaction under a row lock, appends immutable history, and is audited.
 * A MANAGER only ever sees the collateral of their own workers (D-028, `workerScope`/`assertWorkerInScope`) - server-side, never
 * decided by what the client claims.
 */
@Injectable()
export class CollateralService {
  constructor(private readonly prisma: PrismaService, private readonly files: FilesService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async list(actor: AuthUser, q: z.output<typeof listCollateralSchema>) {
    const { where: scopeWhere } = workerScope(actor, 'COLLATERAL');
    const rows = await this.prisma.workerCollateral.findMany({
      where: { workerId: q.workerId, status: q.status, updatedAt: q.updatedSince ? { gt: q.updatedSince } : undefined, worker: scopeWhere },
      include: { worker: { select: WORKER_SELECT }, photos: { orderBy: { createdAt: 'asc' } }, history: { take: 0 } },
      orderBy: { id: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((c) => ({ ...this.dto(c), cover: this.files.ref(c.photos[0]?.fileId) })), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(actor: AuthUser, id: string) {
    const c = await this.load(this.prisma, id);
    assertWorkerInScope(actor, 'COLLATERAL', c.worker, 'Collateral');
    return this.detail(c);
  }

  async receive(actor: AuthUser, id: string, input: z.output<typeof receiveCollateralSchema>) {
    const c = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_collaterals', id))) throw notFound('Collateral');
      const before = await this.load(tx, id);
      assertWorkerInScope(actor, 'COLLATERAL', before.worker, 'Collateral');
      assertTransition('Collateral', COLLATERAL_MACHINE, before.status as CollateralStatus, 'HELD', actor.role);
      const now = new Date();
      const after = await tx.workerCollateral.update({
        where: { id }, data: { status: 'HELD', receivedAt: now, receivedById: actor.id, estimatedValue: input.estimatedValue, storageLocation: input.storageLocation },
      });
      await tx.collateralHistory.create({ data: { collateralId: id, type: 'RECEIVED', actorId: actor.id, actorLabel: actor.fullName, note: input.note, snapshot: this.snapshot(after) } });
      await this.audit.record({ action: 'collateral.receive', entity: 'WorkerCollateral', entityId: id, before: this.snapshot(before), after: this.snapshot(after) }, tx);
      return before;
    });
    await this.events.publish('collateral.updated', { collateralId: id, workerId: c.workerId, type: c.type, status: 'HELD', managerId: c.worker.assignedManagerId });
    return this.get(actor, id);
  }

  async return(actor: AuthUser, id: string, input: z.output<typeof returnCollateralSchema>) {
    const c = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_collaterals', id))) throw notFound('Collateral');
      const before = await this.load(tx, id);
      assertWorkerInScope(actor, 'COLLATERAL', before.worker, 'Collateral');
      assertTransition('Collateral', COLLATERAL_MACHINE, before.status as CollateralStatus, 'RETURNED', actor.role);
      const after = await tx.workerCollateral.update({ where: { id }, data: { status: 'RETURNED', returnedAt: new Date(), returnedById: actor.id, returnNote: input.note } });
      await tx.collateralHistory.create({ data: { collateralId: id, type: 'RETURNED', actorId: actor.id, actorLabel: actor.fullName, note: input.note, snapshot: this.snapshot(after) } });
      await this.audit.record({ action: 'collateral.return', entity: 'WorkerCollateral', entityId: id, before: this.snapshot(before), after: this.snapshot(after) }, tx);
      return before;
    });
    await this.events.publish('collateral.updated', { collateralId: id, workerId: c.workerId, type: c.type, status: 'RETURNED', managerId: c.worker.assignedManagerId });
    return this.get(actor, id);
  }

  /** Photos are append-only evidence. Identical content sent twice (offline retry) is attached once. */
  async addPhoto(actor: AuthUser, id: string, file: { buffer: Buffer; originalName?: string }, caption?: string) {
    const c = await this.load(this.prisma, id);
    assertWorkerInScope(actor, 'COLLATERAL', c.worker, 'Collateral');
    const image = await this.files.prepareImage(file.buffer);
    const same = await this.prisma.fileAsset.findMany({ where: { sha256: image.sha256 }, select: { id: true } });
    const existing = same.length ? await this.prisma.collateralPhoto.findFirst({ where: { collateralId: id, fileId: { in: same.map((f) => f.id) } } }) : null;
    if (!existing) {
      const asset = await this.files.store({ bucket: 'collateral', image, uploadedById: actor.id, originalName: file.originalName });
      await this.prisma.$transaction(async (tx) => {
        await tx.collateralPhoto.create({ data: { collateralId: id, fileId: asset.id, caption } });
        await tx.collateralHistory.create({ data: { collateralId: id, type: 'PHOTO_ADDED', actorId: actor.id, actorLabel: actor.fullName, note: caption, snapshot: this.snapshot(c) } });
        await this.audit.record({ action: 'collateral.photo_add', entity: 'WorkerCollateral', entityId: id, after: { fileId: asset.id } }, tx);
      });
    }
    return this.get(actor, id);
  }

  /** The worker's own collateral ("Хранится у нас"). */
  async mine(user: AuthUser) {
    if (!user.workerId) throw notFound('Worker profile');
    const rows = await this.prisma.workerCollateral.findMany({
      where: { workerId: user.workerId }, orderBy: { createdAt: 'desc' },
      include: { worker: { select: WORKER_SELECT }, photos: { orderBy: { createdAt: 'asc' } }, history: { orderBy: { createdAt: 'asc' } } },
    });
    return { items: rows.map((c) => this.detail(c)) };
  }

  // ---- internals ---------------------------------------------------------------------------------------------------------
  private async load(db: PrismaService | Tx, id: string): Promise<Full> {
    const c = await db.workerCollateral.findUnique({
      where: { id },
      include: { worker: { select: WORKER_SELECT }, photos: { orderBy: { createdAt: 'asc' } }, history: { orderBy: { createdAt: 'asc' } } },
    });
    if (!c) throw notFound('Collateral');
    return c;
  }
  private snapshot(c: WorkerCollateral) {
    return { status: c.status, type: c.type, amount: money(c.amount), description: c.description, estimatedValue: money(c.estimatedValue), storageLocation: c.storageLocation };
  }
  private dto(c: Full) {
    return {
      id: c.id, code: c.code, worker: { id: c.worker.id, code: c.worker.code, fullName: c.worker.fullName }, type: c.type, status: c.status, amount: money(c.amount), description: c.description,
      estimatedValue: money(c.estimatedValue), storageLocation: c.storageLocation, declaredAt: c.declaredAt.toISOString(),
      receivedAt: c.receivedAt?.toISOString() ?? null, returnedAt: c.returnedAt?.toISOString() ?? null, returnNote: c.returnNote, photoCount: c.photos.length,
    };
  }
  private detail(c: Full) {
    return {
      ...this.dto(c),
      photos: c.photos.map((p) => ({ id: p.id, caption: p.caption, createdAt: p.createdAt.toISOString(), file: this.files.ref(p.fileId) })),
      history: c.history.map((h) => ({ id: h.id, type: h.type, actorLabel: h.actorLabel, note: h.note, createdAt: h.createdAt.toISOString() })),
    };
  }
}

@ApiTags('collateral')
@ApiBearerAuth()
@Controller()
export class CollateralController {
  constructor(private readonly collateral: CollateralService) {}

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('collaterals')
  list(@CurrentUser() u: AuthUser, @ZodQuery(listCollateralSchema) q: z.output<typeof listCollateralSchema>) { return this.collateral.list(u, q); }

  /** Worker: her own collateral (declared before ':id' routes of the workers controller is not needed: distinct path). */
  @Roles('WORKER') @Get('workers/me/collateral')
  mine(@CurrentUser() u: AuthUser) { return this.collateral.mine(u); }

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get('collaterals/:id')
  get(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.collateral.get(u, id); }

  @Perm('COLLATERAL_MANAGE') @Post('collaterals/:id/receive') @HttpCode(200) @ApiZodBody(receiveCollateralSchema)
  receive(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(receiveCollateralSchema) b: z.output<typeof receiveCollateralSchema>) { return this.collateral.receive(u, id, b); }

  @Perm('COLLATERAL_MANAGE') @Post('collaterals/:id/return') @HttpCode(200) @ApiZodBody(returnCollateralSchema)
  returnIt(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(returnCollateralSchema) b: z.output<typeof returnCollateralSchema>) { return this.collateral.return(u, id, b); }

  @Perm('COLLATERAL_MANAGE') @Post('collaterals/:id/photos') @HttpCode(201) @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' }, caption: { type: 'string' } } } })
  @UseInterceptors(FileInterceptor('file'))
  addPhoto(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(z.object({ caption: z.string().trim().max(200).optional() })) f: { caption?: string }, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the image as multipart field "file"');
    return this.collateral.addPhoto(u, id, { buffer: file.buffer, originalName: file.originalname }, f.caption);
  }
}

@Module({ controllers: [CollateralController], providers: [CollateralService], exports: [CollateralService] })
export class CollateralModule {}
