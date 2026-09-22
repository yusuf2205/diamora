import { Controller, Get, Injectable, Module } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Perm } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.module';
import { PresenceModule, PresenceService } from '../presence/presence.service';
import { StockModule, StockService } from '../stock/stock.service';
import { StatsModule, StatsService } from './stats.service';

/**
 * Home-screen numbers for SUPER_ADMIN / ADMIN (§31, Web Dashboard). Built only from tables that exist today
 * (D-023: build only what the milestone needs): workers, assignments, ledger, catalog, users. Sales/expenses/net profit
 * are M6 and are reported as `null` here rather than fabricated - the web UI shows "—" for them, honestly.
 */
@Injectable()
class DashboardService {
  constructor(
    private readonly prisma: PrismaService, private readonly presence: PresenceService, private readonly stats: StatsService,
    private readonly stock: StockService,
  ) {}

  async get() {
    const [workers, catalogPublished, catalogDraft, users, lowStock] = await Promise.all([
      this.prisma.workerProfile.groupBy({ by: ['status'], _count: true }),
      this.prisma.productModel.count({ where: { status: 'PUBLISHED' } }),
      this.prisma.productModel.count({ where: { status: 'DRAFT' } }),
      this.prisma.user.groupBy({ by: ['role'], where: { status: 'ACTIVE' }, _count: true }),
      this.stock.balances(true), // real "below minStock" count, now that Materials/Stock exist (M2)
    ]);
    const stockLow = lowStock.items.length;
    const byStatus = Object.fromEntries(workers.map((w) => [w.status, w._count]));
    const byRole = Object.fromEntries(users.map((u) => [u.role, u._count]));
    const global = await this.stats.forWorkers({});
    return {
      workers: { total: workers.reduce((s, w) => s + w._count, 0), active: byStatus.ACTIVE ?? 0, pendingApproval: byStatus.PENDING_APPROVAL ?? 0, paused: byStatus.PAUSED ?? 0 },
      users: { superAdmins: byRole.SUPER_ADMIN ?? 0, admins: byRole.ADMIN ?? 0, managers: byRole.MANAGER ?? 0, online: this.presence.onlineIds().length },
      catalog: { published: catalogPublished, draft: catalogDraft },
      work: { activeAssignments: global.activeAssignments, metersOnHand: global.metersOnHand, toDeliver: global.toDeliver, toPickup: global.toPickup, overdue: global.overdue },
      finance: { earned: global.earned, paid: global.paid, due: global.due, salesRevenue: null, expenses: null, netProfit: null },
      inventory: { lowStockMaterials: stockLow },
    };
  }
}

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Perm('WORKER_VIEW_ALL', 'FINANCE_VIEW_ALL', 'PROFIT_VIEW') @Get()
  get() { return this.dashboard.get(); }
}

@Module({ imports: [PresenceModule, StatsModule, StockModule], controllers: [DashboardController], providers: [DashboardService] })
export class DashboardModule {}
