/** Entrypoint of the `worker` container (node dist/worker.js). */
import 'reflect-metadata';
process.env.SERVICE_NAME = 'worker';
import { NestFactory } from '@nestjs/core';
import { createServer } from 'node:http';
import { AppLogger } from './common/logger';
import './common/serialize';
import { ENV, Env } from './config/env';
import { PrismaService } from './prisma/prisma.module';
import { AppNotifier } from './notifications/app-notifier';
import { MaintenanceService } from './worker/maintenance';
import { OutboxSender } from './worker/outbox';
import { ReleaseWatcher } from './worker/release-watcher';
import { AlertsService } from './alerts/alerts.service';
import { GoalsService } from './goals/goals.service';
import { TelegramBot } from './worker/telegram-bot';
import { ShopBot } from './worker/shop-bot';
import { WorkerModule } from './worker/worker.module';

async function main() {
  const app = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
  const log = app.get(AppLogger);
  app.useLogger(log);
  app.enableShutdownHooks();
  const env = app.get<Env>(ENV);
  const bot = app.get(TelegramBot);
  const outbox = app.get(OutboxSender);
  const maintenance = app.get(MaintenanceService);
  const prisma = app.get(PrismaService);

  if (bot.enabled) await bot.start();
  else if (env.NODE_ENV === 'production') throw new Error('TELEGRAM_BOT_TOKEN is required in production');
  else log.warn('TELEGRAM_BOT_TOKEN not set: bot and outbox delivery are disabled (development)');
  // the customers' bot: optional; a failure here never stops the workers' bot
  const shopBot = app.get(ShopBot);
  if (shopBot.enabled && bot.enabled) await shopBot.start(bot).catch((e) => log.error(`shop bot: ${e.message}`));

  const timers: NodeJS.Timeout[] = [];
  let lastTick = Date.now();
  if (bot.enabled) {
    timers.push(setInterval(() => void outbox.tick(bot).then(() => (lastTick = Date.now())).catch((e) => log.error(`outbox: ${e.message}`)), 2_000));
  }
  timers.push(setInterval(() => void maintenance.integrity().catch((e) => log.error(`integrity: ${e.message}`)), 60 * 60_000));
  timers.push(setInterval(() => void maintenance.cleanup().catch((e) => log.error(`cleanup: ${e.message}`)), 24 * 60 * 60_000));
  void maintenance.integrity().catch(() => undefined);
  // deadlines, overdue, the evening summary, weekly/monthly reports -> in-app notifications (idempotent, dedupeKey)
  const notifier = app.get(AppNotifier);
  timers.push(setInterval(() => void notifier.tick().catch((e) => log.error(`notifier: ${e.message}`)), 5 * 60_000));
  void notifier.tick().catch(() => undefined);
  // «Цель месяца выполнена!» once a month per worker
  const goals = app.get(GoalsService);
  timers.push(setInterval(() => void goals.congratulate(notifier).catch((e) => log.error(`goals: ${e.message}`)), 5 * 60_000));
  // a newly published app version -> a push + realtime hint to every phone (checked every 30 s)
  const release = app.get(ReleaseWatcher);
  timers.push(setInterval(() => void release.tick().catch((e) => log.error(`release: ${e.message}`)), 30_000));
  void release.tick().catch(() => undefined);
  // owner alerts in Telegram: «снова работает, был недоступен N мин» after a down time; «мало места» once a day
  if (bot.enabled) {
    const alerts = app.get(AlertsService);
    void alerts.onStart(bot).catch((e) => log.error(`alerts: ${e.message}`));
    timers.push(setInterval(() => void alerts.beat().catch(() => undefined), 60_000));
    timers.push(setInterval(() => void alerts.checkDisk(bot).catch((e) => log.error(`disk: ${e.message}`)), 60 * 60_000));
    void alerts.checkDisk(bot).catch(() => undefined);
    // backups (incl. the external drive): checked every 3 h, told at most once a day
    timers.push(setInterval(() => void alerts.checkBackups(bot).catch((e) => log.error(`backups: ${e.message}`)), 3 * 60 * 60_000));
  }

  // liveness for the Docker health check (internal network only)
  const server = createServer(async (req, res) => {
    try {
      if (req.url === '/health/live') return void res.writeHead(200, { 'content-type': 'application/json' }).end('{"status":"ok"}');
      if (req.url === '/health/ready') {
        await prisma.$queryRaw`SELECT 1`;
        const fresh = !bot.enabled || Date.now() - lastTick < 30_000;
        return void res.writeHead(fresh ? 200 : 503, { 'content-type': 'application/json' }).end(JSON.stringify({ status: fresh ? 'ready' : 'stalled' }));
      }
      res.writeHead(404).end();
    } catch (e) {
      res.writeHead(503).end(JSON.stringify({ status: 'down', error: (e as Error).message }));
    }
  });
  server.listen(env.WORKER_HEALTH_PORT, '0.0.0.0');

  const shutdown = async (signal: string) => {
    log.log(`shutting down (${signal})`);
    timers.forEach(clearInterval);
    server.close();
    await bot.stop().catch(() => undefined);
    await shopBot.stop().catch(() => undefined);
    await app.close();
    process.exit(0);
  };
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
  log.log('worker started');
}
main().catch((err) => {
  console.error('Fatal worker error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
