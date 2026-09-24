'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatDate, formatDay, formatUzs, statusLabel } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { AssignmentSummary, ManagerSummary, Page, Worker, WorkerLedger } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Badge, Button, Card, ErrorState, Input, ListSkeleton, Modal, PageHeader } from '@/components/ui';
import { PayoutDialog } from '../../assignments/[id]/page';
import { CreateAssignmentDialog } from '../../assignments/page';

/** Мастерица: profile, earnings/payout, and her assignments — the same numbers the worker sees on her own phone (§13). */
export default function WorkerDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { me } = useAuth();
  const [payingOut, setPayingOut] = useState(false);
  const [assigning, setAssigning] = useState(false);
  const worker = useQuery<Worker>({ queryKey: ['worker', id], queryFn: () => api.get<Worker>(`/workers/${id}`) });
  const ledger = useQuery<WorkerLedger>({ queryKey: ['ledger', id], queryFn: () => api.get<WorkerLedger>(`/admin/workers/${id}/ledger`), enabled: hasPerm(me, 'FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED') });
  const assignments = useQuery<Page<AssignmentSummary>>({ queryKey: ['assignments', 'worker', id], queryFn: () => api.get<Page<AssignmentSummary>>('/admin/assignments', { workerId: id, limit: 100 }) });

  if (worker.isLoading) return <ListSkeleton rows={4} />;
  if (worker.error || !worker.data) return <ErrorState error={worker.error} onRetry={() => worker.refetch()} />;
  const w = worker.data;
  const active = (assignments.data?.items ?? []).filter((a) => !['COMPLETED', 'CANCELLED'].includes(a.status));
  const done = (assignments.data?.items ?? []).filter((a) => ['COMPLETED', 'CANCELLED'].includes(a.status));
  const canPay = !!ledger.data && hasPerm(me, 'CASH_PAYOUT') && ledger.data.balance !== '0';
  const canAssign = w.status === 'ACTIVE' && hasPerm(me, 'ASSIGNMENT_CREATE');

  return (
    <div className="max-w-3xl space-y-4 sm:space-y-6">
      <PageHeader
        back={{ href: '/workers', label: 'Мастерицы' }}
        title={w.fullName}
        subtitle={
          <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span>{w.code}</span>
            <a href={`tel:${w.phone}`} className="text-primary hover:underline">{w.phone}</a>
            <Badge tone={w.status === 'ACTIVE' ? 'ok' : w.status === 'PENDING_APPROVAL' ? 'warn' : 'default'}>{statusLabel(w.status)}</Badge>
          </span>
        }
        actions={(canAssign || canPay) ? (
          <>
            {canAssign && <Button onClick={() => setAssigning(true)}>+ Выдать работу</Button>}
            {canPay && <Button variant="outline" onClick={() => setPayingOut(true)}>Выплатить</Button>}
          </>
        ) : undefined}
      />

      {w.status === 'PENDING_APPROVAL' && hasPerm(me, 'WORKER_APPROVE') && <ApprovalCard worker={w} />}
      {w.status === 'REJECTED' && w.rejectedReason && <Card><p className="text-sm text-muted">Причина отказа: {w.rejectedReason}</p></Card>}

      {ledger.data && w.status !== 'PENDING_APPROVAL' && (
        <Card className="grid grid-cols-3 divide-x divide-border p-0 sm:p-0">
          {([['К получению', ledger.data.balance, 'text-primary'], ['Заработано', ledger.data.earned, ''], ['Выплачено', ledger.data.paid, '']] as const).map(([k, v, c]) => (
            <div key={k} className="px-3 py-3 sm:px-5 sm:py-4">
              <p className="text-xs text-muted">{k}</p>
              <p className={`mt-0.5 text-sm font-semibold tabular-nums sm:text-xl ${c}`}>{formatUzs(v)}</p>
            </div>
          ))}
        </Card>
      )}

      {w.status !== 'PENDING_APPROVAL' && w.status !== 'REJECTED' && <ManagerAndStatusCard worker={w} />}

      <Card>
        <h2 className="mb-3 text-sm font-semibold">Текущая работа</h2>
        {assignments.isLoading && <ListSkeleton rows={2} />}
        {assignments.data && active.length === 0 && <p className="text-sm text-muted">Сейчас нет активной работы.</p>}
        <div className="space-y-2">
          {active.map((a) => (
            <Link key={a.id} href={`/assignments/${a.id}`} className="block rounded-lg border border-border p-3 transition hover:bg-border/20">
              <div className="flex items-start justify-between gap-3">
                <span className="min-w-0 text-sm font-medium">{a.product?.name ?? '—'} · {a.color?.name ?? '—'}</span>
                <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge>
              </div>
              <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-border">
                <div className="h-full rounded-full bg-primary" style={{ width: `${a.plannedMeters > 0 ? Math.min(100, (a.reportedMeters / a.plannedMeters) * 100) : 0}%` }} />
              </div>
              <p className="mt-1.5 text-xs text-muted">Готово {a.reportedMeters} из {a.plannedMeters} м{a.dueAt ? ` · срок ${formatDay(a.dueAt)}` : ''}</p>
            </Link>
          ))}
        </div>
      </Card>

      {ledger.data && ledger.data.history.length > 0 && (
        <Card>
          <h2 className="mb-2 text-sm font-semibold">Деньги</h2>
          <ul className="divide-y divide-border text-sm">
            {ledger.data.history.map((e) => (
              <li key={e.id} className="flex items-center justify-between gap-3 py-2">
                <span className="min-w-0">
                  <span className="block">{e.type === 'PAYOUT_CASH' ? 'Выплата наличными' : 'Начисление за работу'}</span>
                  <span className="block text-xs text-muted">{formatDate(e.createdAt)}</span>
                </span>
                <span className={`shrink-0 font-semibold tabular-nums ${e.amount.startsWith('-') ? 'text-danger' : 'text-ok'}`}>{e.amount.startsWith('-') ? '' : '+'}{formatUzs(e.amount)}</span>
              </li>
            ))}
          </ul>
        </Card>
      )}

      {done.length > 0 && (
        <Card>
          <h2 className="mb-2 text-sm font-semibold">Завершённые</h2>
          <ul className="divide-y divide-border text-sm">
            {done.map((a) => (
              <li key={a.id}>
                <Link href={`/assignments/${a.id}`} className="flex items-center justify-between gap-3 py-2 hover:text-primary">
                  <span className="min-w-0">{a.product?.name ?? '—'} · {a.color?.name ?? '—'} · {a.plannedMeters} м</span>
                  <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge>
                </Link>
              </li>
            ))}
          </ul>
        </Card>
      )}

      {payingOut && <PayoutDialog workerId={w.id} onClose={() => setPayingOut(false)} />}
      {assigning && <CreateAssignmentDialog workerId={w.id} onClose={() => setAssigning(false)} />}
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

/** «Менеджер» + «Архивировать / Восстановить». Reassigning moves her whole scope on the server (lists, map, QR,
 * realtime) from the old manager to the new one; archiving keeps every record and only blocks login and new work. */
function ManagerAndStatusCard({ worker: w }: { worker: Worker }) {
  const { me } = useAuth();
  const qc = useQueryClient();
  const canManager = hasPerm(me, 'WORKER_ASSIGN_MANAGER');
  const canStatus = hasPerm(me, 'WORKER_UPDATE');
  const managers = useQuery<{ items: ManagerSummary[] }>({ queryKey: ['managers'], queryFn: () => api.get<{ items: ManagerSummary[] }>('/managers'), enabled: canManager });
  const [picked, setPicked] = useState<string>(w.manager?.id ?? '');
  const [archiving, setArchiving] = useState(false);
  const done = () => {
    qc.invalidateQueries({ queryKey: ['worker', w.id] });
    qc.invalidateQueries({ queryKey: ['workers'] });
    qc.invalidateQueries({ queryKey: ['managers'] });
  };
  const [saved, setSaved] = useState(false);
  const assign = useMutation({
    mutationFn: () => api.post(`/workers/${w.id}/manager`, { managerId: picked || null }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { done(); setSaved(true); setTimeout(() => setSaved(false), 3000); },
  });
  const status = useMutation({ mutationFn: (next: 'ARCHIVED' | 'ACTIVE') => api.patch(`/workers/${w.id}`, { status: next }), onSuccess: () => { setArchiving(false); done(); } });

  return (
    <Card>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <span className="text-muted">Менеджер:</span>
          {canManager ? (
            <>
              <select aria-label="Менеджер" className="min-h-10 w-full rounded-lg border border-border bg-card px-3 py-1.5 sm:w-auto" value={picked} onChange={(e) => setPicked(e.target.value)}>
                <option value="">Без менеджера</option>
                {managers.data?.items.filter((m) => m.status === 'ACTIVE' || m.id === w.manager?.id).map((m) => <option key={m.id} value={m.id}>{m.fullName} · {m.stats.workers}</option>)}
              </select>
              <Button variant="outline" disabled={picked === (w.manager?.id ?? '') || assign.isPending} onClick={() => assign.mutate()}>Сменить менеджера</Button>
            </>
          ) : (
            <span>{w.manager?.fullName ?? 'Без менеджера'}</span>
          )}
        </div>
        {canStatus && (w.status === 'ARCHIVED'
          ? <Button disabled={status.isPending} onClick={() => status.mutate('ACTIVE')}>Восстановить мастерицу</Button>
          : <Button variant="outline" onClick={() => setArchiving(true)}>Архивировать мастерицу</Button>)}
      </div>
      {saved && <p className="mt-2 text-sm text-ok" role="status">✓ Менеджер изменён</p>}
      {(assign.isError || status.isError) && <ErrorState error={assign.error ?? status.error} />}
      {archiving && (
        <Modal title="Архивировать мастерицу" onClose={() => setArchiving(false)}>
          <p className="text-sm">Мастерица не сможет войти и не получит новую работу. История, выплаты и залог сохранятся.</p>
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="ghost" onClick={() => setArchiving(false)}>Отмена</Button>
            <Button variant="danger" disabled={status.isPending} onClick={() => status.mutate('ARCHIVED')}>Архивировать</Button>
          </div>
        </Modal>
      )}
    </Card>
  );
}
