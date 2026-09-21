import { Global, Inject, Injectable, Module, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';
import { ENV, Env } from '../config/env';

/** Redis = realtime bus between processes (API sockets <-> bot worker). Never published to the internet. */
@Injectable()
export class RedisService implements OnModuleDestroy {
  readonly client: Redis | null;
  private readonly extra: Redis[] = [];

  constructor(@Inject(ENV) env: Env) {
    this.client = env.REDIS_URL ? new Redis(env.REDIS_URL, { maxRetriesPerRequest: 2 }) : null;
    this.client?.on('error', () => undefined); // surfaced by /health/ready
  }
  get enabled() { return this.client !== null; }

  /** Dedicated connection (a subscribing connection cannot issue other commands). */
  duplicate(): Redis {
    if (!this.client) throw new Error('redis not configured');
    const c = this.client.duplicate();
    c.on('error', () => undefined);
    this.extra.push(c);
    return c;
  }
  async ping() {
    if (!this.client) throw new Error('redis not configured');
    if ((await this.client.ping()) !== 'PONG') throw new Error('unexpected redis reply');
  }
  async onModuleDestroy() {
    for (const c of [this.client, ...this.extra]) if (c) await c.quit().catch(() => c.disconnect());
  }
}

@Global()
@Module({ providers: [RedisService], exports: [RedisService] })
export class RedisModule {}
