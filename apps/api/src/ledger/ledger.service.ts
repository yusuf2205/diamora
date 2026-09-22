import { Controller, Get, HttpCode, Injectable, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { WorkerLedgerTransaction } from '@yusmus/database';
import { cashPayoutSchema } from '@yusmus/shared';
import { z } from 'zod';
import { AuditService } from '../audit/audit.service';
import { ApiZodBody, CurrentUser, Perm, Roles } from '../common/decorators';
import { forbidden, invariant, notFound } from '../common/errors';
import type { AuthUser } from '../common/request-context';
import { assertWorkerInScope } from '../common/scope';
import { lockRow, type Tx } from '../common/sequence';
import { money } from '../common/serialize';
import { ZodBody } from '../common/zod.pipe';
import { EventBus } from '../events/event-bus';
import { PayRateModule, PayRateService } from '../settings/pay-rate.service';
import { PrismaService } from '../prisma/prisma.module';

/**
 * M3 §14-16: earnings and cash payouts. `WorkerProfile.balance` is a materialised "к получению" total, kept in the SAME
 * transaction as every ledger write under a row lock — the exact same pattern as `StockBalance` (belt: row lock +
 * transactional update; suspenders: none needed here, balance may legitimately go negative only via `forced` payout,
 * which is explicit and audited, never silent). `WorkerLedgerTransaction` is append-only (DB trigger); a correction is a
 * new row, never an edit. Earnings are settled at the rate in force AT ACCEPTANCE TIME (D-027) and never recalculated
 * afterward, even if ADMIN changes the global rate the next day.
 */
@Injectable()
export class LedgerService {
  constructor(
    private readonly prisma: PrismaService, private readonly payRate: PayRateService, private readonly audit: AuditService, private readonly events: EventBus,
  ) {}

  /** Called from inside WorkAssignment acceptance (assignments.service.ts): one EARNING row at the CURRENT global rate. */
  async earnFor(tx: Tx, workerId: string, assignmentId: string, acceptedCm: number): Promise<{ amount: bigint; ratePerKit: bigint }> {
    const { amount, ratePerKit } = await this.payRate.earning(tx, acceptedCm);
    if (amount > 0n) await this.applyEntry(tx, workerId, 'EARNING', amount, { assignmentId, comment: 'Оплата за принятую работу' });
    return { amount, ratePerKit };
  }

  async summary(actor: AuthUser, workerId: string) {
    const w = await this.prisma.workerProfile.findUnique({ where: { id: workerId } });
    if (!w) throw notFound('Worker');
    assertWorkerInScope(actor, 'FINANCE', w);
    return this.summaryFor(workerId);
  }

  /** A worker reading her OWN earnings (§13): self-only, no staff scope check — same trust pattern as `work/current`. */
  async summaryForWorker(workerId: string) {
    return this.summaryFor(workerId);
  }

  private async summaryFor(workerId: string) {
    const w = await this.prisma.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
    const [earnedAgg, paidAgg, history] = await Promise.all([
      this.prisma.workerLedgerTransaction.aggregate({ where: { workerId, type: 'EARNING' }, _sum: { amount: true } }),
      this.prisma.workerLedgerTransaction.aggregate({ where: { workerId, type: 'PAYOUT_CASH' }, _sum: { amount: true } }),
      this.prisma.workerLedgerTransaction.findMany({ where: { workerId }, orderBy: { createdAt: 'desc' }, take: 50 }),
    ]);
    return {
      workerId, balance: money(w.balance)!, earned: money(earnedAgg._sum.amount ?? 0n)!, paid: money(-(paidAgg._sum.amount ?? 0n))!,
      history: history.map((h) => this.dto(h)),
    };
  }

  async payout(actor: AuthUser, workerId: string, input: z.output<typeof cashPayoutSchema>) {
    const w = await this.prisma.workerProfile.findUnique({ where: { id: workerId } });
    if (!w) throw notFound('Worker');
    assertWorkerInScope(actor, 'FINANCE', w);
    if (input.amount <= 0n) throw invariant('Amount must be positive');

    const result = await this.prisma.$transaction(async (tx) => {
      if (!(await lockRow(tx, 'worker_profiles', workerId))) throw notFound('Worker');
      const fresh = await tx.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
      if (!input.forced && input.amount > fresh.balance) {
        throw invariant(`Payout exceeds balance: ${fresh.balance} owed, ${input.amount} requested (use forced:true to override)`);
      }
      const payment = await tx.cashPayment.create({ data: { workerId, amount: input.amount, comment: input.comment, forced: input.forced ?? false, paidById: actor.id } });
      const balanceAfter = await this.applyEntry(tx, workerId, 'PAYOUT_CASH', -input.amount, { cashPaymentId: payment.id, comment: input.comment });
      await this.audit.record({
        action: 'cash_payment.create', entity: 'CashPayment', entityId: payment.id,
        after: { workerId, amount: input.amount.toString(), forced: input.forced ?? false, balanceAfter: balanceAfter.toString() },
      }, tx);
      return { payment, balanceAfter };
    });

    await this.events.publish('cash_payment.created', { workerId, paymentId: result.payment.id, amount: money(input.amount)!, managerId: w.assignedManagerId });
    const after = await this.summary(actor, workerId);
    await this.events.publish('worker.balance_updated', { workerId, balance: after.balance, earned: after.earned, paid: after.paid, managerId: w.assignedManagerId });
    return after;
  }

  /** The ONE place a WorkerLedgerTransaction is ever written: locks WorkerProfile, applies the signed amount, records `balanceAfter`. */
  private async applyEntry(tx: Tx, workerId: string, type: 'EARNING' | 'PAYOUT_CASH', signedAmount: bigint, extra: { assignmentId?: string; cashPaymentId?: string; comment?: string }) {
    if (!(await lockRow(tx, 'worker_profiles', workerId))) throw notFound('Worker');
    const w = await tx.workerProfile.findUniqueOrThrow({ where: { id: workerId } });
    const balanceAfter = w.balance + signedAmount;
    await tx.workerLedgerTransaction.create({
      data: { workerId, type, amount: signedAmount, balanceAfter, assignmentId: extra.assignmentId, cashPaymentId: extra.cashPaymentId, comment: extra.comment, createdById: workerId },
    });
    await tx.workerProfile.update({ where: { id: workerId }, data: { balance: balanceAfter } });
    return balanceAfter;
  }

  private dto(h: WorkerLedgerTransaction) {
    return { id: h.id, type: h.type, amount: money(h.amount)!, balanceAfter: money(h.balanceAfter)!, comment: h.comment, createdAt: h.createdAt.toISOString() };
  }
}

@ApiTags('ledger')
@ApiBearerAuth()
@Controller()
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Perm('FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED') @Get('admin/workers/:id/ledger')
  summary(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string) { return this.ledger.summary(u, id); }

  @Perm('CASH_PAYOUT') @Post('admin/workers/:id/payout') @HttpCode(200) @ApiZodBody(cashPayoutSchema)
  payout(@CurrentUser() u: AuthUser, @Param('id', new ParseUUIDPipe()) id: string, @ZodBody(cashPayoutSchema) b: z.output<typeof cashPayoutSchema>) {
    return this.ledger.payout(u, id, b);
  }

  /** M3 §13: a worker's own "К получению / Заработано / Выплачено" — self-only, scoped by the JWT's workerId. */
  @Roles('WORKER') @Get('work/earnings')
  myEarnings(@CurrentUser() u: AuthUser) {
    if (!u.workerId) throw forbidden();
    return this.ledger.summaryForWorker(u.workerId);
  }
}

@Module({ imports: [PayRateModule], controllers: [LedgerController], providers: [LedgerService], exports: [LedgerService] })
export class LedgerModule {}
