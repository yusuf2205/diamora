'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Clock } from 'lucide-react';
import { useState } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState, Input, Modal } from '@/components/ui';

export interface VisitTime { days: number[]; from: string; to: string; note?: string | null }
const DAYS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/** Worker page: «Удобное время» in words; staff may set it for her (e.g. she said it on the phone). */
export function VisitTimeCard({ workerId, visitTime, visitText, canEdit }: { workerId: string; visitTime: VisitTime | null; visitText: string | null; canEdit: boolean }) {
  const [editing, setEditing] = useState(false);
  return (
    <Card className="flex flex-wrap items-center gap-3">
      <Clock size={20} className="text-primary" aria-hidden />
      <div className="min-w-0 flex-1">
        <p className="text-xs text-muted">Когда удобно, чтобы приезжали</p>
        <p className="font-medium">{visitText ?? 'Не указано'}</p>
      </div>
      {canEdit && <Button variant="outline" onClick={() => setEditing(true)}>Изменить</Button>}
      {editing && <VisitTimeModal workerId={workerId} initial={visitTime} onClose={() => setEditing(false)} />}
    </Card>
  );
}

function VisitTimeModal({ workerId, initial, onClose }: { workerId: string; initial: VisitTime | null; onClose: () => void }) {
  const qc = useQueryClient();
  const [days, setDays] = useState<Set<number>>(new Set(initial?.days ?? [1, 2, 3, 4, 5]));
  const [from, setFrom] = useState(initial?.from ?? '10:00');
  const [to, setTo] = useState(initial?.to ?? '18:00');
  const [note, setNote] = useState(initial?.note ?? '');
  const save = useMutation({
    mutationFn: (clear: boolean) => api.put(`/admin/workers/${workerId}/visit-time`, { visitTime: clear ? null : { days: [...days].sort(), from, to, note: note.trim() || null } }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['worker', workerId] }); onClose(); },
  });
  const valid = days.size > 0 && from < to;
  return (
    <Modal title="Когда удобно, чтобы приезжали" onClose={onClose}>
      <div className="space-y-3">
        <div className="flex flex-wrap gap-2">
          {DAYS.map((d, i) => (
            <button key={d} type="button" aria-pressed={days.has(i + 1)} onClick={() => setDays((s) => { const n = new Set(s); if (n.has(i + 1)) n.delete(i + 1); else n.add(i + 1); return n; })}
              className={`rounded-full border px-3 py-1.5 text-sm font-medium ${days.has(i + 1) ? 'border-primary bg-primary text-white' : 'border-border'}`}>{d}</button>
          ))}
        </div>
        <div className="flex items-center gap-2">
          <span>с</span><Input type="time" aria-label="С" value={from} onChange={(e) => setFrom(e.target.value)} className="w-32" />
          <span>до</span><Input type="time" aria-label="До" value={to} onChange={(e) => setTo(e.target.value)} className="w-32" />
        </div>
        {from >= to && <p className="text-sm text-danger">«С» должно быть раньше, чем «до»</p>}
        <Input aria-label="Пометка" placeholder="Пометка: звонить заранее…" value={note} maxLength={200} onChange={(e) => setNote(e.target.value)} />
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex flex-wrap justify-end gap-2">
          {initial && <Button variant="ghost" onClick={() => save.mutate(true)} disabled={save.isPending}>Убрать</Button>}
          <Button onClick={() => save.mutate(false)} disabled={!valid || save.isPending}>Сохранить</Button>
        </div>
      </div>
    </Modal>
  );
}
