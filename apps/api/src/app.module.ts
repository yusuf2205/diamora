import { MiddlewareConsumer, Module, NestModule, Injectable, NestMiddleware } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { AssignmentsModule } from './assignments/assignments.service';
import { AuditModule } from './audit/audit.service';
import { AuthModule } from './auth/auth.controller';
import { JwtAuthGuard, RolesGuard } from './auth/auth-core';
import { AllExceptionsFilter } from './common/all-exceptions.filter';
import { IdempotencyInterceptor } from './common/idempotency.interceptor';
import { AppLogger } from './common/logger';
import { RequestContext } from './common/request-context';
import { CatalogModule } from './catalog/catalog.service';
import { CollateralModule } from './collateral/collateral.service';
import { ENV, Env, EnvModule } from './config/env';
import { EventBusModule } from './events/event-bus';
import { RealtimeModule } from './events/events.module';
import { ColorsModule } from './colors/colors.service';
import { FilesModule } from './files/files.service';
import { HealthController } from './health.controller';
import { KitsModule } from './kits/kits.service';
import { LedgerModule } from './ledger/ledger.service';
import { LocationModule } from './location/location.service';
import { MaterialsModule } from './materials/materials.service';
import { NotificationsModule } from './notifications/notifications.service';
import { PresenceModule } from './presence/presence.service';
import { PrismaModule } from './prisma/prisma.module';
import { QrModule } from './qr/qr.service';
import { RedisModule } from './redis/redis.module';
import { RegistrationModule } from './registration/registration.service';
import { CompanyContactModule } from './settings/company-contact.service';
import { PayRateModule } from './settings/pay-rate.service';
import { StatsModule } from './stats/stats.service';
import { DashboardModule } from './stats/dashboard.controller';
import { StockModule } from './stock/stock.service';
import { StorageModule } from './storage/storage.module';
import { UsersModule } from './users/users.service';
import { WorkersModule } from './workers/workers.service';

const VALID_ID = /^[A-Za-z0-9._-]{8,64}$/;

/** Request id + async context (used by audit and logs) + one structured log line per request. */
@Injectable()
class RequestMiddleware implements NestMiddleware {
  constructor(private readonly logger: AppLogger) {}
  use(req: Request, res: Response, next: NextFunction) {
    const inc = req.header('x-request-id');
    const requestId = inc && VALID_ID.test(inc) ? inc : randomUUID();
    req.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    const started = process.hrtime.bigint();
    RequestContext.run({ requestId, ip: req.ip, userAgent: req.headers['user-agent'] }, () => {
      res.on('finish', () => {
        if (req.path.startsWith('/health')) return;
        const status = res.statusCode;
        this.logger.event('http_request', { method: req.method, path: req.originalUrl.split('?')[0], status, durationMs: Math.round(Number(process.hrtime.bigint() - started) / 1e6), ip: req.ip }, status >= 500 ? 'error' : status >= 400 ? 'warn' : 'info');
      });
      next();
    });
  }
}

@Module({
  imports: [
    EnvModule,
    ThrottlerModule.forRootAsync({
      inject: [ENV],
      useFactory: (env: Env) => ({ throttlers: [{ name: 'default', ttl: 60_000, limit: env.RATE_LIMIT_PER_MINUTE }], skipIf: () => !env.RATE_LIMIT_ENABLED }),
    }),
    PrismaModule, RedisModule, StorageModule, AuditModule, NotificationsModule, EventBusModule, PresenceModule, StatsModule,
    AuthModule, FilesModule, RealtimeModule, WorkersModule, CollateralModule, RegistrationModule, PayRateModule,
    UsersModule, CatalogModule, CompanyContactModule, LocationModule, DashboardModule,
    MaterialsModule, StockModule, KitsModule, QrModule, ColorsModule, LedgerModule, AssignmentsModule,
  ],
  controllers: [HealthController],
  providers: [
    AppLogger,
    // Global guards in order: rate limit -> authenticate -> authorise (deny by default)
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    RequestMiddleware,
  ],
  exports: [AppLogger],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) { consumer.apply(RequestMiddleware).forRoutes('*'); }
}
