'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { Card, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';

interface Month { month: string; earned: string; bonus: string; paid: string; sales?: string; materials?: string; expenses?: string; profit?: string }
interface Money {
  owed: { total: string; workers: number; top: { id: string; fullName: string; code: string; balance: string }[] };
  thisMonth: Month; lastMonth: Month; profitVisible: boolean;
}
const MONTHS = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

/** «Деньги» (owner, 2026-10-11): owed to workers, this month and the last - earned, paid, sales, materials, expenses, profit. */
export default function MoneyPage() {
  const q = useQuery<Money>({ queryKey: ['money'], queryFn: () => api.get<Money>('/admin/money') });
  const d = q.data;
  const Row = ({ label, v, strong }: { label: string; v?: string; strong?: boolean }) => (
    <div className="flex justify-between py-1 text-sm">
      <span className={strong ? 'font-semibold' : 'text-muted'}>{label}</span>
      <span className={`tabular-nums ${strong ? (Number(v) < 0 ? 'font-bold text-danger' : 'font-bold text-ok') : 'font-medium'}`}>{formatUzs(v ?? '0')}</span>
    </div>
  );
  const MonthCard = ({ m }: { m: Month }) => (
    <Card>
      <h2 className="mb-1 font-semibold">{MONTHS[Number(m.month.slice(5)) - 1]} {m.month.slice(0, 4)}</h2>
      <Row label="Начислено за работу" v={m.earned} />
      {Number(m.bonus) > 0 && <Row label="Бонус за качество" v={m.bonus} />}
      <Row label="Выплачено" v={m.paid} />
      {d?.profitVisible && (
        <div className="mt-2 border-t border-border pt-2">
          <Row label="Продажи" v={m.sales} />
          <Row label="Материалы" v={m.materials} />
          <Row label="Расходы" v={m.expenses} />
          <Row label="Прибыль" v={m.profit} strong />
        </div>
      )}
    </Card>
  );
  return (
    <div className="max-w-3xl space-y-4">
      <PageHeader title="Деньги" subtitle="Долг мастерицам и деньги за этот и прошлый месяц на одном экране." />
      {q.error && <ErrorState error={q.error} onRetry={() => q.refetch()} />}
      {q.isLoading && <ListSkeleton />}
      {d && (
        <>
          <Card>
            <p className="text-sm text-muted">Должны мастерицам · {d.owed.workers}</p>
            <p className="text-3xl font-semibold">{formatUzs(d.owed.total)}</p>
            <div className="mt-2 divide-y divide-border">
              {d.owed.top.map((w) => (
                <Link key={w.id} href={`/workers/${w.id}`} className="flex justify-between py-1.5 text-sm hover:text-primary">
                  <span>{w.fullName}</span><span className="tabular-nums">{formatUzs(w.balance)}</span>
                </Link>
              ))}
            </div>
          </Card>
          <div className="grid gap-4 sm:grid-cols-2"><MonthCard m={d.thisMonth} /><MonthCard m={d.lastMonth} /></div>
        </>
      )}
    </div>
  );
}
