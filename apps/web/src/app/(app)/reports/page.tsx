'use client';

import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { accessToken, api, apiOrigin } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { Button, Card, Chips, DataList, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';

type Period = 'day' | 'week' | 'month';
interface ReportRow { worker: { id: string; code: string; fullName: string }; issuedCount: number; issuedMeters: number; acceptedMeters: number; defectiveMeters: number; earned: string; paid: string; overdue: number }
interface Report {
  period: Period; offset: number; from: string; to: string;
  total: Omit<ReportRow, 'worker'>;
  rows: ReportRow[];
  lowStock: { materialId: string; name: string; unit: string; quantity: number; minStock: number }[] | null;
}

const PERIODS = [{ value: 'day', label: 'День' }, { value: 'week', label: 'Неделя' }, { value: 'month', label: 'Месяц' }] as const;
const day = (iso: string, minus = 0) => new Date(new Date(iso).getTime() + 5 * 3600_000 - minus).toISOString().slice(0, 10).split('-').reverse().join('.');
const m = (v: number) => (Number.isInteger(v) ? String(v) : v.toFixed(1));

/** «Отчёты»: issued / accepted / earned / paid per worker for a day, week or month, and «Скачать для Excel». */
export default function ReportsPage() {
  const params = useSearchParams();
  const [period, setPeriod] = useState<Period>(() => (params.get('period') as Period) || 'week');
  const [offset, setOffset] = useState(() => Number(params.get('offset') ?? 0) || 0);
  const [downloading, setDownloading] = useState(false);
  const { data, error, isLoading } = useQuery<Report>({ queryKey: ['report', period, offset], queryFn: () => api.get<Report>('/admin/reports', { period, offset }) });

  const download = async () => {
    setDownloading(true);
    try {
      const res = await fetch(`${apiOrigin()}/v1/admin/reports/export?period=${period}&offset=${offset}`, { headers: { Authorization: `Bearer ${accessToken() ?? ''}` } });
      const blob = await res.blob();
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `diamoraa-${period}-${data ? day(data.from) : 'report'}.csv`;
      a.click();
      URL.revokeObjectURL(a.href);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Отчёты" subtitle="Выпуск, начисления и выплаты по мастерицам" actions={<Button variant="outline" onClick={download} disabled={!data || downloading}>{downloading ? 'Готовим…' : 'Скачать для Excel'}</Button>} />
      <div className="flex flex-wrap items-center gap-3">
        <Chips options={PERIODS} value={period} onChange={(v) => { setPeriod(v as Period); setOffset(0); }} label="Период" />
        <div className="flex items-center gap-1">
          <Button variant="ghost" aria-label="Раньше" onClick={() => setOffset((o) => o - 1)}>‹</Button>
          <span className="min-w-36 text-center text-sm font-medium">{data ? (period === 'day' ? day(data.from) : `${day(data.from)} — ${day(data.to, 86_400_000)}`) : '…'}</span>
          <Button variant="ghost" aria-label="Позже" disabled={offset >= 0} onClick={() => setOffset((o) => o + 1)}>›</Button>
        </div>
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <ListSkeleton />}
      {data && (
        <>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
            <Card><p className="text-xs text-muted">Выдано</p><p className="text-lg font-bold">{data.total.issuedCount} · {m(data.total.issuedMeters)} м</p></Card>
            <Card><p className="text-xs text-muted">Принято</p><p className="text-lg font-bold">{m(data.total.acceptedMeters)} м</p></Card>
            <Card><p className="text-xs text-muted">Начислено</p><p className="text-lg font-bold">{formatUzs(data.total.earned)}</p></Card>
            <Card><p className="text-xs text-muted">Выплачено</p><p className="text-lg font-bold">{formatUzs(data.total.paid)}</p></Card>
            <Card><p className="text-xs text-muted">Просрочено</p><p className={`text-lg font-bold ${data.total.overdue ? 'text-danger' : ''}`}>{data.total.overdue}</p></Card>
          </div>
          {data.rows.length === 0 ? (
            <Card><p className="text-sm text-muted">За этот период ничего не было.</p></Card>
          ) : (
            <DataList
              rows={data.rows}
              rowKey={(r) => r.worker.id}
              href={(r) => `/workers/${r.worker.id}`}
              columns={[
                { header: 'Мастерица', cell: (r) => <span className="font-medium">{r.worker.fullName}</span> },
                { header: 'Выдано', cell: (r) => `${r.issuedCount} · ${m(r.issuedMeters)} м` },
                { header: 'Принято', cell: (r) => `${m(r.acceptedMeters)} м${r.defectiveMeters ? ` · брак ${m(r.defectiveMeters)}` : ''}` },
                { header: 'Начислено', cell: (r) => formatUzs(r.earned), className: 'text-right' },
                { header: 'Выплачено', cell: (r) => formatUzs(r.paid), className: 'text-right' },
                { header: 'Просрочено', cell: (r) => (r.overdue ? <span className="text-danger">{r.overdue}</span> : '—'), className: 'text-right' },
              ]}
              card={(r) => (
                <div className="space-y-1">
                  <p className="font-medium">{r.worker.fullName}</p>
                  <p className="text-sm">Принято {m(r.acceptedMeters)} м · выдано {m(r.issuedMeters)} м</p>
                  <p className="text-sm text-muted">Начислено {formatUzs(r.earned)} · выплачено {formatUzs(r.paid)}</p>
                </div>
              )}
            />
          )}
          {data.lowStock && data.lowStock.length > 0 && (
            <Card>
              <h2 className="mb-2 text-sm font-semibold">Заканчивается на складе</h2>
              <ul className="divide-y divide-border text-sm">
                {data.lowStock.map((s) => <li key={s.materialId} className="flex justify-between py-2"><span>{s.name}</span><span className="text-danger">{m(s.quantity)} / {m(s.minStock)}</span></li>)}
              </ul>
            </Card>
          )}
        </>
      )}
    </div>
  );
}
