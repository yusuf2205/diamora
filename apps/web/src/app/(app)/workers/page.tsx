'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs, statusLabel } from '@/lib/format';
import type { Page, Worker } from '@/lib/types';
import { Badge, EmptyState, ErrorState, Input, Select, Table, Td, Th } from '@/components/ui';

const STATUS_TONE: Record<Worker['status'], 'default' | 'ok' | 'danger' | 'warn'> = {
  PENDING_APPROVAL: 'warn', ACTIVE: 'ok', PAUSED: 'default', REJECTED: 'danger', ARCHIVED: 'default',
};

/** Mirrors the Flutter ADMIN workers list — same API, same server-side scope (a MANAGER sees only her own, D-028). */
export default function WorkersPage() {
  const params = useSearchParams();
  const [status, setStatus] = useState(() => params.get('status') ?? '');
  const [q, setQ] = useState('');
  const { data, error, isLoading, refetch } = useQuery<Page<Worker>>({
    queryKey: ['workers', status, q],
    queryFn: () => api.get<Page<Worker>>('/workers', { status: status || undefined, q: q || undefined, limit: 100 }),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Мастерицы</h1>
          <p className="text-sm text-muted">Заявки, статус, залог, менеджер.</p>
        </div>
      </div>
      <div className="flex gap-3">
        <Input placeholder="Поиск: имя, телефон" value={q} onChange={(e) => setQ(e.target.value)} className="max-w-xs" />
        <Select value={status} onChange={(e) => setStatus(e.target.value)} className="max-w-xs">
          <option value="">Все статусы</option>
          <option value="PENDING_APPROVAL">На рассмотрении</option>
          <option value="ACTIVE">Активна</option>
          <option value="PAUSED">На паузе</option>
          <option value="REJECTED">Отклонена</option>
          <option value="ARCHIVED">В архиве</option>
        </Select>
      </div>
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Здесь пока никого нет" />}
      {data && data.items.length > 0 && (
        <Table>
          <thead>
            <tr>
              <Th>Мастерица</Th>
              <Th>Телефон</Th>
              <Th>Статус</Th>
              <Th>Менеджер</Th>
              <Th>Залог</Th>
              <Th>К получению</Th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((w) => (
              <tr key={w.id} className="cursor-pointer hover:bg-border/20">
                <Td className="font-medium"><Link href={`/workers/${w.id}`} className="block">{w.fullName} <span className="text-muted">· {w.code}</span></Link></Td>
                <Td><Link href={`/workers/${w.id}`} className="block">{w.phone}</Link></Td>
                <Td><Link href={`/workers/${w.id}`} className="block"><Badge tone={STATUS_TONE[w.status]}>{statusLabel(w.status)}</Badge></Link></Td>
                <Td><Link href={`/workers/${w.id}`} className="block">{w.manager?.fullName ?? '—'}</Link></Td>
                <Td><Link href={`/workers/${w.id}`} className="block">{w.collateral ? (w.collateral.type === 'MONEY' ? formatUzs(w.collateral.amount) : w.collateral.description) : '—'}</Link></Td>
                <Td><Link href={`/workers/${w.id}`} className="block">{formatUzs(w.balance)}</Link></Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </div>
  );
}
