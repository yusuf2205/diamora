'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatUzs } from '@/lib/format';
import type { AssignmentDetail } from '@/lib/types';
import { Badge, Button, Card, ErrorState, Input, Modal } from '@/components/ui';

/** One operational screen per assignment, exactly like the mobile app: human status, history, and ONE contextual
 * action for whatever the status actually allows right now — never a generic "edit" form (§28). */
export default function AssignmentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [accepting, setAccepting] = useState(false);
  const [payingOut, setPayingOut] = useState(false);
  const { data: a, error, isLoading } = useQuery<AssignmentDetail>({ queryKey: ['assignment', id], queryFn: () => api.get<AssignmentDetail>(`/admin/assignments/${id}`) });

  const deliver = useMutation({
    mutationFn: () => api.post(`/admin/assignments/${id}/deliver`, undefined, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignment', id] }),
  });
  const pickup = useMutation({
    mutationFn: () => api.post(`/admin/assignments/${id}/pickup`, undefined, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['assignment', id] }),
  });

  if (isLoading) return <p className="text-muted">Загрузка…</p>;
  if (error || !a) return <ErrorState error={error} />;

  return (
    <div className="max-w-2xl space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{a.product?.name ?? 'Задание'}{a.variant?.label ? ` · ${a.variant.label}` : ''}</h1>
          <p className="text-sm text-muted">{a.color?.name} · {a.plannedMeters} м · <Link href={`/workers/${a.worker.id}`} className="underline">{a.worker.fullName}</Link> · {a.worker.phone}</p>
        </div>
        <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge>
      </div>

      <Card>
        <div className="flex items-center justify-between text-sm">
          <span>Сделано: {a.reportedMeters} из {a.plannedMeters} м</span>
          <span className="font-medium">{a.plannedMeters > 0 ? Math.min(100, Math.round((a.reportedMeters / a.plannedMeters) * 100)) : 0}%</span>
        </div>
        <div className="mt-2 h-2 overflow-hidden rounded-full bg-border">
          <div className="h-full bg-primary" style={{ width: `${a.plannedMeters > 0 ? Math.min(100, (a.reportedMeters / a.plannedMeters) * 100) : 0}%` }} />
        </div>
        {a.calculatedPayment && <p className="mt-3 text-sm">Расчётная оплата: <span className="font-semibold">{formatUzs(a.calculatedPayment)}</span></p>}
        {a.dueAt && <p className="mt-1 text-sm text-muted">Срок: {a.dueAt.slice(0, 10)}</p>}
        {a.notes && <p className="mt-1 text-sm text-muted">{a.notes}</p>}
      </Card>

      {error && <ErrorState error={error} />}

      {a.status === 'READY_TO_DELIVER' && (
        <div className="space-y-2">
          {deliver.isError && <ErrorState error={deliver.error} />}
          <Button onClick={() => deliver.mutate()} disabled={deliver.isPending}>Доставлено</Button>
        </div>
      )}
      {a.status === 'READY_FOR_PICKUP' && (
        <div className="space-y-2">
          {pickup.isError && <ErrorState error={pickup.error} />}
          <Button onClick={() => pickup.mutate()} disabled={pickup.isPending}>Забрал</Button>
        </div>
      )}
      {a.status === 'UNDER_REVIEW' && <Button onClick={() => setAccepting(true)}>Принять работу</Button>}
      {(a.status === 'ACCEPTED' || a.status === 'PARTIALLY_ACCEPTED' || a.status === 'COMPLETED') && (
        <Button onClick={() => setPayingOut(true)}>Выплатить наличными</Button>
      )}

      <Card>
        <h2 className="mb-3 text-sm font-medium text-muted">История</h2>
        <div className="space-y-2 text-sm">
          {a.statusHistory.length === 0 && <p className="text-muted">Пока пусто.</p>}
          {[...a.statusHistory].reverse().map((h, i) => (
            <div key={i} className="flex items-center justify-between border-b border-border pb-2 last:border-0">
              <span>{assignmentStatusLabel(h.to)}</span>
              <span className="text-muted">{h.changedAt.slice(0, 16).replace('T', ' ')}</span>
            </div>
          ))}
        </div>
      </Card>

      {accepting && <AcceptDialog assignment={a} onClose={() => setAccepting(false)} />}
      {payingOut && <PayoutDialog workerId={a.worker.id} onClose={() => setPayingOut(false)} />}
    </div>
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
        {accept.isError && <ErrorState error={accept.error} />}
        <div className="flex justify-end gap-2 pt-2">
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
      <Input id={id} type="number" step="0.1" value={value} onChange={(e) => onChange(e.target.value)} />
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
            <Input type="number" min={0} placeholder="Сумма" value={amount} onChange={(e) => setAmount(e.target.value)} />
            {friendlyError && <div className="rounded-lg bg-danger/10 p-3 text-sm text-danger">{friendlyError}</div>}
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={onClose}>Отмена</Button>
              <Button onClick={() => setConfirming(true)} disabled={!(amountInt > 0)}>Выплатить</Button>
            </div>
          </>
        ) : (
          <>
            <p className="text-sm">Вы действительно выдали <span className="font-semibold">{formatUzs(String(amountInt))}</span> наличными?</p>
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
