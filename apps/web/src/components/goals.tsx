'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState, Field, Input } from '@/components/ui';

interface Goal { goalMeters: number; personal: boolean; doneMeters: number; leftMeters: number | null; percent: number | null; daysLeft: number; place: number | null; of: number; badges: { code: string; title: string; hint: string; earned: boolean }[] }

/** Settings: the common «Цель месяца» in metres for every worker (no money - progress, place and badges only). */
export function CommonGoalSection() {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['goals'], queryFn: () => api.get<{ monthlyMeters: number }>('/admin/goals') });
  const [v, setV] = useState('');
  useEffect(() => { if (q.data) setV(String(q.data.monthlyMeters || '')); }, [q.data]);
  const [saved, setSaved] = useState(false);
  const save = useMutation({
    mutationFn: () => api.put('/admin/goals', { monthlyMeters: Number(v || 0) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['goals'] }); setSaved(true); setTimeout(() => setSaved(false), 4000); },
  });
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-medium">Цель месяца для мастериц</h2>
      <p className="text-sm text-muted">Мастерица видит на главной: «27 из 90 м», своё место среди всех и значки. Это не деньги — премию, если хотите, начисляете сами. Для отдельной мастерицы цель можно изменить на её странице.</p>
      <Card className="space-y-3">
        <Field label="Метров в месяц (0 — без цели)" htmlFor="goal-m"><Input id="goal-m" inputMode="numeric" value={v} onChange={(e) => setV(e.target.value.replace(/\D/g, ''))} placeholder="например, 90" /></Field>
        {save.isError && <ErrorState error={save.error} />}
        {saved && <p className="text-sm text-ok" role="status">✓ Сохранено. Мастерицы уже видят новую цель.</p>}
        <Button onClick={() => { setSaved(false); save.mutate(); }} disabled={save.isPending}>{save.isPending ? 'Сохраняем…' : 'Сохранить'}</Button>
      </Card>
    </section>
  );
}

/** Worker page: her progress this month, badges, and a personal goal (or back to the common one). */
export function WorkerGoalCard({ workerId, canEdit }: { workerId: string; canEdit: boolean }) {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['worker-goal', workerId], queryFn: () => api.get<Goal>(`/admin/workers/${workerId}/goal`) });
  const [editing, setEditing] = useState(false);
  const [v, setV] = useState('');
  const save = useMutation({
    mutationFn: (m: number | null) => api.put(`/admin/workers/${workerId}/goal`, { monthlyMeters: m }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['worker-goal', workerId] }); setEditing(false); },
  });
  const g = q.data;
  if (!g || !Array.isArray(g.badges)) return null; // not loaded / not allowed / unexpected: the rest of the page stays as it is
  return (
    <Card className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold">Цель месяца {g.personal && <span className="font-normal text-muted">(личная)</span>}</h2>
        {g.place && <span className="rounded-full bg-primary/10 px-3 py-0.5 text-sm font-semibold text-primary">{g.place}-е место из {g.of}</span>}
      </div>
      {g.goalMeters > 0 ? (
        <>
          <p className="text-lg font-semibold">{g.doneMeters} из {g.goalMeters} м</p>
          <div className="h-3 overflow-hidden rounded-full bg-border" role="progressbar" aria-valuenow={g.percent ?? 0} aria-valuemin={0} aria-valuemax={100}>
            <div className="h-full rounded-full bg-primary" style={{ width: `${g.percent ?? 0}%` }} />
          </div>
          <p className="text-sm text-muted">{(g.leftMeters ?? 0) <= 0 ? 'Цель выполнена 🎉' : `Ещё ${g.leftMeters} м · до конца месяца ${g.daysLeft} дн.`}</p>
        </>
      ) : <p className="text-sm">Принято в этом месяце: <b>{g.doneMeters} м</b> · цель не задана</p>}
      <div className="flex flex-wrap gap-2">
        {g.badges.map((b) => (
          <span key={b.code} title={b.hint} className={`rounded-full px-3 py-1 text-xs font-medium ${b.earned ? 'bg-primary/15 text-primary' : 'bg-border/60 text-muted'}`}>{b.earned ? '★ ' : ''}{b.title}</span>
        ))}
      </div>
      {canEdit && !editing && (
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => { setV(String(g.goalMeters || '')); setEditing(true); }}>Изменить цель для неё</Button>
          {g.personal && <Button variant="ghost" onClick={() => save.mutate(null)} disabled={save.isPending}>Вернуть общую цель</Button>}
        </div>
      )}
      {editing && (
        <div className="flex flex-wrap items-end gap-2">
          <Field label="Метров в месяц" htmlFor="wg-m"><Input id="wg-m" inputMode="numeric" value={v} onChange={(e) => setV(e.target.value.replace(/\D/g, ''))} autoFocus /></Field>
          <Button onClick={() => save.mutate(Number(v || 0))} disabled={save.isPending}>Сохранить</Button>
          <Button variant="ghost" onClick={() => setEditing(false)}>Отмена</Button>
        </div>
      )}
      {save.isError && <ErrorState error={save.error} />}
    </Card>
  );
}
