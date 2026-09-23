'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatUzs, statusLabel } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { AssignmentSummary, Page, Worker, WorkerLedger } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Badge, Button, Card, ErrorState, StatCard } from '@/components/ui';
import { PayoutDialog } from '../../assignments/[id]/page';

/** Мастерица: profile, earnings/payout, and her assignments — the same numbers the worker sees on her own phone (§13). */
export default function WorkerDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { me } = useAuth();
  const [payingOut, setPayingOut] = useState(false);
  const worker = useQuery<Worker>({ queryKey: ['worker', id], queryFn: () => api.get<Worker>(`/workers/${id}`) });
  const ledger = useQuery<WorkerLedger>({ queryKey: ['ledger', id], queryFn: () => api.get<WorkerLedger>(`/admin/workers/${id}/ledger`), enabled: hasPerm(me, 'FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED') });
  const assignments = useQuery<Page<AssignmentSummary>>({ queryKey: ['assignments', 'worker', id], queryFn: () => api.get<Page<AssignmentSummary>>('/admin/assignments', { workerId: id, limit: 50 }) });

  if (worker.isLoading) return <p className="text-muted">Загрузка…</p>;
  if (worker.error || !worker.data) return <ErrorState error={worker.error} />;
  const w = worker.data;

  return (
    <div className="max-w-3xl space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{w.fullName} <span className="text-muted">· {w.code}</span></h1>
          <p className="text-sm text-muted">{w.phone} · <Badge tone={w.status === 'ACTIVE' ? 'ok' : 'default'}>{statusLabel(w.status)}</Badge></p>
        </div>
        {ledger.data && hasPerm(me, 'CASH_PAYOUT') && <Button onClick={() => setPayingOut(true)}>Выплатить наличными</Button>}
      </div>

      {ledger.data && (
        <div className="grid grid-cols-3 gap-4">
          <StatCard label="К получению" value={formatUzs(ledger.data.balance)} />
          <StatCard label="Заработано" value={formatUzs(ledger.data.earned)} />
          <StatCard label="Выплачено" value={formatUzs(ledger.data.paid)} />
        </div>
      )}

      {ledger.data && ledger.data.history.length > 0 && (
        <Card>
          <h2 className="mb-3 text-sm font-medium text-muted">История</h2>
          <div className="space-y-2 text-sm">
            {ledger.data.history.map((e) => (
              <div key={e.id} className="flex items-center justify-between border-b border-border pb-2 last:border-0">
                <span>{e.type === 'PAYOUT_CASH' ? 'Выплатить наличными' : 'Начисление'}</span>
                <span className="text-muted">{e.createdAt.slice(0, 10)}</span>
                <span className={`font-medium ${e.amount.startsWith('-') ? 'text-danger' : 'text-ok'}`}>{e.amount.startsWith('-') ? '' : '+'}{formatUzs(e.amount)}</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      <Card>
        <h2 className="mb-3 text-sm font-medium text-muted">Задания</h2>
        {assignments.data && assignments.data.items.length === 0 && <p className="text-muted">Заданий пока нет.</p>}
        <div className="space-y-2 text-sm">
          {assignments.data?.items.map((a) => (
            <Link key={a.id} href={`/assignments/${a.id}`} className="flex items-center justify-between rounded-lg border border-border px-3 py-2 hover:bg-border/20">
              <span>{a.product?.name ?? '—'} · {a.color?.name ?? '—'} · {a.plannedMeters} м</span>
              <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge>
            </Link>
          ))}
        </div>
      </Card>

      {payingOut && <PayoutDialog workerId={w.id} onClose={() => setPayingOut(false)} />}
    </div>
  );
}
