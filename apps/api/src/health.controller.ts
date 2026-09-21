import { Controller, Get, Inject, Res } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { Response } from 'express';
import { Public } from './common/decorators';
import { PrismaService } from './prisma/prisma.module';
import { RedisService } from './redis/redis.module';
import { STORAGE, StoragePort } from './storage/storage.module';

type Check = { status: 'up' | 'down' | 'disabled'; latencyMs?: number; error?: string };
async function timed(fn: () => Promise<void>): Promise<Check> {
  const t = Date.now();
  try {
    await Promise.race([fn(), new Promise<never>((_, rej) => setTimeout(() => rej(new Error('timeout after 3s')), 3000))]);
    return { status: 'up', latencyMs: Date.now() - t };
  } catch (e) {
    return { status: 'down', latencyMs: Date.now() - t, error: (e as Error).message };
  }
}
const startedAt = Date.now();

@ApiExcludeController()
@Public()
@SkipThrottle()
@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService, @Inject(STORAGE) private readonly storage: StoragePort) {}

  /** Liveness: safe to expose publicly (uptime monitors). */
  @Get('health/live')
  live() { return { status: 'ok', uptimeSeconds: Math.round((Date.now() - startedAt) / 1000) }; }

  /** Readiness: NAS dependencies reachable. Blocked at the reverse proxy. */
  @Get('health/ready')
  async ready(@Res({ passthrough: true }) res: Response) {
    const [database, storage, redis] = await Promise.all([
      timed(async () => void (await this.prisma.$queryRaw`SELECT 1`)),
      timed(() => this.storage.ping()),
      this.redis.enabled ? timed(() => this.redis.ping()) : Promise.resolve<Check>({ status: 'disabled' }),
    ]);
    const checks = { database, storage, redis };
    const ok = Object.values(checks).every((c) => c.status !== 'down');
    if (!ok) res.status(503);
    return { status: ok ? 'ready' : 'degraded', checks };
  }
}
