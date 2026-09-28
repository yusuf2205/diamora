'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { Button, ErrorState, Field, Input, Modal } from '@/components/ui';

export interface CollateralRow {
  id: string; code: string | null; type: 'MONEY' | 'ITEM'; status: 'PENDING' | 'HELD' | 'RETURNED';
  amount: string | null; description: string | null; estimatedValue: string | null; storageLocation: string | null;
  declaredAt: string; receivedAt: string | null; returnedAt: string | null; returnNote: string | null;
  worker: { id: string; code: string; fullName: string };
}

/** What she gave, in words: «Деньги: 1 500 000 сум» or the item's description. */
export const collateralWhat = (c: Pick<CollateralRow, 'type' | 'amount' | 'description'>) =>
  c.type === 'MONEY' ? `Деньги: ${formatUzs(c.amount)} сум` : (c.description || 'Вещь');

export const COLLATERAL_STATUS: Record<CollateralRow['status'], { label: string; tone: 'warn' | 'ok' | 'default' }> = {
  PENDING: { label: 'Ещё не получен', tone: 'warn' },
  HELD: { label: 'У нас', tone: 'ok' },
  RETURNED: { label: 'Возвращён', tone: 'default' },
};

const invalidate = (qc: ReturnType<typeof useQueryClient>, workerId: string) => {
  qc.invalidateQueries({ queryKey: ['collaterals'] });
  qc.invalidateQueries({ queryKey: ['worker', workerId] });
  qc.invalidateQueries({ queryKey: ['workers'] });
};

/** «Принял залог»: PENDING -> HELD, where it is kept (optional). */
export function ReceiveCollateralDialog({ c, onClose }: { c: CollateralRow; onClose: () => void }) {
  const qc = useQueryClient();
  const [place, setPlace] = useState('');
  const save = useMutation({
    mutationFn: () => api.post(`/collaterals/${c.id}/receive`, { storageLocation: place.trim() || undefined }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { invalidate(qc, c.worker.id); onClose(); },
  });
  return (
    <Modal title="Принять залог" onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm"><span className="font-semibold">{c.worker.fullName}</span> — {collateralWhat(c)}</p>
        <Field label="Где хранится (необязательно)" htmlFor="col-place"><Input id="col-place" placeholder="Сейф, полка 2" value={place} onChange={(e) => setPlace(e.target.value)} /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button disabled={save.isPending} onClick={() => save.mutate()}>Залог у нас</Button>
        </div>
      </div>
    </Modal>
  );
}

/** «Вернуть залог»: HELD -> RETURNED, only with a note and her confirmation that she got it back. */
export function ReturnCollateralDialog({ c, onClose }: { c: CollateralRow; onClose: () => void }) {
  const qc = useQueryClient();
  const [note, setNote] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const save = useMutation({
    mutationFn: () => api.post(`/collaterals/${c.id}/return`, { note: note.trim(), workerConfirmed: true }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { invalidate(qc, c.worker.id); onClose(); },
  });
  return (
    <Modal title="Вернуть залог" onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm"><span className="font-semibold">{c.worker.fullName}</span> — {collateralWhat(c)}{c.storageLocation ? ` (хранится: ${c.storageLocation})` : ''}</p>
        <Field label="Как вернули" htmlFor="col-note"><Input id="col-note" placeholder="Отдали лично в руки" value={note} onChange={(e) => setNote(e.target.value)} /></Field>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" className="h-5 w-5" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} />
          Мастерица получила залог обратно
        </label>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button disabled={save.isPending || !confirmed || note.trim().length < 2} onClick={() => save.mutate()}>Вернуть залог</Button>
        </div>
      </div>
    </Modal>
  );
}
