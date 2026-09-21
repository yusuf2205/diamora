import { Global, Injectable, Module } from '@nestjs/common';
import type { Prisma } from '@yusmus/database';
import { PrismaService } from '../prisma/prisma.module';

type Db = PrismaService | Prisma.TransactionClient;

/**
 * Outbox for Telegram messages (D-006). The API only writes rows; the bot process (apps/api/src/worker.ts) delivers them,
 * retries with back-off and clears sensitive bodies (login codes) after sending.
 */
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async telegram(p: { workerId?: string; chatId: bigint; type: string; body: string; data?: Prisma.InputJsonValue }, db: Db = this.prisma) {
    return db.notification.create({
      data: { channel: 'TELEGRAM', workerId: p.workerId, telegramChatId: p.chatId, type: p.type, body: p.body, data: p.data },
    });
  }
}

@Global()
@Module({ providers: [NotificationsService], exports: [NotificationsService] })
export class NotificationsModule {}
