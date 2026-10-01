import { Inject, Injectable, Logger } from '@nestjs/common';
import { Bot, type Context } from 'grammy';
import { ENV, Env } from '../config/env';
import { adminKeyboard, AdminBot } from '../alerts/admin-bot';
import { ALERT_PREFIX, AlertsService } from '../alerts/alerts.service';
import { RegistrationService, type BotInput } from '../registration/registration.service';
import { parseAction, render, type BotKeyboard } from '../registration/texts';
import { CO_CALLBACK, OrdersService } from '../orders/orders.service';
import { PO_CALLBACK, SUPPLIER_PREFIX, SupplierBot } from '../purchases/supplier-bot';
import type { SendOptions, TelegramSender } from './outbox';
import { ShopBot } from './shop-bot';

const toMarkup = (k: BotKeyboard) => {
  if (k.type === 'remove') return { remove_keyboard: true as const };
  if (k.type === 'inline') return { inline_keyboard: [[{ text: k.text, url: k.url }]] };
  return {
    keyboard: k.rows.map((row) => row.map((b) => ({ text: b.text, request_contact: b.requestContact, request_location: b.requestLocation }))),
    resize_keyboard: true,
  };
};

/**
 * Telegram INTERFACE only (D-005): translates updates into `BotInput`, calls RegistrationService (all business logic),
 * renders the reply. No decisions, no database access here.
 */
@Injectable()
export class TelegramBot implements TelegramSender {
  private readonly log = new Logger('TelegramBot');
  private bot?: Bot;

  constructor(@Inject(ENV) private readonly env: Env, private readonly registration: RegistrationService, private readonly alerts: AlertsService, private readonly adminBot: AdminBot, private readonly supplierBot: SupplierBot, private readonly shopBot: ShopBot, private readonly orders: OrdersService) {}

  get enabled() { return !!this.env.TELEGRAM_BOT_TOKEN; }

  async send(chatId: bigint, text: string, opts?: SendOptions) {
    if (opts?.via === 'shop') return this.shopBot.send(chatId, text); // customers only know the shop bot
    if (!this.bot) throw new Error('bot not started');
    const markup = opts?.buttons ? { inline_keyboard: opts.buttons.map((row) => row.map((b) => ({ text: b.text, callback_data: b.data }))) } : undefined;
    await this.bot.api.sendMessage(Number(chatId), text, markup ? { reply_markup: markup } : undefined);
  }

  async start() {
    const token = this.env.TELEGRAM_BOT_TOKEN;
    if (!token) throw new Error('TELEGRAM_BOT_TOKEN is not set');
    const bot = (this.bot = new Bot(token));

    const handle = async (ctx: Context, input: BotInput) => {
      if (ctx.chat?.type !== 'private' || !ctx.from) return; // registration happens in a private chat only
      const reply = await this.registration.process({ telegramUserId: BigInt(ctx.from.id), chatId: BigInt(ctx.chat.id) }, input);
      const r = render(reply);
      await ctx.reply(r.text, { reply_markup: toMarkup(r.keyboard) });
    };

    bot.command('start', async (ctx) => {
      const payload = ctx.match ? String(ctx.match) : undefined;
      // an admin linking this chat for owner alerts - not a worker registration
      if (payload?.startsWith(ALERT_PREFIX) && ctx.chat?.type === 'private') {
        const text = await this.alerts.completeLink(payload.slice(ALERT_PREFIX.length), BigInt(ctx.chat.id));
        // linked: the owner's menu appears under the ⌘ button right away
        const linked = await this.adminBot.isAdminChat(BigInt(ctx.chat.id));
        await ctx.reply(linked ? `${text}

${this.adminBot.menuText()}` : text, linked ? { reply_markup: adminKeyboard } : undefined);
        return;
      }
      // a supplier linking this chat: orders from «Закупки» arrive here
      if (payload?.startsWith(SUPPLIER_PREFIX) && ctx.chat?.type === 'private') {
        await ctx.reply(await this.supplierBot.completeLink(payload.slice(SUPPLIER_PREFIX.length), BigInt(ctx.chat.id)), { reply_markup: { remove_keyboard: true } });
        return;
      }
      if (ctx.chat?.type === 'private' && (await this.adminBot.isAdminChat(BigInt(ctx.chat.id)))) {
        await ctx.reply(this.adminBot.menuText(), { reply_markup: adminKeyboard });
        return;
      }
      if (ctx.chat?.type === 'private' && (await this.supplierBot.isSupplierChat(BigInt(ctx.chat.id)))) {
        await ctx.reply('Здесь будут приходить заказы Diamoraa. Под каждым — кнопки «Принял» и «Нет в наличии».');
        return;
      }
      return handle(ctx, { kind: 'command', command: 'start', payload });
    });
    bot.command('menu', async (ctx) => {
      if (ctx.chat?.type === 'private' && (await this.adminBot.isAdminChat(BigInt(ctx.chat.id)))) await ctx.reply(this.adminBot.menuText(), { reply_markup: adminKeyboard });
    });
    bot.command('cancel', (ctx) => handle(ctx, { kind: 'command', command: 'cancel' }));
    bot.on('message:contact', (ctx) => handle(ctx, { kind: 'contact', phone: ctx.message.contact.phone_number, contactUserId: ctx.message.contact.user_id ?? null }));
    bot.on('message:location', (ctx) => handle(ctx, { kind: 'location', latitude: ctx.message.location.latitude, longitude: ctx.message.location.longitude }));
    bot.on('message:photo', (ctx) => {
      const largest = ctx.message.photo[ctx.message.photo.length - 1];
      return handle(ctx, {
        kind: 'photo',
        download: async () => {
          const file = await ctx.api.getFile(largest.file_id);
          const res = await fetch(`https://api.telegram.org/file/bot${token}/${file.file_path}`);
          if (!res.ok) throw new Error(`telegram file download failed: ${res.status}`);
          return { buffer: Buffer.from(await res.arrayBuffer()), filename: file.file_path?.split('/').pop() };
        },
      });
    });
    bot.on('message:text', async (ctx) => {
      // an admin's linked chat: the menu buttons, never the worker registration
      if (ctx.chat.type === 'private' && (await this.adminBot.isAdminChat(BigInt(ctx.chat.id)))) {
        const answer = await this.adminBot.answer(ctx.message.text);
        await ctx.reply(answer ?? this.adminBot.menuText(), { reply_markup: adminKeyboard });
        return;
      }
      // a supplier's message: passed to the staff
      if (ctx.chat.type === 'private') {
        const answer = await this.supplierBot.message(BigInt(ctx.chat.id), ctx.message.text);
        if (answer) {
          await ctx.reply(answer.reply);
          await this.alerts.notifyOwners(this, answer.owners).catch(() => undefined);
          return;
        }
      }
      const action = parseAction(ctx.message.text);
      return handle(ctx, action ? { kind: 'action', action } : { kind: 'text', text: ctx.message.text });
    });
    // the buttons under an order sent to a supplier
    bot.on('callback_query:data', async (ctx) => {
      // the owner's «Подтвердить» / «Отменить» under a new customer order
      const co = CO_CALLBACK.exec(ctx.callbackQuery.data);
      if (co && ctx.chat) {
        const text = await this.orders.decide(BigInt(ctx.chat.id), co[2], co[1] === 'ok');
        await ctx.answerCallbackQuery({ text: text ?? 'Нет доступа.' }).catch(() => undefined);
        if (text) {
          await ctx.editMessageReplyMarkup({ reply_markup: { inline_keyboard: [] } }).catch(() => undefined);
          await ctx.reply(text);
        }
        return;
      }
      const m = PO_CALLBACK.exec(ctx.callbackQuery.data);
      const chatId = ctx.chat?.id;
      if (!m || chatId === undefined) { await ctx.answerCallbackQuery(); return; }
      const r = await this.supplierBot.reply(BigInt(chatId), m[2], m[1] === 'ok' ? 'ACCEPTED' : 'UNAVAILABLE');
      await ctx.answerCallbackQuery(r ? { text: r.text } : { text: 'Этот заказ не ваш.' });
      if (r) await ctx.reply(r.text);
      if (r?.changed && r.owners) await this.alerts.notifyOwners(this, r.owners).catch(() => undefined);
    });
    bot.catch((err) => this.log.error(`update ${err.ctx.update.update_id} failed: ${err.error instanceof Error ? err.error.message : String(err.error)}`));

    await bot.init();
    this.log.log(`bot @${bot.botInfo.username} started (long polling)`);
    void bot.start({ drop_pending_updates: false });
  }

  async stop() { await this.bot?.stop(); }
}
