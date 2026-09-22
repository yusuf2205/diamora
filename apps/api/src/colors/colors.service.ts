import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Color } from '@yusmus/database';
import { createColorSchema, listColorsSchema, updateColorSchema } from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, Perm } from '../common/decorators';
import { conflict, notFound } from '../common/errors';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';

/**
 * Colors (M3 tech-debt closeout, D-039): a plain shared lookup — Material, ProductVariant and WorkAssignment all
 * already referenced `colorId` before this module existed (schema was ready from M0), but nothing could list/create
 * one. No PIM: just name + optional hex + active flag, same shape as Materials.
 */
@Injectable()
export class ColorsService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  list(q: z.output<typeof listColorsSchema>) {
    return this.prisma.color.findMany({ where: { isActive: q.isActive }, orderBy: { name: 'asc' } }).then((rows) => ({ items: rows.map(this.dto) }));
  }

  async get(id: string) {
    return this.dto(await this.load(id));
  }

  async create(input: z.output<typeof createColorSchema>) {
    if (await this.prisma.color.findUnique({ where: { name: input.name } })) throw conflict('A color with this name already exists');
    const c = await this.prisma.$transaction(async (tx) => {
      const created = await tx.color.create({ data: { name: input.name, hex: input.hex } });
      await this.audit.record({ action: 'color.create', entity: 'Color', entityId: created.id, after: { name: created.name, hex: created.hex } }, tx);
      return created;
    });
    await this.events.publish('color.created', { colorId: c.id });
    return this.dto(c);
  }

  async update(id: string, patch: z.output<typeof updateColorSchema>) {
    const before = await this.load(id);
    if (patch.name && patch.name !== before.name && (await this.prisma.color.findUnique({ where: { name: patch.name } })))
      throw conflict('A color with this name already exists');
    const c = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.color.update({ where: { id }, data: patch });
      await this.audit.record({ action: 'color.update', entity: 'Color', entityId: id, before: { name: before.name, hex: before.hex, isActive: before.isActive }, after: patch }, tx);
      return updated;
    });
    await this.events.publish('color.updated', { colorId: id });
    return this.dto(c);
  }

  /** No hard delete (already referenced by materials/variants/assignments): deactivate instead. */
  deactivate(id: string) {
    return this.update(id, { isActive: false });
  }

  private async load(id: string): Promise<Color> {
    const c = await this.prisma.color.findUnique({ where: { id } });
    if (!c) throw notFound('Color');
    return c;
  }
  private dto(c: Color) {
    return { id: c.id, name: c.name, hex: c.hex, isActive: c.isActive, createdAt: c.createdAt.toISOString(), updatedAt: c.updatedAt.toISOString() };
  }
}

@ApiTags('colors')
@ApiBearerAuth()
@Controller()
export class ColorsController {
  constructor(private readonly colors: ColorsService) {}

  /** Public-ish for staff: any authenticated staff role can read the list to populate a picker — same as `CATALOG_VIEW`
   * covers today for other read-only lookups. Workers never call this directly (they read `colors` embedded in `/v1/catalog`). */
  @Perm('CATALOG_VIEW', 'CATALOG_MANAGE', 'INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('admin/colors')
  list(@ZodQuery(listColorsSchema) q: z.output<typeof listColorsSchema>) { return this.colors.list(q); }

  @Perm('CATALOG_VIEW', 'CATALOG_MANAGE', 'INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('admin/colors/:id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.colors.get(id); }

  @Perm('CATALOG_MANAGE') @Post('admin/colors') @ApiZodBody(createColorSchema)
  create(@ZodBody(createColorSchema) b: z.output<typeof createColorSchema>) { return this.colors.create(b); }

  @Perm('CATALOG_MANAGE') @Patch('admin/colors/:id') @ApiZodBody(updateColorSchema)
  update(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateColorSchema) b: z.output<typeof updateColorSchema>) { return this.colors.update(id, b); }

  @Perm('CATALOG_MANAGE') @Post('admin/colors/:id/deactivate') @HttpCode(200)
  deactivate(@Param('id', new ParseUUIDPipe()) id: string) { return this.colors.deactivate(id); }
}

@Module({ controllers: [ColorsController], providers: [ColorsService], exports: [ColorsService] })
export class ColorsModule {}
