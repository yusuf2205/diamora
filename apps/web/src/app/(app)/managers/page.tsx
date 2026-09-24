'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { formatUzs, initials } from '@/lib/format';
import type { ManagerSummary, Page } from '@/lib/types';
import { Badge, DataList, EmptyState, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';

/** Per-manager numbers (§33): each manager's own group, computed server-side from their assigned workers only. */
export default function ManagersPage() {
  const { data, error, isLoading, refetch } = useQuery<Page<ManagerSummary>>({ queryKey: ['managers'], queryFn: () => api.get<Page<ManagerSummary>>('/managers') });

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Менеджеры" subtitle="Сколько мастериц у каждого менеджера и как идут дела в его группе." />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton rows={3} />}
      {data && data.items.length === 0 && <EmptyState title="Менеджеров пока нет" hint="Добавьте менеджера в разделе «Команда»" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(m) => m.id}
          href={(m) => `/team/${m.id}`}
          columns={[
            { header: 'Менеджер', cell: (m) => <span className="font-medium">{m.fullName}<span className="block text-xs font-normal text-muted">{m.phone}</span></span> },
            { header: 'В сети', cell: (m) => (m.online ? <Badge tone="ok">в сети</Badge> : <span className="text-muted">—</span>) },
            { header: 'Мастериц', cell: (m) => m.stats.workers, className: 'text-right tabular-nums' },
            { header: 'Активных', cell: (m) => m.stats.activeWorkers, className: 'text-right tabular-nums' },
            { header: 'Заданий', cell: (m) => m.stats.activeAssignments, className: 'text-right tabular-nums' },
            { header: 'Начислено', cell: (m) => formatUzs(m.stats.earned), className: 'text-right whitespace-nowrap tabular-nums' },
            { header: 'К выплате', cell: (m) => formatUzs(m.stats.due), className: 'text-right whitespace-nowrap tabular-nums' },
          ]}
          card={(m) => (
            <div className="space-y-3">
              <div className="flex items-center gap-3">
                <span className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
                  {initials(m.fullName)}
                  <span className={`absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-card ${m.online ? 'bg-ok' : 'bg-border'}`} />
                </span>
                <div className="min-w-0">
                  <p className="font-medium leading-snug">{m.fullName}</p>
                  <p className="text-sm text-muted">{m.phone}</p>
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2 text-center">
                {([['Мастериц', m.stats.workers], ['Заданий', m.stats.activeAssignments], ['К выплате', formatUzs(m.stats.due)]] as const).map(([k, v]) => (
                  <div key={k} className="rounded-lg bg-border/30 px-2 py-1.5">
                    <p className="text-[11px] text-muted">{k}</p>
                    <p className="text-sm font-semibold tabular-nums">{v}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        />
      )}
    </div>
  );
}
