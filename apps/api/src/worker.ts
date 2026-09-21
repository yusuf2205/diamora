/** Entrypoint of the `worker` container (node dist/worker.js). */
import 'reflect-metadata';
process.env.SERVICE_NAME = 'worker';
import { NestFactory } from '@nestjs/core';
import { createServer } from 'node:http';
import { AppLogger } from './common/logger';
import './common/serialize';
import { ENV, Env } from './config/env';
import { PrismaService } from './prisma/prisma.module';
import { MaintenanceService } from './worker/maintenance';
import { OutboxSender } from './worker/outbox';
import { TelegramBot } from './worker/telegram-bot';
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

  const timers: NodeJS.Timeout[] = [];
  let lastTick = Date.now();
  if (bot.enabled) {
    timers.push(setInterval(() => void outbox.tick(bot).then(() => (lastTick = Date.now())).catch((e) => log.error(`outbox: ${e.message}`)), 2_000));
  }
  timers.push(setInterval(() => void maintenance.integrity().catch((e) => log.error(`integrity: ${e.message}`)), 60 * 60_000));
  timers.push(setInterval(() => void maintenance.cleanup().catch((e) => log.error(`cleanup: ${e.message}`)), 24 * 60 * 60_000));
  void maintenance.integrity().catch(() => undefined);

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
