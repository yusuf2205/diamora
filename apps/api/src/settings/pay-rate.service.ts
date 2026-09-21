import { Controller, Get, HttpCode, Injectable, Module, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { PayRateChange } from '@yusmus/database';
import { KIT_METERS, changePayRateSchema, earningFor } from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import type { Tx } from '../common/sequence';
import { money } from '../common/serialize';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/events.module';
import { PrismaService } from '../prisma/prisma.module';

/**
 * The ONE global price of a 9 m kit (D-024, D-027). ADMIN changes it at any moment; the change applies to everyone at once:
 * work that is not yet accepted is paid at the current rate, accepted work keeps the amount in the immutable ledger.
 * Every change is a new append-only row (who, when, from/to) + an audit entry + a realtime broadcast to all screens.
 */
@Injectable()
export class PayRateService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService, private readonly events: EventBus) {}

  /** The current rate. Pass the transaction client when it must be read consistently with other writes (acceptance, M5). */
  async current(db: PrismaService | Tx = this.prisma): Promise<PayRateChange> {
    const row = await db.payRateChange.findFirst({ orderBy: { seq: 'desc' } });
    if (!row) throw new Error('pay rate is not configured (the seed row of migration 20260921190000_global_pay_rate is missing)');
    return row;
  }

  /** Amount for `acceptedCm` centimetres of accepted work at the CURRENT rate (used inside the acceptance transaction, M5). */
  async earning(db: PrismaService | Tx, acceptedCm: number): Promise<{ amount: bigint; ratePerKit: bigint }> {
    const { ratePerKit } = await this.current(db);
    return { amount: earningFor(ratePerKit, acceptedCm), ratePerKit };
  }

  async change(actor: AuthUser, input: z.output<typeof changePayRateSchema>) {
    const { row, changed } = await this.prisma.$transaction(async (tx) => {
      // Serialises concurrent changes, so the history is always one straight chain (previous = the row before it).
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('yusmus:pay_rate'))`;
      const before = await this.current(tx);
      if (before.ratePerKit === input.ratePerKit) return { row: before, changed: false };
      const created = await tx.payRateChange.create({
        data: { ratePerKit: input.ratePerKit, previousRatePerKit: before.ratePerKit, changedById: actor.id, note: input.note },
      });
      await this.audit.record(
        { action: 'pay_rate.change', entity: 'PayRate', entityId: created.id, before: { ratePerKit: before.ratePerKit }, after: { ratePerKit: created.ratePerKit, note: input.note } },
        tx,
      );
      return { row: created, changed: true };
    });
    if (changed) {
      await this.events.publish('pay_rate.changed', {
        ratePerKit: row.ratePerKit.toString(), previousRatePerKit: money(row.previousRatePerKit), changedAt: row.createdAt.toISOString(),
      });
    }
    return { ...this.dto(row), changed };
  }

  async history(limit = 50) {
    const rows = await this.prisma.payRateChange.findMany({ orderBy: { seq: 'desc' }, take: limit });
    const ids = [...new Set(rows.map((r) => r.changedById).filter((x): x is string => !!x))];
    const users = ids.length ? await this.prisma.user.findMany({ where: { id: { in: ids } }, select: { id: true, fullName: true } }) : [];
    const names = new Map(users.map((u) => [u.id, u.fullName]));
    return {
      items: rows.map((r) => ({
        id: r.id, ratePerKit: money(r.ratePerKit)!, previousRatePerKit: money(r.previousRatePerKit),
        changedBy: r.changedById ? (names.get(r.changedById) ?? null) : null, note: r.note, createdAt: r.createdAt.toISOString(),
      })),
    };
  }

  dto(r: PayRateChange) {
    return { ratePerKit: r.ratePerKit.toString(), kitMeters: KIT_METERS, updatedAt: r.createdAt.toISOString() };
  }
}

@ApiTags('settings')
@ApiBearerAuth()
@Controller('settings/pay-rate')
export class PayRateController {
  constructor(private readonly rates: PayRateService) {}

  /** ADMIN and WORKER read the same current price (workers see what a 9 m kit pays). */
  @Roles('ADMIN', 'WORKER') @Get()
  async get() { return this.rates.dto(await this.rates.current()); }

  @Roles('ADMIN') @Put() @HttpCode(200) @ApiZodBody(changePayRateSchema)
  change(@CurrentUser() u: AuthUser, @ZodBody(changePayRateSchema) b: z.output<typeof changePayRateSchema>) { return this.rates.change(u, b); }

  @Roles('ADMIN') @Get('history')
  history() { return this.rates.history(); }
}

@Module({ controllers: [PayRateController], providers: [PayRateService], exports: [PayRateService] })
export class PayRateModule {}
