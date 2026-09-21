import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';

const DAY = 86_400_000;

/** Integrity self-checks (must always be clean) and housekeeping. Runs inside the worker container. */
@Injectable()
export class MaintenanceService {
  private readonly log = new Logger('Maintenance');
  constructor(private readonly prisma: PrismaService) {}

  /** Money ledger and stock balances must equal the sum of their immutable rows. Any hit is a critical incident. */
  async integrity(): Promise<{ ledgerMismatches: number; stockMismatches: number }> {
    const ledger = await this.prisma.$queryRaw<{ workerId: string }[]>`SELECT "workerId" FROM ledger_balance_mismatches LIMIT 50`;
    const stock = await this.prisma.$queryRaw<{ materialId: string }[]>`SELECT "materialId" FROM stock_balance_mismatches LIMIT 50`;
    if (ledger.length) this.log.error(`LEDGER MISMATCH for workers: ${ledger.map((r) => r.workerId).join(', ')}`);
    if (stock.length) this.log.error(`STOCK MISMATCH for materials: ${stock.map((r) => r.materialId).join(', ')}`);
    return { ledgerMismatches: ledger.length, stockMismatches: stock.length };
  }

  async cleanup(now = new Date()) {
    const t = now.getTime();
    const ago = (days: number) => new Date(t - days * DAY);
    const r = {
      idempotencyKeys: (await this.prisma.idempotencyKey.deleteMany({ where: { createdAt: { lt: ago(2) } } })).count,
      loginAttempts: (await this.prisma.loginAttempt.deleteMany({ where: { createdAt: { lt: ago(30) } } })).count,
      loginCodes: (await this.prisma.loginCode.deleteMany({ where: { expiresAt: { lt: ago(1) } } })).count,
      sessions: (await this.prisma.userSession.deleteMany({ where: { OR: [{ expiresAt: { lt: ago(30) } }, { revokedAt: { lt: ago(60) } }] } })).count,
      drafts: (await this.prisma.registrationDraft.deleteMany({ where: { updatedAt: { lt: ago(30) } } })).count,
      sentNotifications: (await this.prisma.notification.deleteMany({ where: { status: 'SENT', sentAt: { lt: ago(90) } } })).count,
    };
    this.log.log(`cleanup: ${JSON.stringify(r)}`);
    return r;
  }
}
