import { Controller, Delete, Get, HttpCode, Inject, Injectable, Module, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { createPurchaseSchema, receivePurchaseSchema, supplierSchema, updatePurchaseSchema } from '@diamoraa/shared';
import type { StockMovement } from '@diamoraa/database';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm } from '../common/decorators';
import { invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { nextCode } from '../common/sequence';
import { ZodBody } from '../common/zod.pipe';
import { ENV, Env } from '../config/env';
import { EventBus } from '../events/event-bus';
import { NotificationsModule, NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.module';
import { materialUsage } from '../stock/forecast';
import { StockModule, StockService } from '../stock/stock.service';
import { sha256, SUPPLIER_PREFIX } from './supplier-bot';

/** how long the «connect the bot» link for a supplier works (it is sent to them, they may open it later) */
const LINK_TTL_MS = 7 * 86_400_000;

const UNIT: Record<string, string> = { METER: 'м', GRAM: 'г', PCS: 'шт', SET: 'компл.', ROLL: 'рул.', PACKAGE: 'уп.' };
/** buy enough for about a month at the current pace (at least back to twice the minimum) */
const COVER_DAYS = 30;
/** list what runs out within two weeks (the «скоро закончится» notice warns at a week: this list is a step ahead) */
const PLAN_DAYS = 14;

/**
 * «Закупки»: what to buy (from the stock forecast), who from (suppliers), the order as a message to send, and receiving
 * it: one stock RECEIPT per line in one transaction, and the price paid becomes the material's purchase price - so
 * the cost and profit per product stay right without typing prices twice.
 */
@Injectable()
export class PurchasesService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus, private readonly stock: StockService,
    private readonly notifications: NotificationsService, @Inject(ENV) private readonly env: Env) {}

  // ---- suppliers
  async suppliers() {
    const rows = await this.prisma.supplier.findMany({ orderBy: [{ isActive: 'desc' }, { name: 'asc' }], include: { _count: { select: { materials: true } } } });
    return { items: rows.map((s) => ({ id: s.id, name: s.name, phone: s.phone, telegram: s.telegram, note: s.note, isActive: s.isActive, materials: s._count.materials, botLinked: s.telegramChatId !== null })) };
  }

  async addSupplier(input: z.output<typeof supplierSchema>) {
    const s = await this.prisma.supplier.create({ data: { name: input.name, phone: input.phone ?? null, telegram: input.telegram?.replace(/^@/, '') ?? null, note: input.note ?? null } });
    await this.audit.record({ action: 'supplier.create', entity: 'Supplier', entityId: s.id, after: { name: s.name } });
    return s;
  }

  async updateSupplier(id: string, input: z.output<typeof supplierSchema>) {
    if (!(await this.prisma.supplier.findUnique({ where: { id } }))) throw notFound('Supplier');
    const s = await this.prisma.supplier.update({
      where: { id },
      data: { name: input.name, phone: input.phone, telegram: input.telegram === undefined ? undefined : input.telegram?.replace(/^@/, '') ?? null, note: input.note, isActive: input.isActive },
    });
    await this.audit.record({ action: 'supplier.update', entity: 'Supplier', entityId: id, after: input });
    return s;
  }

  /** A link for the supplier: pressing «Старт» in our bot connects their chat (orders then go straight there). */
  async botLink(id: string, now = new Date()) {
    if (!(await this.prisma.supplier.findUnique({ where: { id } }))) throw notFound('Supplier');
    const token = randomBytes(18).toString('base64url');
    await this.prisma.supplier.update({ where: { id }, data: { linkTokenHash: sha256(token), linkExpiresAt: new Date(now.getTime() + LINK_TTL_MS) } });
    return { url: `https://t.me/${this.env.TELEGRAM_BOT_USERNAME}?start=${SUPPLIER_PREFIX}${token}`, expiresInDays: 7 };
  }

  async botUnlink(id: string) {
    if (!(await this.prisma.supplier.findUnique({ where: { id } }))) throw notFound('Supplier');
    await this.prisma.supplier.update({ where: { id }, data: { telegramChatId: null, linkTokenHash: null, linkExpiresAt: null } });
    await this.audit.record({ action: 'supplier.bot_unlinked', entity: 'Supplier', entityId: id });
    return { botLinked: false };
  }

  /** The order goes to the supplier's chat by our bot, with «Принял» / «Нет в наличии» under it; the order becomes «Заказано». */
  async sendByBot(actor: AuthUser, id: string) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id }, include: { supplier: true } });
    if (!o) throw notFound('Purchase');
    if (o.status === 'RECEIVED' || o.status === 'CANCELLED') throw invariant('This purchase is already closed');
    if (!o.supplier?.telegramChatId) throw invariant('The supplier has not connected the bot yet');
    const { text } = await this.text(id);
    await this.prisma.$transaction(async (tx) => {
      await this.notifications.telegram({
        chatId: o.supplier!.telegramChatId!, type: 'purchase.order', body: text,
        data: { purchaseId: id, buttons: [[{ text: '✅ Принял', data: `po:ok:${id}` }, { text: '❌ Нет в наличии', data: `po:no:${id}` }]] },
      }, tx);
      await tx.purchaseOrder.update({
        where: { id },
        data: { status: 'ORDERED', orderedAt: o.orderedAt ?? new Date(), sentByBotAt: new Date(), supplierReply: null, supplierReplyAt: null },
      });
      await this.audit.record({ action: 'purchase.sent_by_bot', entity: 'PurchaseOrder', entityId: id, actorId: actor.id, actorRole: actor.role }, tx);
    });
    await this.events.publish('purchase.updated', { purchaseId: id });
    return this.get(id);
  }

  // ---- «Что купить»
  async suggest(now = new Date()) {
    const mats = await this.prisma.material.findMany({ where: { isActive: true, deletedAt: null }, include: { balance: true, supplier: { select: { id: true, name: true } } }, orderBy: { name: 'asc' } });
    const qty = new Map(mats.map((m) => [m.id, Number(m.balance?.quantity ?? 0)]));
    const usage = await materialUsage(this.prisma, qty, now);
    // what is already on its way (ordered, not received) is not suggested again
    const onWay = await this.prisma.purchaseOrderItem.groupBy({ by: ['materialId'], where: { order: { status: { in: ['DRAFT', 'ORDERED'] } } }, _sum: { quantity: true } });
    const coming = new Map(onWay.map((r) => [r.materialId, Number(r._sum.quantity ?? 0)]));
    const items = mats.flatMap((m) => {
      const left = (qty.get(m.id) ?? 0) + (coming.get(m.id) ?? 0);
      const min = Number(m.minStock);
      const u = usage.get(m.id) ?? { dailyUse: 0, daysLeft: null };
      const daysLeft = u.dailyUse > 0 ? Math.floor(left / u.dailyUse) : null;
      const low = left < min;
      const soon = daysLeft !== null && daysLeft <= PLAN_DAYS;
      if (!low && !soon) return [];
      const target = Math.max(min * 2, u.dailyUse * COVER_DAYS);
      const quantity = Math.max(1, Math.ceil(target - left));
      return [{
        materialId: m.id, name: m.name, unit: m.unit, unitLabel: UNIT[m.unit] ?? '', left: qty.get(m.id) ?? 0, coming: coming.get(m.id) ?? 0, minStock: min,
        dailyUse: u.dailyUse, daysLeft, quantity, lastPrice: m.unitCost === null ? null : m.unitCost.toString(),
        supplier: m.supplier, reason: left <= 0 ? 'закончился' : low ? `ниже минимума (${min})` : `хватит ≈ на ${daysLeft} дн.`,
      }];
    });
    return { items };
  }

  // ---- orders
  async list(status?: string) {
    const rows = await this.prisma.purchaseOrder.findMany({
      where: status ? { status: status as never } : undefined,
      orderBy: { createdAt: 'desc' }, take: 50,
      include: { supplier: true, items: { include: { material: { select: { id: true, name: true, unit: true } } } } },
    });
    return { items: rows.map((o) => this.dto(o)) };
  }

  async create(actor: AuthUser, input: z.output<typeof createPurchaseSchema>) {
    await this.checkMaterials(input.items.map((i) => i.materialId));
    const row = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'purchase_code', 'ЗК-', 4);
      const o = await tx.purchaseOrder.create({
        data: {
          code, supplierId: input.supplierId ?? null, note: input.note, createdById: actor.id,
          items: { create: input.items.map((i) => ({ materialId: i.materialId, quantity: i.quantity, unitPrice: i.unitPrice ?? null })) },
        },
      });
      await this.audit.record({ action: 'purchase.create', entity: 'PurchaseOrder', entityId: o.id, after: { code, lines: input.items.length } }, tx);
      return o;
    });
    return this.get(row.id);
  }

  async update(actor: AuthUser, id: string, input: z.output<typeof updatePurchaseSchema>) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id } });
    if (!o) throw notFound('Purchase');
    if (o.status === 'RECEIVED' || o.status === 'CANCELLED') throw invariant('This purchase is already closed');
    if (input.items) {
      if (o.status !== 'DRAFT') throw invariant('Lines can only be changed before the order is sent');
      await this.checkMaterials(input.items.map((i) => i.materialId));
    }
    await this.prisma.$transaction(async (tx) => {
      if (input.items) {
        await tx.purchaseOrderItem.deleteMany({ where: { orderId: id } });
        await tx.purchaseOrderItem.createMany({ data: input.items.map((i) => ({ orderId: id, materialId: i.materialId, quantity: i.quantity, unitPrice: i.unitPrice ?? null })) });
      }
      await tx.purchaseOrder.update({
        where: { id },
        data: { status: input.status, note: input.note === undefined ? undefined : input.note, orderedAt: input.status === 'ORDERED' ? new Date() : undefined },
      });
      await this.audit.record({ action: 'purchase.update', entity: 'PurchaseOrder', entityId: id, before: { status: o.status }, after: { status: input.status ?? o.status, lines: input.items?.length } }, tx);
    });
    return this.get(id);
  }

  /** On the shelf: a RECEIPT per line (what really came), the price becomes the material's purchase price. Once. */
  async receive(actor: AuthUser, id: string, input: z.output<typeof receivePurchaseSchema>) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id }, include: { items: true } });
    if (!o) throw notFound('Purchase');
    if (o.status === 'RECEIVED' || o.status === 'CANCELLED') throw invariant('This purchase is already closed');
    const lines = new Map(o.items.map((i) => [i.id, i]));
    if (input.items.some((i) => !lines.has(i.itemId))) throw invariant('Unknown line');
    const movements: StockMovement[] = await this.prisma.$transaction(async (tx) => {
      const done: StockMovement[] = [];
      for (const r of input.items) {
        const line = lines.get(r.itemId)!;
        const price = r.unitPrice ?? line.unitPrice;
        if (Number(r.quantity) > 0) {
          done.push(await this.stock.recordMovement(tx, actor, { type: 'RECEIPT', materialId: line.materialId, quantity: r.quantity, warehouseDelta: r.quantity, comment: `Закупка ${o.code}` }));
        }
        await tx.purchaseOrderItem.update({ where: { id: line.id }, data: { quantity: r.quantity, unitPrice: price ?? null } });
        if (price !== null && price !== undefined) await tx.material.update({ where: { id: line.materialId }, data: { unitCost: BigInt(price) } });
      }
      await tx.purchaseOrder.update({ where: { id }, data: { status: 'RECEIVED', receivedAt: new Date() } });
      await this.audit.record({ action: 'purchase.receive', entity: 'PurchaseOrder', entityId: id, after: { lines: input.items.length } }, tx);
      return done;
    });
    for (const m of movements) await this.stock.publish(m);
    return this.get(id);
  }

  /** The order as a message for the supplier (Telegram / SMS / copy). */
  async text(id: string) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id }, include: { supplier: true, items: { include: { material: true } } } });
    if (!o) throw notFound('Purchase');
    const lines = o.items.map((i, n) => `${n + 1}. ${i.material.name}${i.material.article ? ` (${i.material.article})` : ''} — ${Number(i.quantity)} ${UNIT[i.material.unit] ?? ''}`);
    const text = [`Здравствуйте${o.supplier ? `, ${o.supplier.name}` : ''}! Заказ ${o.code} от Diamoraa:`, ...lines, o.note ? `\nКомментарий: ${o.note}` : '', '\nСпасибо!'].filter(Boolean).join('\n');
    return { text, telegram: o.supplier?.telegram ?? null, phone: o.supplier?.phone ?? null, botLinked: !!o.supplier?.telegramChatId };
  }

  async get(id: string) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id }, include: { supplier: true, items: { include: { material: { select: { id: true, name: true, unit: true } } } } } });
    if (!o) throw notFound('Purchase');
    return this.dto(o);
  }

  private async checkMaterials(ids: string[]) {
    const n = await this.prisma.material.count({ where: { id: { in: [...new Set(ids)] }, deletedAt: null } });
    if (n !== new Set(ids).size) throw notFound('Material');
  }

  private dto(o: {
    id: string; code: string; status: string; note: string | null; createdAt: Date; orderedAt: Date | null; receivedAt: Date | null;
    sentByBotAt: Date | null; supplierReply: string | null; supplierReplyAt: Date | null;
    supplier: { id: string; name: string; phone: string | null; telegram: string | null; telegramChatId: bigint | null } | null;
    items: { id: string; quantity: { toString(): string }; unitPrice: bigint | null; material: { id: string; name: string; unit: string } }[];
  }) {
    const total = o.items.reduce((a, i) => a + (i.unitPrice === null ? 0 : Math.round(Number(i.quantity.toString()) * Number(i.unitPrice))), 0);
    return {
      id: o.id, code: o.code, status: o.status, note: o.note, createdAt: o.createdAt.toISOString(), orderedAt: o.orderedAt?.toISOString() ?? null, receivedAt: o.receivedAt?.toISOString() ?? null,
      supplier: o.supplier ? { id: o.supplier.id, name: o.supplier.name, phone: o.supplier.phone, telegram: o.supplier.telegram, botLinked: o.supplier.telegramChatId !== null } : null,
      sentByBotAt: o.sentByBotAt?.toISOString() ?? null, supplierReply: o.supplierReply, supplierReplyAt: o.supplierReplyAt?.toISOString() ?? null,
      items: o.items.map((i) => ({ id: i.id, material: i.material, unitLabel: UNIT[i.material.unit] ?? '', quantity: Number(i.quantity.toString()), unitPrice: i.unitPrice === null ? null : i.unitPrice.toString() })),
      total: String(total), priced: o.items.every((i) => i.unitPrice !== null),
    };
  }
}

@ApiTags('purchases')
@ApiBearerAuth()
@Controller('admin')
export class PurchasesController {
  constructor(private readonly purchases: PurchasesService) {}

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('suppliers')
  suppliers() { return this.purchases.suppliers(); }

  @Perm('INVENTORY_MANAGE') @Post('suppliers') @ApiZodBody(supplierSchema)
  addSupplier(@ZodBody(supplierSchema) b: z.output<typeof supplierSchema>) { return this.purchases.addSupplier(b); }

  @Perm('INVENTORY_MANAGE') @Patch('suppliers/:id') @ApiZodBody(supplierSchema)
  updateSupplier(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(supplierSchema) b: z.output<typeof supplierSchema>) { return this.purchases.updateSupplier(id, b); }

  @Perm('INVENTORY_MANAGE') @Post('suppliers/:id/bot-link') @HttpCode(200)
  botLink(@Param('id', new ParseUUIDPipe()) id: string) { return this.purchases.botLink(id); }

  @Perm('INVENTORY_MANAGE') @Delete('suppliers/:id/bot-link')
  botUnlink(@Param('id', new ParseUUIDPipe()) id: string) { return this.purchases.botUnlink(id); }

  @Perm('INVENTORY_MANAGE') @Post('purchases/:id/send') @HttpCode(200)
  send(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.purchases.sendByBot(u, id); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('purchases/suggest')
  suggest() { return this.purchases.suggest(); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('purchases')
  list(@Query('status') status?: string) { return this.purchases.list(['DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED'].includes(status ?? '') ? status : undefined); }

  @Perm('INVENTORY_MANAGE') @Post('purchases') @ApiZodBody(createPurchaseSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createPurchaseSchema) b: z.output<typeof createPurchaseSchema>) { return this.purchases.create(u, b); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('purchases/:id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.purchases.get(id); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('purchases/:id/text')
  text(@Param('id', new ParseUUIDPipe()) id: string) { return this.purchases.text(id); }

  @Perm('INVENTORY_MANAGE') @Patch('purchases/:id') @ApiZodBody(updatePurchaseSchema)
  update(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updatePurchaseSchema) b: z.output<typeof updatePurchaseSchema>) { return this.purchases.update(u, id, b); }

  @Perm('INVENTORY_MANAGE') @Post('purchases/:id/receive') @HttpCode(200) @ApiZodBody(receivePurchaseSchema)
  receive(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(receivePurchaseSchema) b: z.output<typeof receivePurchaseSchema>) { return this.purchases.receive(u, id, b); }
}

@Module({ imports: [StockModule, NotificationsModule], controllers: [PurchasesController], providers: [PurchasesService] })
export class PurchasesModule {}
