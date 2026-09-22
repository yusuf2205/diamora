import {
  Controller, Delete, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Patch, Post, Put, UploadedFile, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import type { Prisma, ProductMedia, ProductModel, ProductVariant } from '@yusmus/database';
import {
  addMediaSchema, createCatalogItemSchema, createVariantSchema, idSchema, listCatalogSchema, reorderSchema, updateCatalogItemSchema, updateVariantSchema,
} from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { fileRejected, invariant, notFound } from '../common/errors';
import { nextCode } from '../common/sequence';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { FilesService } from '../files/files.service';
import { PrismaService } from '../prisma/prisma.module';
import type { AuthUser } from '../common/request-context';

type ModelWithMedia = ProductModel & { media: ProductMedia[]; variants: ProductVariant[] };

/**
 * "Наши работы" — the informational catalog a WORKER opens by default (D-029). NEVER a price: the catalog tables have no
 * price column, and nothing here ever reads `pay_rate_changes`. Staff manage it (CATALOG_MANAGE); only PUBLISHED items and
 * only non-internal fields are ever returned to a WORKER.
 */
@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService, private readonly files: FilesService, private readonly audit: AuditService, private readonly events: EventBus) {}

  // ---- WORKER: published catalog only, no prices, no drafts -----------------------------------------------------------------
  async published() {
    const rows = await this.prisma.productModel.findMany({
      where: { status: 'PUBLISHED' },
      include: { media: { orderBy: { sortOrder: 'asc' } }, variants: { where: { active: true }, orderBy: { sortOrder: 'asc' }, include: { color: true } } },
      orderBy: [{ sortOrder: 'asc' }, { publishedAt: 'desc' }],
    });
    return { items: rows.map((m) => this.workerCard(m)) };
  }

  async publishedDetail(id: string) {
    const m = await this.prisma.productModel.findFirst({
      where: { id, status: 'PUBLISHED' },
      include: { media: { orderBy: { sortOrder: 'asc' } }, variants: { where: { active: true }, orderBy: { sortOrder: 'asc' }, include: { color: true } } },
    });
    if (!m) throw notFound('Item');
    return this.workerDetail(m);
  }

  // ---- staff: manage everything -----------------------------------------------------------------------------------------------
  async list(q: z.output<typeof listCatalogSchema>) {
    const rows = await this.prisma.productModel.findMany({
      where: { status: q.status },
      include: { media: { orderBy: { sortOrder: 'asc' } }, variants: { orderBy: { sortOrder: 'asc' }, include: { color: true } } },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }], take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((m) => this.staffDto(m)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async get(id: string) {
    const m = await this.load(id);
    return this.staffDto(m);
  }

  async create(actor: AuthUser, input: z.output<typeof createCatalogItemSchema>) {
    const m = await this.prisma.$transaction(async (tx) => {
      const code = await nextCode(tx, 'product_model_code', 'PRD-', 4);
      const created = await tx.productModel.create({ data: { code, name: input.name, description: input.description }, include: { media: true, variants: { include: { color: true } } } });
      await this.audit.record({ action: 'catalog.create', entity: 'ProductModel', entityId: created.id, after: { name: created.name } }, tx);
      return created;
    });
    await this.events.publish('catalog.item.created', { itemId: m.id });
    return this.staffDto(m);
  }

  async update(id: string, patch: z.output<typeof updateCatalogItemSchema>) {
    const before = await this.load(id);
    await this.prisma.$transaction(async (tx) => {
      await tx.productModel.update({ where: { id }, data: patch });
      await this.audit.record({ action: 'catalog.update', entity: 'ProductModel', entityId: id, before: { name: before.name }, after: patch }, tx);
    });
    await this.events.publish('catalog.item.updated', { itemId: id });
    return this.get(id);
  }

  async setStatus(actor: AuthUser, id: string, status: 'PUBLISHED' | 'HIDDEN' | 'DRAFT') {
    const before = await this.load(id);
    if (status === 'PUBLISHED' && before.media.length === 0) throw invariant('Add at least one photo before publishing');
    await this.prisma.$transaction(async (tx) => {
      await tx.productModel.update({ where: { id }, data: { status, publishedAt: status === 'PUBLISHED' ? new Date() : before.publishedAt } });
      await this.audit.record({ action: 'catalog.status_change', entity: 'ProductModel', entityId: id, before: { status: before.status }, after: { status } }, tx);
    });
    await this.events.publish(status === 'PUBLISHED' ? 'catalog.item.published' : status === 'HIDDEN' ? 'catalog.item.hidden' : 'catalog.item.updated', { itemId: id });
    return this.get(id);
  }

  async remove(id: string) {
    const used = await this.prisma.workAssignment.count({ where: { productModelId: id } }) + await this.prisma.saleItem.count({ where: { productModelId: id } });
    if (used > 0) throw invariant('This item is used by real work or sales — hide it instead of deleting');
    await this.prisma.$transaction(async (tx) => {
      await tx.productModel.delete({ where: { id } });
      await this.audit.record({ action: 'catalog.delete', entity: 'ProductModel', entityId: id }, tx);
    });
    await this.events.publish('catalog.item.deleted', { itemId: id });
    return { deleted: true };
  }

  async reorder(ids: string[]) {
    await this.prisma.$transaction(ids.map((id, i) => this.prisma.productModel.update({ where: { id }, data: { sortOrder: i } })));
    await this.events.publish('catalog.order.changed', {});
    return { ok: true };
  }

  // ---- variants ------------------------------------------------------------------------------------------------------------------
  async addVariant(modelId: string, input: z.output<typeof createVariantSchema>) {
    await this.load(modelId);
    const sku = `${modelId.slice(0, 8)}-${input.colorId.slice(0, 8)}`.toUpperCase();
    const v = await this.prisma.productVariant.create({ data: { modelId, colorId: input.colorId, sku, label: input.label } });
    await this.audit.record({ action: 'catalog.variant_add', entity: 'ProductVariant', entityId: v.id, after: { modelId, colorId: input.colorId } });
    await this.events.publish('catalog.item.updated', { itemId: modelId });
    return this.get(modelId);
  }

  async updateVariant(id: string, patch: z.output<typeof updateVariantSchema>) {
    const v = await this.prisma.productVariant.findUnique({ where: { id } });
    if (!v) throw notFound('Variant');
    await this.prisma.productVariant.update({ where: { id }, data: patch });
    await this.events.publish('catalog.item.updated', { itemId: v.modelId });
    return this.get(v.modelId);
  }

  // ---- media (MinIO on the NAS) ----------------------------------------------------------------------------------------------------
  async addMedia(actor: AuthUser, modelId: string, input: z.output<typeof addMediaSchema>, file: { buffer: Buffer; originalName?: string }) {
    const m = await this.load(modelId);
    if (input.variantId && !m.variants.some((v) => v.id === input.variantId)) throw notFound('Variant');
    const asset = input.kind === 'VIDEO'
      ? await this.files.uploadVideo({ bucket: 'products', buffer: file.buffer, uploadedById: actor.id, originalName: file.originalName })
      : await this.files.uploadImage({ bucket: 'products', buffer: file.buffer, uploadedById: actor.id, originalName: file.originalName });
    const isFirst = m.media.filter((x) => x.kind === 'PHOTO').length === 0 && input.kind === 'PHOTO';
    const media = await this.prisma.productMedia.create({
      data: { productModelId: modelId, variantId: input.variantId, fileId: asset.id, kind: input.kind, caption: input.caption, isMain: isFirst, sortOrder: m.media.length },
    });
    await this.audit.record({ action: 'catalog.media_add', entity: 'ProductModel', entityId: modelId, after: { mediaId: media.id, kind: input.kind } });
    await this.events.publish('catalog.item.updated', { itemId: modelId });
    return this.get(modelId);
  }

  async setMainMedia(mediaId: string) {
    const media = await this.prisma.productMedia.findUnique({ where: { id: mediaId } });
    if (!media || media.kind !== 'PHOTO') throw notFound('Photo');
    await this.prisma.$transaction([
      this.prisma.productMedia.updateMany({ where: { productModelId: media.productModelId, kind: 'PHOTO' }, data: { isMain: false } }),
      this.prisma.productMedia.update({ where: { id: mediaId }, data: { isMain: true } }),
    ]);
    await this.events.publish('catalog.item.updated', { itemId: media.productModelId });
    return this.get(media.productModelId);
  }

  async removeMedia(mediaId: string) {
    const media = await this.prisma.productMedia.findUnique({ where: { id: mediaId } });
    if (!media) throw notFound('Media');
    await this.prisma.productMedia.delete({ where: { id: mediaId } });
    if (media.isMain) {
      const next = await this.prisma.productMedia.findFirst({ where: { productModelId: media.productModelId, kind: 'PHOTO' }, orderBy: { sortOrder: 'asc' } });
      if (next) await this.prisma.productMedia.update({ where: { id: next.id }, data: { isMain: true } });
    }
    await this.events.publish('catalog.item.updated', { itemId: media.productModelId });
    return { deleted: true };
  }

  async reorderMedia(modelId: string, mediaIds: string[]) {
    await this.load(modelId);
    await this.prisma.$transaction(mediaIds.map((id, i) => this.prisma.productMedia.update({ where: { id, productModelId: modelId }, data: { sortOrder: i } })));
    await this.events.publish('catalog.item.updated', { itemId: modelId });
    return this.get(modelId);
  }

  // ---- internals --------------------------------------------------------------------------------------------------------------
  private async load(id: string): Promise<ModelWithMedia> {
    const m = await this.prisma.productModel.findUnique({ where: { id }, include: { media: { orderBy: { sortOrder: 'asc' } }, variants: { orderBy: { sortOrder: 'asc' }, include: { color: true } } } });
    if (!m) throw notFound('Item');
    return m;
  }
  private mediaRef(m: ProductMedia) {
    return { id: m.id, kind: m.kind, isMain: m.isMain, caption: m.caption, variantId: m.variantId, file: m.kind === 'VIDEO' ? { id: m.fileId, url: this.files.signedUrl(m.fileId, 'original') } : this.files.ref(m.fileId) };
  }
  private workerCard(m: ModelWithMedia) {
    const main = m.media.find((x) => x.isMain) ?? m.media.find((x) => x.kind === 'PHOTO');
    return { id: m.id, name: m.name, isNew: m.isNew, availability: m.availability, coverPhoto: main ? this.files.ref(main.fileId) : null, colors: m.variants.map((v) => ({ id: v.colorId, name: (v as ProductVariant & { color?: { name: string; hex: string | null } }).color?.name })) };
  }
  private workerDetail(m: ModelWithMedia) {
    return {
      id: m.id, name: m.name, description: m.description, isNew: m.isNew, availability: m.availability,
      media: m.media.map((x) => this.mediaRef(x)),
      variants: m.variants.map((v) => ({ id: v.id, label: v.label, color: (v as ProductVariant & { color?: { id: string; name: string; hex: string | null } }).color })),
    };
  }
  private staffDto(m: ModelWithMedia) {
    return {
      id: m.id, code: m.code, name: m.name, description: m.description, status: m.status, availability: m.availability,
      isNew: m.isNew, sortOrder: m.sortOrder, publishedAt: m.publishedAt?.toISOString() ?? null,
      media: m.media.map((x) => this.mediaRef(x)),
      variants: m.variants.map((v) => ({ id: v.id, label: v.label, active: v.active, sortOrder: v.sortOrder, color: (v as ProductVariant & { color?: { id: string; name: string; hex: string | null } }).color })),
    };
  }
}

@ApiTags('catalog')
@ApiBearerAuth()
@Controller()
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  // WORKER: "Наши работы" — no price, no draft
  @Roles('WORKER') @Get('catalog')
  published() { return this.catalog.published(); }

  @Roles('WORKER') @Get('catalog/:id')
  publishedDetail(@Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.publishedDetail(id); }

  // staff management
  @Perm('CATALOG_VIEW', 'CATALOG_MANAGE') @Get('admin/catalog')
  list(@ZodQuery(listCatalogSchema) q: z.output<typeof listCatalogSchema>) { return this.catalog.list(q); }

  @Perm('CATALOG_VIEW', 'CATALOG_MANAGE') @Get('admin/catalog/:id')
  get(@Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.get(id); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog') @ApiZodBody(createCatalogItemSchema)
  create(@CurrentUser() u: AuthUser, @ZodBody(createCatalogItemSchema) b: z.output<typeof createCatalogItemSchema>) { return this.catalog.create(u, b); }

  @Perm('CATALOG_MANAGE') @Patch('admin/catalog/:id') @ApiZodBody(updateCatalogItemSchema)
  update(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateCatalogItemSchema) b: z.output<typeof updateCatalogItemSchema>) { return this.catalog.update(id, b); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/:id/publish') @HttpCode(200)
  publish(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.setStatus(u, id, 'PUBLISHED'); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/:id/hide') @HttpCode(200)
  hide(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.setStatus(u, id, 'HIDDEN'); }

  @Perm('CATALOG_MANAGE') @Delete('admin/catalog/:id') @HttpCode(200)
  remove(@Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.remove(id); }

  @Perm('CATALOG_MANAGE') @Put('admin/catalog/order') @ApiZodBody(reorderSchema)
  reorder(@ZodBody(reorderSchema) b: z.output<typeof reorderSchema>) { return this.catalog.reorder(b.ids); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/:id/variants') @ApiZodBody(createVariantSchema)
  addVariant(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(createVariantSchema) b: z.output<typeof createVariantSchema>) { return this.catalog.addVariant(id, b); }

  @Perm('CATALOG_MANAGE') @Patch('admin/catalog/variants/:id') @ApiZodBody(updateVariantSchema)
  updateVariant(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(updateVariantSchema) b: z.output<typeof updateVariantSchema>) { return this.catalog.updateVariant(id, b); }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/:id/media') @HttpCode(201) @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' }, kind: { type: 'string' }, caption: { type: 'string' } } } })
  @UseInterceptors(FileInterceptor('file'))
  addMedia(
    @CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string,
    @ZodBody(addMediaSchema) b: z.output<typeof addMediaSchema>, @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw fileRejected('Attach the file as multipart field "file"');
    return this.catalog.addMedia(u, id, b, { buffer: file.buffer, originalName: file.originalname });
  }

  @Perm('CATALOG_MANAGE') @Post('admin/catalog/media/:id/main') @HttpCode(200)
  setMain(@Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.setMainMedia(id); }

  @Perm('CATALOG_MANAGE') @Delete('admin/catalog/media/:id') @HttpCode(200)
  removeMedia(@Param('id', new ParseUUIDPipe()) id: string) { return this.catalog.removeMedia(id); }

  @Perm('CATALOG_MANAGE') @Put('admin/catalog/:id/media/order') @ApiZodBody(reorderSchema)
  reorderMedia(@Param('id', new ParseUUIDPipe()) id: string, @ZodBody(reorderSchema) b: z.output<typeof reorderSchema>) { return this.catalog.reorderMedia(id, b.ids); }
}

@Module({ controllers: [CatalogController], providers: [CatalogService], exports: [CatalogService] })
export class CatalogModule {}
