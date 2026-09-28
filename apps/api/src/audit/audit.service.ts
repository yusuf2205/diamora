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
    const actors = await this.names('User', items.map((r) => r.actorId));
    const targets = new Map<string, Map<string, string>>();
    for (const entity of new Set(items.map((r) => r.entity))) {
      targets.set(entity, await this.names(entity, items.filter((r) => r.entity === entity).map((r) => r.entityId)));
    }
    return {
      items: items.map((r) => ({
        id: r.id, action: r.action, entity: r.entity, entityId: r.entityId, actorId: r.actorId, actorRole: r.actorRole,
        // who and what, in words: the person's name (not just a role) and the name of the thing that changed
        actorName: r.actorId ? (actors.get(r.actorId) ?? null) : null,
        targetName: r.entityId ? (targets.get(r.entity)?.get(r.entityId) ?? null) : null,
        before: r.before, after: r.after, ip: r.ip, device: r.device, requestId: r.requestId, createdAt: r.createdAt.toISOString(),
      })),
      nextCursor: rows.length > q.limit ? items[items.length - 1].id : null,
    };
  }

  /** id -> a human name for one entity type, in ONE query per type (unknown types simply get no name). */
  private async names(entity: string, rawIds: (string | null)[]): Promise<Map<string, string>> {
    const ids = [...new Set(rawIds.filter((x): x is string => !!x))];
    const out = new Map<string, string>();
    if (ids.length === 0) return out;
    const p = this.prisma;
    const put = (rows: { id: string; label: string }[]) => rows.forEach((r) => out.set(r.id, r.label));
    switch (entity) {
      case 'User':
        put((await p.user.findMany({ where: { id: { in: ids } }, select: { id: true, fullName: true } })).map((u) => ({ id: u.id, label: u.fullName })));
        break;
      case 'WorkerProfile':
        put((await p.workerProfile.findMany({ where: { id: { in: ids } }, select: { id: true, fullName: true, code: true } })).map((w) => ({ id: w.id, label: `${w.fullName} · ${w.code}` })));
        break;
      case 'WorkAssignment':
        put((await p.workAssignment.findMany({ where: { id: { in: ids } }, select: { id: true, code: true, worker: { select: { fullName: true } }, productModel: { select: { name: true } } } }))
          .map((a) => ({ id: a.id, label: `${a.productModel?.name ?? a.code} · ${a.worker.fullName}` })));
        break;
      case 'WorkerCollateral':
        put((await p.workerCollateral.findMany({ where: { id: { in: ids } }, select: { id: true, code: true, worker: { select: { fullName: true } } } })).map((c) => ({ id: c.id, label: `${c.worker.fullName} · ${c.code}` })));
        break;
      case 'Delivery':
        put((await p.delivery.findMany({ where: { id: { in: ids } }, select: { id: true, code: true, worker: { select: { fullName: true } } } })).map((d) => ({ id: d.id, label: `${d.worker.fullName} · ${d.code}` })));
        break;
      case 'CashPayment':
        put((await p.cashPayment.findMany({ where: { id: { in: ids } }, select: { id: true, worker: { select: { fullName: true } } } })).map((c) => ({ id: c.id, label: c.worker.fullName })));
        break;
      case 'Material':
        put((await p.material.findMany({ where: { id: { in: ids } }, select: { id: true, name: true } })).map((m) => ({ id: m.id, label: m.name })));
        break;
      case 'MaterialKitTemplate':
        put((await p.materialKitTemplate.findMany({ where: { id: { in: ids } }, select: { id: true, name: true } })).map((k) => ({ id: k.id, label: k.name })));
        break;
      case 'ProductModel':
        put((await p.productModel.findMany({ where: { id: { in: ids } }, select: { id: true, name: true } })).map((m) => ({ id: m.id, label: m.name })));
        break;
      case 'ProductVariant':
        put((await p.productVariant.findMany({ where: { id: { in: ids } }, select: { id: true, color: { select: { name: true } }, model: { select: { name: true } } } }))
          .map((v) => ({ id: v.id, label: `${v.model.name} · ${v.color.name}` })));
        break;
      case 'Color':
        put((await p.color.findMany({ where: { id: { in: ids } }, select: { id: true, name: true } })).map((c) => ({ id: c.id, label: c.name })));
        break;
      case 'UserSession':
        put((await p.userSession.findMany({ where: { id: { in: ids } }, select: { id: true, deviceName: true, user: { select: { fullName: true } } } }))
          .map((x) => ({ id: x.id, label: `${x.user.fullName}${x.deviceName ? ` · ${x.deviceName}` : ''}` })));
        break;
      default:
        break;
    }
    return out;
  }
}

@Global()
@Module({ controllers: [AuditController], providers: [AuditService], exports: [AuditService] })
export class AuditModule {}
