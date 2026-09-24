'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatUzs, statusLabel } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { AssignmentSummary, Page, Worker, WorkerLedger } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Badge, Button, Card, ErrorState, Input, Modal, StatCard } from '@/components/ui';
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

      {w.status === 'PENDING_APPROVAL' && hasPerm(me, 'WORKER_APPROVE') && <ApprovalCard worker={w} />}
      {w.status === 'REJECTED' && w.rejectedReason && <Card><p className="text-sm text-muted">Причина отказа: {w.rejectedReason}</p></Card>}

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

/** Same decision the mobile ADMIN app offers (§ registration): approve (optionally confirming the collateral was
 * physically received) or reject with a reason she will read in Telegram. The server creates her account on approve. */
function ApprovalCard({ worker: w }: { worker: Worker }) {
  const qc = useQueryClient();
  const [mode, setMode] = useState<'approve' | 'reject' | null>(null);
  const [collateralReceived, setCollateralReceived] = useState(false);
  const [reason, setReason] = useState('');
  const done = () => { qc.invalidateQueries({ queryKey: ['worker', w.id] }); qc.invalidateQueries({ queryKey: ['workers'] }); setMode(null); };

  const approve = useMutation({
    mutationFn: () => api.post(`/workers/${w.id}/approve`, { collateralReceived }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: done,
  });
  const reject = useMutation({
    mutationFn: () => api.post(`/workers/${w.id}/reject`, { reason: reason.trim() }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: done,
  });
  const c = w.collateral;

  return (
    <Card>
      <h2 className="text-sm font-medium">Заявка на рассмотрении</h2>
      <p className="mt-1 text-sm text-muted">
        {c ? `Залог: ${c.type === 'MONEY' ? `${formatUzs(c.amount)} сум` : (c.description ?? 'вещь')}` : 'Залог не указан'}
      </p>
      <div className="mt-4 flex gap-2">
        <Button onClick={() => setMode('approve')}>Одобрить</Button>
        <Button variant="outline" onClick={() => setMode('reject')}>Отклонить</Button>
      </div>

      {mode === 'approve' && (
        <Modal title="Одобрить мастерицу?" onClose={() => setMode(null)}>
          <div className="space-y-3">
            <p className="text-sm">{w.fullName} получит сообщение в Telegram и сможет войти в приложение.</p>
            {c && (
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={collateralReceived} onChange={(e) => setCollateralReceived(e.target.checked)} />
                Залог получен
              </label>
            )}
            {approve.isError && <ErrorState error={approve.error} />}
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setMode(null)}>Отмена</Button>
              <Button onClick={() => approve.mutate()} disabled={approve.isPending}>Одобрить</Button>
            </div>
          </div>
        </Modal>
      )}

      {mode === 'reject' && (
        <Modal title="Отклонить заявку?" onClose={() => setMode(null)}>
          <div className="space-y-3">
            <Input placeholder="Причина (её увидит мастерица)" value={reason} onChange={(e) => setReason(e.target.value)} />
            {reject.isError && <ErrorState error={reject.error} />}
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setMode(null)}>Отмена</Button>
              <Button onClick={() => reject.mutate()} disabled={reason.trim().length < 3 || reject.isPending}>Отклонить</Button>
            </div>
          </div>
        </Modal>
      )}
    </Card>
  );
}
