import { Controller, Get, Injectable, Module, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { parseQrCode } from '@diamoraa/shared';
import { AssignmentsModule, AssignmentsService } from '../assignments/assignments.service';
import { CurrentUser, Roles } from '../common/decorators';
import { AppError, forbidden, notFound } from '../common/errors';
import { can, inWorkerScope } from '../common/scope';
import { num } from '../common/serialize';
import { PrismaService } from '../prisma/prisma.module';
import { WorkersModule, WorkersService } from '../workers/workers.service';
import type { AuthUser } from '../common/request-context';

/**
 * QR resolve (M2 §10-13). The code itself is opaque (`YQ1.<12 chars>`, D-012) — no name/phone/GPS/money is ever encoded in
 * it. Scanning only works for staff (SUPER_ADMIN/ADMIN/MANAGER); a WORKER QR resolves through the SAME scope check as
 * `GET /workers/:id` (a MANAGER scanning a worker outside her assignment gets 404, never the worker's data "hidden in the
 * UI"). A KIT QR (a physically-assembled batch, M2 §11) resolves for anyone with INVENTORY_VIEW.
 */
@Injectable()
export class QrService {
  constructor(private readonly prisma: PrismaService, private readonly workers: WorkersService, private readonly assignments: AssignmentsService) {}

  async resolve(actor: AuthUser, rawCode: string) {
    const code = parseQrCode(rawCode);
    if (!code) throw notFound('QR code');
    const qr = await this.prisma.qrEntity.findUnique({ where: { code } });
    if (!qr) throw notFound('QR code');
    // A real code that stopped working, or a real code of somebody else's worker: said plainly (the camera did read it —
    // «не найден» made people think the scanner was broken). Only the reason is returned, never the worker's data.
    if (qr.revokedAt) throw new AppError('QR_REVOKED', 'This QR no longer works', 410);
    if (qr.workerId && qr.type !== 'KIT') {
      const w = await this.prisma.workerProfile.findUnique({ where: { id: qr.workerId }, select: { assignedManagerId: true, deletedAt: true } });
      if (!w || w.deletedAt) throw new AppError('QR_REVOKED', 'This QR no longer works', 410);
      if (!inWorkerScope(actor, qr.type === 'WORKER' ? 'WORKER' : 'ASSIGNMENT', w)) throw new AppError('QR_NOT_YOURS', 'This worker is assigned to another manager', 403);
    }

    if (qr.type === 'WORKER') {
      if (!qr.workerId) throw notFound('QR code');
      // Reuses the exact same scope check as GET /workers/:id: a MANAGER scanning a stranger's worker gets 404.
      return { type: 'WORKER' as const, worker: await this.workers.get(actor, qr.workerId) };
    }

    if (qr.type === 'KIT') {
      if (!can(actor, 'INVENTORY_VIEW')) throw forbidden();
      if (!qr.kitTemplateId) throw notFound('QR code');
      const t = await this.prisma.materialKitTemplate.findUnique({ where: { id: qr.kitTemplateId }, include: { items: { include: { material: true } } } });
      if (!t) throw notFound('Kit template');
      return {
        type: 'KIT' as const,
        kit: {
          kitTemplateId: t.id, kitTemplateName: t.name, count: qr.kitCount ?? 1, ribbonMeters: num(t.ribbonMeters),
          totalMeters: (num(t.ribbonMeters) ?? 0) * (qr.kitCount ?? 1), assembledAt: qr.createdAt.toISOString(),
          items: t.items.map((i) => ({ materialId: i.materialId, name: i.material.name, unit: i.material.unit, requiredQuantity: num(i.requiredQuantity) })),
        },
      };
    }

    if (qr.type === 'ASSIGNMENT') {
      if (!qr.assignmentId) throw notFound('QR code');
      // Reuses the exact same scope check as GET /admin/assignments/:id (workerScope 'ASSIGNMENT'): a MANAGER scanning a
      // stranger's assignment gets 404, never the data (M2 §13's rule, extended to M3).
      return { type: 'ASSIGNMENT' as const, assignment: await this.assignments.get(actor, qr.assignmentId) };
    }

    throw notFound('QR code');
  }
}

@ApiTags('qr')
@ApiBearerAuth()
@Controller('qr')
export class QrController {
  constructor(private readonly qr: QrService) {}

  @Roles('SUPER_ADMIN', 'ADMIN', 'MANAGER') @Get(':code')
  resolve(@CurrentUser() u: AuthUser, @Param('code') code: string) { return this.qr.resolve(u, code); }
}

@Module({ imports: [WorkersModule, AssignmentsModule], controllers: [QrController], providers: [QrService], exports: [QrService] })
export class QrModule {}
