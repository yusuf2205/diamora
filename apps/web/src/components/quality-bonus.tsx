'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState, Input } from '@/components/ui';

export interface QualityBonus { enabled: boolean; percent: number; maxDefectPercent: number; minMeters: number }

/** «Бонус за качество»: + N % of the month's earnings for a month with few defects, paid on the 1st by itself. */
export function QualityBonusSection({ canManage }: { canManage: boolean }) {
  const qc = useQueryClient();
  const q = useQuery<QualityBonus>({ queryKey: ['quality-bonus'], queryFn: () => api.get<QualityBonus>('/admin/quality-bonus') });
  const [form, setForm] = useState<QualityBonus | null>(null);
  useEffect(() => { if (q.data) setForm(q.data); }, [q.data]);
  const save = useMutation({
    mutationFn: (b: QualityBonus) => api.put<QualityBonus>('/admin/quality-bonus', b),
    onSuccess: (b) => { qc.setQueryData(['quality-bonus'], b); setForm(b); },
  });
  const num = (v: string) => Number(v.replace(/\D/g, '') || '0');
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-medium">Бонус за качество</h2>
      {q.error && <ErrorState error={q.error} />}
      {form && (
        <Card className="space-y-3">
          <p className="text-sm text-muted">
            Мастерица получает надбавку к заработку за месяц, если брака было мало. Бонус начисляется сам 1-го числа за прошлый месяц
            и сразу виден ей в приложении. Пока месяц идёт, она видит, получит ли бонус.
          </p>
          <label className="flex items-center gap-2 text-sm font-medium">
            <input type="checkbox" checked={form.enabled} disabled={!canManage} onChange={(e) => setForm({ ...form, enabled: e.target.checked })} />
            Включить бонус
          </label>
          <div className="grid gap-3 sm:grid-cols-3">
            <label className="text-sm text-muted">Бонус, % от заработка
              <Input inputMode="numeric" value={String(form.percent)} disabled={!canManage} onChange={(e) => setForm({ ...form, percent: num(e.target.value) })} />
            </label>
            <label className="text-sm text-muted">Брака не больше, %
              <Input inputMode="numeric" value={String(form.maxDefectPercent)} disabled={!canManage} onChange={(e) => setForm({ ...form, maxDefectPercent: num(e.target.value) })} />
            </label>
            <label className="text-sm text-muted">Сдано за месяц не меньше, м
              <Input inputMode="numeric" value={String(form.minMeters)} disabled={!canManage} onChange={(e) => setForm({ ...form, minMeters: num(e.target.value) })} />
            </label>
          </div>
          <p className="rounded-lg bg-ok/10 p-3 text-sm">
            Пример: заработала за месяц 1 000 000 сум, брака {form.maxDefectPercent}% или меньше, сдала от {form.minMeters} м →
            бонус <b>{Math.round(1_000_000 * form.percent / 100).toLocaleString('ru-RU')} сум</b>.
          </p>
          {canManage && (
            <Button onClick={() => save.mutate(form)} disabled={save.isPending || form.percent < 1}>Сохранить</Button>
          )}
          {save.isError && <ErrorState error={save.error} />}
          {save.isSuccess && <p className="text-sm text-ok">Сохранено</p>}
        </Card>
      )}
    </section>
  );
}
