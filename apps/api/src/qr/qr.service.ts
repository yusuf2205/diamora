import { Controller, Get, Injectable, Module, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { parseQrCode } from '@yusmus/shared';
import { CurrentUser, Roles } from '../common/decorators';
import { forbidden, notFound } from '../common/errors';
import { can } from '../common/scope';
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
  constructor(private readonly prisma: PrismaService, private readonly workers: WorkersService) {}

  async resolve(actor: AuthUser, rawCode: string) {
    const code = parseQrCode(rawCode);
    if (!code) throw notFound('QR code');
    const qr = await this.prisma.qrEntity.findUnique({ where: { code } });
    if (!qr || qr.revokedAt) throw notFound('QR code');

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

    // type === 'ASSIGNMENT': architecture is ready (same QrEntity, same opaque code), but nothing creates one of these
    // yet — WorkAssignment is M3. Never fabricate a response for it.
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

@Module({ imports: [WorkersModule], controllers: [QrController], providers: [QrService], exports: [QrService] })
export class QrModule {}
