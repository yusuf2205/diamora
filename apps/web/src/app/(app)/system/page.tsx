'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { Badge, Card, EmptyState, ErrorState, ListSkeleton, PageHeader } from '@/components/ui';
import { OffsiteCard } from '@/components/offsite-card';

interface Status {
  now: string; version: string | null; uptimeSeconds: number;
  database: { ok: boolean; ms: number | null; size: string | null }; redis: { ok: boolean; ms: number | null };
  backupsVisible: boolean; backups: { job: string; ok: boolean; at: string | null; bytes: number | null }[];
}

// job names as the backup scripts write them (infra/backup/*.sh: JOB=...)
const JOB: Record<string, string> = { pg_dump: 'База данных (каждый день)', pg_basebackup: 'Полная копия базы (раз в неделю)', minio_mirror: 'Фото и файлы', config: 'Настройки', offsite: 'Копия на внешнем диске', verify: 'Проверка восстановления', restore: 'Восстановление' };
const hours = (iso: string | null) => (iso ? (Date.now() - new Date(iso).getTime()) / 3_600_000 : Infinity);
const size = (b: number | null) => (b == null ? '' : b > 1e9 ? `${(b / 1e9).toFixed(1)} ГБ` : b > 1e6 ? `${(b / 1e6).toFixed(1)} МБ` : `${Math.round(b / 1e3)} КБ`);
const uptime = (s: number) => (s > 86_400 ? `${Math.floor(s / 86_400)} дн` : s > 3600 ? `${Math.floor(s / 3600)} ч` : `${Math.floor(s / 60)} мин`);

/** «Состояние системы»: is everything up, and when did each backup last succeed. Refreshes every 30 s. */
export default function SystemPage() {
  const { me } = useAuth();
  const allowed = me?.role === 'SUPER_ADMIN' || hasPerm(me, 'SETTINGS_MANAGE');
  const { data, error, isLoading, refetch } = useQuery<Status>({ queryKey: ['system'], queryFn: () => api.get<Status>('/admin/system/status'), refetchInterval: 30_000, enabled: allowed });
  if (!allowed) return <EmptyState title="Недостаточно прав" />;
  const ok = (v: boolean, label = v ? 'работает' : 'не отвечает') => <Badge tone={v ? 'ok' : 'danger'}>{label}</Badge>;
  return (
    <div className="max-w-3xl space-y-4 sm:space-y-6">
      <PageHeader title="Состояние системы" subtitle="Работает ли сервер и когда была последняя резервная копия." />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton rows={4} />}
      {data && (
        <>
          <Card>
            <ul className="divide-y divide-border text-sm">
              <li className="flex items-center justify-between py-2"><span>Сервер</span><span className="flex items-center gap-2 text-muted">работает {uptime(data.uptimeSeconds)}{data.version ? ` · версия ${data.version}` : ''} {ok(true)}</span></li>
              <li className="flex items-center justify-between py-2"><span>База данных</span><span className="flex items-center gap-2 text-muted">{data.database.size ?? ''}{data.database.ms != null ? ` · ${data.database.ms} мс` : ''} {ok(data.database.ok)}</span></li>
              <li className="flex items-center justify-between py-2"><span>Быстрая память (Redis)</span><span className="flex items-center gap-2 text-muted">{data.redis.ms != null ? `${data.redis.ms} мс` : ''} {ok(data.redis.ok)}</span></li>
            </ul>
          </Card>
          <Card>
            <h2 className="mb-2 text-sm font-semibold">Резервные копии</h2>
            {!data.backupsVisible && <p className="text-sm text-muted">Сервер не видит папку с отметками резервных копий.</p>}
            {data.backupsVisible && data.backups.length === 0 && <p className="text-sm text-muted">Копий ещё не было.</p>}
            <ul className="divide-y divide-border text-sm">
              {data.backups.map((b) => {
                const late = hours(b.at) > (b.job === 'pg_basebackup' ? 8 * 24 : b.job === 'restore' ? Infinity : 26);
                return (
                  <li key={b.job} className="flex items-center justify-between gap-3 py-2">
                    <span>{JOB[b.job] ?? b.job}</span>
                    <span className="flex items-center gap-2 text-muted">
                      {b.at ? formatDate(b.at) : '—'}{b.bytes ? ` · ${size(b.bytes)}` : ''}
                      {ok(b.ok && !late, !b.ok ? 'ошибка' : late ? 'давно не было' : 'в порядке')}
                    </span>
                  </li>
                );
              })}
            </ul>
          </Card>
        </>
      )}
      {me?.role === 'SUPER_ADMIN' && <OffsiteCard />}
    </div>
  );
}
