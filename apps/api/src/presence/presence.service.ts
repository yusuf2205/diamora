import { Controller, Get, Injectable, Module } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { scopeFor, type Role } from '@yusmus/shared';
import { CurrentUser, Perm } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

const DB_WRITE_EVERY_MS = 30_000;

/**
 * Who is online right now (D-031). Presence is LIVE state of the API process: a user is ONLINE while at least one of their
 * Socket.IO connections is alive (Socket.IO's own ping/pong detects dead connections). `lastSeenAt` is the fallback that survives
 * restarts: written on connect, disconnect and (throttled) on the app's heartbeat. Separate from GPS by design.
 */
@Injectable()
export class PresenceService {
  private readonly sockets = new Map<string, Set<string>>();
  private readonly lastWrite = new Map<string, number>();
  private readonly lastBeat = new Map<string, number>();

  constructor(private readonly prisma: PrismaService, private readonly events: EventBus) {}

  isOnline(userId: string): boolean { return (this.sockets.get(userId)?.size ?? 0) > 0; }
  onlineIds(): string[] { return [...this.sockets.keys()].filter((id) => this.isOnline(id)); }

  async connected(user: AuthUser, socketId: string): Promise<void> {
    const set = this.sockets.get(user.id) ?? new Set<string>();
    const first = set.size === 0;
    set.add(socketId);
    this.sockets.set(user.id, set);
    this.lastBeat.set(user.id, Date.now());
    if (first) await this.changed(user, true);
  }

  async disconnected(user: AuthUser, socketId: string): Promise<void> {
    const set = this.sockets.get(user.id);
    if (!set) return;
    set.delete(socketId);
    if (set.size > 0) return;
    this.sockets.delete(user.id);
    await this.changed(user, false);
  }

  /** The app's periodic "I am alive" signal (also while the app is in the background). */
  async heartbeat(userId: string): Promise<void> {
    const now = Date.now();
    this.lastBeat.set(userId, now);
    if (now - (this.lastWrite.get(userId) ?? 0) < DB_WRITE_EVERY_MS) return;
    this.lastWrite.set(userId, now);
    await this.prisma.user.update({ where: { id: userId }, data: { lastSeenAt: new Date(now) } }).catch(() => undefined);
  }

  /** Best-effort: a socket can disconnect after the process (or, in tests, the Prisma engine) has already started shutting down. */
  private async changed(user: AuthUser, online: boolean): Promise<void> {
    try {
      const at = new Date();
      this.lastWrite.set(user.id, at.getTime());
      await this.prisma.user.update({ where: { id: user.id }, data: { lastSeenAt: at } });
      const worker = user.workerId ? await this.prisma.workerProfile.findUnique({ where: { id: user.workerId }, select: { assignedManagerId: true } }) : null;
      await this.events.publish('user.presence_changed', { userId: user.id, role: user.role, online, lastSeenAt: at.toISOString(), managerId: worker?.assignedManagerId ?? null });
    } catch { /* presence is a live hint, never a source of truth: a lost update just means a slightly stale lastSeenAt */ }
  }

  /** Presence of the users this viewer may see (server-side scope; a MANAGER sees only their workers and themselves). */
  async visibleTo(viewer: AuthUser, roles?: Role[]) {
    const seeAll = viewer.permissions.includes('USER_VIEW_ALL');
    const workerScope = scopeFor(viewer.permissions, 'WORKER');
    const where = seeAll
      ? {}
      : workerScope === 'assigned'
        ? { OR: [{ id: viewer.id }, { workerProfile: { assignedManagerId: viewer.id } }] }
        : { id: viewer.id };
    const users = await this.prisma.user.findMany({
      where: { status: 'ACTIVE', ...where, ...(roles?.length ? { role: { in: roles } } : {}) },
      select: { id: true, role: true, fullName: true, lastSeenAt: true, workerProfile: { select: { id: true, assignedManagerId: true } } },
      orderBy: { fullName: 'asc' },
    });
    return users.map((u) => {
      const online = this.isOnline(u.id);
      const beat = this.lastBeat.get(u.id);
      return {
        userId: u.id, role: u.role, fullName: u.fullName, online,
        lastSeenAt: online ? new Date(beat ?? Date.now()).toISOString() : (u.lastSeenAt?.toISOString() ?? null),
        workerId: u.workerProfile?.id ?? null, managerId: u.workerProfile?.assignedManagerId ?? null,
      };
    });
  }
}

@ApiTags('presence')
@ApiBearerAuth()
@Controller('presence')
export class PresenceController {
  constructor(private readonly presence: PresenceService) {}

  /** ONLINE / OFFLINE + lastSeenAt of the users the caller may see. */
  @Perm('USER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED') @Get()
  async list(@CurrentUser() u: AuthUser) { return { items: await this.presence.visibleTo(u) }; }
}

@Module({ controllers: [PresenceController], providers: [PresenceService], exports: [PresenceService] })
export class PresenceModule {}
