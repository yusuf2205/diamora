'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { HardDrive, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState, ListSkeleton } from '@/components/ui';

interface Offsite {
  found: boolean; drive?: string; freeBytes?: number | null; totalBytes?: number | null; updated?: string | null;
  copies?: { path: string; kind: 'daily' | 'weekly' | 'monthly'; name: string; at: string | null; bytes: number }[];
  photosBytes?: number; baseBytes?: number; usedBytes?: number;
}
const KIND: Record<string, string> = { daily: 'за день', weekly: 'за неделю', monthly: 'за месяц' };
const gb = (b: number | null | undefined) => (b == null ? '—' : b >= 1e9 ? `${(b / 1e9).toFixed(1)} ГБ` : b >= 1e6 ? `${(b / 1e6).toFixed(1)} МБ` : `${Math.max(1, Math.round(b / 1e3))} КБ`);
const when = (iso: string | null) => (iso ? new Date(iso).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');

/**
 * «Внешний диск» (SUPER_ADMIN): what the external drive keeps and how much space is left. Database copies stay there as
 * a long history (the NAS keeps only the last days / weeks / months); old ones can be removed here - and are never
 * copied back. Photos, settings and the full copy are kept up to date by the nightly job and are not removable here.
 */
export function OffsiteCard() {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['offsite'], queryFn: () => api.get<Offsite>('/admin/backups/offsite') });
  const [howTo, setHowTo] = useState(false);
  const remove = useMutation({ mutationFn: (path: string) => api.delete(`/admin/backups/offsite?path=${encodeURIComponent(path)}`), onSuccess: () => qc.invalidateQueries({ queryKey: ['offsite'] }) });
  const d = q.data;
  return (
    <Card className="space-y-3">
      <div className="flex items-center gap-3">
        <HardDrive size={22} className="text-primary" aria-hidden />
        <h2 className="flex-1 font-semibold">Внешний диск</h2>
        {d?.found && <span className="text-sm text-muted">свободно {gb(d.freeBytes)} из {gb(d.totalBytes)}</span>}
      </div>
      {q.error && <ErrorState error={q.error} />}
      {q.isLoading && <ListSkeleton rows={2} />}
      {d && !d.found && <p className="text-sm text-danger">Внешний диск не найден. Подключите его к NAS — копия сделается сама этой ночью.</p>}
      {d?.found && (
        <>
          <p className="text-sm text-muted">
            Обновлено: {d.updated ? `${d.updated} (UTC)` : '—'} · занято копиями {gb(d.usedBytes)} · фото и файлы {gb(d.photosBytes)} · полная копия базы {gb(d.baseBytes)}
          </p>
          <div>
            <p className="mb-1 text-sm font-semibold">Копии базы данных ({d.copies?.length ?? 0})</p>
            <ul className="max-h-80 divide-y divide-border overflow-y-auto rounded-lg border border-border">
              {d.copies?.map((c) => (
                <li key={c.path} className="flex items-center gap-3 px-3 py-2 text-sm">
                  <span className="min-w-0 flex-1"><b>{when(c.at)}</b> <span className="text-muted">· копия {KIND[c.kind]} · {gb(c.bytes)}</span></span>
                  <button type="button" aria-label={`Удалить копию от ${when(c.at)}`} className="rounded p-1.5 text-muted hover:bg-danger/10 hover:text-danger" disabled={remove.isPending}
                    onClick={() => { if (confirm(`Удалить копию от ${when(c.at)} с внешнего диска? Её нельзя будет вернуть.`)) remove.mutate(c.path); }}>
                    <Trash2 size={16} aria-hidden />
                  </button>
                </li>
              ))}
            </ul>
          </div>
          {remove.isError && <ErrorState error={remove.error} />}
        </>
      )}
      <Button variant="outline" onClick={() => setHowTo(!howTo)}>{howTo ? 'Скрыть' : 'Как восстановить данные с диска'}</Button>
      {howTo && (
        <div className="space-y-2 rounded-lg bg-background p-3 text-sm">
          <p><b>Когда это нужно:</b> если сломались диски NAS или данные случайно испорчены. В обычной жизни ничего делать не нужно — копии делаются сами каждую ночь.</p>
          <ol className="list-decimal space-y-1 pl-5">
            <li>Не удаляйте ничего на внешнем диске и не форматируйте его.</li>
            <li>Если NAS работает — просто напишите разработчику: «восстанови базу от &lt;дата&gt;». Копия выбирается по дате из списка выше.</li>
            <li>Если NAS сломан — отключите внешний диск и подключите его к новому NAS или компьютеру; разработчик поднимет Diamoraa заново и восстановит базу, фото и настройки с этого диска.</li>
            <li>Восстановление всегда идёт в <b>новую пустую базу</b>: текущие данные не стираются, пока вы не убедитесь, что всё на месте.</li>
          </ol>
          <p className="text-muted">Подробная инструкция для разработчика — в файле ПРОЧТИ.txt на самом диске и в docs/RESTORE-FROM-USB.md.</p>
        </div>
      )}
    </Card>
  );
}
