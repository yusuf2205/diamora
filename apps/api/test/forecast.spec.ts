import { materialUsage } from '../src/stock/forecast';

/** «Хватит примерно на N дней»: the pace of the last 30 days, minus what workers brought back. */
describe('stock forecast', () => {
  const now = new Date('2026-10-01T10:00:00Z');
  const daysAgo = (d: number) => new Date(now.getTime() - d * 86_400_000);
  // a stand-in for prisma.stockMovement.groupBy: answers by what the query asks for
  const fake = (out: Record<string, number>, back: Record<string, number>, first: Record<string, Date>) => ({
    stockMovement: {
      groupBy: async (args: { where: { type?: unknown } }) => {
        const t = args.where.type;
        if (t === 'RETURN_FROM_WORKER') return Object.entries(back).map(([materialId, v]) => ({ materialId, _sum: { warehouseDelta: v } }));
        if (t) return Object.entries(out).map(([materialId, v]) => ({ materialId, _sum: { warehouseDelta: -v } }));
        return Object.entries(first).map(([materialId, d]) => ({ materialId, _min: { createdAt: d } }));
      },
    },
  }) as never;

  it('300 m issued in 30 days (minus 30 m returned) = 9 m a day; 45 m left lasts 5 days', async () => {
    const u = await materialUsage(fake({ a: 300 }, { a: 30 }, { a: daysAgo(90) }), new Map([['a', 45]]), now);
    expect(u.get('a')).toEqual({ dailyUse: 9, daysLeft: 5 });
  });

  it('not used lately: no forecast (never «закончится через 0 дней» for a quiet material)', async () => {
    const u = await materialUsage(fake({}, {}, { b: daysAgo(90) }), new Map([['b', 10]]), now);
    expect(u.get('b')).toEqual({ dailyUse: 0, daysLeft: null });
  });

  it('a material bought 2 days ago is averaged over at least 7 days (one big kit is not «a huge daily use»)', async () => {
    const u = await materialUsage(fake({ c: 70 }, {}, { c: daysAgo(2) }), new Map([['c', 100]]), now);
    expect(u.get('c')).toEqual({ dailyUse: 10, daysLeft: 10 });
  });
});
