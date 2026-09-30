import type { PrismaClient } from '@diamoraa/database';

/** What leaves the warehouse for work (a write-off or a correction is not «usage»). */
const OUT = ['ISSUE_TO_KIT', 'ISSUE_TO_WORKER', 'CONSUMPTION'] as const;
const WINDOW_DAYS = 30;
/** a material bought a few days ago: a very short history would make one big kit look like a huge daily use */
const MIN_WINDOW_DAYS = 7;
/** warn this many days before a material runs out */
export const RUNOUT_WARN_DAYS = 7;

export interface Usage { dailyUse: number; daysLeft: number | null }

/**
 * «Хватит примерно на N дней»: average use per day over the last 30 days (issued to kits / workers, minus what workers
 * brought back), and how long the current balance lasts at that pace. null days = not used lately (nothing to forecast).
 */
export async function materialUsage(prisma: Pick<PrismaClient, 'stockMovement'>, balances: Map<string, number>, now = new Date()): Promise<Map<string, Usage>> {
  const since = new Date(now.getTime() - WINDOW_DAYS * 86_400_000);
  const ids = [...balances.keys()];
  if (!ids.length) return new Map();
  const [out, back, first] = await Promise.all([
    prisma.stockMovement.groupBy({ by: ['materialId'], where: { materialId: { in: ids }, createdAt: { gte: since }, type: { in: [...OUT] } }, _sum: { warehouseDelta: true } }),
    prisma.stockMovement.groupBy({ by: ['materialId'], where: { materialId: { in: ids }, createdAt: { gte: since }, type: 'RETURN_FROM_WORKER' }, _sum: { warehouseDelta: true } }),
    prisma.stockMovement.groupBy({ by: ['materialId'], where: { materialId: { in: ids } }, _min: { createdAt: true } }),
  ]);
  const outBy = new Map(out.map((r) => [r.materialId, -Number(r._sum.warehouseDelta ?? 0)]));
  const backBy = new Map(back.map((r) => [r.materialId, Number(r._sum.warehouseDelta ?? 0)]));
  const firstBy = new Map(first.map((r) => [r.materialId, r._min.createdAt]));
  const res = new Map<string, Usage>();
  for (const id of ids) {
    const used = Math.max(0, (outBy.get(id) ?? 0) - (backBy.get(id) ?? 0));
    const firstAt = firstBy.get(id);
    const days = firstAt ? Math.min(WINDOW_DAYS, Math.max(MIN_WINDOW_DAYS, (now.getTime() - firstAt.getTime()) / 86_400_000)) : WINDOW_DAYS;
    const dailyUse = used / days;
    const qty = balances.get(id) ?? 0;
    res.set(id, { dailyUse: Math.round(dailyUse * 1000) / 1000, daysLeft: dailyUse > 0 ? Math.floor(qty / dailyUse) : null });
  }
  return res;
}
