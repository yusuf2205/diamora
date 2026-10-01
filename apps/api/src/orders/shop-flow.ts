import { Inject, Injectable, Module } from '@nestjs/common';
import { phoneSchema } from '@diamoraa/shared';
import { ENV, Env } from '../config/env';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import { FOLLOW_PREFIX, linesText, type OrderLine, OrdersModule, OrdersService, STATUS_RU } from './orders.service';

/** the customer's reply keyboard */
export const SHOP_MENU = [['🛍 Каталог', '📝 Заказать'], ['📦 Мои заказы', '📞 Связаться']] as const;

export type ShopInput =
  | { kind: 'start'; payload?: string }
  | { kind: 'text'; text: string; from?: string }
  | { kind: 'contact'; phone: string }
  | { kind: 'callback'; data: string };

export interface ShopReply {
  text: string;
  /** inline buttons: callback data, or a url */
  buttons?: { text: string; data?: string; url?: string }[][];
  /** the «📱 Отправить номер» keyboard instead of the menu */
  askContact?: boolean;
  /** show the menu keyboard */
  menu?: boolean;
  /** replace the message the button was pressed under (ticking colours) instead of sending a new one */
  edit?: boolean;
  /** for the owners' Telegram (a customer wrote something) */
  owners?: string;
}

interface Draft {
  step: 'product' | 'color' | 'qty' | 'name' | 'phone' | 'confirm';
  productId?: string; productName?: string; colors?: string[];
  /** the colours ticked, in the catalog's order */
  picked?: string[];
  /** metres per picked colour (asked one by one); without colours: one number */
  lines?: OrderLine[]; qty?: number;
  name?: string; phone?: string;
  at: number;
}
const DRAFT_TTL_MS = 60 * 60_000;
const MAX_ITEMS = 40;
const fmt = (n: number) => String(Math.round(n * 100) / 100);

/**
 * The customers' bot (separate from the workers' bot, owner 2026-10-01): browse, order step by step (item -> one or
 * several colours -> metres for each -> name -> phone -> confirm), see «Мои заказы», contact us. Telegram-free so it
 * is tested directly; the worker's ShopBot only turns updates into ShopInput and replies into messages.
 */
@Injectable()
export class ShopFlow {
  private readonly drafts = new Map<string, Draft>();
  constructor(private readonly prisma: PrismaService, private readonly orders: OrdersService, private readonly events: EventBus, @Inject(ENV) private readonly env: Env) {}

  private get shopUrl() { return `https://${this.env.SHOP_HOST || 'shop.diamoraa.uz'}`; }

  async handle(chatId: bigint, input: ShopInput, now = Date.now()): Promise<ShopReply> {
    const key = String(chatId);
    const d = this.drafts.get(key);
    const draft = d && now - d.at < DRAFT_TTL_MS ? d : undefined;
    if (d && !draft) this.drafts.delete(key);

    if (input.kind === 'start') {
      this.drafts.delete(key);
      if (input.payload?.startsWith(FOLLOW_PREFIX)) {
        const f = await this.orders.follow(input.payload, chatId);
        if (f) return { text: `Готово! Здесь будут новости по заказу ${f.code} (сейчас: ${STATUS_RU[f.status]}).`, menu: true };
      }
      return { text: 'Здравствуйте! Это Diamoraa 💎\nЗдесь можно посмотреть каталог, заказать изделие и следить за заказом.\nНажмите кнопку внизу.', menu: true };
    }

    if (input.kind === 'callback') return this.callback(key, chatId, draft, input.data, now);

    if (input.kind === 'contact') {
      if (draft?.step === 'phone') return this.setPhone(key, draft, input.phone, now);
      return { text: 'Спасибо! Чтобы заказать, нажмите «📝 Заказать».', menu: true };
    }

    const text = input.text.trim();
    switch (text) {
      case '🛍 Каталог': return this.catalog();
      case '📝 Заказать': return this.startOrder(key, now);
      case '📦 Мои заказы': return this.mine(chatId);
      case '📞 Связаться': return this.contact();
      case '/cancel': this.drafts.delete(key); return { text: 'Отменили.', menu: true };
    }

    if (draft?.step === 'qty') {
      const n = Number(text.replace(',', '.').replace(/[^\d.]/g, ''));
      if (!(n > 0 && n <= 100_000)) return { text: 'Напишите число метров, например 27. Или нажмите «Пропустить».', buttons: [[{ text: 'Пропустить', data: 'sh:q:-' }]] };
      return this.setQty(key, draft, n, now);
    }
    if (draft?.step === 'name') {
      if (text.length < 2 || text.length > 80) return { text: 'Напишите ваше имя (от 2 букв).' };
      return this.next(key, { ...draft, name: text, step: 'phone' }, now);
    }
    if (draft?.step === 'phone') return this.setPhone(key, draft, text, now);

    // not in an order: a question for us
    await this.events.publish('client_order.message', { from: input.from ?? 'покупатель', text: text.slice(0, 500) });
    return { text: 'Спасибо, передали Diamoraa. Мы ответим или перезвоним.', menu: true, owners: `💬 Покупатель ${input.from ?? ''} пишет в бот магазина:\n${text.slice(0, 500)}` };
  }

  /** «📞 Связаться»: the company's Telegram and phone from «Настройки → Контакты компании» */
  private async contact(): Promise<ShopReply> {
    const c = await this.orders.contact();
    const lines = ['📞 Связаться с Diamoraa:'];
    if (c.telegramUsername) lines.push(`Telegram: @${c.telegramUsername}`);
    if (c.phone) lines.push(`Телефон: ${c.phone}`);
    lines.push('', 'Или напишите вопрос прямо сюда — мы ответим.');
    return c.telegramUrl ? { text: lines.join('\n'), buttons: [[{ text: `✈️ Написать @${c.telegramUsername}`, url: c.telegramUrl }]] } : { text: lines.join('\n'), menu: true };
  }

  private async catalog(): Promise<ShopReply> {
    const items = await this.items();
    if (!items.length) return { text: 'Каталог скоро появится. Напишите, что хотите — мы ответим.', menu: true };
    return {
      text: `🛍 Наш каталог (${items.length}):\n${items.slice(0, 20).map((i) => `• ${i.name}${i.colors.length ? ` — ${i.colors.length} цв.` : ''}`).join('\n')}\n\nФото и цвета — на сайте:`,
      buttons: [
        [{ text: '🛍 Открыть каталог', url: this.shopUrl }],
        [{ text: '📝 Заказать здесь', data: 'sh:new' }],
        // the customers' training video (tools/tutorials), played right in Telegram's browser
        [{ text: '🎬 Video: qanday buyurtma berish', url: `${this.env.PUBLIC_API_URL.replace(/\/+$/, '')}/download/tutorials/customer-uz.mp4` }],
      ],
    };
  }

  private async startOrder(key: string, now: number): Promise<ShopReply> {
    const items = await this.items();
    if (!items.length) return { text: 'Каталог пока пуст. Напишите, что хотите, — мы перезвоним.', menu: true };
    this.drafts.set(key, { step: 'product', at: now });
    return { text: '1/5 · Какое изделие?', buttons: items.slice(0, MAX_ITEMS).map((i) => [{ text: i.name, data: `sh:p:${i.id}` }]) };
  }

  private async callback(key: string, chatId: bigint, draft: Draft | undefined, data: string, now: number): Promise<ShopReply> {
    if (data === 'sh:new') return this.startOrder(key, now);
    if (data === 'sh:x') { this.drafts.delete(key); return { text: 'Заказ отменён.', menu: true }; }
    if (!draft) return { text: 'Этот шаг устарел. Нажмите «📝 Заказать» ещё раз.', menu: true };
    const [, kind, value] = data.split(':');
    if (kind === 'p' && value) {
      const item = (await this.items()).find((i) => i.id === value);
      if (!item) return { text: 'Это изделие больше недоступно. Выберите другое.', menu: true };
      return this.next(key, { step: item.colors.length ? 'color' : 'qty', productId: item.id, productName: item.name, colors: item.colors, picked: [], at: now }, now);
    }
    if (draft.step === 'color') {
      // tick / untick a colour: the same message is redrawn
      if (kind === 'c' && value !== '-' && value !== undefined) {
        const name = draft.colors?.[Number(value)];
        if (!name) return this.next(key, draft, now);
        const on = new Set(draft.picked);
        if (on.has(name)) on.delete(name); else on.add(name);
        return { ...(await this.next(key, { ...draft, picked: draft.colors!.filter((c) => on.has(c)) }, now)), edit: true };
      }
      if (kind === 'c' && value === '-') return this.next(key, { ...draft, picked: [], lines: [], step: 'qty' }, now);
      if (kind === 'cd') {
        if (!draft.picked?.length) return { ...(await this.next(key, draft, now)), text: '2/5 · Отметьте хотя бы один цвет (или «Ещё не знаю»).', edit: true };
        return this.next(key, { ...draft, lines: [], step: 'qty' }, now);
      }
    }
    if (kind === 'q' && draft.step === 'qty') return this.setQty(key, draft, undefined, now);
    if (kind === 'me' && draft.step === 'name') {
      const last = await this.prisma.clientOrder.findFirst({ where: { customerChatId: chatId }, orderBy: { createdAt: 'desc' }, select: { name: true, phone: true } });
      if (last) return this.next(key, { ...draft, name: last.name, phone: last.phone, step: 'confirm' }, now);
    }
    if (data === 'sh:ok' && draft.step === 'confirm') {
      const lines = draft.lines?.length ? draft.lines : undefined;
      const r = await this.orders.create(
        { name: draft.name!, phone: draft.phone!, productModelId: draft.productId, lines, quantity: lines ? undefined : draft.qty },
        undefined, { source: 'BOT', chatId },
      );
      this.drafts.delete(key);
      return { text: `Спасибо! Заказ ${r.code} принят 🎉\nМы позвоним по номеру ${draft.phone}, чтобы уточнить срок и цену. Новости по заказу придут сюда.`, menu: true };
    }
    return { text: 'Этот шаг устарел. Нажмите «📝 Заказать» ещё раз.', menu: true };
  }

  /** metres for the next picked colour (or the one number without colours); `undefined` = skipped */
  private setQty(key: string, draft: Draft, n: number | undefined, now: number) {
    if (!draft.picked?.length) return this.next(key, { ...draft, qty: n, step: 'name' }, now);
    const lines = [...(draft.lines ?? []), { colorName: draft.picked[(draft.lines ?? []).length], ...(n ? { quantity: n } : {}) }];
    return this.next(key, { ...draft, lines, step: lines.length < draft.picked.length ? 'qty' : 'name' }, now);
  }

  private async setPhone(key: string, draft: Draft, raw: string, now: number): Promise<ShopReply> {
    // a shared contact comes without «+» (998901234567)
    const ok = [raw, `+${raw.replace(/^\+/, '')}`].map((v) => phoneSchema.safeParse(v)).find((r) => r.success) ?? phoneSchema.safeParse(raw);
    if (!ok.success) return { text: 'Не похоже на номер. Нажмите «📱 Отправить номер» или напишите, например, +998 90 123 45 67.', askContact: true };
    return this.next(key, { ...draft, phone: ok.data, step: 'confirm' }, now);
  }

  /** saves the draft and asks the next question */
  private async next(key: string, d: Draft, now: number): Promise<ShopReply> {
    this.drafts.set(key, { ...d, at: now });
    switch (d.step) {
      case 'color': {
        const on = new Set(d.picked);
        return {
          text: `2/5 · ${d.productName}: какие цвета? Можно отметить несколько, потом «Готово».${d.picked?.length ? `\nВыбрано: ${d.picked.join(', ')}` : ''}`,
          buttons: [
            ...chunk((d.colors ?? []).map((c, i) => ({ text: `${on.has(c) ? '✅ ' : ''}${c}`, data: `sh:c:${i}` })), 2),
            [{ text: 'Ещё не знаю', data: 'sh:c:-' }, { text: `Готово ➡️${d.picked?.length ? ` (${d.picked.length})` : ''}`, data: 'sh:cd' }],
          ],
        };
      }
      case 'qty': {
        const color = d.picked?.[(d.lines ?? []).length];
        return { text: color ? `3/5 · Сколько метров «${color}»? Напишите число (можно примерно).` : '3/5 · Сколько метров? Напишите число (можно примерно).', buttons: [[{ text: 'Пропустить', data: 'sh:q:-' }]] };
      }
      case 'name': {
        const known = await this.prisma.clientOrder.findFirst({ where: { customerChatId: BigInt(key) }, orderBy: { createdAt: 'desc' }, select: { name: true, phone: true } });
        return known
          ? { text: '4/5 · Как вас зовут? Напишите имя.', buttons: [[{ text: `Это я: ${known.name}, ${known.phone}`, data: 'sh:me' }]] }
          : { text: '4/5 · Как вас зовут? Напишите имя.' };
      }
      case 'phone':
        return { text: '5/5 · Ваш номер телефона — нажмите кнопку внизу или напишите.', askContact: true };
      case 'confirm': {
        const what = d.lines?.length ? linesText(d.lines) : d.qty ? `${fmt(d.qty)} м` : '';
        return {
          text: ['Проверьте заказ:', `• ${d.productName ?? 'изделие'}${what ? `: ${what}` : ''}`, `• ${d.name}, ${d.phone}`].join('\n'),
          buttons: [[{ text: '✅ Отправить заказ', data: 'sh:ok' }], [{ text: '✖ Отмена', data: 'sh:x' }]],
        };
      }
      default:
        return { text: '1/5 · Какое изделие?' };
    }
  }

  private async mine(chatId: bigint): Promise<ShopReply> {
    const rows = await this.orders.ofChat(chatId);
    if (!rows.length) return { text: 'Заказов пока нет. Нажмите «📝 Заказать».', menu: true };
    return {
      text: ['📦 Ваши заказы:', ...rows.map((o) => `• ${o.code}: ${o.product ?? 'изделие'}${o.colorName ? `, ${o.colorName}` : ''}${o.quantity ? `, ${o.quantity} м` : ''} — ${STATUS_RU[o.status]}`)].join('\n'),
      menu: true,
    };
  }

  private async items() {
    const c = await this.orders.publicCatalog();
    return c.items.map((i) => ({ id: i.id, name: i.name, colors: i.colors.map((x) => x.name).filter((x): x is string => !!x) }));
  }
}

const chunk = <T>(a: T[], n: number) => Array.from({ length: Math.ceil(a.length / n) }, (_, i) => a.slice(i * n, i * n + n));

@Module({ imports: [OrdersModule], providers: [ShopFlow], exports: [ShopFlow] })
export class ShopFlowModule {}
