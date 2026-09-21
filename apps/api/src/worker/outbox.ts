import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';

/** Transport port implemented by the Telegram bot (kept abstract so the outbox is testable without Telegram). */
export interface TelegramSender {
  send(chatId: bigint, text: string): Promise<void>;
}

const MAX_ATTEMPTS = 5;
const backoffMs = (attempt: number) => Math.min(30 * 60_000, 15_000 * 2 ** attempt);
/** Sensitive bodies are wiped from the database once delivered. */
const WIPE_AFTER_SEND = new Set(['login_code']);

/** Delivers `notifications` rows (channel TELEGRAM): claims with SKIP LOCKED + lease, retries with back-off (D-006). */
@Injectable()
export class OutboxSender {
  private readonly log = new Logger('Outbox');
  constructor(private readonly prisma: PrismaService) {}

  async tick(sender: TelegramSender, batch = 20): Promise<{ sent: number; failed: number }> {
    const claimed = await this.prisma.$queryRaw<{ id: string; telegramChatId: bigint | null; body: string | null; type: string; attempts: number }[]>`
      UPDATE notifications SET attempts = attempts + 1, "nextAttemptAt" = now() + interval '60 seconds'
      WHERE id IN (
        SELECT id FROM notifications
        WHERE channel = 'TELEGRAM' AND status = 'PENDING' AND "nextAttemptAt" <= now()
        ORDER BY "createdAt" LIMIT ${batch} FOR UPDATE SKIP LOCKED)
      RETURNING id, "telegramChatId", body, type, attempts`;
    let sent = 0;
    let failed = 0;
    for (const n of claimed) {
      try {
        if (n.telegramChatId === null || !n.body) throw new Error('no recipient or body');
        await sender.send(n.telegramChatId, n.body);
        await this.prisma.notification.update({ where: { id: n.id }, data: { status: 'SENT', sentAt: new Date(), lastError: null, body: WIPE_AFTER_SEND.has(n.type) ? null : undefined } });
        sent++;
      } catch (e) {
        failed++;
        const final = n.attempts >= MAX_ATTEMPTS;
        await this.prisma.notification.update({
          where: { id: n.id },
          data: { status: final ? 'FAILED' : 'PENDING', lastError: (e as Error).message.slice(0, 300), nextAttemptAt: new Date(Date.now() + backoffMs(n.attempts)), body: final && WIPE_AFTER_SEND.has(n.type) ? null : undefined },
        });
        this.log.warn(`notification ${n.id} attempt ${n.attempts} failed: ${(e as Error).message}`);
      }
    }
    return { sent, failed };
  }
}
