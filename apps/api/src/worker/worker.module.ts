import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.service';
import { AppLogger } from '../common/logger';
import { EnvModule } from '../config/env';
import { EventBusModule } from '../events/events.module';
import { FilesModule } from '../files/files.service';
import { NotificationsModule } from '../notifications/notifications.service';
import { PrismaModule } from '../prisma/prisma.module';
import { RedisModule } from '../redis/redis.module';
import { RegistrationModule } from '../registration/registration.service';
import { StorageModule } from '../storage/storage.module';
import { MaintenanceService } from './maintenance';
import { OutboxSender } from './outbox';
import { TelegramBot } from './telegram-bot';

/** The `worker` container: Telegram bot + outbox delivery + maintenance. Same code base as the API, no HTTP business surface. */
@Module({
  imports: [EnvModule, PrismaModule, RedisModule, StorageModule, AuditModule, NotificationsModule, EventBusModule, FilesModule, RegistrationModule],
  providers: [AppLogger, TelegramBot, OutboxSender, MaintenanceService],
})
export class WorkerModule {}
