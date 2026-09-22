import { Logger, Module } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { roomsForEvent, roomsForUser, type RealtimeEnvelope } from '@yusmus/shared';
import type { Server, Socket } from 'socket.io';
import { EventBus, EventBusModule } from './event-bus';
import { SessionAuthService } from '../auth/auth-core';
import type { AuthUser } from '../common/request-context';
import { PresenceModule, PresenceService } from '../presence/presence.service';

export { EventBus, EventBusModule };

/**
 * Socket.IO gateway. Handshake: auth { token: <access JWT> }. Rooms are computed from the user's EFFECTIVE permissions
 * (packages/shared roomsForUser): a MANAGER only ever joins rooms of their own workers, a WORKER only their own room plus the
 * public broadcast rooms. Events are routed by roomsForEvent - the SERVER decides who receives what. Revoked/expired sessions
 * are refused at connect; a role/permission change disconnects the user's sockets so they reconnect with fresh rooms.
 * The app's `presence:ping` heartbeat keeps lastSeenAt fresh (presence = live sockets, D-031).
 */
@WebSocketGateway({ cors: { origin: true } })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly log = new Logger('Realtime');
  @WebSocketServer() server!: Server;

  constructor(private readonly jwt: JwtService, private readonly sessions: SessionAuthService, private readonly presence: PresenceService, bus: EventBus) {
    bus.subscribe((e) => this.fanOut(e));
    sessions.onRevoked((ids) => void this.disconnectSessions(ids));
  }

  async handleConnection(@ConnectedSocket() socket: Socket) {
    try {
      const token = (socket.handshake.auth as { token?: string })?.token ?? '';
      const payload = await this.jwt.verifyAsync<{ sid: string }>(token, { algorithms: ['HS256'] });
      const user = await this.sessions.resolve(payload.sid);
      if (!user) throw new Error('session revoked');
      if (user.role === 'WORKER' && !user.workerId) throw new Error('worker profile missing');
      await socket.join(roomsForUser(user));
      socket.data.userId = user.id;
      socket.data.sessionId = user.sessionId;
      socket.data.principal = user;
      // presence is awaited BEFORE 'ready' so a caller that has seen 'ready' can rely on the connect-presence event having landed
      await this.presence.connected(user, socket.id);
      socket.emit('ready', { role: user.role });
    } catch (e) {
      this.log.debug(`refused connection: ${(e as Error).message}`);
      socket.emit('unauthorized');
      socket.disconnect(true);
    }
  }

  async handleDisconnect(socket: Socket) {
    const user = socket.data.principal as AuthUser | undefined;
    if (user) await this.presence.disconnected(user, socket.id);
  }

  @SubscribeMessage('presence:ping')
  async ping(@ConnectedSocket() socket: Socket) {
    if (socket.data.userId) await this.presence.heartbeat(socket.data.userId as string);
    return { ok: true };
  }

  private fanOut(e: RealtimeEnvelope) {
    if (!this.server) return;
    const rooms = roomsForEvent(e.type, e.data);
    if (rooms.length) this.server.to(rooms).emit('event', e);
  }

  /** Called when a session is revoked (or its user's role/permissions changed) so the socket stops receiving data immediately. */
  async disconnectSessions(sessionIds: string[]) {
    if (!this.server) return;
    for (const s of await this.server.fetchSockets()) if (sessionIds.includes(s.data.sessionId)) s.disconnect(true);
  }
}

/** WebSocket gateway: API process only. */
@Module({ imports: [PresenceModule], providers: [RealtimeGateway], exports: [RealtimeGateway] })
export class RealtimeModule {}
