'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { formatUzs } from '@/lib/format';
import type { Dashboard } from '@/lib/types';
import { Card, ErrorState, StatCard } from '@/components/ui';

export default function DashboardPage() {
  const { data, error, isLoading } = useQuery<Dashboard>({ queryKey: ['dashboard'], queryFn: () => api.get<Dashboard>('/dashboard'), refetchInterval: 30_000 });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Обзор</h1>
        <p className="text-sm text-muted">Данные — с нашего NAS, обновляются каждые 30 секунд.</p>
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && (
        <>
          <section>
            <h2 className="mb-3 text-sm font-medium text-muted">Мастерицы</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <StatCard label="Всего" value={data.workers.total} />
              <StatCard label="Активных" value={data.workers.active} />
              <StatCard label="На рассмотрении" value={data.workers.pendingApproval} />
              <StatCard label="На паузе" value={data.workers.paused} />
            </div>
          </section>
          <section>
            <h2 className="mb-3 text-sm font-medium text-muted">Команда</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <StatCard label="Главных админов" value={data.users.superAdmins} />
              <StatCard label="Администраторов" value={data.users.admins} />
              <StatCard label="Менеджеров" value={data.users.managers} />
              <StatCard label="Сейчас в сети" value={data.users.online} />
            </div>
          </section>
          <section>
            <h2 className="mb-3 text-sm font-medium text-muted">Работа</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <StatCard label="В работе" value={data.work.activeAssignments} hint="комплектов у мастериц" />
              <StatCard label="Метров на руках" value={data.work.metersOnHand} />
              <StatCard label="Нужно доставить" value={data.work.toDeliver} />
              <StatCard label="Есть что забрать" value={data.work.toPickup} />
            </div>
          </section>
          <section>
            <h2 className="mb-3 text-sm font-medium text-muted">Финансы</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <StatCard label="Начислено" value={formatUzs(data.finance.earned)} />
              <StatCard label="Выплачено" value={formatUzs(data.finance.paid)} />
              <StatCard label="К выплате" value={formatUzs(data.finance.due)} />
              <StatCard label="Просрочено заданий" value={data.work.overdue} />
            </div>
            <Card className="mt-4 text-sm text-muted">
              Продажи, расходы и чистая прибыль появятся на этапе M6 — сейчас эти данные ещё не ведутся в системе, поэтому мы не показываем выдуманные цифры.
            </Card>
          </section>
          <section>
            <h2 className="mb-3 text-sm font-medium text-muted">Каталог</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <StatCard label="Опубликовано" value={data.catalog.published} />
              <StatCard label="Черновиков" value={data.catalog.draft} />
              <StatCard label="Материалов с нулевым остатком" value={data.inventory.lowStockMaterials} />
            </div>
          </section>
        </>
      )}
    </div>
  );
}
