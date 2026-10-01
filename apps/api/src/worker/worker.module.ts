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
import { ReleaseWatcher } from './release-watcher';
import { AlertsModule } from '../alerts/alerts.service';
import { GoalsWorkerModule } from '../goals/goals.service';
import { TelegramBot } from './telegram-bot';
import { SupplierBotModule } from '../purchases/supplier-bot';

/** The `worker` container: Telegram bot + outbox delivery + maintenance. Same code base as the API, no HTTP business surface. */
import { AppNotifierModule } from '../notifications/app-notifier';

@Module({
  imports: [EnvModule, PrismaModule, RedisModule, StorageModule, AuditModule, NotificationsModule, EventBusModule, FilesModule, RegistrationModule, AppNotifierModule, AlertsModule, GoalsWorkerModule, SupplierBotModule],
  providers: [AppLogger, TelegramBot, OutboxSender, MaintenanceService, ReleaseWatcher],
})
export class WorkerModule {}
