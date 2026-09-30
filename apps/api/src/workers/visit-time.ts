import { Controller, Get, Injectable, Module, Param, ParseUUIDPipe, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { visitTimeSchema, visitTimeText, type VisitTime } from '@diamoraa/shared';
import { Prisma } from '@diamoraa/database';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { workerScope } from '../common/scope';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

/** what a stored value looks like to the rest of the app: the value and its words («Пн–Пт 10:00–18:00») */
export function visitTimeView(raw: Prisma.JsonValue | null | undefined) {
  const v = raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as unknown as VisitTime) : null;
  return { visitTime: v, visitText: visitTimeText(v) };
}

/**
 * «Удобное время»: when a worker is happy for staff to come (deliver materials / collect work). She sets it in the app;
 * staff see it on her page, on the map and in «Маршрут»; a staff member may set it for her (by phone).
 */
@Injectable()
export class VisitTimeService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async get(workerId: string) {
    const w = await this.prisma.workerProfile.findUnique({ where: { id: workerId }, select: { visitTime: true } });
    if (!w) throw notFound('Worker');
    return visitTimeView(w.visitTime);
  }

  async set(workerId: string, value: z.output<typeof visitTimeSchema>, by: 'self' | 'staff') {
    const before = await this.prisma.workerProfile.findUnique({ where: { id: workerId }, select: { visitTime: true, assignedManagerId: true, status: true } });
    if (!before) throw notFound('Worker');
    const clean = value ? { days: [...new Set(value.days)].sort((a, b) => a - b), from: value.from, to: value.to, note: value.note || null } : null;
    await this.prisma.workerProfile.update({ where: { id: workerId }, data: { visitTime: clean ?? Prisma.DbNull } });
    await this.audit.record({ action: 'worker.visit_time', entity: 'WorkerProfile', entityId: workerId, before: { visitTime: before.visitTime }, after: { visitTime: clean, by } });
    await this.events.publish('worker.updated', { workerId, status: before.status, managerId: before.assignedManagerId });
    return visitTimeView(clean as Prisma.JsonValue);
  }
}

@ApiTags('workers')
@ApiBearerAuth()
@Controller()
export class VisitTimeController {
  constructor(private readonly visits: VisitTimeService, private readonly prisma: PrismaService) {}

  @Roles('WORKER') @Get('work/visit-time')
  mine(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.visits.get(u.workerId);
  }

  @Roles('WORKER') @Put('work/visit-time')
  setMine(@CurrentUser() u: AuthUser, @ZodBody(z.object({ visitTime: visitTimeSchema })) b: { visitTime: z.output<typeof visitTimeSchema> }) {
    if (!u.workerId) throw forbidden();
    return this.visits.set(u.workerId, b.visitTime, 'self');
  }

  @Perm('WORKER_UPDATE') @Put('admin/workers/:id/visit-time')
  async setFor(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(z.object({ visitTime: visitTimeSchema })) b: { visitTime: z.output<typeof visitTimeSchema> }) {
    const { where: scope } = workerScope(u, 'WORKER');
    if (!(await this.prisma.workerProfile.findFirst({ where: { ...scope, id, deletedAt: null }, select: { id: true } }))) throw notFound('Worker');
    return this.visits.set(id, b.visitTime, 'staff');
  }
}

@Module({ controllers: [VisitTimeController], providers: [VisitTimeService] })
export class VisitTimeModule {}
