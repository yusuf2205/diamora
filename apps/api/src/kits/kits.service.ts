import { Controller, Get, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Material, MaterialKitTemplate, MaterialKitTemplateItem } from '@yusmus/database';
import { KIT_METERS, assembleKitSchema, createKitTemplateSchema, updateKitTemplateSchema } from '@yusmus/shared';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm } from '../common/decorators';
import { invariant, notFound } from '../common/errors';
import { generateQrCode } from '../common/sequence';
import { num } from '../common/serialize';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import { StockModule, StockService } from '../stock/stock.service';
import type { AuthUser } from '../common/request-context';

type TemplateWithItems = MaterialKitTemplate & { items: (MaterialKitTemplateItem & { material: Material })[] };

/**
 * The 9 m kit recipe (M2 §8-9): a template names WHAT goes into one 9 m set (ribbon + beads + thread + extras). 18/27 m
 * are the SAME template × 2 or × 3 (`requiredQuantity × kitCount`) — no separate 18m/27m templates exist, by design.
 * `assemble()` is the one place a template becomes a real, physically-prepared batch: it consumes warehouse stock and
 * issues ONE opaque QR for the batch (M2 §10-11), ready for the future WorkAssignment to reuse the same code.
 */
@Injectable()
export class KitsService {
  constructor(
    private readonly prisma: PrismaService, private readonly stock: StockService, private readonly audit: AuditService, private readonly events: EventBus,
  ) {}

  async list() {
    const rows = await this.prisma.materialKitTemplate.findMany({ include: { items: { include: { material: true } } }, orderBy: { name: 'asc' } });
    return { items: rows.map((t) => this.dto(t)) };
  }

  async get(id: string) {
    return this.dto(await this.load(id));
  }

  async create(actor: AuthUser, input: z.output<typeof createKitTemplateSchema>) {
    await this.assertMaterialsExist(input.items.map((i) => i.materialId));
    const t = await this.prisma.$transaction(async (tx) => {
      const created = await tx.materialKitTemplate.create({
        data: {
          name: input.name, variantId: input.variantId, ribbonMeters: input.ribbonMeters,
          items: { create: input.items.map((i) => ({ materialId: i.materialId, requiredQuantity: i.requiredQuantity })) },
        },
        include: { items: { include: { material: true } } },
      });
      await this.audit.record({ action: 'kit.create', entity: 'MaterialKitTemplate', entityId: created.id, after: { name: created.name, items: input.items.length } }, tx);
      return created;
    });
    await this.events.publish('kit.created', { kitTemplateId: t.id });
    return this.dto(t);
  }

  async update(id: string, patch: z.output<typeof updateKitTemplateSchema>) {
    const before = await this.load(id);
    if (patch.items) await this.assertMaterialsExist(patch.items.map((i) => i.materialId));
    await this.prisma.$transaction(async (tx) => {
      await tx.materialKitTemplate.update({ where: { id }, data: { name: patch.name, variantId: patch.variantId, active: patch.active } });
      if (patch.items) {
        await tx.materialKitTemplateItem.deleteMany({ where: { templateId: id } });
        await tx.materialKitTemplateItem.createMany({ data: patch.items.map((i) => ({ templateId: id, materialId: i.materialId, requiredQuantity: i.requiredQuantity })) });
      }
      await this.audit.record({ action: 'kit.update', entity: 'MaterialKitTemplate', entityId: id, before: { name: before.name, active: before.active }, after: patch }, tx);
    });
    await this.events.publish('kit.updated', { kitTemplateId: id });
    return this.get(id);
  }

  /** Physically assemble `count` copies of this 9 m recipe (M2 §8/§11): consumes count × requiredQuantity of every
   * ingredient from the warehouse in ONE atomic group of movements, then issues one QR for the whole batch. */
  async assemble(actor: AuthUser, id: string, input: z.output<typeof assembleKitSchema>) {
    const t = await this.load(id);
    if (!t.active) throw invariant('This kit template is inactive');
    if (t.items.length === 0) throw invariant('This kit template has no materials yet');
    const groupId = randomUUID();
    const { movements, qr } = await this.prisma.$transaction(async (tx) => {
      const written = [];
      for (const item of t.items) {
        const needed = item.requiredQuantity.times(input.count).toFixed(3);
        written.push(await this.stock.recordMovement(tx, actor, {
          type: 'ISSUE_TO_KIT', materialId: item.materialId, quantity: needed, warehouseDelta: `-${needed}`,
          comment: input.comment ?? `Сборка: ${t.name} × ${input.count}`, groupId,
        }));
      }
      const qrEntity = await tx.qrEntity.create({ data: { code: generateQrCode(), type: 'KIT', kitTemplateId: id, kitCount: input.count, stockGroupId: groupId } });
      await this.audit.record({ action: 'kit.assemble', entity: 'MaterialKitTemplate', entityId: id, after: { count: input.count, qrCode: qrEntity.code, groupId } }, tx);
      return { movements: written, qr: qrEntity };
    });
    for (const m of movements) await this.stock.publish(m);
    await this.events.publish('kit.assembled', { kitTemplateId: id, qrCode: qr.code, count: input.count });
    await this.events.publish('qr.created', { code: qr.code, type: 'KIT', kitTemplateId: id });
    return {
      qrCode: qr.code, kitTemplateId: id, kitTemplateName: t.name, count: input.count,
      totalMeters: num(t.ribbonMeters)! * input.count, assembledAt: qr.createdAt.toISOString(),
    };
  }

  // ---- internals -------------------------------------------------------------------------------------------------------
  private async assertMaterialsExist(ids: string[]) {
    const found = await this.prisma.material.count({ where: { id: { in: [...new Set(ids)] }, isActive: true } });
    if (found !== new Set(ids).size) throw invariant('One or more materials are unknown or inactive');
  }
  private async load(id: string): Promise<TemplateWithItems> {
    const t = await this.prisma.materialKitTemplate.findUnique({ where: { id }, include: { items: { include: { material: true } } } });
    if (!t) throw notFound('Kit template');
    return t;
  }
  private dto(t: TemplateWithItems) {
    return {
      id: t.id, name: t.name, variantId: t.variantId, ribbonMeters: num(t.ribbonMeters), baseMeters: KIT_METERS, active: t.active,
      items: t.items.map((i) => ({ id: i.id, materialId: i.materialId, materialName: i.material.name, unit: i.material.unit, requiredQuantity: num(i.requiredQuantity) })),
      createdAt: t.createdAt.toISOString(),
    };
  }
}

@ApiTags('kits')
@ApiBearerAuth()
@Controller('admin/kits')
export class KitsController {
  constructor(private readonly kits: KitsService) {}

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get()
  list() { return this.kits.list(); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get(':id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.kits.get(id); }

  @Perm('INVENTORY_MANAGE') @Post() @ApiZodBody(createKitTemplateSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createKitTemplateSchema) b: z.output<typeof createKitTemplateSchema>) { return this.kits.create(u, b); }

  @Perm('INVENTORY_MANAGE') @Patch(':id') @ApiZodBody(updateKitTemplateSchema)
  update(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateKitTemplateSchema) b: z.output<typeof updateKitTemplateSchema>) { return this.kits.update(id, b); }

  @Perm('INVENTORY_MANAGE') @Post(':id/assemble') @ApiZodBody(assembleKitSchema)
  assemble(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(assembleKitSchema) b: z.output<typeof assembleKitSchema>) { return this.kits.assemble(u, id, b); }
}

@Module({ imports: [StockModule], controllers: [KitsController], providers: [KitsService], exports: [KitsService] })
export class KitsModule {}
