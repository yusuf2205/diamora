import { Controller, Get, HttpCode, Inject, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { clientOrderSchema, listClientOrdersSchema, updateClientOrderSchema } from '@diamoraa/shared';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { CatalogModule, CatalogService } from '../catalog/catalog.service';
import { ApiZodBody, CurrentUser, Public, Roles } from '../common/decorators';
import { notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { nextCode } from '../common/sequence';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { ENV, Env } from '../config/env';
import { EventBus } from '../events/event-bus';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.module';

export type OrderSource = 'PANEL' | 'SITE' | 'BOT';
/** `/start o_<order id hex>_<signature>`: a customer from the site follows their order in the shop bot */
export const FOLLOW_PREFIX = 'o_';

const STEP_TEXT: Record<string, (code: string) => string> = {
  CONFIRMED: (c) => `✅ Заказ ${c} подтверждён. Скоро начнём работу.`,
  IN_WORK: (c) => `🧵 Заказ ${c} в работе.`,
  DONE: (c) => `🎉 Заказ ${c} готов! Мы свяжемся с вами насчёт получения.`,
  CANCELLED: (c) => `Заказ ${c} отменён. Если это ошибка — напишите сюда, мы ответим.`,
};
export const STATUS_RU: Record<string, string> = { NEW: 'принят, скоро позвоним', CONFIRMED: 'подтверждён', IN_WORK: 'в работе', DONE: 'готов', CANCELLED: 'отменён' };

/**
 * Customer orders from three doors (owner, 2026-10-01): staff write them down in the panel (SUPER_ADMIN / ADMIN /
 * MANAGER), customers order themselves on shop.diamoraa.uz or in the separate shop bot. All of them land in «Заказы
 * клиентов» and move NEW -> CONFIRMED -> IN_WORK -> DONE (or CANCELLED); a customer with the bot hears about each step.
 */
@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus,
    private readonly catalog: CatalogService, private readonly notifications: NotificationsService, @Inject(ENV) private readonly env: Env,
  ) {}

  /** what can be ordered: every item (drafts too - staff know what is made) with its colours, for the order form */
  async products() {
    const rows = await this.prisma.productModel.findMany({
      where: { deletedAt: null }, orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      select: { id: true, name: true, variants: { where: { active: true }, select: { color: { select: { name: true, hex: true } } } } },
    });
    return { items: rows.map((p) => ({ id: p.id, name: p.name, colors: p.variants.map((v) => v.color) })) };
  }

  /** The shop: the published catalog only (photos, colours - never prices for workers, never a draft). */
  async publicCatalog() {
    const c = await this.catalog.published();
    return { ...c, bot: this.env.SHOP_BOT_USERNAME || null };
  }

  publicItem(id: string) { return this.catalog.publishedDetail(id); }

  async create(input: z.output<typeof clientOrderSchema>, actor?: AuthUser, from: { source?: OrderSource; chatId?: bigint } = {}) {
    const source = from.source ?? 'PANEL';
    if (input.productModelId) {
      // customers pick from the published catalog; staff may write down anything that is made
      const p = await this.prisma.productModel.findFirst({ where: { id: input.productModelId, deletedAt: null, ...(source === 'PANEL' ? {} : { status: 'PUBLISHED' }) }, select: { id: true } });
      if (!p) throw notFound('Item');
    }
    const row = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'client_order_code', 'CO-', 5);
      return tx.clientOrder.create({
        data: {
          code, name: input.name, phone: input.phone, productModelId: input.productModelId, colorName: input.colorName || null, quantity: input.quantity,
          comment: input.comment || null, handledById: actor?.id ?? null, source, customerChatId: from.chatId ?? null,
        },
      });
    });
    await this.events.publish('client_order.created', { orderId: row.id, code: row.code, name: row.name });
    return { ok: true, code: row.code, id: row.id };
  }

  /** shop.diamoraa.uz: no account. A filled trap field = a bot: pretend it worked, store nothing. */
  async createFromSite(input: z.output<typeof clientOrderSchema>) {
    if (input.website) return { ok: true, code: null, follow: null };
    const r = await this.create(input, undefined, { source: 'SITE' });
    const bot = this.env.SHOP_BOT_USERNAME;
    return { ok: true, code: r.code, follow: bot ? `https://t.me/${bot}?start=${this.followToken(r.id)}` : null };
  }

  followToken(orderId: string) {
    const hex = orderId.replace(/-/g, '');
    return `${FOLLOW_PREFIX}${hex}_${this.sign(hex)}`;
  }

  /** The shop bot: `/start o_...` from the site's «Следить в Telegram» - this chat now hears about that order. */
  async follow(token: string, chatId: bigint) {
    const m = /^o_([0-9a-f]{32})_([0-9a-f]{16})$/.exec(token);
    if (!m) return null;
    const a = Buffer.from(this.sign(m[1])), b = Buffer.from(m[2]);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
    const id = `${m[1].slice(0, 8)}-${m[1].slice(8, 12)}-${m[1].slice(12, 16)}-${m[1].slice(16, 20)}-${m[1].slice(20)}`;
    const o = await this.prisma.clientOrder.findUnique({ where: { id } });
    if (!o) return null;
    await this.prisma.clientOrder.update({ where: { id }, data: { customerChatId: chatId } });
    return { code: o.code, status: o.status };
  }

  /** «Мои заказы» in the shop bot */
  async ofChat(chatId: bigint) {
    const rows = await this.prisma.clientOrder.findMany({ where: { customerChatId: chatId }, orderBy: { createdAt: 'desc' }, take: 10, include: { productModel: { select: { name: true } } } });
    return rows.map((o) => ({ code: o.code, status: o.status, product: o.productModel?.name ?? null, colorName: o.colorName, quantity: o.quantity === null ? null : Number(o.quantity), createdAt: o.createdAt }));
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
      // the customer follows the order in the shop bot: tell them about the new step (the staff note stays inside)
      const say = r.status !== before.status ? STEP_TEXT[r.status] : undefined;
      if (say && r.customerChatId !== null) {
        await this.notifications.telegram({ chatId: r.customerChatId, type: 'client_order.step', body: say(r.code), data: { orderId: id, via: 'shop' } }, tx);
      }
      return r;
    });
    await this.events.publish('client_order.updated', { orderId: id });
    return this.dto(row);
  }

  private sign(v: string) {
    return createHmac('sha256', this.env.FILE_SIGNING_SECRET).update(`order-follow:${v}`).digest('hex').slice(0, 16);
  }

  private dto(r: { id: string; code: string; name: string; phone: string; colorName: string | null; quantity: { toString(): string } | null; comment: string | null; status: string; staffNote: string | null; source: string; customerChatId: bigint | null; createdAt: Date; updatedAt: Date; productModel: { id: string; name: string } | null }) {
    return {
      id: r.id, code: r.code, name: r.name, phone: r.phone, product: r.productModel, colorName: r.colorName,
      quantity: r.quantity === null ? null : Number(r.quantity.toString()), comment: r.comment, status: r.status, staffNote: r.staffNote,
      source: r.source, followsInBot: r.customerChatId !== null,
      createdAt: r.createdAt.toISOString(), updatedAt: r.updatedAt.toISOString(),
    };
  }
}

@ApiTags('orders')
@Controller()
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  // the shop (shop.diamoraa.uz): no account
  @Public() @Get('public/catalog')
  catalog() { return this.orders.publicCatalog(); }

  @Public() @Get('public/catalog/:id')
  item(@Param('id', new ParseUUIDPipe()) id: string) { return this.orders.publicItem(id); }

  /** at most 5 orders in 10 minutes from one address: a person never needs more, a spammer gets nowhere */
  @Public() @Throttle({ default: { limit: 5, ttl: 600_000 } }) @Post('public/orders') @HttpCode(201) @ApiZodBody(clientOrderSchema)
  createPublic(@ZodBody(clientOrderSchema) b: z.output<typeof clientOrderSchema>) { return this.orders.createFromSite(b); }

  // staff write down an order taken by phone / in person
  @ApiBearerAuth() @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Post('admin/orders') @HttpCode(201) @ApiZodBody(clientOrderSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(clientOrderSchema) b: z.output<typeof clientOrderSchema>) { return this.orders.create(b, u); }

  @ApiBearerAuth() @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Get('admin/orders/products')
  products() { return this.orders.products(); }

  @ApiBearerAuth() @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Get('admin/orders')
  list(@ZodQuery(listClientOrdersSchema) q: z.output<typeof listClientOrdersSchema>) { return this.orders.list(q); }

  @ApiBearerAuth() @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Patch('admin/orders/:id') @ApiZodBody(updateClientOrderSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateClientOrderSchema) b: z.output<typeof updateClientOrderSchema>) {
    return this.orders.update(u, id, b);
  }
}

@Module({ imports: [CatalogModule], controllers: [OrdersController], providers: [OrdersService], exports: [OrdersService] })
export class OrdersModule {}
