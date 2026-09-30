import type { PrismaService } from '../prisma/prisma.module';

const OPEN = ['READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'REWORK_REQUIRED'] as const;
const DAY = 86_400_000;

export interface WorkerSuggestion {
  workerId: string;
  fullName: string;
  code: string;
  score: number;
  openWorks: number;
  openMeters: number;
  /** average days for 9 m over the last 90 days (issue -> ready); null = no finished work yet */
  daysPer9m: number | null;
  defectRate: number;
  onTimeRate: number | null;
  sameProduct: number;
  reasons: string[];
}

/**
 * «Кому дать работу»: who is free, fast, clean and on time (last 90 days), and who already made this item. One simple
 * score, and the reasons in words so staff see WHY (never a black box). Only workers the caller may see (`workerIds`).
 */
export async function suggestWorkers(prisma: PrismaService, workerIds: string[], productModelId?: string, now = new Date()): Promise<WorkerSuggestion[]> {
  if (!workerIds.length) return [];
  const since = new Date(now.getTime() - 90 * DAY);
  const [workers, open, finished, quality, same] = await Promise.all([
    prisma.workerProfile.findMany({ where: { id: { in: workerIds }, status: 'ACTIVE', deletedAt: null }, select: { id: true, fullName: true, code: true } }),
    prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: workerIds }, status: { in: [...OPEN] } }, _count: { _all: true }, _sum: { plannedMeters: true } }),
    // how long a work took: from the day she got it (issuedAt / created) to «готово к забору»; and whether it was late
    prisma.$queryRaw<{ workerId: string; days: number; meters: string; late: boolean | null }[]>`
      SELECT a."workerId", EXTRACT(EPOCH FROM (r.ready_at - COALESCE(a."issuedAt", a."createdAt"))) / 86400 AS days, a."plannedMeters"::text AS meters,
             CASE WHEN a."dueAt" IS NULL THEN NULL ELSE r.ready_at > a."dueAt" END AS late
      FROM work_assignments a
      JOIN LATERAL (SELECT MIN(h."changedAt") AS ready_at FROM work_assignment_status_history h
                    WHERE h."assignmentId" = a.id AND h."toStatus" = 'READY_FOR_PICKUP') r ON r.ready_at IS NOT NULL
      WHERE a."workerId" = ANY(${workerIds}::uuid[]) AND r.ready_at >= ${since}`,
    prisma.$queryRaw<{ workerId: string; accepted: string; defective: string }[]>`
      SELECT a."workerId", COALESCE(SUM(q."acceptedMeters"), 0)::text AS accepted, COALESCE(SUM(q."defectiveMeters"), 0)::text AS defective
      FROM quality_inspections q JOIN work_assignments a ON a.id = q."assignmentId"
      WHERE q."inspectedAt" >= ${since} AND a."workerId" = ANY(${workerIds}::uuid[])
      GROUP BY a."workerId"`,
    productModelId
      ? prisma.workAssignment.groupBy({ by: ['workerId'], where: { workerId: { in: workerIds }, productModelId, status: { in: ['ACCEPTED', 'PARTIALLY_ACCEPTED', 'COMPLETED'] } }, _count: { _all: true } })
      : Promise.resolve([] as { workerId: string; _count: { _all: number } }[]),
  ]);
  const openBy = new Map(open.map((o) => [o.workerId, o]));
  const qBy = new Map(quality.map((q) => [q.workerId, q]));
  const sameBy = new Map(same.map((s) => [s.workerId, s._count._all]));
  const speed = new Map<string, { days: number; meters: number; late: number; withDue: number }>();
  for (const f of finished) {
    const s = speed.get(f.workerId) ?? { days: 0, meters: 0, late: 0, withDue: 0 };
    s.days += Math.max(0, Number(f.days)); s.meters += Number(f.meters);
    if (f.late !== null) { s.withDue++; if (f.late) s.late++; }
    speed.set(f.workerId, s);
  }

  return workers.map((w) => {
    const o = openBy.get(w.id);
    const openWorks = o?._count._all ?? 0;
    const openMeters = Number(o?._sum.plannedMeters ?? 0);
    const sp = speed.get(w.id);
    const daysPer9m = sp && sp.meters > 0 ? Math.round((sp.days / sp.meters) * 9 * 10) / 10 : null;
    const acc = Number(qBy.get(w.id)?.accepted ?? 0), def = Number(qBy.get(w.id)?.defective ?? 0);
    const defectRate = acc + def > 0 ? def / (acc + def) : 0;
    const onTimeRate = sp && sp.withDue > 0 ? 1 - sp.late / sp.withDue : null;
    const sameProduct = sameBy.get(w.id) ?? 0;

    // 0-100: being free matters most; then speed, quality, deadlines; a little for knowing this item
    const free = openWorks === 0 ? 1 : openWorks === 1 ? 0.45 : 0.1;
    const fast = daysPer9m === null ? 0.5 : Math.max(0, Math.min(1, (10 - daysPer9m) / 8)); // 2 days per 9 m = top, 10+ = 0
    const clean = acc + def > 0 ? 1 - Math.min(1, defectRate * 4) : 0.6; // 25 % defects = 0
    const onTime = onTimeRate ?? 0.7;
    const knows = Math.min(1, sameProduct / 3);
    const score = Math.round(100 * (0.35 * free + 0.25 * fast + 0.2 * clean + 0.15 * onTime + 0.05 * knows));

    const reasons: string[] = [];
    reasons.push(openWorks === 0 ? 'свободна' : `в работе: ${openWorks} (${Math.round(openMeters)} м)`);
    if (daysPer9m !== null) reasons.push(`9 м за ≈ ${daysPer9m} дн.`);
    else reasons.push('ещё нет сданных работ');
    if (acc + def > 0) reasons.push(def === 0 ? 'без брака' : `брак ${Math.round(defectRate * 100)}%`);
    if (onTimeRate !== null) reasons.push(onTimeRate === 1 ? 'всё вовремя' : `вовремя ${Math.round(onTimeRate * 100)}%`);
    if (sameProduct > 0) reasons.push(`делала это изделие: ${sameProduct}`);
    return { workerId: w.id, fullName: w.fullName, code: w.code, score, openWorks, openMeters, daysPer9m, defectRate: Math.round(defectRate * 1000) / 10, onTimeRate: onTimeRate === null ? null : Math.round(onTimeRate * 100), sameProduct, reasons };
  }).sort((a, b) => b.score - a.score || a.fullName.localeCompare(b.fullName));
}
