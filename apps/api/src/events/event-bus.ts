import { Global, Injectable, Logger, Module, OnModuleDestroy } from '@nestjs/common';
import { EVENTS_CHANNEL, type EventMap, type EventType, type RealtimeEnvelope } from '@diamoraa/shared';
import { EventEmitter } from 'node:events';
import { randomUUID } from 'node:crypto';
import type Redis from 'ioredis';
import { RedisService } from '../redis/redis.module';

type Handler = (e: RealtimeEnvelope) => void | Promise<void>;

/**
 * Domain event bus (D-008). Services call `publish` AFTER the transaction has committed.
 * Redis pub/sub in production (the bot process reaches the API's sockets), in-process emitter otherwise.
 * Kept in its own file so that services (presence, catalog, ...) and the gateway can both depend on it without an import cycle.
 */
@Injectable()
export class EventBus implements OnModuleDestroy {
  private readonly log = new Logger('EventBus');
  private readonly local = new EventEmitter();
  private subscriber?: Redis;
  /** in-process listeners run once per event, in the process that published it (in-app notifications) */
  private readonly hooks: Handler[] = [];

  constructor(private readonly redis: RedisService) {
    this.local.setMaxListeners(50);
  }

  async publish<T extends EventType>(type: T, data: EventMap[T]): Promise<void> {
    const envelope: RealtimeEnvelope<T> = { id: randomUUID(), type, occurredAt: new Date().toISOString(), data };
    try {
      if (this.redis.enabled) await this.redis.client!.publish(EVENTS_CHANNEL, JSON.stringify(envelope));
      else this.local.emit('event', envelope);
    } catch (e) {
      // the data is already committed; a lost hint only delays the UI until its next refetch
      this.log.warn(`publish ${type} failed: ${(e as Error).message}`);
    }
    // hooks run AFTER this call returns: a notice must never slow down (or fail) the business action that caused it
    for (const h of this.hooks) {
      setImmediate(() => { Promise.resolve(h(envelope as RealtimeEnvelope)).catch((e: Error) => this.log.warn(`hook ${type}: ${e.message}`)); });
    }
  }

  /** Runs `handler` right after every publish from THIS process (never for events received from Redis). */
  onPublished(handler: (e: RealtimeEnvelope) => void | Promise<void>): void { this.hooks.push(handler as Handler); }

  /** Called by the WebSocket gateway (API process). */
  subscribe(handler: Handler): void {
    if (!this.redis.enabled) {
      this.local.on('event', handler);
      return;
    }
    this.subscriber = this.redis.duplicate();
    void this.subscriber.subscribe(EVENTS_CHANNEL);
    this.subscriber.on('message', (_ch, raw) => {
      try { handler(JSON.parse(raw) as RealtimeEnvelope); } catch { /* ignore malformed */ }
    });
  }

  onModuleDestroy() { this.local.removeAllListeners(); }
}

/** The bus is used by every process (API and bot worker). */
@Global()
@Module({ providers: [EventBus], exports: [EventBus] })
export class EventBusModule {}
