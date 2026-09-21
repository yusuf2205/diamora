import { Inject, Injectable, Logger } from '@nestjs/common';
import { Bot, type Context } from 'grammy';
import { ENV, Env } from '../config/env';
import { RegistrationService, type BotInput } from '../registration/registration.service';
import { parseAction, render, type BotKeyboard } from '../registration/texts';
import type { TelegramSender } from './outbox';

const toMarkup = (k: BotKeyboard) =>
  k.type === 'remove'
    ? { remove_keyboard: true as const }
    : {
        keyboard: k.rows.map((row) => row.map((b) => ({ text: b.text, request_contact: b.requestContact, request_location: b.requestLocation }))),
        resize_keyboard: true,
      };

/**
 * Telegram INTERFACE only (D-005): translates updates into `BotInput`, calls RegistrationService (all business logic),
 * renders the reply. No decisions, no database access here.
 */
@Injectable()
export class TelegramBot implements TelegramSender {
  private readonly log = new Logger('TelegramBot');
  private bot?: Bot;

  constructor(@Inject(ENV) private readonly env: Env, private readonly registration: RegistrationService) {}

  get enabled() { return !!this.env.TELEGRAM_BOT_TOKEN; }

  async send(chatId: bigint, text: string) {
    if (!this.bot) throw new Error('bot not started');
    await this.bot.api.sendMessage(Number(chatId), text);
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

    bot.command('start', (ctx) => handle(ctx, { kind: 'command', command: 'start' }));
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
    bot.on('message:text', (ctx) => {
      const action = parseAction(ctx.message.text);
      return handle(ctx, action ? { kind: 'action', action } : { kind: 'text', text: ctx.message.text });
    });
    bot.catch((err) => this.log.error(`update ${err.ctx.update.update_id} failed: ${err.error instanceof Error ? err.error.message : String(err.error)}`));

    await bot.init();
    this.log.log(`bot @${bot.botInfo.username} started (long polling)`);
    void bot.start({ drop_pending_updates: false });
  }

  async stop() { await this.bot?.stop(); }
}
