'use client';

import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs, statusLabel } from '@/lib/format';
import type { Page, Worker } from '@/lib/types';
import { Badge, Chips, DataList, EmptyState, ErrorState, Input, ListSkeleton, PageHeader } from '@/components/ui';

const STATUS_TONE: Record<Worker['status'], 'default' | 'ok' | 'danger' | 'warn'> = {
  PENDING_APPROVAL: 'warn', ACTIVE: 'ok', PAUSED: 'default', REJECTED: 'danger', ARCHIVED: 'default',
};
const FILTERS = [
  { value: '', label: 'Все' },
  { value: 'PENDING_APPROVAL', label: 'Заявки' },
  { value: 'ACTIVE', label: 'Активные' },
  { value: 'PAUSED', label: 'На паузе' },
  { value: 'ARCHIVED', label: 'Архив' },
  { value: 'REJECTED', label: 'Отклонённые' },
] as const;

const collateral = (w: Worker) => (w.collateral ? (w.collateral.type === 'MONEY' ? formatUzs(w.collateral.amount) : w.collateral.description) : '—');

/** Mirrors the Flutter ADMIN workers list — same API, same server-side scope (a MANAGER sees only her own, D-028). */
export default function WorkersPage() {
  const params = useSearchParams();
  const [status, setStatus] = useState<string>(() => params.get('status') ?? '');
  const [search, setSearch] = useState('');
  const [q, setQ] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setQ(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);
  const { data, error, isLoading, refetch } = useQuery<Page<Worker>>({
    queryKey: ['workers', status, q],
    queryFn: () => api.get<Page<Worker>>('/workers', { status: status || undefined, q: q || undefined, limit: 100 }),
  });

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Мастерицы" subtitle="Заявки, статус, менеджер и сколько кому выплатить." />
      <div className="space-y-3">
        <Input type="search" placeholder="Поиск: имя, телефон, код" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Поиск" className="md:max-w-sm" />
        <Chips options={FILTERS} value={status as (typeof FILTERS)[number]['value']} onChange={setStatus} label="Статус" />
      </div>
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Никого не найдено" hint={q ? 'Попробуйте другое имя или номер' : 'Мастерицы появятся здесь после регистрации в Telegram'} />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(w) => w.id}
          href={(w) => `/workers/${w.id}`}
          columns={[
            { header: 'Мастерица', cell: (w) => <span className="font-medium">{w.fullName} <span className="font-normal text-muted">· {w.code}</span></span> },
            { header: 'Телефон', cell: (w) => <span className="whitespace-nowrap">{w.phone}</span> },
            { header: 'Статус', cell: (w) => <Badge tone={STATUS_TONE[w.status]}>{statusLabel(w.status)}</Badge> },
            { header: 'Менеджер', cell: (w) => w.manager?.fullName ?? <span className="text-muted">—</span> },
            { header: 'Залог', cell: collateral },
            { header: 'К получению', cell: (w) => <span className="whitespace-nowrap font-medium tabular-nums">{formatUzs(w.balance)}</span>, className: 'text-right' },
          ]}
          card={(w) => (
            <div className="space-y-1.5">
              <div className="flex items-start justify-between gap-3">
                <p className="min-w-0 font-medium leading-snug">{w.fullName}</p>
                <Badge tone={STATUS_TONE[w.status]}>{statusLabel(w.status)}</Badge>
              </div>
              <p className="text-sm text-muted">{w.code} · {w.phone}</p>
              <div className="flex items-center justify-between gap-3 text-sm">
                <span className="min-w-0 truncate text-muted">{w.manager ? `Менеджер: ${w.manager.fullName}` : 'Без менеджера'}</span>
                {w.balance !== '0' && <span className="shrink-0 font-semibold tabular-nums text-primary">{formatUzs(w.balance)}</span>}
              </div>
            </div>
          )}
        />
      )}
    </div>
  );
}
