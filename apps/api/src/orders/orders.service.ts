import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { clientOrderSchema, listClientOrdersSchema, updateClientOrderSchema } from '@diamoraa/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Public } from '../common/decorators';
import { notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { nextCode } from '../common/sequence';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { CatalogModule, CatalogService } from '../catalog/catalog.service';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

/**
 * Customer orders (owner's decision: ONLY from the form on diamoraa.uz - no bot, no online payment). A customer picks an
 * item from the published catalog, a colour and metres, leaves a name and a phone; staff see it in «Заказы клиентов» with
 * a notice right away and move it NEW -> CONFIRMED -> IN_WORK -> DONE (or CANCELLED).
 */
@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus, private readonly catalog: CatalogService) {}

  /** What a customer can pick from: the same published catalog workers see (never a purchase price, never a draft). */
  publicCatalog() {
    return this.catalog.published();
  }

  async create(input: z.output<typeof clientOrderSchema>) {
    if (input.website) return { ok: true, code: null }; // a bot filled the hidden field: pretend it worked, store nothing
    if (input.productModelId) {
      const p = await this.prisma.productModel.findFirst({ where: { id: input.productModelId, status: 'PUBLISHED', deletedAt: null }, select: { id: true } });
      if (!p) throw notFound('Item');
    }
    const row = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'client_order_code', 'CO-', 5);
      return tx.clientOrder.create({
        data: { code, name: input.name, phone: input.phone, productModelId: input.productModelId, colorName: input.colorName || null, quantity: input.quantity, comment: input.comment || null },
      });
    });
    await this.events.publish('client_order.created', { orderId: row.id, code: row.code, name: row.name });
    return { ok: true, code: row.code };
  }

  async list(q: z.output<typeof listClientOrdersSchema>) {
    const [rows, counts] = await Promise.all([
      this.prisma.clientOrder.findMany({ where: { status: q.status }, orderBy: { createdAt: 'desc' }, take: q.limit, include: { productModel: { select: { id: true, name: true } } } }),
      this.prisma.clientOrder.groupBy({ by: ['status'], _count: { _all: true } }),
    ]);
    return {
      items: rows.map((r) => this.dto(r)),
      counts: Object.fromEntries(counts.map((c) => [c.status, c._count._all])),
    };
  }

  async update(actor: AuthUser, id: string, input: z.output<typeof updateClientOrderSchema>) {
    const before = await this.prisma.clientOrder.findUnique({ where: { id } });
    if (!before) throw notFound('Order');
    const row = await this.prisma.$transaction(async (tx) => {
      const r = await tx.clientOrder.update({
        where: { id },
        data: { status: input.status, staffNote: input.staffNote === undefined ? undefined : input.staffNote || null, handledById: actor.id },
        include: { productModel: { select: { id: true, name: true } } },
      });
      await this.audit.record({ action: 'client_order.update', entity: 'ClientOrder', entityId: id, before: { status: before.status, staffNote: before.staffNote }, after: { status: r.status, staffNote: r.staffNote } }, tx);
      return r;
    });
    await this.events.publish('client_order.updated', { orderId: id });
    return this.dto(row);
  }

  private dto(r: { id: string; code: string; name: string; phone: string; colorName: string | null; quantity: { toString(): string } | null; comment: string | null; status: string; staffNote: string | null; createdAt: Date; updatedAt: Date; productModel: { id: string; name: string } | null }) {
    return {
      id: r.id, code: r.code, name: r.name, phone: r.phone, product: r.productModel, colorName: r.colorName,
      quantity: r.quantity === null ? null : Number(r.quantity.toString()), comment: r.comment, status: r.status, staffNote: r.staffNote,
      createdAt: r.createdAt.toISOString(), updatedAt: r.updatedAt.toISOString(),
    };
  }
}

@ApiTags('orders')
@Controller()
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Public() @Get('public/catalog')
  catalog() { return this.orders.publicCatalog(); }

  /** at most 5 orders in 10 minutes from one address: a person never needs more, a spammer gets nowhere */
  @Public() @Throttle({ default: { limit: 5, ttl: 600_000 } }) @Post('public/orders') @HttpCode(201) @ApiZodBody(clientOrderSchema)
  create(@ZodBody(clientOrderSchema) b: z.output<typeof clientOrderSchema>) { return this.orders.create(b); }

  @ApiBearerAuth() @Perm('CATALOG_VIEW', 'CATALOG_MANAGE') @Get('admin/orders')
  list(@ZodQuery(listClientOrdersSchema) q: z.output<typeof listClientOrdersSchema>) { return this.orders.list(q); }

  @ApiBearerAuth() @Perm('CATALOG_MANAGE') @Patch('admin/orders/:id') @ApiZodBody(updateClientOrderSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateClientOrderSchema) b: z.output<typeof updateClientOrderSchema>) {
    return this.orders.update(u, id, b);
  }
}

@Module({ imports: [CatalogModule], controllers: [OrdersController], providers: [OrdersService] })
export class OrdersModule {}
