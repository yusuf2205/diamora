'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs, roleLabel } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { Dashboard } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Button, ErrorState, PageHeader, StatCard, StatCardSkeleton, useIsPhone } from '@/components/ui';
import { CreateAssignmentDialog } from '../assignments/page';

export default function DashboardPage() {
  const { me } = useAuth();
  const router = useRouter();
  const [creating, setCreating] = useState(false);
  const phone = useIsPhone();
  const { data, error, isLoading, refetch } = useQuery<Dashboard>({ queryKey: ['dashboard'], queryFn: () => api.get<Dashboard>('/dashboard'), refetchInterval: 30_000 });

  const canCreateAssignment = hasPerm(me, 'ASSIGNMENT_CREATE');
  const canSeeAssignments = hasPerm(me, 'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED');
  const canSeeWorkers = hasPerm(me, 'WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED');

  const hour = Number(new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Tashkent', hour: '2-digit', hourCycle: 'h23' }).format(new Date()));
  const greeting = hour < 12 ? 'Доброе утро' : hour < 18 ? 'Добрый день' : 'Добрый вечер';
  const firstName = me?.fullName.split(/\s+/)[0] ?? '';

  const attention: { text: string; href: string; tone: 'danger' | 'warn' }[] = [];
  if (data?.work) {
    const w = data.work;
    if (w.overdue) attention.push({ text: `Просрочено работ: ${w.overdue}`, href: '/assignments?status=IN_PROGRESS', tone: 'danger' });
    if (w.toDeliver) attention.push({ text: `Нужно доставить: ${w.toDeliver}`, href: '/assignments?status=READY_TO_DELIVER', tone: 'warn' });
    if (w.toPickup) attention.push({ text: `Есть что забрать: ${w.toPickup}`, href: '/assignments?status=READY_FOR_PICKUP', tone: 'warn' });
    if (w.needsAcceptance) attention.push({ text: `Ждут приёмки: ${w.needsAcceptance}`, href: '/assignments?status=UNDER_REVIEW', tone: 'warn' });
    if (w.reworkRequired) attention.push({ text: `На доработке: ${w.reworkRequired}`, href: '/assignments?status=REWORK_REQUIRED', tone: 'warn' });
  }
  if (data?.finance?.workersDue) attention.push({ text: `Ждут выплату мастериц: ${data.finance.workersDue}`, href: '/workers?status=ACTIVE', tone: 'warn' });

  return (
    <div className="space-y-5 sm:space-y-6">
      <PageHeader
        title={`${greeting}${firstName ? `, ${firstName}` : ''}`}
        subtitle={me ? roleLabel(me.role) : undefined}
        actions={(canCreateAssignment || canSeeAssignments || canSeeWorkers) ? (
          <>
            {canCreateAssignment && <Button onClick={() => setCreating(true)}>+ Выдать работу</Button>}
            {canSeeAssignments && !phone && <Button variant="outline" onClick={() => router.push('/assignments')}>Задания</Button>}
            {canSeeWorkers && !phone && <Button variant="outline" onClick={() => router.push('/workers')}>Мастерицы</Button>}
          </>
        ) : undefined}
      />

      {data && (data.work || data.finance) && (
        <section aria-label="Требует внимания" className="rounded-xl border border-border bg-card p-4 sm:p-5">
          <h2 className="mb-2 text-sm font-semibold">Требует внимания</h2>
          {attention.length === 0 ? (
            <p className="text-sm text-ok">✓ Всё под контролем</p>
          ) : (
            <ul className="divide-y divide-border">
              {attention.map((a) => (
                <li key={a.text}>
                  <Link href={a.href} className="flex min-h-11 items-center justify-between gap-3 py-2 text-sm hover:text-primary">
                    <span className="flex items-center gap-2"><span className={`h-2 w-2 shrink-0 rounded-full ${a.tone === 'danger' ? 'bg-danger' : 'bg-primary'}`} />{a.text}</span>
                    <span className="text-muted">›</span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {data?.today && Object.values(data.today).some((v) => v !== null) && (
        <section>
          <h2 className="mb-3 text-sm font-medium text-muted">Сегодня</h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
            {data.today.dueToday !== null && <StatCard label="Срок сегодня" value={data.today.dueToday} />}
            {data.today.deliveredToday !== null && <StatCard label="Доставлено" value={data.today.deliveredToday} />}
            {data.today.pickedUpToday !== null && <StatCard label="Забрано" value={data.today.pickedUpToday} />}
            {data.today.paidToday !== null && <StatCard label="Выплачено" value={formatUzs(data.today.paidToday)} />}
          </div>
        </section>
      )}

      {error && <ErrorState error={error} onRetry={() => refetch()} />}

      {isLoading && (
        <div className="space-y-6">
          {[0, 1, 2].map((s) => (
            <div key={s} className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              {[0, 1, 2, 3].map((c) => <StatCardSkeleton key={c} />)}
            </div>
          ))}
        </div>
      )}

      {data && (
        <>
          {data.work && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Задания</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Активных" value={data.work.activeAssignments} hint="комплектов у мастериц" />
                <StatCard label="В работе" value={data.work.inProgress} href="/assignments?status=IN_PROGRESS" />
                <StatCard label="Нужно доставить" value={data.work.toDeliver} href="/assignments?status=READY_TO_DELIVER" />
                <StatCard label="Есть что забрать" value={data.work.toPickup} href="/assignments?status=READY_FOR_PICKUP" />
                <StatCard label="Требуют приёмки" value={data.work.needsAcceptance} href="/assignments?status=UNDER_REVIEW" />
                <StatCard label="Закрыто" value={data.work.completed} href="/assignments?status=COMPLETED" />
                <StatCard label="Просрочено" value={data.work.overdue} hint="срок прошёл" tone={data.work.overdue ? 'danger' : undefined} />
                <StatCard label="Метров на руках" value={data.work.metersOnHand} />
              </div>
            </section>
          )}

          {data.workers && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Мастерицы</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Всего" value={data.workers.total} href="/workers" />
                <StatCard label="Активных" value={data.workers.active} href="/workers?status=ACTIVE" />
                <StatCard label="С заданием сейчас" value={data.workers.withActiveAssignment} />
                <StatCard label="Без задания" value={data.workers.withoutActiveAssignment} />
              </div>
            </section>
          )}

          {data.finance && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Финансы</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Начислено" value={formatUzs(data.finance.earned)} />
                <StatCard label="Выплачено" value={formatUzs(data.finance.paid)} />
                <StatCard label="К выплате" value={formatUzs(data.finance.due)} tone={data.finance.due !== '0' ? 'primary' : undefined} />
              </div>
            </section>
          )}

          {data.materials && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Материалы</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Низкий остаток" value={data.materials.lowStock} />
                <StatCard label="Закончились" value={data.materials.outOfStock} />
              </div>
            </section>
          )}

          {data.catalog && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Каталог</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Опубликовано" value={data.catalog.published} />
                <StatCard label="Черновиков" value={data.catalog.draft} />
              </div>
            </section>
          )}

          {data.users && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Команда</h2>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <StatCard label="Главных админов" value={data.users.superAdmins} />
                <StatCard label="Администраторов" value={data.users.admins} />
                <StatCard label="Менеджеров" value={data.users.managers} />
                <StatCard label="Сейчас в сети" value={data.users.online} />
              </div>
            </section>
          )}
        </>
      )}

      {creating && <CreateAssignmentDialog onClose={() => setCreating(false)} />}
    </div>
  );
}
