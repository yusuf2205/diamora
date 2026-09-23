'use client';

import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { Dashboard } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Button, Card, ErrorState, StatCard, StatCardSkeleton } from '@/components/ui';
import { CreateAssignmentDialog } from '../assignments/page';

export default function DashboardPage() {
  const { me } = useAuth();
  const router = useRouter();
  const [creating, setCreating] = useState(false);
  const { data, error, isLoading, refetch } = useQuery<Dashboard>({ queryKey: ['dashboard'], queryFn: () => api.get<Dashboard>('/dashboard'), refetchInterval: 30_000 });

  const canCreateAssignment = hasPerm(me, 'ASSIGNMENT_CREATE');
  const canSeeAssignments = hasPerm(me, 'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED');
  const canSeeWorkers = hasPerm(me, 'WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED');

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Обзор</h1>
          <p className="text-sm text-muted">Данные — с нашего NAS, обновляются каждые 30 секунд.</p>
        </div>
        {(canCreateAssignment || canSeeAssignments || canSeeWorkers) && (
          <div className="flex gap-2">
            {canCreateAssignment && <Button onClick={() => setCreating(true)}>Выдать работу</Button>}
            {canSeeAssignments && <Button variant="outline" onClick={() => router.push('/assignments')}>Задания</Button>}
            {canSeeWorkers && <Button variant="outline" onClick={() => router.push('/workers')}>Мастерицы</Button>}
          </div>
        )}
      </div>

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
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <StatCard label="Активных" value={data.work.activeAssignments} hint="комплектов у мастериц" />
                <StatCard label="В работе" value={data.work.inProgress} href="/assignments?status=IN_PROGRESS" />
                <StatCard label="Нужно доставить" value={data.work.toDeliver} href="/assignments?status=READY_TO_DELIVER" />
                <StatCard label="Есть что забрать" value={data.work.toPickup} href="/assignments?status=READY_FOR_PICKUP" />
                <StatCard label="Требуют приёмки" value={data.work.needsAcceptance} href="/assignments?status=UNDER_REVIEW" />
                <StatCard label="Закрыто" value={data.work.completed} href="/assignments?status=COMPLETED" />
                <StatCard label="Просрочено" value={data.work.overdue} hint="доставлено, но срок прошёл" />
                <StatCard label="Метров на руках" value={data.work.metersOnHand} />
              </div>
            </section>
          )}

          {data.workers && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Мастерицы</h2>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
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
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <StatCard label="Начислено" value={formatUzs(data.finance.earned)} />
                <StatCard label="Выплачено" value={formatUzs(data.finance.paid)} />
                <StatCard label="К выплате" value={formatUzs(data.finance.due)} />
              </div>
              <Card className="mt-4 text-sm text-muted">
                Продажи, расходы и чистая прибыль появятся на этапе M6 — сейчас эти данные ещё не ведутся в системе, поэтому мы не показываем выдуманные цифры.
              </Card>
            </section>
          )}

          {data.materials && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Материалы</h2>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <StatCard label="Низкий остаток" value={data.materials.lowStock} />
                <StatCard label="Закончились" value={data.materials.outOfStock} />
              </div>
              <Card className="mt-4 text-sm text-muted">
                Полный склад с движениями и приходом появится на этапе M5 — сейчас здесь только сводные цифры.
              </Card>
            </section>
          )}

          {data.catalog && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Каталог</h2>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                <StatCard label="Опубликовано" value={data.catalog.published} />
                <StatCard label="Черновиков" value={data.catalog.draft} />
              </div>
            </section>
          )}

          {data.users && (
            <section>
              <h2 className="mb-3 text-sm font-medium text-muted">Команда</h2>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
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
