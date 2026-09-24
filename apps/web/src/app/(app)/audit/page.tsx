'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { formatDate, roleLabel } from '@/lib/format';
import { AUDIT_ENTITY_LABELS, AUDIT_LABELS } from '@/lib/permissions';
import type { AuditEntry, Page } from '@/lib/types';
import { DataList, EmptyState, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';

const action = (e: AuditEntry) => AUDIT_LABELS[e.action] ?? e.action;
const entity = (e: AuditEntry) => AUDIT_ENTITY_LABELS[e.entity] ?? e.entity;
const who = (e: AuditEntry) => (e.actorRole ? roleLabel(e.actorRole) : 'Система');

/** AUDIT_VIEW (§35): append-only, enforced by the database itself — nothing here can be edited or deleted. */
export default function AuditPage() {
  const { data, error, isLoading, refetch } = useQuery<Page<AuditEntry>>({ queryKey: ['audit'], queryFn: () => api.get<Page<AuditEntry>>('/audit', { limit: 100 }) });

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Журнал действий" subtitle="Кто и что изменил: роли, права, залог, склад, выплаты, настройки." />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton rows={8} />}
      {data && data.items.length === 0 && <EmptyState title="Записей пока нет" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(e) => e.id}
          columns={[
            { header: 'Когда', cell: (e) => <span className="whitespace-nowrap text-muted">{formatDate(e.createdAt)}</span> },
            { header: 'Действие', cell: (e) => <span className="font-medium" title={e.action}>{action(e)}</span> },
            { header: 'Объект', cell: entity },
            { header: 'Кто', cell: who },
          ]}
          card={(e) => (
            <div>
              <p className="font-medium leading-snug" title={e.action}>{action(e)}</p>
              <p className="mt-0.5 text-sm text-muted">{entity(e)} · {who(e)}</p>
              <p className="mt-0.5 text-xs text-muted">{formatDate(e.createdAt)}</p>
            </div>
          )}
        />
      )}
    </div>
  );
}
