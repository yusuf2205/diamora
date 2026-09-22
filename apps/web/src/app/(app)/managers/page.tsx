'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import type { ManagerSummary, Page } from '@/lib/types';
import { Badge, EmptyState, ErrorState, Table, Td, Th } from '@/components/ui';

/** Per-manager numbers (§33): each manager's own group, computed server-side from their assigned workers only. */
export default function ManagersPage() {
  const { data, error, isLoading } = useQuery<Page<ManagerSummary>>({ queryKey: ['managers'], queryFn: () => api.get<Page<ManagerSummary>>('/managers') });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Менеджеры</h1>
        <p className="text-sm text-muted">Сколько мастериц у каждого менеджера и как идут дела в его группе.</p>
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Менеджеров пока нет" />}
      {data && data.items.length > 0 && (
        <Table>
          <thead>
            <tr>
              <Th>Менеджер</Th><Th>Онлайн</Th><Th>Мастериц</Th><Th>Активных</Th><Th>В работе</Th><Th>Начислено</Th><Th>К выплате</Th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((m) => (
              <tr key={m.id}>
                <Td className="font-medium">{m.fullName}<span className="block text-xs text-muted">{m.phone}</span></Td>
                <Td>{m.online ? <Badge tone="ok">в сети</Badge> : <span className="text-muted">—</span>}</Td>
                <Td>{m.stats.workers}</Td>
                <Td>{m.stats.activeWorkers}</Td>
                <Td>{m.stats.activeAssignments}</Td>
                <Td>{formatUzs(m.stats.earned)}</Td>
                <Td>{formatUzs(m.stats.due)}</Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </div>
  );
}
