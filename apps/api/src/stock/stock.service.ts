import { Controller, Get, Injectable, Module, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Material, StockMovement, StockMovementType } from '@yusmus/database';
import { listStockMovementsSchema, stockAdjustSchema, stockReceiptSchema, stockWriteOffSchema } from '@yusmus/shared';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm } from '../common/decorators';
import { insufficientStock, notFound } from '../common/errors';
import { lockMaterialBalance, type Tx } from '../common/sequence';
import { num } from '../common/serialize';
import { ZodBody, ZodQuery } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PrismaService } from '../prisma/prisma.module';
import type { AuthUser } from '../common/request-context';

export interface MovementInput {
  type: StockMovementType;
  materialId: string;
  quantity: string; // positive magnitude
  warehouseDelta: string; // signed
  workerDelta?: string;
  workerId?: string | null;
  assignmentId?: string | null;
  comment?: string | null;
  groupId?: string;
}

/**
 * Stock is a ledger, not a mutable counter (M2 §6-7): every change is an immutable `StockMovement` row (DB trigger, see
 * `db-guards.spec.ts`); `StockBalance` is only a materialised cache of Σ warehouseDelta, kept in the SAME transaction under
 * a row lock so two concurrent movements on the same material can never both pass the "stock ≥ 0" check (belt) — the
 * `stock_balances_quantity_nonneg` CHECK in PostgreSQL is the suspenders. A wrong entry is fixed with a compensating
 * movement (ADJUSTMENT_IN/OUT), never an edit.
 */
@Injectable()
export class StockService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  async balances(lowOnly = false) {
    const rows = await this.prisma.material.findMany({
      where: { isActive: true }, include: { category: true, balance: true }, orderBy: { name: 'asc' },
    });
    const items = rows.map((m) => {
      const qty = num(m.balance?.quantity) ?? 0;
      const min = num(m.minStock) ?? 0;
      return { materialId: m.id, name: m.name, unit: m.unit, category: m.category?.name ?? null, quantity: qty, minStock: min, low: qty < min };
    });
    return { items: lowOnly ? items.filter((i) => i.low) : items };
  }

  async movements(q: z.output<typeof listStockMovementsSchema>) {
    const rows = await this.prisma.stockMovement.findMany({
      where: { materialId: q.materialId, type: q.type },
      include: { material: { select: { name: true, unit: true } } },
      orderBy: { createdAt: 'desc' }, take: q.limit + 1, ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, q.limit);
    return { items: items.map((m) => this.dto(m)), nextCursor: rows.length > q.limit ? items[items.length - 1].id : null };
  }

  async receipt(actor: AuthUser, input: z.output<typeof stockReceiptSchema>) {
    const movement = await this.prisma.$transaction((tx) =>
      this.recordMovement(tx, actor, { type: 'RECEIPT', materialId: input.materialId, quantity: input.quantity, warehouseDelta: input.quantity, comment: input.comment }),
    );
    await this.publish(movement);
    return this.dtoOf(movement.id);
  }

  async adjust(actor: AuthUser, input: z.output<typeof stockAdjustSchema>) {
    const signed = input.direction === 'IN' ? input.quantity : `-${input.quantity}`;
    const movement = await this.prisma.$transaction((tx) =>
      this.recordMovement(tx, actor, {
        type: input.direction === 'IN' ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT', materialId: input.materialId,
        quantity: input.quantity, warehouseDelta: signed, comment: input.reason,
      }),
    );
    await this.publish(movement);
    return this.dtoOf(movement.id);
  }

  async writeOff(actor: AuthUser, input: z.output<typeof stockWriteOffSchema>) {
    const movement = await this.prisma.$transaction((tx) =>
      this.recordMovement(tx, actor, { type: 'WRITE_OFF', materialId: input.materialId, quantity: input.quantity, warehouseDelta: `-${input.quantity}`, comment: input.reason }),
    );
    await this.publish(movement);
    return this.dtoOf(movement.id);
  }

  /**
   * The one place a StockMovement is ever written. Runs INSIDE the caller's transaction (a kit assembly writes several
   * movements — one per material — under a single groupId, atomically). Row-locks the balance first so two concurrent
   * calls for the same material serialise instead of racing past the non-negative check.
   */
  async recordMovement(tx: Tx, actor: AuthUser, input: MovementInput): Promise<StockMovement> {
    if (!(await lockMaterialBalance(tx, input.materialId))) throw notFound('Material');
    const balance = await tx.stockBalance.findUniqueOrThrow({ where: { materialId: input.materialId } });
    const next = balance.quantity.plus(input.warehouseDelta);
    if (next.isNegative()) throw insufficientStock(`Not enough stock: ${balance.quantity.toString()} available, ${input.warehouseDelta} requested`, { materialId: input.materialId, available: balance.quantity.toString() });
    const movement = await tx.stockMovement.create({
      data: {
        groupId: input.groupId ?? randomUUID(), type: input.type, materialId: input.materialId, quantity: input.quantity,
        warehouseDelta: input.warehouseDelta, workerDelta: input.workerDelta ?? '0', workerId: input.workerId ?? null,
        assignmentId: input.assignmentId ?? null, performedById: actor.id, comment: input.comment ?? null,
      },
    });
    await tx.stockBalance.update({ where: { materialId: input.materialId }, data: { quantity: next } });
    await this.audit.record({ action: 'stock.movement', entity: 'Material', entityId: input.materialId, after: { type: input.type, quantity: input.quantity, warehouseDelta: input.warehouseDelta } }, tx);
    return movement;
  }

  /** Public so other modules (kit assembly) can raise the same two realtime events for movements they wrote via `recordMovement`. */
  async publish(movement: StockMovement) {
    await this.events.publish('stock.movement.created', { movementId: movement.id, materialId: movement.materialId, type: movement.type });
    const balance = await this.prisma.stockBalance.findUnique({ where: { materialId: movement.materialId } });
    const material = await this.prisma.material.findUnique({ where: { id: movement.materialId }, select: { minStock: true } });
    if (balance && material) {
      const qty = num(balance.quantity) ?? 0;
      await this.events.publish('stock.updated', { materialId: movement.materialId, quantity: balance.quantity.toString(), low: qty < (num(material.minStock) ?? 0) });
    }
  }

  private async dtoOf(id: string) {
    const m = await this.prisma.stockMovement.findUniqueOrThrow({ where: { id }, include: { material: { select: { name: true, unit: true } } } });
    return this.dto(m);
  }
  private dto(m: StockMovement & { material: Pick<Material, 'name' | 'unit'> }) {
    return {
      id: m.id, groupId: m.groupId, type: m.type, materialId: m.materialId, materialName: m.material.name, unit: m.material.unit,
      quantity: num(m.quantity), warehouseDelta: num(m.warehouseDelta), workerId: m.workerId, comment: m.comment, createdAt: m.createdAt.toISOString(),
    };
  }
}

@ApiTags('stock')
@ApiBearerAuth()
@Controller('admin/stock')
export class StockController {
  constructor(private readonly stock: StockService) {}

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('balances')
  balances() { return this.stock.balances(); }

  @Perm('INVENTORY_VIEW', 'INVENTORY_MANAGE') @Get('movements')
  movements(@ZodQuery(listStockMovementsSchema) q: z.output<typeof listStockMovementsSchema>) { return this.stock.movements(q); }

  @Perm('INVENTORY_MANAGE') @Post('receipt') @ApiZodBody(stockReceiptSchema)
  receipt(@CurrentUser() u: AuthUser, @ZodBody(stockReceiptSchema) b: z.output<typeof stockReceiptSchema>) { return this.stock.receipt(u, b); }

  @Perm('INVENTORY_MANAGE') @Post('adjust') @ApiZodBody(stockAdjustSchema)
  adjust(@CurrentUser() u: AuthUser, @ZodBody(stockAdjustSchema) b: z.output<typeof stockAdjustSchema>) { return this.stock.adjust(u, b); }

  @Perm('INVENTORY_MANAGE') @Post('write-off') @ApiZodBody(stockWriteOffSchema)
  writeOff(@CurrentUser() u: AuthUser, @ZodBody(stockWriteOffSchema) b: z.output<typeof stockWriteOffSchema>) { return this.stock.writeOff(u, b); }
}

@Module({ controllers: [StockController], providers: [StockService], exports: [StockService] })
export class StockModule {}
