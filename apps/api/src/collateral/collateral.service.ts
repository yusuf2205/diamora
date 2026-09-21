import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import type { CollateralHistory, CollateralPhoto, WorkerCollateral } from '@yusmus/database';
import {
  COLLATERAL_MACHINE, assertTransition, listCollateralSchema, receiveCollateralSchema, returnCollateralSchema, type CollateralStatus,
} from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Roles } from '../common/decorators';
import { fileRejected, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { lockRow, type Tx } from '../common/sequence';
import { money } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/events.module';
import { FilesService } from '../files/files.service';
import { PrismaService } from '../prisma/prisma.module';

type Full = WorkerCollateral & { worker: { id: string; code: string; fullName: string }; photos: CollateralPhoto[]; history: CollateralHistory[] };

/** Collateral is a critical record: every step is a DB transaction under a row lock, appends immutable history, and is audited. */
@Injectable()
export class CollateralService {
  constructor(private readonly prisma: PrismaService, private readonly files: FilesService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async list(q: z.output<typeof listCollateralSchema>) {
    const rows = await this.prisma.workerCollateral.findMany({
      where: { workerId: q.workerId, status: q.status, updatedAt: q.updatedSince ? { gt: q.updatedSince } : undefined },
      include: { worker: { select: { id: true, code: true, fullName: true } }, photos: { orderBy: { createdAt: 'asc' } }, history: { take: 0 } },
      orderBy: { id: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((c) => ({ ...this.dto(c), cover: this.files.ref(c.photos[0]?.fileId) })), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(id: string) {
    const c = await this.load(this.prisma, id);
    return this.detail(c);
  }

  async receive(actor: AuthUser, id: string, input: z.output<typeof receiveCollateralSchema>) {
    const c = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_collaterals', id))) throw notFound('Collateral');
      const before = await this.load(tx, id);
      assertTransition('Collateral', COLLATERAL_MACHINE, before.status as CollateralStatus, 'HELD', actor.role);
      const now = new Date();
      const after = await tx.workerCollateral.update({
        where: { id }, data: { status: 'HELD', receivedAt: now, receivedById: actor.id, estimatedValue: input.estimatedValue, storageLocation: input.storageLocation },
      });
      await tx.collateralHistory.create({ data: { collateralId: id, type: 'RECEIVED', actorId: actor.id, actorLabel: actor.fullName, note: input.note, snapshot: this.snapshot(after) } });
      await this.audit.record({ action: 'collateral.receive', entity: 'WorkerCollateral', entityId: id, before: this.snapshot(before), after: this.snapshot(after) }, tx);
      return before;
    });
    await this.events.publish('collateral.updated', { collateralId: id, workerId: c.workerId, type: c.type, status: 'HELD' });
    return this.get(id);
  }

  async return(actor: AuthUser, id: string, input: z.output<typeof returnCollateralSchema>) {
    const c = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_collaterals', id))) throw notFound('Collateral');
      const before = await this.load(tx, id);
      assertTransition('Collateral', COLLATERAL_MACHINE, before.status as CollateralStatus, 'RETURNED', actor.role);
      const after = await tx.workerCollateral.update({ where: { id }, data: { status: 'RETURNED', returnedAt: new Date(), returnedById: actor.id, returnNote: input.note } });
      await tx.collateralHistory.create({ data: { collateralId: id, type: 'RETURNED', actorId: actor.id, actorLabel: actor.fullName, note: input.note, snapshot: this.snapshot(after) } });
      await this.audit.record({ action: 'collateral.return', entity: 'WorkerCollateral', entityId: id, before: this.snapshot(before), after: this.snapshot(after) }, tx);
      return before;
    });
    await this.events.publish('collateral.updated', { collateralId: id, workerId: c.workerId, type: c.type, status: 'RETURNED' });
    return this.get(id);
  }

  /** Photos are append-only evidence. Identical content sent twice (offline retry) is attached once. */
  async addPhoto(actor: AuthUser, id: string, file: { buffer: Buffer; originalName?: string }, caption?: string) {
    const c = await this.load(this.prisma, id);
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
    return this.get(id);
  }

  /** The worker's own collateral ("Хранится у нас"). */
  async mine(user: AuthUser) {
    if (!user.workerId) throw notFound('Worker profile');
    const rows = await this.prisma.workerCollateral.findMany({
      where: { workerId: user.workerId }, orderBy: { createdAt: 'desc' },
      include: { worker: { select: { id: true, code: true, fullName: true } }, photos: { orderBy: { createdAt: 'asc' } }, history: { orderBy: { createdAt: 'asc' } } },
    });
    return { items: rows.map((c) => this.detail(c)) };
  }

  // ---- internals ---------------------------------------------------------------------------------------------------------
  private async load(db: PrismaService | Tx, id: string): Promise<Full> {
    const c = await db.workerCollateral.findUnique({
      where: { id },
      include: { worker: { select: { id: true, code: true, fullName: true } }, photos: { orderBy: { createdAt: 'asc' } }, history: { orderBy: { createdAt: 'asc' } } },
    });
    if (!c) throw notFound('Collateral');
    return c;
  }
  private snapshot(c: WorkerCollateral) {
    return { status: c.status, type: c.type, amount: money(c.amount), description: c.description, estimatedValue: money(c.estimatedValue), storageLocation: c.storageLocation };
  }
  private dto(c: Full) {
    return {
      id: c.id, code: c.code, worker: c.worker, type: c.type, status: c.status, amount: money(c.amount), description: c.description,
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

  @Roles('ADMIN') @Get('collaterals')
  list(@ZodQuery(listCollateralSchema) q: z.output<typeof listCollateralSchema>) { return this.collateral.list(q); }

  /** Worker: her own collateral (declared before ':id' routes of the workers controller is not needed: distinct path). */
  @Roles('WORKER') @Get('workers/me/collateral')
  mine(@CurrentUser() u: AuthUser) { return this.collateral.mine(u); }

  @Roles('ADMIN') @Get('collaterals/:id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.collateral.get(id); }

  @Roles('ADMIN') @Post('collaterals/:id/receive') @HttpCode(200) @ApiZodBody(receiveCollateralSchema)
  receive(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(receiveCollateralSchema) b: z.output<typeof receiveCollateralSchema>) { return this.collateral.receive(u, id, b); }

  @Roles('ADMIN') @Post('collaterals/:id/return') @HttpCode(200) @ApiZodBody(returnCollateralSchema)
  returnIt(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(returnCollateralSchema) b: z.output<typeof returnCollateralSchema>) { return this.collateral.return(u, id, b); }

  @Roles('ADMIN') @Post('collaterals/:id/photos') @HttpCode(201) @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' }, caption: { type: 'string' } } } })
  @UseInterceptors(FileInterceptor('file'))
  addPhoto(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(z.object({ caption: z.string().trim().max(200).optional() })) f: { caption?: string }, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw fileRejected('Attach the image as multipart field "file"');
    return this.collateral.addPhoto(u, id, { buffer: file.buffer, originalName: file.originalname }, f.caption);
  }
}

@Module({ controllers: [CollateralController], providers: [CollateralService], exports: [CollateralService] })
export class CollateralModule {}
