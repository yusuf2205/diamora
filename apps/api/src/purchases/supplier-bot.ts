import { Injectable, Module } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { AuditModule, AuditService } from '../audit/audit.service';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

export const SUPPLIER_PREFIX = 'sup_';
/** callback data under an order sent to a supplier: po:<ok|no>:<purchase id> */
export const PO_CALLBACK = /^po:(ok|no):([0-9a-f-]{36})$/;
export const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

export type SupplierReply = 'ACCEPTED' | 'UNAVAILABLE';
export const REPLY_RU: Record<SupplierReply, string> = { ACCEPTED: '✅ Принял', UNAVAILABLE: '❌ Нет в наличии' };

/**
 * The supplier's side of the bot: the supplier presses «Старт» on the link from «Поставщики» once, then orders arrive
 * in that chat with two buttons and the answer comes back to the panel. A supplier never sees anything else of Diamoraa.
 */
@Injectable()
export class SupplierBot {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async isSupplierChat(chatId: bigint) {
    return !!(await this.prisma.supplier.findUnique({ where: { telegramChatId: chatId }, select: { id: true } }));
  }

  /** `/start sup_<token>`. Returns the reply text. */
  async completeLink(token: string, chatId: bigint, now = new Date()): Promise<string> {
    const s = await this.prisma.supplier.findUnique({ where: { linkTokenHash: sha256(token) } });
    if (!s || !s.linkExpiresAt || s.linkExpiresAt < now) return 'Ссылка устарела. Попросите Diamoraa прислать новую.';
    // one chat belongs to one supplier: a re-link moves it
    await this.prisma.$transaction([
      this.prisma.supplier.updateMany({ where: { telegramChatId: chatId, id: { not: s.id } }, data: { telegramChatId: null } }),
      this.prisma.supplier.update({ where: { id: s.id }, data: { telegramChatId: chatId, linkTokenHash: null, linkExpiresAt: null } }),
    ]);
    await this.audit.record({ action: 'supplier.bot_linked', entity: 'Supplier', entityId: s.id });
    await this.events.publish('purchase.updated', { purchaseId: null });
    return `Здравствуйте, ${s.name}! Теперь заказы Diamoraa будут приходить сюда.\nПод каждым заказом — кнопки «Принял» и «Нет в наличии». Можно и просто написать сообщение — мы его получим.`;
  }

  /** A button under an order. Returns the new message text, or null when it is not this supplier's order. */
  async reply(chatId: bigint, purchaseId: string, reply: SupplierReply, now = new Date()) {
    const o = await this.prisma.purchaseOrder.findUnique({ where: { id: purchaseId }, include: { supplier: true } });
    if (!o || o.supplier?.telegramChatId !== chatId) return null;
    if (o.status === 'CANCELLED') return { text: `Заказ ${o.code} отменён — ничего делать не нужно.`, changed: false, owners: null };
    if (o.supplierReply !== reply) {
      await this.prisma.purchaseOrder.update({ where: { id: o.id }, data: { supplierReply: reply, supplierReplyAt: now } });
      await this.audit.record({ action: 'purchase.supplier_reply', entity: 'PurchaseOrder', entityId: o.id, after: { reply } });
      await this.events.publish('purchase.replied', { purchaseId: o.id, code: o.code, supplier: o.supplier.name, reply });
    }
    const owners = `📦 ${o.supplier.name}: ${reply === 'ACCEPTED' ? 'принял заказ' : 'нет в наличии по заказу'} ${o.code}.
Подробнее — в панели «Закупки».`;
    return { text: `${REPLY_RU[reply]} — заказ ${o.code}. Спасибо, передали Diamoraa.`, changed: o.supplierReply !== reply, owners };
  }

  /** Plain text from a supplier: passed to the staff as a notice. */
  async message(chatId: bigint, text: string) {
    const s = await this.prisma.supplier.findUnique({ where: { telegramChatId: chatId } });
    if (!s) return null;
    await this.events.publish('purchase.supplier_message', { supplierId: s.id, supplier: s.name, text: text.slice(0, 500) });
    return { reply: 'Спасибо, передали Diamoraa.', owners: `💬 Поставщик ${s.name} пишет:
${text.slice(0, 500)}` };
  }
}

@Module({ imports: [AuditModule], providers: [SupplierBot], exports: [SupplierBot] })
export class SupplierBotModule {}
