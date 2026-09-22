import { Controller, Get, Global, Injectable, Module } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Prisma } from '@yusmus/database';
import { idSchema, paginationSchema } from '@yusmus/shared';
import { z } from 'zod';
import { Perm } from '../common/decorators';
import { RequestContext } from '../common/request-context';
import { jsonSafe } from '../common/serialize';
import { ZodQuery } from '../common/zod.pipe';
import { PrismaService } from '../prisma/prisma.module';

export interface AuditEntry {
  action: string; // e.g. worker.approve, collateral.return
  entity: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
  /** override when there is no request context (bot, jobs) */
  actorId?: string | null;
  actorRole?: string | null;
}
type Db = PrismaService | Prisma.TransactionClient;

/** Append-only audit trail; pass the transaction client so it commits atomically with the change it describes. */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}
  async record(e: AuditEntry, db: Db = this.prisma): Promise<void> {
    const c = RequestContext.get();
    await db.auditLog.create({
      data: {
        actorId: e.actorId === undefined ? (c?.user?.id ?? null) : e.actorId,
        actorRole: e.actorRole === undefined ? (c?.user?.role ?? null) : e.actorRole,
        action: e.action, entity: e.entity, entityId: e.entityId ?? null,
        before: e.before === undefined ? undefined : jsonSafe(e.before),
        after: e.after === undefined ? undefined : jsonSafe(e.after),
        ip: c?.ip ?? null, device: c?.userAgent?.slice(0, 200) ?? null, requestId: c?.requestId ?? null,
      },
    });
  }
}

const querySchema = paginationSchema.extend({ entity: z.string().max(60).optional(), entityId: idSchema.optional(), action: z.string().max(80).optional() });

@ApiTags('audit')
@ApiBearerAuth()
@Controller('audit')
export class AuditController {
  constructor(private readonly prisma: PrismaService) {}

  /** Fixed bug (M2 audit): was `@Roles('ADMIN')`, which silently excluded SUPER_ADMIN (D-028: SUPER_ADMIN always has every
   * permission, including AUDIT_VIEW, now in ADMIN_DEFAULTS too). MANAGER is never grantable this — audit is store-wide. */
  @Perm('AUDIT_VIEW')
  @Get()
  async list(@ZodQuery(querySchema) q: z.output<typeof querySchema>) {
    const rows = await this.prisma.auditLog.findMany({
      where: { entity: q.entity, entityId: q.entityId, action: q.action },
      orderBy: { id: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return {
      items: items.map((r) => ({ id: r.id, action: r.action, entity: r.entity, entityId: r.entityId, actorId: r.actorId, actorRole: r.actorRole, before: r.before, after: r.after, requestId: r.requestId, createdAt: r.createdAt.toISOString() })),
      nextCursor: rows.length > q.limit ? items[items.length - 1].id : null,
    };
  }
}

@Global()
@Module({ controllers: [AuditController], providers: [AuditService], exports: [AuditService] })
export class AuditModule {}
