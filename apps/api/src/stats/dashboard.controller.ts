import { Controller, Get, Injectable, Module } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Prisma } from '@yusmus/database';
import { scopeFor, type WorkerCategory } from '@yusmus/shared';
import { CurrentUser, Perm } from '../common/decorators';
import type { AuthUser } from '../common/request-context';
import { PrismaService } from '../prisma/prisma.module';
import { PresenceModule, PresenceService } from '../presence/presence.service';
import { StockModule, StockService } from '../stock/stock.service';
import { StatsModule, StatsService } from './stats.service';

/** The WorkerProfile filter for a category, or `null` when the viewer may not see this kind of data at all (§28). */
function scopedWhere(actor: AuthUser, cat: WorkerCategory): Prisma.WorkerProfileWhereInput | null {
  const s = scopeFor(actor.permissions, cat);
  if (s === 'none') return null;
  return s === 'all' ? {} : { assignedManagerId: actor.id };
}

/**
 * Home-screen numbers (§31, Web Dashboard). Built only from tables that exist today (D-023: build only what the
 * milestone needs): workers, assignments, ledger, catalog, users, stock. Sales/expenses/net profit are M6 and are
 * reported as `null` here rather than fabricated - the web UI shows "—" for them, honestly.
 *
 * Every section is independently gated by the viewer's OWN permissions and, for MANAGER, scoped to their own workers
 * (same `scopeFor` rule as everywhere else, D-028) - a section the viewer may not see is simply absent from the
 * response (`null`), never a fabricated zero and never a 403 for the whole endpoint just because one section is out
 * of reach.
 */
@Injectable()
class DashboardService {
  constructor(
    private readonly prisma: PrismaService, private readonly presence: PresenceService, private readonly stats: StatsService,
    private readonly stock: StockService,
  ) {}

  async get(actor: AuthUser) {
    const workerWhere = scopedWhere(actor, 'WORKER');
    const canFinance = scopeFor(actor.permissions, 'FINANCE') !== 'none';
    const canAssignments = scopeFor(actor.permissions, 'ASSIGNMENT') !== 'none';
    const canUsers = actor.permissions.includes('USER_VIEW_ALL');
    const canCatalog = actor.permissions.includes('CATALOG_VIEW');
    const canInventory = actor.permissions.includes('INVENTORY_VIEW');

    const [global, today, catalogPublished, catalogDraft, userRoles, lowStock] = await Promise.all([
      workerWhere ? this.stats.forWorkers(workerWhere) : null,
      workerWhere ? this.stats.today(workerWhere) : null,
      canCatalog ? this.prisma.productModel.count({ where: { status: 'PUBLISHED' } }) : null,
      canCatalog ? this.prisma.productModel.count({ where: { status: 'DRAFT' } }) : null,
      canUsers ? this.prisma.user.groupBy({ by: ['role'], where: { status: 'ACTIVE' }, _count: true }) : null,
      canInventory ? this.stock.balances(true) : null,
    ]);
    const byRole = userRoles ? Object.fromEntries(userRoles.map((u) => [u.role, u._count])) : null;

    return {
      workers: global && workerWhere
        ? { total: global.workers, active: global.activeWorkers, withActiveAssignment: global.workersWithActiveAssignment, withoutActiveAssignment: global.workersWithoutActiveAssignment }
        : null,
      users: byRole ? { superAdmins: byRole.SUPER_ADMIN ?? 0, admins: byRole.ADMIN ?? 0, managers: byRole.MANAGER ?? 0, online: this.presence.onlineIds().length } : null,
      catalog: canCatalog ? { published: catalogPublished!, draft: catalogDraft! } : null,
      work: global && canAssignments
        ? {
            activeAssignments: global.activeAssignments, inProgress: global.inProgress, metersOnHand: global.metersOnHand,
            toDeliver: global.toDeliver, toPickup: global.toPickup, needsAcceptance: global.needsAcceptance, completed: global.completed, overdue: global.overdue,
            reworkRequired: global.reworkRequired,
          }
        : null,
      finance: global && canFinance
        ? { earned: global.earned, paid: global.paid, due: global.due, workersDue: global.workersDue, salesRevenue: null, expenses: null, netProfit: null }
        : null,
      today: today && (canAssignments || canFinance)
        ? {
            dueToday: canAssignments ? today.dueToday : null, deliveredToday: canAssignments ? today.deliveredToday : null,
            pickedUpToday: canAssignments ? today.pickedUpToday : null, paidToday: canFinance ? today.paidToday : null,
          }
        : null,
      materials: lowStock ? { lowStock: lowStock.items.length, outOfStock: lowStock.items.filter((i) => i.quantity <= 0).length } : null,
    };
  }
}

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Perm('WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED', 'FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'PROFIT_VIEW') @Get()
  get(@CurrentUser() u: AuthUser) { return this.dashboard.get(u); }
}

@Module({ imports: [PresenceModule, StatsModule, StockModule], controllers: [DashboardController], providers: [DashboardService] })
export class DashboardModule {}
