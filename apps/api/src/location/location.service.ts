import { Controller, Injectable, Module, Post, Get, HttpCode } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { LOCATION_STALE_SECONDS, locationFreshness, reportLocationSchema, scopeFor } from '@yusmus/shared';
import { z } from 'zod';
import { ApiZodBody, Authenticated, CurrentUser, Perm } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PresenceModule, PresenceService } from '../presence/presence.service';
import { PrismaService } from '../prisma/prisma.module';

export { LOCATION_STALE_SECONDS }; // re-exported: thresholds now live in packages/shared (M2 §17), this keeps old imports working

/**
 * Background live location (D-030, docs/LIVE-LOCATION.md). Every role reports its OWN current working position; the server
 * never trusts a userId/workerId in the body. Only the latest position is kept (`UserLiveLocation`, one row per user) - no
 * unbounded coordinate history. Reads are scoped server-side exactly like worker data (`scopeFor(... 'LOCATION')`):
 * a MANAGER's map never includes another manager's workers.
 */
@Injectable()
export class LocationService {
  constructor(private readonly prisma: PrismaService, private readonly events: EventBus, private readonly presence: PresenceService) {}

  async report(user: AuthUser, input: z.output<typeof reportLocationSchema>) {
    const receivedAt = new Date();
    await this.prisma.userLiveLocation.upsert({
      where: { userId: user.id },
      create: { userId: user.id, latitude: input.latitude, longitude: input.longitude, accuracy: input.accuracy, heading: input.heading, speed: input.speed, recordedAt: input.recordedAt, receivedAt, source: 'GPS', isBackground: input.isBackground },
      update: { latitude: input.latitude, longitude: input.longitude, accuracy: input.accuracy, heading: input.heading, speed: input.speed, recordedAt: input.recordedAt, receivedAt, isBackground: input.isBackground },
    });
    let workerId: string | undefined;
    let managerId: string | null = null;
    if (user.workerId) {
      workerId = user.workerId;
      const w = await this.prisma.workerProfile.update({
        where: { id: user.workerId },
        data: { latitude: input.latitude, longitude: input.longitude, locationReceivedAt: receivedAt },
        select: { assignedManagerId: true },
      });
      managerId = w.assignedManagerId;
      await this.events.publish('worker.location.updated', { workerId: user.workerId, latitude: input.latitude, longitude: input.longitude, receivedAt: receivedAt.toISOString(), managerId });
    }
    await this.events.publish('user.location.updated', { userId: user.id, role: user.role, latitude: input.latitude, longitude: input.longitude, recordedAt: input.recordedAt.toISOString(), managerId, workerId });
    return { ok: true, receivedAt: receivedAt.toISOString() };
  }

  /** Locations the viewer is allowed to see (map screen). The route requires the permission, so scope is always 'all' or 'assigned' here. */
  async list(viewer: AuthUser) {
    const scope = scopeFor(viewer.permissions, 'LOCATION');
    const where = scope === 'all' ? {} : { OR: [{ id: viewer.id }, { workerProfile: { assignedManagerId: viewer.id } }] };
    // a person the SUPER_ADMIN hid is invisible to everyone else (except themselves); SUPER_ADMIN sees them, flagged
    const visibility = viewer.role === 'SUPER_ADMIN' ? {} : { OR: [{ locationHidden: false }, { id: viewer.id }] };
    const users = await this.prisma.user.findMany({
      where: { AND: [{ status: 'ACTIVE' }, where, visibility] },
      include: { liveLocation: true, workerProfile: { select: { id: true, code: true, fullName: true, phone: true, assignedManagerId: true } } },
    });
    const now = Date.now();
    return {
      // map markers (M2 §14-16): role, online (presence, separate from GPS) and phone are what a marker's bottom sheet needs.
      items: users.filter((u) => u.liveLocation).map((u) => {
        const l = u.liveLocation!;
        const ageSeconds = Math.max(0, Math.round((now - l.recordedAt.getTime()) / 1000));
        return {
          userId: u.id, role: u.role, fullName: u.fullName, phone: u.phone, hidden: u.locationHidden,
          online: this.presence.isOnline(u.id),
          worker: u.workerProfile ? { id: u.workerProfile.id, code: u.workerProfile.code, phone: u.workerProfile.phone, managerId: u.workerProfile.assignedManagerId } : null,
          latitude: l.latitude, longitude: l.longitude, accuracy: l.accuracy, heading: l.heading, speed: l.speed,
          recordedAt: l.recordedAt.toISOString(), ageSeconds, freshness: locationFreshness(ageSeconds), stale: ageSeconds > LOCATION_STALE_SECONDS, isBackground: l.isBackground,
        };
      }),
    };
  }
}

@ApiTags('location')
@ApiBearerAuth()
@Controller()
export class LocationController {
  constructor(private readonly location: LocationService) {}

  /** Any authenticated role reports its own position (SUPER_ADMIN, ADMIN, MANAGER, WORKER all support background tracking, §19). */
  @Authenticated() @Post('location') @HttpCode(200) @ApiZodBody(reportLocationSchema)
  report(@CurrentUser() u: AuthUser, @ZodBody(reportLocationSchema) b: z.output<typeof reportLocationSchema>) { return this.location.report(u, b); }

  @Perm('LIVE_LOCATION_VIEW_ALL', 'LIVE_LOCATION_VIEW_ASSIGNED') @Get('locations')
  list(@CurrentUser() u: AuthUser) { return this.location.list(u); }
}

@Module({ imports: [PresenceModule], controllers: [LocationController], providers: [LocationService], exports: [LocationService] })
export class LocationModule {}
