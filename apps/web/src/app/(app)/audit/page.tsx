'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { formatDate } from '@/lib/format';
import type { AuditEntry, Page } from '@/lib/types';
import { EmptyState, ErrorState, Table, Td, Th } from '@/components/ui';

/** AUDIT_VIEW (§35): append-only, enforced by the database itself — nothing here can be edited or deleted. */
export default function AuditPage() {
  const { data, error, isLoading } = useQuery<Page<AuditEntry>>({ queryKey: ['audit'], queryFn: () => api.get<Page<AuditEntry>>('/audit', { limit: 100 }) });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Журнал действий</h1>
        <p className="text-sm text-muted">Все важные изменения: роли, права, залог, склад, выплаты, настройки, ставка.</p>
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Записей пока нет" />}
      {data && data.items.length > 0 && (
        <Table>
          <thead>
            <tr><Th>Когда</Th><Th>Действие</Th><Th>Объект</Th><Th>Роль</Th></tr>
          </thead>
          <tbody>
            {data.items.map((e) => (
              <tr key={e.id}>
                <Td className="whitespace-nowrap text-muted">{formatDate(e.createdAt)}</Td>
                <Td className="font-medium">{e.action}</Td>
                <Td>{e.entity}{e.entityId ? ` #${e.entityId.slice(0, 8)}` : ''}</Td>
                <Td>{e.actorRole ?? '—'}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </div>
  );
}
