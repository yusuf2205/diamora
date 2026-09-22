import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Material, MaterialCategory, StockBalance } from '@yusmus/database';
import { createMaterialSchema, listMaterialsSchema, updateMaterialSchema } from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm } from '../common/decorators';
import { invariant, notFound } from '../common/errors';
import { num } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import type { AuthUser } from '../common/request-context';

type MaterialRow = Material & { category: MaterialCategory | null; balance: StockBalance | null };

/**
 * The materials reference book (M2 §5): a normal lookup — no financial fields are ever computed here (cost lives on
 * `unitCost`, used only by the M6 profit report, never returned to a WORKER — the catalog module never even joins this
 * table). Categories are a FIXED, seeded set (TAPE/BEAD/THREAD/ACCESSORY/OTHER); not user-creatable in this round.
 */
@Injectable()
export class MaterialsService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  categories() {
    return this.prisma.materialCategory.findMany({ orderBy: { name: 'asc' } });
  }

  async list(q: z.output<typeof listMaterialsSchema>) {
    const text = q.q?.trim();
    const rows = await this.prisma.material.findMany({
      where: {
        categoryId: q.categoryId, isActive: q.isActive,
        name: text ? { contains: text, mode: 'insensitive' } : undefined,
      },
      include: { category: true, balance: true },
      orderBy: { name: 'asc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((m) => this.dto(m)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(id: string) {
    return this.dto(await this.load(id));
  }

  async create(actor: AuthUser, input: z.output<typeof createMaterialSchema>) {
    if (input.categoryId && !(await this.prisma.materialCategory.findUnique({ where: { id: input.categoryId } })))
      throw invariant('Unknown category');
    const m = await this.prisma.$transaction(async (tx) => {
      const created = await tx.material.create({
        data: { name: input.name, categoryId: input.categoryId, colorId: input.colorId, article: input.article, unit: input.unit, minStock: input.minStock ?? '0' },
      });
      await tx.stockBalance.create({ data: { materialId: created.id, quantity: 0 } });
      await this.audit.record({ action: 'material.create', entity: 'Material', entityId: created.id, after: { name: created.name, unit: created.unit } }, tx);
      return created;
    });
    await this.events.publish('material.created', { materialId: m.id });
    return this.get(m.id);
  }

  async update(id: string, patch: z.output<typeof updateMaterialSchema>) {
    const before = await this.load(id);
    if (patch.categoryId && !(await this.prisma.materialCategory.findUnique({ where: { id: patch.categoryId } })))
      throw invariant('Unknown category');
    await this.prisma.$transaction(async (tx) => {
      await tx.material.update({ where: { id }, data: patch });
      await this.audit.record({ action: 'material.update', entity: 'Material', entityId: id, before: { name: before.name, unit: before.unit, isActive: before.isActive }, after: patch }, tx);
    });
    await this.events.publish('material.updated', { materialId: id });
    return this.get(id);
  }

  /** No hard delete (a material may already be referenced by movements/kit items): deactivate instead. */
  async deactivate(id: string) {
    await this.load(id);
    return this.update(id, { isActive: false });
  }

  // ---- internals -------------------------------------------------------------------------------------------------------
  private async load(id: string): Promise<MaterialRow> {
    const m = await this.prisma.material.findUnique({ where: { id }, include: { category: true, balance: true } });
    if (!m) throw notFound('Material');
    return m;
  }
  private dto(m: MaterialRow) {
    const qty = num(m.balance?.quantity) ?? 0;
    const min = num(m.minStock) ?? 0;
    return {
      id: m.id, name: m.name, article: m.article, unit: m.unit, isActive: m.isActive,
      category: m.category ? { id: m.category.id, code: m.category.code, name: m.category.name } : null,
      colorId: m.colorId, minStock: min, balance: qty, low: qty < min,
      createdAt: m.createdAt.toISOString(), updatedAt: m.updatedAt.toISOString(),
    };
  }
}

@ApiTags('materials')
@ApiBearerAuth()
@Controller('admin/materials')
export class MaterialsController {
  constructor(private readonly materials: MaterialsService) {}

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('categories')
  categories() { return this.materials.categories(); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get()
  list(@ZodQuery(listMaterialsSchema) q: z.output<typeof listMaterialsSchema>) { return this.materials.list(q); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get(':id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.materials.get(id); }

  @Perm('INVENTORY_MANAGE') @Post() @ApiZodBody(createMaterialSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createMaterialSchema) b: z.output<typeof createMaterialSchema>) { return this.materials.create(u, b); }

  @Perm('INVENTORY_MANAGE') @Patch(':id') @ApiZodBody(updateMaterialSchema)
  update(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateMaterialSchema) b: z.output<typeof updateMaterialSchema>) { return this.materials.update(id, b); }

  @Perm('INVENTORY_MANAGE') @Post(':id/deactivate') @HttpCode(200)
  deactivate(@Param('id', new ParseUUIDPipe()) id: string) { return this.materials.deactivate(id); }
}

@Module({ controllers: [MaterialsController], providers: [MaterialsService], exports: [MaterialsService] })
export class MaterialsModule {}
