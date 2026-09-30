'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Phone } from 'lucide-react';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { Button, Card, EmptyState, ErrorState, ListSkeleton, PageHeader, Select } from '@/components/ui';

interface Order { id: string; code: string; name: string; phone: string; product: { id: string; name: string } | null; colorName: string | null; quantity: number | null; comment: string | null; status: Status; staffNote: string | null; createdAt: string }
type Status = 'NEW' | 'CONFIRMED' | 'IN_WORK' | 'DONE' | 'CANCELLED';

const LABEL: Record<Status, string> = { NEW: 'Новые', CONFIRMED: 'Подтверждены', IN_WORK: 'В работе', DONE: 'Выполнены', CANCELLED: 'Отменены' };
const ONE: Record<Status, string> = { NEW: 'Новый', CONFIRMED: 'Подтверждён', IN_WORK: 'В работе', DONE: 'Выполнен', CANCELLED: 'Отменён' };
const TONE: Record<Status, string> = { NEW: 'bg-primary text-white', CONFIRMED: 'bg-sky-100 text-sky-900', IN_WORK: 'bg-amber-100 text-amber-900', DONE: 'bg-emerald-100 text-emerald-900', CANCELLED: 'bg-border text-muted' };

/** «Заказы клиентов»: what customers ordered on diamoraa.uz/order; call back and move it along. */
export default function OrdersPage() {
  const { me } = useAuth();
  const [status, setStatus] = useState<Status | ''>('NEW');
  const q = useQuery({ queryKey: ['client-orders', status], queryFn: () => api.get<{ items: Order[]; counts: Partial<Record<Status, number>> }>('/admin/orders', { status: status || undefined }) });
  const canManage = hasPerm(me, 'CATALOG_MANAGE');
  if (!hasPerm(me, 'CATALOG_VIEW', 'CATALOG_MANAGE')) return <EmptyState title="Недостаточно прав" />;
  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Заказы клиентов" subtitle="Заказы с сайта diamoraa.uz/order. Позвоните покупателю и отметьте, на каком этапе заказ." />
      <div className="flex flex-wrap gap-2">
        {(['NEW', 'CONFIRMED', 'IN_WORK', 'DONE', 'CANCELLED', ''] as const).map((s) => (
          <button key={s || 'all'} type="button" onClick={() => setStatus(s)}
            className={`rounded-full border px-4 py-1.5 text-sm font-medium ${status === s ? 'border-primary bg-primary text-white' : 'border-border hover:bg-border/40'}`}>
            {s ? LABEL[s] : 'Все'}{s && q.data?.counts[s] ? ` · ${q.data.counts[s]}` : ''}
          </button>
        ))}
      </div>
      {q.error && <ErrorState error={q.error} onRetry={() => q.refetch()} />}
      {q.isLoading && <ListSkeleton />}
      {q.data?.items.length === 0 && <EmptyState title={status === 'NEW' ? 'Новых заказов нет' : 'Здесь пока пусто'} hint="Ссылка для покупателей: diamoraa.uz/order" />}
      <div className="grid gap-3 lg:grid-cols-2">
        {q.data?.items.map((o) => <OrderCard key={o.id} order={o} canManage={canManage} />)}
      </div>
    </div>
  );
}

function OrderCard({ order: o, canManage }: { order: Order; canManage: boolean }) {
  const qc = useQueryClient();
  const [note, setNote] = useState(o.staffNote ?? '');
  const save = useMutation({
    mutationFn: (b: { status?: Status; staffNote?: string | null }) => api.patch(`/admin/orders/${o.id}`, b),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['client-orders'] }),
  });
  return (
    <Card className="space-y-2">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="font-semibold">{o.name} <span className="text-sm font-normal text-muted">· {o.code} · {formatDate(o.createdAt)}</span></p>
          <a href={`tel:${o.phone}`} className="inline-flex items-center gap-1.5 text-primary hover:underline"><Phone size={15} aria-hidden />{o.phone}</a>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-0.5 text-xs font-semibold ${TONE[o.status]}`}>{ONE[o.status]}</span>
      </div>
      <p className="text-sm">
        {o.product ? <b>{o.product.name}</b> : <span className="text-muted">Изделие не выбрано</span>}
        {o.colorName && ` · ${o.colorName}`}{o.quantity !== null && ` · ${o.quantity} м`}
      </p>
      {o.comment && <p className="rounded-lg bg-background p-2 text-sm">«{o.comment}»</p>}
      {canManage && (
        <div className="flex flex-wrap items-center gap-2 pt-1">
          <Select aria-label="Этап заказа" value={o.status} onChange={(e) => save.mutate({ status: e.target.value as Status })} className="w-auto">
            {(Object.keys(ONE) as Status[]).map((s) => <option key={s} value={s}>{ONE[s]}</option>)}
          </Select>
          <input aria-label="Заметка" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Заметка: договорились на пятницу…"
            className="min-w-0 flex-1 rounded-lg border border-border bg-background px-3 py-2 text-sm" />
          {note !== (o.staffNote ?? '') && <Button variant="outline" onClick={() => save.mutate({ staffNote: note.trim() || null })} disabled={save.isPending}>Сохранить</Button>}
        </div>
      )}
      {!canManage && o.staffNote && <p className="text-sm text-muted">Заметка: {o.staffNote}</p>}
      {save.isError && <ErrorState error={save.error} />}
    </Card>
  );
}
