'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { hasPerm } from '@/lib/types';
import { earningFor, metersToCm } from '@diamoraa/shared';
import { assignmentStatusLabel, assignmentStatusTone, formatDate, formatDay, formatUzs, handoffProblemLabel } from '@/lib/format';
import type { AssignmentDetail, AssignmentHandoff, HandoffTimelineEntry, PayRate } from '@/lib/types';
import { Badge, Button, Card, ErrorState, Input, ListSkeleton, Modal, PageHeader } from '@/components/ui';
import { QrCard } from '@/components/qr';

/** One operational screen per assignment, exactly like the mobile app: human status, history, and ONE contextual
 * action for whatever the status actually allows right now — never a generic "edit" form (§28). */
export default function AssignmentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [accepting, setAccepting] = useState(false);
  const [payingOut, setPayingOut] = useState(false);
  const [controlling, setControlling] = useState<'due' | 'cancel' | null>(null);
  const { me } = useAuth();
  const canControl = hasPerm(me, 'ASSIGNMENT_CREATE');
  const { data: a, error, isLoading } = useQuery<AssignmentDetail>({ queryKey: ['assignment', id], queryFn: () => api.get<AssignmentDetail>(`/admin/assignments/${id}`) });

  // Phase 5: staff only STARTS the handoff; the worker confirms receipt in her own app, then this page updates live
  const deliver = useMutation({
    mutationFn: () => api.post(`/admin/assignments/${id}/handoff`, undefined, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignment', id] }),
  });
  const pickup = useMutation({
    mutationFn: () => api.post(`/admin/assignments/${id}/pickup`, undefined, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignment', id] }),
  });

  if (isLoading) return <ListSkeleton rows={4} />;
  if (error || !a) return <ErrorState error={error} />;

  const pct = a.plannedMeters > 0 ? Math.min(100, (a.reportedMeters / a.plannedMeters) * 100) : 0;
  const unit = (u?: string | null) => (u === 'METER' ? 'м' : u === 'GRAM' ? 'г' : 'шт');
  const action = (() => {
    if (a.status === 'READY_TO_DELIVER') {
      if (a.handoff?.status === 'AWAITING_WORKER' && !a.handoff.expired) return null; // she is confirming: nothing to press
      return {
        label: a.handoff ? 'Начать передачу снова' : 'Начать передачу',
        hint: 'Вы у мастерицы: после этого она сама отсканирует QR и подтвердит получение. Материалы перейдут к ней только после её подтверждения.',
        run: () => deliver.mutate(), pending: deliver.isPending, err: deliver.error,
      };
    }
    if (a.status === 'READY_FOR_PICKUP') return { label: 'Забрал', hint: 'Отметьте, когда забрали готовую работу', run: () => pickup.mutate(), pending: pickup.isPending, err: pickup.error };
    if (a.status === 'UNDER_REVIEW') return { label: 'Принять работу', hint: 'Проверьте работу и укажите, сколько принято', run: () => setAccepting(true), pending: false, err: null };
    if (a.status === 'ACCEPTED' || a.status === 'PARTIALLY_ACCEPTED' || a.status === 'COMPLETED') return { label: 'Выплатить наличными', hint: null, run: () => setPayingOut(true), pending: false, err: null };
    return null;
  })();

  return (
    <div className="max-w-2xl space-y-4 pb-24 sm:space-y-6 sm:pb-0">
      <PageHeader
        back={{ href: '/assignments', label: 'Задания' }}
        title={<>{a.product?.name ?? 'Задание'}{a.variant?.label ? ` · ${a.variant.label}` : ''}</>}
        subtitle={<span className="flex flex-wrap items-center gap-2"><span>{a.color?.name} · {a.plannedMeters} м</span><Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge></span>}
      />

      <Card>
        <Link href={`/workers/${a.worker.id}`} className="flex items-center justify-between gap-3 hover:text-primary">
          <span className="min-w-0">
            <span className="block font-medium">{a.worker.fullName}</span>
            <span className="block text-sm text-muted">{a.worker.phone}</span>
          </span>
          <span className="text-muted">›</span>
        </Link>
        <div className="mt-4 flex items-center justify-between text-sm">
          <span>Готово {a.reportedMeters} из {a.plannedMeters} м</span>
          <span className="font-semibold tabular-nums">{Math.round(pct)}%</span>
        </div>
        <div className="mt-2 h-2 overflow-hidden rounded-full bg-border"><div className="h-full rounded-full bg-primary transition-all" style={{ width: `${pct}%` }} /></div>
        <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
          <dt className="text-muted">Срок</dt><dd className="text-right">{a.dueAt ? formatDay(a.dueAt) : 'без срока'}</dd>
          <dt className="text-muted">Комплектов</dt><dd className="text-right">{a.kitCount} × 9 м</dd>
          {a.expectedPayment && a.acceptedMeters === 0 && <><dt className="text-muted">Ожидаемая оплата</dt><dd className="text-right">{formatUzs(a.expectedPayment)}</dd></>}
          {a.calculatedPayment && a.acceptedMeters > 0 && <><dt className="text-muted">Начислено</dt><dd className="text-right font-semibold text-ok">{formatUzs(a.calculatedPayment)}</dd></>}
          {a.acceptedMeters > 0 && <><dt className="text-muted">Принято</dt><dd className="text-right">{a.acceptedMeters} м{a.defectiveMeters > 0 ? ` · брак ${a.defectiveMeters} м` : ''}</dd></>}
        </dl>
        {a.notes && <p className="mt-3 rounded-lg bg-border/30 p-3 text-sm">{a.notes}</p>}
      </Card>

      {canControl && !['COMPLETED', 'CANCELLED', 'ACCEPTED'].includes(a.status) && (
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => setControlling('due')}>Изменить срок</Button>
          {['DRAFT', 'READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP'].includes(a.status) && (
            <Button variant="outline" className="text-danger" onClick={() => setControlling('cancel')}>Отменить работу</Button>
          )}
        </div>
      )}
      {controlling && <ControlDialog assignment={a} kind={controlling} onClose={() => setControlling(null)} />}

      {a.handoff && <HandoffCard handoff={a.handoff} workerName={a.worker.fullName} timeline={a.handoffTimeline ?? []} />}

      {action && (
        <div className="fixed inset-x-0 bottom-0 z-20 border-t border-border bg-card/95 p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] backdrop-blur sm:static sm:border-0 sm:bg-transparent sm:p-0">
          {action.err && <div className="mb-2"><ErrorState error={action.err} /></div>}
          {action.hint && <p className="mb-2 hidden text-sm text-muted sm:block">{action.hint}</p>}
          <Button className="w-full sm:w-auto" onClick={action.run} disabled={action.pending}>{action.pending ? 'Сохраняем…' : action.label}</Button>
        </div>
      )}

      {a.qrCode && a.status !== 'COMPLETED' && a.status !== 'CANCELLED' && (
        <QrCard heading="QR задания" code={a.qrCode} title={`${a.product?.name ?? ''} · ${a.color?.name ?? ''}`} lines={[a.worker.fullName, `${a.plannedMeters} м · ${a.code}`]} />
      )}

      {a.materials.length > 0 && (
        <Card>
          <h2 className="mb-2 text-sm font-semibold">{a.status === 'READY_TO_DELIVER' || a.status === 'DRAFT' ? 'Подготовленные материалы' : 'Материалы у мастерицы'}</h2>
          <ul className="divide-y divide-border text-sm">
            {a.materials.map((m) => (
              <li key={m.materialId} className="flex justify-between gap-3 py-2"><span>{m.name ?? 'Материал'}</span><span className="shrink-0 tabular-nums text-muted">{m.quantity} {unit(m.unit)}</span></li>
            ))}
          </ul>
        </Card>
      )}

      <Card>
        <h2 className="mb-2 text-sm font-semibold">История</h2>
        {a.statusHistory.length === 0 && <p className="text-sm text-muted">Пока пусто.</p>}
        <ol className="space-y-3 text-sm">
          {[...a.statusHistory].reverse().map((h, i) => (
            <li key={i} className="relative pl-5">
              <span className={`absolute left-0 top-1.5 h-2 w-2 rounded-full ${i === 0 ? 'bg-primary' : 'bg-border'}`} />
              <p className="font-medium">{assignmentStatusLabel(h.to)}</p>
              <p className="text-xs text-muted">{formatDate(h.changedAt)}{h.comment ? ` · ${h.comment}` : ''}</p>
            </li>
          ))}
        </ol>
      </Card>

      {accepting && <AcceptDialog assignment={a} onClose={() => setAccepting(false)} />}
      {payingOut && <PayoutDialog workerId={a.worker.id} onClose={() => setPayingOut(false)} />}
    </div>
  );
}

/** Phase 5.9/5.10: who started the handoff, when the worker scanned and confirmed (the fact of receipt), or her problem. */
export function HandoffCard({ handoff: h, workerName, timeline }: { handoff: AssignmentHandoff; workerName: string; timeline: HandoffTimelineEntry[] }) {
  const state = h.status === 'CONFIRMED'
    ? { tone: 'bg-ok/10 text-ok', title: `${workerName} получила комплект`, hint: h.workerAcceptedAt ? formatDate(h.workerAcceptedAt) : null }
    : h.status === 'PROBLEM'
      ? { tone: 'bg-danger/10 text-danger', title: 'Мастерица сообщила о проблеме', hint: [handoffProblemLabel(h.problemReason), h.problemComment].filter(Boolean).join(' · ') }
      : h.status === 'EXPIRED' || h.expired
        ? { tone: 'bg-danger/10 text-danger', title: 'Время передачи истекло', hint: 'Начните передачу снова' }
        : h.workerScannedAt
          ? { tone: 'bg-primary/10 text-primary', title: 'Мастерица отсканировала QR и проверяет комплект', hint: null }
          : { tone: 'bg-primary/10 text-primary', title: 'Ожидаем подтверждения мастерицы', hint: 'Попросите мастерицу открыть приложение и отсканировать QR комплекта' };
  const line = (e: HandoffTimelineEntry) =>
    e.kind === 'HANDOFF_STARTED' ? `Передачу начал(а): ${e.by ?? ''}`
      : e.kind === 'WORKER_SCANNED' ? 'Мастерица отсканировала QR'
        : e.kind === 'WORKER_CONFIRMED' ? 'Мастерица подтвердила получение'
          : `Мастерица сообщила о проблеме: ${handoffProblemLabel(e.reason)}`;
  return (
    <Card>
      <h2 className="mb-2 text-sm font-semibold">Передача мастерице</h2>
      <div className={`rounded-lg p-3 ${state.tone}`}>
        <p className="font-semibold">{state.title}</p>
        {state.hint && <p className="text-sm opacity-90">{state.hint}</p>}
      </div>
      {timeline.length > 0 && (
        <ol className="mt-3 space-y-2 text-sm">
          {timeline.map((e, i) => (
            <li key={i} className="relative pl-5">
              <span className={`absolute left-0 top-1.5 h-2 w-2 rounded-full ${e.kind === 'WORKER_PROBLEM' ? 'bg-danger' : 'bg-primary'}`} />
              <p>{line(e)}</p>
              <p className="text-xs text-muted">{formatDate(e.at)}</p>
            </li>
          ))}
        </ol>
      )}
      {h.status === 'CONFIRMED' && <p className="mt-2 text-xs text-muted">Передачу начал(а): {h.staff.fullName}{h.hasLocation ? ' · место получения сохранено' : ''}</p>}
    </Card>
  );
}

/** «Изменить срок» / «Отменить работу» (materials back to the shelf, or written off). */
function ControlDialog({ assignment: a, kind, onClose }: { assignment: AssignmentDetail; kind: 'due' | 'cancel'; onClose: () => void }) {
  const qc = useQueryClient();
  const [due, setDue] = useState(a.dueAt ? a.dueAt.slice(0, 10) : '');
  const [reason, setReason] = useState('');
  const [returned, setReturned] = useState(true);
  const m = useMutation({
    mutationFn: () => kind === 'due'
      ? api.patch(`/admin/assignments/${a.id}`, { dueAt: due ? new Date(`${due}T18:00:00`).toISOString() : null })
      : api.post(`/admin/assignments/${a.id}/cancel`, { reason: reason.trim(), materialsReturned: returned }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['assignment', a.id] }); onClose(); },
  });
  return (
    <Modal title={kind === 'due' ? 'Изменить срок' : 'Отменить работу'} onClose={onClose}>
      <div className="space-y-3">
        {kind === 'due' ? (
          <Input type="date" aria-label="Срок" value={due} onChange={(e) => setDue(e.target.value)} />
        ) : (
          <>
            <Input placeholder="Причина" aria-label="Причина" value={reason} onChange={(e) => setReason(e.target.value)} />
            <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={returned} onChange={(e) => setReturned(e.target.checked)} /> Материалы вернулись на склад</label>
          </>
        )}
        {m.isError && <ErrorState error={m.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Закрыть</Button>
          <Button variant={kind === 'cancel' ? 'danger' : 'primary'} disabled={m.isPending || (kind === 'cancel' && reason.trim().length < 2)} onClick={() => m.mutate()}>
            {kind === 'due' ? 'Сохранить' : 'Отменить работу'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export function AcceptDialog({ assignment: a, onClose }: { assignment: AssignmentDetail; onClose: () => void }) {
  const qc = useQueryClient();
  const initial = a.reportedMeters > 0 ? a.reportedMeters : a.plannedMeters;
  const [brought, setBrought] = useState(String(initial));
  const [accepted, setAccepted] = useState(String(initial));
  const [defective, setDefective] = useState('0');
  const [rework, setRework] = useState('0');
  const [comment, setComment] = useState('');

  const bV = Number(brought) || 0, acV = Number(accepted) || 0, dV = Number(defective) || 0, rV = Number(rework) || 0;
  const valid = Math.abs(acV + dV + rV - bV) < 0.01 && bV >= 0;
  // the SAME shared formula the server settles with (packages/shared earningFor) - a preview, the server has the last word
  const rate = useQuery<PayRate>({ queryKey: ['pay-rate'], queryFn: () => api.get<PayRate>('/settings/pay-rate') });
  let preview: string | null = null;
  try {
    if (rate.data && valid) preview = earningFor(BigInt(rate.data.ratePerKit), metersToCm(acV)).toString();
  } catch { preview = null; }

  const accept = useMutation({
    mutationFn: () => api.post(`/admin/assignments/${a.id}/accept`, {
      broughtMeters: bV.toFixed(2), acceptedMeters: acV.toFixed(2), defectiveMeters: dV.toFixed(2), reworkMeters: rV.toFixed(2), comment: comment.trim() || undefined,
    }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['assignment', a.id] }); onClose(); },
  });

  return (
    <Modal title="Приёмка работы" onClose={onClose}>
      <div className="space-y-3">
        <NumberField label="Принесено, м" value={brought} onChange={setBrought} />
        <NumberField label="Принято, м" value={accepted} onChange={setAccepted} />
        <NumberField label="Брак, м" value={defective} onChange={setDefective} />
        <NumberField label="На доработку, м" value={rework} onChange={setRework} />
        <Input placeholder="Комментарий (необязательно)" value={comment} onChange={(e) => setComment(e.target.value)} />
        {!valid && <p className="text-sm text-danger">Принято + брак + доработка должно равняться принесено</p>}
        {preview !== null && (
          <div className="rounded-lg bg-ok/10 p-3 text-sm">
            Мастерице начислится: <span className="font-semibold text-ok">{formatUzs(preview)}</span>
            <span className="block text-xs text-muted">за {acV} м по ставке {formatUzs(rate.data!.ratePerKit)} за 9 м</span>
          </div>
        )}
        {accept.isError && <ErrorState error={accept.error} />}
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => accept.mutate()} disabled={!valid || accept.isPending}>Принять работу</Button>
        </div>
      </div>
    </Modal>
  );
}

function NumberField({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  const id = `field-${label}`;
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-xs text-muted">{label}</label>
      <Input id={id} type="number" inputMode="decimal" step="0.1" min={0} value={value} onChange={(e) => onChange(e.target.value)} />
    </div>
  );
}

export function PayoutDialog({ workerId, onClose }: { workerId: string; onClose: () => void }) {
  const qc = useQueryClient();
  const ledger = useQuery<{ balance: string }>({ queryKey: ['ledger', workerId], queryFn: () => api.get(`/admin/workers/${workerId}/ledger`) });
  const balance = Number(ledger.data?.balance ?? '0');
  const [amount, setAmount] = useState('');
  const [confirming, setConfirming] = useState(false);
  const [friendlyError, setFriendlyError] = useState<string | null>(null);

  const payout = useMutation({
    mutationFn: () => api.post(`/admin/workers/${workerId}/payout`, { amount: String(Math.trunc(Number(amount) || 0)) }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['ledger', workerId] });
      qc.invalidateQueries({ queryKey: ['assignments'] });
      onClose();
    },
    onError: (err) => {
      setConfirming(false);
      if (err instanceof ApiError && err.code === 'INVARIANT_VIOLATION') setFriendlyError('Сумма больше, чем причитается мастерице');
      else setFriendlyError(null);
    },
  });

  const amountInt = Math.trunc(Number(amount) || 0);

  return (
    <Modal title="Выплатить наличными" onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm text-muted">К выплате: <span className="font-semibold text-foreground">{formatUzs(String(balance))}</span></p>
        {balance <= 0 ? (
          <p className="text-sm text-muted">Выплачивать нечего.</p>
        ) : !confirming ? (
          <>
            <div className="flex gap-2">
              <Button variant="outline" className="flex-1" onClick={() => setAmount(String(balance))}>Вся сумма</Button>
              <Button variant="outline" className="flex-1" onClick={() => setAmount(String(Math.trunc(balance / 2)))}>Половина</Button>
            </div>
            <Input type="number" inputMode="numeric" min={0} placeholder="Сумма, сум" aria-label="Сумма" value={amount} onChange={(e) => setAmount(e.target.value)} />
            {amountInt > balance && <p className="text-sm text-danger">Больше, чем причитается: максимум {formatUzs(String(balance))}</p>}
            {friendlyError && <div className="rounded-lg bg-danger/10 p-3 text-sm text-danger">{friendlyError}</div>}
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={onClose}>Отмена</Button>
              <Button onClick={() => setConfirming(true)} disabled={!(amountInt > 0) || amountInt > balance}>Выплатить</Button>
            </div>
          </>
        ) : (
          <>
            <p className="text-sm">Вы действительно выдали <span className="font-semibold">{formatUzs(String(amountInt))}</span> наличными?</p>
            <p className="text-xs text-muted">Подтверждайте только после того, как деньги физически переданы мастерице. Запись в истории отменить нельзя.</p>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setConfirming(false)}>Отмена</Button>
              <Button onClick={() => payout.mutate()} disabled={payout.isPending}>Выплатить</Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
