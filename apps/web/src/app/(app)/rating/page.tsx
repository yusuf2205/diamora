'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useState } from 'react';
import { api } from '@/lib/api';
import { Chips, DataList, EmptyState, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';

interface RatingRow { worker: { id: string; code: string; fullName: string }; acceptedMeters: number; defectiveMeters: number; defectRate: number; works: number; late: number; withDeadline: number; score: number }

const PERIODS = [{ value: '1', label: 'Месяц' }, { value: '3', label: '3 месяца' }, { value: '6', label: 'Полгода' }] as const;
const tone = (score: number) => (score >= 75 ? 'text-ok' : score >= 50 ? 'text-primary' : 'text-danger');
const n = (v: number) => (Number.isInteger(v) ? String(v) : v.toFixed(1));

/** «Рейтинг мастериц»: who sews the most with the fewest defects and on time — helps decide who gets more work. */
export default function RatingPage() {
  const [months, setMonths] = useState<(typeof PERIODS)[number]['value']>('3');
  const { data, error, isLoading, refetch } = useQuery<{ items: RatingRow[] }>({
    queryKey: ['rating', months],
    queryFn: () => api.get<{ items: RatingRow[] }>('/admin/reports/rating', { months }),
  });
  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Рейтинг мастериц" subtitle="Балл из 100: сколько метров сдала, сколько брака, успевает ли к сроку. Лучшие — сверху." />
      <Chips options={PERIODS} value={months} onChange={setMonths} label="Период" />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Пока нет данных" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(r) => r.worker.id}
          href={(r) => `/workers/${r.worker.id}`}
          columns={[
            { header: '#', cell: (r) => <span className="text-muted">{data.items.indexOf(r) + 1}</span> },
            { header: 'Мастерица', cell: (r) => <span className="font-medium">{r.worker.fullName}</span> },
            { header: 'Балл', cell: (r) => <span className={`font-bold tabular-nums ${tone(r.score)}`}>{r.score}</span>, className: 'text-right' },
            { header: 'Сдала, м', cell: (r) => <span className="tabular-nums">{n(r.acceptedMeters)}</span>, className: 'text-right' },
            { header: 'Брак', cell: (r) => <span className={`tabular-nums ${r.defectRate > 10 ? 'text-danger' : ''}`}>{n(r.defectRate)}%</span>, className: 'text-right' },
            { header: 'Работ', cell: (r) => <span className="tabular-nums">{r.works}</span>, className: 'text-right' },
            { header: 'Опоздала', cell: (r) => <span className={`tabular-nums ${r.late ? 'text-danger' : ''}`}>{r.late} из {r.withDeadline}</span>, className: 'text-right' },
          ]}
          card={(r) => (
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate font-medium">{data.items.indexOf(r) + 1}. {r.worker.fullName}</p>
                <p className="text-xs text-muted">{n(r.acceptedMeters)} м · брак {n(r.defectRate)}% · опоздала {r.late} из {r.withDeadline}</p>
              </div>
              <span className={`shrink-0 text-2xl font-bold tabular-nums ${tone(r.score)}`}>{r.score}</span>
            </div>
          )}
        />
      )}
      <p className="text-xs text-muted">Балл: 40% — объём (≈54 м в месяц = максимум), 35% — без брака, 25% — вовремя. <Link className="text-primary hover:underline" href="/reports">Подробный отчёт</Link></p>
    </div>
  );
}
