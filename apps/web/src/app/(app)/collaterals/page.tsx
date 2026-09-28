'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate, formatUzs } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { Badge, Button, Card, Chips, DataList, EmptyState, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';
import { COLLATERAL_STATUS, collateralWhat, ReceiveCollateralDialog, ReturnCollateralDialog, type CollateralRow } from '@/components/collateral-actions';

const FILTERS = [
  { value: 'HELD', label: 'У нас' },
  { value: 'PENDING', label: 'Ещё не получены' },
  { value: 'RETURNED', label: 'Возвращены' },
] as const;

interface CollateralPage { items: CollateralRow[]; nextCursor: string | null; held: { moneyTotal: string; moneyCount: number; itemCount: number } }

/** «Залоги»: who gave what, what is in our hands right now, and «Вернуть» when she leaves. */
export default function CollateralsPage() {
  const { me } = useAuth();
  const canManage = hasPerm(me, 'COLLATERAL_MANAGE');
  const [status, setStatus] = useState<(typeof FILTERS)[number]['value']>('HELD');
  const [receiving, setReceiving] = useState<CollateralRow | null>(null);
  const [returning, setReturning] = useState<CollateralRow | null>(null);
  const { data, error, isLoading, refetch } = useQuery<CollateralPage>({
    queryKey: ['collaterals', status],
    queryFn: () => api.get<CollateralPage>('/collaterals', { status, limit: 100 }),
  });

  if (!hasPerm(me, 'COLLATERAL_VIEW')) return <EmptyState title="Недостаточно прав для просмотра залогов" />;

  const action = (c: CollateralRow) =>
    !canManage ? null
      : c.status === 'PENDING' ? <Button variant="outline" onClick={(e) => { e.stopPropagation(); setReceiving(c); }}>Принять</Button>
        : c.status === 'HELD' ? <Button variant="outline" onClick={(e) => { e.stopPropagation(); setReturning(c); }}>Вернуть</Button>
          : null;

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Залоги" subtitle="Кто из мастериц что оставил в залог, что сейчас у нас и возврат." />
      {data && (
        <Card>
          <p className="text-sm text-muted">Сейчас у нас</p>
          <p className="mt-1 text-lg font-semibold">
            {formatUzs(data.held.moneyTotal)} сум <span className="text-sm font-normal text-muted">деньгами ({data.held.moneyCount})</span>
            {' · '}{data.held.itemCount} <span className="text-sm font-normal text-muted">вещей</span>
          </p>
        </Card>
      )}
      <Chips options={FILTERS} value={status} onChange={setStatus} label="Залоги" />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Здесь пусто" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(c) => c.id}
          columns={[
            { header: 'Мастерица', cell: (c) => <Link href={`/workers/${c.worker.id}`} className="font-medium hover:underline">{c.worker.fullName} <span className="text-muted">· {c.worker.code}</span></Link> },
            { header: 'Что оставила', cell: (c) => collateralWhat(c) },
            { header: 'Где хранится', cell: (c) => c.storageLocation ?? <span className="text-muted">—</span> },
            { header: 'Когда', cell: (c) => <span className="whitespace-nowrap text-muted">{formatDate(c.returnedAt ?? c.receivedAt ?? c.declaredAt)}</span> },
            { header: '', cell: (c) => action(c) ?? <Badge tone={COLLATERAL_STATUS[c.status].tone}>{COLLATERAL_STATUS[c.status].label}</Badge> },
          ]}
          card={(c) => (
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <Link href={`/workers/${c.worker.id}`} className="block truncate font-medium">{c.worker.fullName}</Link>
                <p className="text-sm">{collateralWhat(c)}</p>
                <p className="text-xs text-muted">{c.storageLocation ? `${c.storageLocation} · ` : ''}{formatDate(c.returnedAt ?? c.receivedAt ?? c.declaredAt)}</p>
              </div>
              <div className="shrink-0">{action(c) ?? <Badge tone={COLLATERAL_STATUS[c.status].tone}>{COLLATERAL_STATUS[c.status].label}</Badge>}</div>
            </div>
          )}
        />
      )}
      {receiving && <ReceiveCollateralDialog c={receiving} onClose={() => setReceiving(null)} />}
      {returning && <ReturnCollateralDialog c={returning} onClose={() => setReturning(null)} />}
    </div>
  );
}
