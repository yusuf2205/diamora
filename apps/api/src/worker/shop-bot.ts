import { Inject, Injectable, Logger } from '@nestjs/common';
import { Bot, type Context } from 'grammy';
import { AlertsService } from '../alerts/alerts.service';
import { ENV, Env } from '../config/env';
import { SHOP_MENU, ShopFlow, type ShopInput, type ShopReply } from '../orders/shop-flow';
import type { TelegramSender } from './outbox';

const menuKeyboard = { keyboard: SHOP_MENU.map((row) => row.map((text) => ({ text }))), resize_keyboard: true, is_persistent: true };
const contactKeyboard = { keyboard: [[{ text: '📱 Отправить номер', request_contact: true }]], resize_keyboard: true, one_time_keyboard: true };

/**
 * The customers' bot (SHOP_BOT_TOKEN; separate from the workers' @diamora1_bot). Telegram INTERFACE only: every decision
 * is in ShopFlow. Unset token = no shop bot (the site still takes orders).
 */
@Injectable()
export class ShopBot implements TelegramSender {
  private readonly log = new Logger('ShopBot');
  private bot?: Bot;

  constructor(@Inject(ENV) private readonly env: Env, private readonly flow: ShopFlow, private readonly alerts: AlertsService) {}

  get enabled() { return !!this.env.SHOP_BOT_TOKEN; }

  async send(chatId: bigint, text: string) {
    if (!this.bot) throw new Error('shop bot not started');
    await this.bot.api.sendMessage(Number(chatId), text);
  }

  /** `owners`: the sender that reaches the owners' linked chats (the main bot) */
  async start(owners: TelegramSender) {
    const bot = (this.bot = new Bot(this.env.SHOP_BOT_TOKEN!));
    const run = async (ctx: Context, input: ShopInput) => {
      if (ctx.chat?.type !== 'private') return;
      const r = await this.flow.handle(BigInt(ctx.chat.id), input);
      await this.reply(ctx, r);
      if (r.owners) await this.alerts.notifyOwners(owners, r.owners).catch(() => undefined);
    };
    bot.command('start', (ctx) => run(ctx, { kind: 'start', payload: ctx.match ? String(ctx.match) : undefined }));
    bot.command('cancel', (ctx) => run(ctx, { kind: 'text', text: '/cancel' }));
    bot.on('message:contact', (ctx) => run(ctx, { kind: 'contact', phone: ctx.message.contact.phone_number }));
    bot.on('message:text', (ctx) => {
      const f = ctx.from;
      const from = [f?.first_name, f?.last_name].filter(Boolean).join(' ') + (f?.username ? ` (@${f.username})` : '');
      return run(ctx, { kind: 'text', text: ctx.message.text, from: from || undefined });
    });
    bot.on('callback_query:data', async (ctx) => {
      await ctx.answerCallbackQuery().catch(() => undefined);
      await run(ctx, { kind: 'callback', data: ctx.callbackQuery.data });
    });
    bot.catch((err) => this.log.error(`update ${err.ctx.update.update_id} failed: ${err.error instanceof Error ? err.error.message : String(err.error)}`));
    await bot.init();
    this.log.log(`shop bot @${bot.botInfo.username} started (long polling)`);
    void bot.start({ drop_pending_updates: false });
  }

  private async reply(ctx: Context, r: ShopReply) {
    if (r.buttons) {
      const inline_keyboard = r.buttons.map((row) => row.map((b) => (b.url ? { text: b.text, url: b.url } : { text: b.text, callback_data: b.data! })));
      await ctx.reply(r.text, { reply_markup: { inline_keyboard } });
      return;
    }
    await ctx.reply(r.text, { reply_markup: r.askContact ? contactKeyboard : r.menu ? menuKeyboard : undefined });
  }

  async stop() { await this.bot?.stop(); }
}
