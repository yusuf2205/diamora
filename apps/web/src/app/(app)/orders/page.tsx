'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Phone } from 'lucide-react';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate } from '@/lib/format';
import { Button, Card, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select } from '@/components/ui';

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
  // every staff member takes and handles customer orders (owner, 2026-10-01)
  const canManage = !!me && me.role !== 'WORKER';
  const [adding, setAdding] = useState(false);
  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Заказы клиентов" subtitle="Запишите заказ покупателя и отмечайте, на каком он этапе." actions={canManage && <Button onClick={() => setAdding(true)}>+ Новый заказ</Button>} />
      {adding && <NewOrderModal onClose={() => setAdding(false)} />}
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
      {q.data?.items.length === 0 && <EmptyState title={status === 'NEW' ? 'Новых заказов нет' : 'Здесь пока пусто'} hint="Нажмите «+ Новый заказ», когда покупатель позвонит или напишет" />}
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

interface OrderProduct { id: string; name: string; colors: { name: string; hex: string | null }[] }

/** A customer's order, taken by phone / Telegram / in person. */
function NewOrderModal({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const products = useQuery({ queryKey: ['order-products'], queryFn: () => api.get<{ items: OrderProduct[] }>('/admin/orders/products') });
  const [productId, setProductId] = useState('');
  const [color, setColor] = useState('');
  const [meters, setMeters] = useState('');
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('+998 ');
  const [comment, setComment] = useState('');
  const product = products.data?.items.find((p) => p.id === productId);
  const save = useMutation({
    mutationFn: () => api.post('/admin/orders', {
      name: name.trim(), phone: phone.trim(), productModelId: productId || undefined, colorName: color || undefined,
      quantity: meters ? Number(meters.replace(',', '.')) : undefined, comment: comment.trim() || undefined,
    }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['client-orders'] }); onClose(); },
  });
  return (
    <Modal title="Новый заказ" onClose={onClose}>
      <div className="space-y-3">
        <Field label="Изделие" htmlFor="no-p">
          <Select id="no-p" value={productId} onChange={(e) => { setProductId(e.target.value); setColor(''); }}>
            <option value="">— не выбрано —</option>
            {products.data?.items.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Select>
        </Field>
        {!!product?.colors.length && (
          <div className="flex flex-wrap gap-2">
            {product.colors.map((c) => (
              <button key={c.name} type="button" aria-pressed={color === c.name} onClick={() => setColor(c.name)}
                className={`flex items-center gap-2 rounded-full border-2 px-3 py-1.5 text-sm ${color === c.name ? 'border-primary bg-primary/10' : 'border-border'}`}>
                <span className="h-3.5 w-3.5 rounded-full border border-border" style={{ background: c.hex ?? undefined }} />{c.name}
              </button>
            ))}
          </div>
        )}
        <Field label="Сколько метров" htmlFor="no-m"><Input id="no-m" inputMode="decimal" value={meters} onChange={(e) => setMeters(e.target.value.replace(/[^\d.,]/g, ''))} /></Field>
        <Field label="Покупатель *" htmlFor="no-n"><Input id="no-n" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label="Телефон *" htmlFor="no-t"><Input id="no-t" type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
        <Field label="Комментарий" htmlFor="no-c"><Input id="no-c" value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Срок, адрес, пожелания…" /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex justify-end gap-2 pt-1">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || name.trim().length < 2 || phone.replace(/\D/g, '').length < 9}>Сохранить заказ</Button>
        </div>
      </div>
    </Modal>
  );
}
