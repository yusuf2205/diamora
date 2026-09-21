import { Global, Inject, Injectable, Logger, Module, OnModuleDestroy } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, OnGatewayConnection, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import {
  ADMIN_ROOM, EVENTS_CHANNEL, EVENT_AUDIENCE, WORKERS_ROOM, workerRoom,
  type EventMap, type EventType, type RealtimeEnvelope,
} from '@yusmus/shared';
import { EventEmitter } from 'node:events';
import { randomUUID } from 'node:crypto';
import type { Server, Socket } from 'socket.io';
import type Redis from 'ioredis';
import { RedisService } from '../redis/redis.module';
import { SessionAuthService } from '../auth/auth-core';

type Handler = (e: RealtimeEnvelope) => void;

/**
 * Domain event bus (D-008). Services call `publish` AFTER the transaction has committed.
 * Redis pub/sub in production (the bot process reaches the API's sockets), in-process emitter otherwise.
 */
@Injectable()
export class EventBus implements OnModuleDestroy {
  private readonly log = new Logger('EventBus');
  private readonly local = new EventEmitter();
  private subscriber?: Redis;

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
  }

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

/**
 * Socket.IO gateway. Handshake: auth { token: <access JWT> }. ADMIN -> room `admin`, WORKER -> rooms `worker:<id>` + `workers`.
 * Revoked/expired sessions are refused at connect. Events are hints; clients refetch from the API.
 */
@WebSocketGateway({ cors: { origin: true } })
export class RealtimeGateway implements OnGatewayConnection {
  private readonly log = new Logger('Realtime');
  @WebSocketServer() server!: Server;

  constructor(private readonly jwt: JwtService, private readonly sessions: SessionAuthService, bus: EventBus) {
    bus.subscribe((e) => this.fanOut(e));
    sessions.onRevoked((ids) => void this.disconnectSessions(ids));
  }

  async handleConnection(@ConnectedSocket() socket: Socket) {
    try {
      const token = (socket.handshake.auth as { token?: string })?.token ?? '';
      const payload = await this.jwt.verifyAsync<{ sid: string }>(token, { algorithms: ['HS256'] });
      const user = await this.sessions.resolve(payload.sid);
      if (!user) throw new Error('session revoked');
      if (user.role === 'ADMIN') await socket.join(ADMIN_ROOM);
      else if (user.workerId) await socket.join([workerRoom(user.workerId), WORKERS_ROOM]);
      else throw new Error('worker profile missing');
      socket.data.userId = user.id;
      socket.data.sessionId = user.sessionId;
      socket.emit('ready', { role: user.role });
    } catch (e) {
      this.log.debug(`refused connection: ${(e as Error).message}`);
      socket.emit('unauthorized');
      socket.disconnect(true);
    }
  }

  private fanOut(e: RealtimeEnvelope) {
    if (!this.server) return;
    const aud = EVENT_AUDIENCE[e.type];
    if (!aud) return;
    if (aud.admin) this.server.to(ADMIN_ROOM).emit('event', e);
    if (aud.allWorkers) this.server.to(WORKERS_ROOM).emit('event', e);
    const workerId = (e.data as { workerId?: string }).workerId;
    if (aud.worker && workerId) this.server.to(workerRoom(workerId)).emit('event', e);
  }

  /** Called when a session is revoked so the socket stops receiving data immediately. */
  async disconnectSessions(sessionIds: string[]) {
    if (!this.server) return;
    for (const s of await this.server.fetchSockets()) if (sessionIds.includes(s.data.sessionId)) s.disconnect(true);
  }
}

/** The bus is used by every process (API and bot worker). */
@Global()
@Module({ providers: [EventBus], exports: [EventBus] })
export class EventBusModule {}

/** WebSocket gateway: API process only. */
@Module({ providers: [RealtimeGateway], exports: [RealtimeGateway] })
export class RealtimeModule {}
