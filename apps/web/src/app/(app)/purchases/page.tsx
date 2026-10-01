'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bot, Copy, Plus, Send, Trash2, Truck } from 'lucide-react';
import { useMemo, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate, formatUzs } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { Button, Card, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select } from '@/components/ui';

interface Supplier { id: string; name: string; phone: string | null; telegram: string | null; note: string | null; isActive: boolean; materials: number; botLinked: boolean }
interface Suggest { materialId: string; name: string; unitLabel: string; left: number; coming: number; minStock: number; dailyUse: number; daysLeft: number | null; quantity: number; lastPrice: string | null; supplier: { id: string; name: string } | null; reason: string }
interface Purchase {
  id: string; code: string; status: 'DRAFT' | 'ORDERED' | 'RECEIVED' | 'CANCELLED'; note: string | null; createdAt: string; receivedAt: string | null;
  supplier: { id: string; name: string; phone: string | null; telegram: string | null; botLinked: boolean } | null;
  sentByBotAt: string | null; supplierReply: 'ACCEPTED' | 'UNAVAILABLE' | null; supplierReplyAt: string | null;
  items: { id: string; material: { id: string; name: string }; unitLabel: string; quantity: number; unitPrice: string | null }[]; total: string; priced: boolean;
}
const STATUS: Record<Purchase['status'], string> = { DRAFT: 'Черновик', ORDERED: 'Заказано', RECEIVED: 'Получено', CANCELLED: 'Отменено' };
const digits = (v: string) => v.replace(/\D/g, '');
interface MaterialRow { id: string; name: string; unit: string; isActive: boolean; unitCost?: string | null; supplierId?: string | null }
const UNIT: Record<string, string> = { METER: 'м', GRAM: 'г', PCS: 'шт', SET: 'компл.', ROLL: 'рул.', PACKAGE: 'уп.' };

/** «Закупки»: what to buy (from the stock forecast), orders to suppliers as a message, receiving them onto the shelf. */
export default function PurchasesPage() {
  const { me } = useAuth();
  const canManage = hasPerm(me, 'INVENTORY_MANAGE');
  const [suppliersOpen, setSuppliersOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  if (!hasPerm(me, 'INVENTORY_VIEW', 'INVENTORY_MANAGE')) return <EmptyState title="Недостаточно прав" />;
  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Закупки" subtitle="Что пора купить, заказ поставщику прямо в Telegram и приход на склад по заказу."
        actions={<>
          <Button variant="outline" onClick={() => setSuppliersOpen(true)}>Поставщики</Button>
          {canManage && <Button onClick={() => setNewOpen(true)}><Plus size={16} aria-hidden /> Новый заказ</Button>}
        </>} />
      <ToBuy canManage={canManage} />
      <Orders canManage={canManage} />
      {suppliersOpen && <SuppliersModal canManage={canManage} onClose={() => setSuppliersOpen(false)} />}
      {newOpen && <NewPurchaseModal onClose={() => setNewOpen(false)} />}
    </div>
  );
}

function ToBuy({ canManage }: { canManage: boolean }) {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['purchase-suggest'], queryFn: () => api.get<{ items: Suggest[] }>('/admin/purchases/suggest') });
  const suppliers = useQuery({ queryKey: ['suppliers'], queryFn: () => api.get<{ items: Supplier[] }>('/admin/suppliers') });
  const [qty, setQty] = useState<Record<string, string>>({});
  const [price, setPrice] = useState<Record<string, string>>({});
  const [off, setOff] = useState<Set<string>>(new Set());
  // one order per supplier («без поставщика» is its own group)
  const groups = useMemo(() => {
    const g = new Map<string, { supplier: Suggest['supplier']; items: Suggest[] }>();
    for (const s of q.data?.items ?? []) {
      const k = s.supplier?.id ?? '';
      if (!g.has(k)) g.set(k, { supplier: s.supplier, items: [] });
      g.get(k)!.items.push(s);
    }
    return [...g.values()];
  }, [q.data]);
  const setSupplier = useMutation({
    mutationFn: ({ materialId, supplierId }: { materialId: string; supplierId: string | null }) => api.patch(`/admin/materials/${materialId}`, { supplierId }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['purchase-suggest'] }),
  });
  const create = useMutation({
    mutationFn: (g: { supplier: Suggest['supplier']; items: Suggest[] }) => api.post('/admin/purchases', {
      supplierId: g.supplier?.id ?? null,
      items: g.items.filter((s) => !off.has(s.materialId)).map((s) => ({
        materialId: s.materialId, quantity: (qty[s.materialId] ?? String(s.quantity)).replace(',', '.'),
        unitPrice: digits(price[s.materialId] ?? s.lastPrice ?? '') || null,
      })),
    }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['purchase-suggest'] }); qc.invalidateQueries({ queryKey: ['purchases'] }); },
  });
  return (
    <Card>
      <h2 className="mb-1 text-sm font-semibold">Что пора купить</h2>
      <p className="mb-3 text-xs text-muted">Всё, что ниже минимума или закончится в ближайшие 2 недели по расходу за 30 дней. Количество — примерно на месяц; можно поменять.</p>
      {q.error && <ErrorState error={q.error} />}
      {q.isLoading && <ListSkeleton rows={3} />}
      {q.data?.items.length === 0 && <p className="text-sm text-ok">✓ Всего хватает — покупать пока нечего.</p>}
      <div className="space-y-4">
        {groups.map((g) => (
          <div key={g.supplier?.id ?? 'none'} className="rounded-xl border border-border p-3">
            <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
              <p className="font-semibold">{g.supplier ? g.supplier.name : 'Поставщик не указан'}</p>
              {canManage && <Button onClick={() => create.mutate(g)} disabled={create.isPending || g.items.every((s) => off.has(s.materialId))}><Truck size={16} aria-hidden /> Создать заказ</Button>}
            </div>
            <div className="divide-y divide-border">
              {g.items.map((s) => (
                <div key={s.materialId} className={`grid grid-cols-[auto_1fr] items-center gap-x-3 gap-y-1 py-2 sm:grid-cols-[auto_1fr_7rem_8rem_10rem] ${off.has(s.materialId) ? 'opacity-50' : ''}`}>
                  <input type="checkbox" aria-label={`Купить ${s.name}`} className="h-5 w-5 accent-primary" checked={!off.has(s.materialId)} disabled={!canManage}
                    onChange={(e) => setOff((o) => { const n = new Set(o); if (e.target.checked) n.delete(s.materialId); else n.add(s.materialId); return n; })} />
                  <span className="min-w-0">
                    <span className="block font-medium">{s.name}</span>
                    <span className="block text-xs text-muted">{s.reason} · осталось {s.left} {s.unitLabel}{s.coming ? ` · едет ${s.coming}` : ''}</span>
                  </span>
                  <Input aria-label="Сколько купить" inputMode="decimal" disabled={!canManage} value={qty[s.materialId] ?? String(s.quantity)} onChange={(e) => setQty((v) => ({ ...v, [s.materialId]: e.target.value }))} className="col-start-2 sm:col-start-auto" />
                  <Input aria-label="Цена за единицу" inputMode="numeric" placeholder="цена, сум" disabled={!canManage} value={price[s.materialId] ?? s.lastPrice ?? ''} onChange={(e) => setPrice((v) => ({ ...v, [s.materialId]: e.target.value }))} className="col-start-2 sm:col-start-auto" />
                  {canManage && (
                    <Select aria-label="Поставщик" value={s.supplier?.id ?? ''} onChange={(e) => setSupplier.mutate({ materialId: s.materialId, supplierId: e.target.value || null })} className="col-start-2 sm:col-start-auto">
                      <option value="">— поставщик —</option>
                      {suppliers.data?.items.filter((x) => x.isActive).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                    </Select>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
      {create.isError && <ErrorState error={create.error} />}
    </Card>
  );
}

function Orders({ canManage }: { canManage: boolean }) {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['purchases'], queryFn: () => api.get<{ items: Purchase[] }>('/admin/purchases') });
  const [sending, setSending] = useState<Purchase | null>(null);
  const [receiving, setReceiving] = useState<Purchase | null>(null);
  const cancel = useMutation({ mutationFn: (id: string) => api.patch(`/admin/purchases/${id}`, { status: 'CANCELLED' }), onSuccess: () => { qc.invalidateQueries({ queryKey: ['purchases'] }); qc.invalidateQueries({ queryKey: ['purchase-suggest'] }); } });
  return (
    <Card>
      <h2 className="mb-3 text-sm font-semibold">Заказы поставщикам</h2>
      {q.data?.items.length === 0 && <p className="text-sm text-muted">Пока нет. Нажмите «+ Новый заказ» или создайте его из списка «Что пора купить».</p>}
      <div className="grid gap-3 lg:grid-cols-2">
        {q.data?.items.map((o) => (
          <div key={o.id} className="space-y-2 rounded-xl border border-border p-3">
            <div className="flex items-start justify-between gap-2">
              <p className="font-semibold">{o.code} · {o.supplier?.name ?? 'без поставщика'} <span className="text-sm font-normal text-muted">· {formatDate(o.createdAt)}</span></p>
              <span className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold ${o.status === 'RECEIVED' ? 'bg-emerald-100 text-emerald-900' : o.status === 'ORDERED' ? 'bg-sky-100 text-sky-900' : o.status === 'CANCELLED' ? 'bg-border text-muted' : 'bg-primary/10 text-primary'}`}>{STATUS[o.status]}</span>
            </div>
            <ul className="text-sm">
              {o.items.map((i) => <li key={i.id}>{i.material.name} — {i.quantity} {i.unitLabel}{i.unitPrice ? ` × ${formatUzs(i.unitPrice)}` : ''}</li>)}
            </ul>
            {o.sentByBotAt && <p className="text-xs text-muted">Отправлен в Telegram {formatDate(o.sentByBotAt)}{o.supplierReply ? '' : ' · ждём ответа'}</p>}
            {o.supplierReply && (
              <p className={`rounded-lg px-2.5 py-1.5 text-sm font-medium ${o.supplierReply === 'ACCEPTED' ? 'bg-emerald-50 text-emerald-900' : 'bg-red-50 text-red-900'}`}>
                {o.supplierReply === 'ACCEPTED' ? '✅ Поставщик принял заказ' : '❌ Поставщик: нет в наличии'}{o.supplierReplyAt ? ` · ${formatDate(o.supplierReplyAt)}` : ''}
              </p>
            )}
            {o.total !== '0' && <p className="text-sm">Сумма: <b>{formatUzs(o.total)} сум</b>{o.priced ? '' : ' (не у всех указана цена)'}</p>}
            {canManage && (o.status === 'DRAFT' || o.status === 'ORDERED') && (
              <div className="flex flex-wrap gap-2 pt-1">
                <Button variant="outline" onClick={() => setSending(o)}><Send size={16} aria-hidden /> {o.status === 'DRAFT' ? 'Отправить поставщику' : 'Сообщение ещё раз'}</Button>
                <Button onClick={() => setReceiving(o)}><Truck size={16} aria-hidden /> Принять на склад</Button>
                <Button variant="ghost" className="text-danger" onClick={() => { if (confirm(`Отменить заказ ${o.code}?`)) cancel.mutate(o.id); }}>Отменить</Button>
              </div>
            )}
          </div>
        ))}
      </div>
      {sending && <SendModal order={sending} onClose={() => setSending(null)} />}
      {receiving && <ReceiveModal order={receiving} onClose={() => setReceiving(null)} />}
    </Card>
  );
}

/** The order as a message: copy it, or open the supplier's Telegram with it ready; marks the order «Заказано». */
function SendModal({ order, onClose }: { order: Purchase; onClose: () => void }) {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['purchase-text', order.id], queryFn: () => api.get<{ text: string; telegram: string | null; phone: string | null; botLinked: boolean }>(`/admin/purchases/${order.id}/text`) });
  const viaBot = useMutation({ mutationFn: () => api.post(`/admin/purchases/${order.id}/send`, {}), onSuccess: () => { qc.invalidateQueries({ queryKey: ['purchases'] }); onClose(); } });
  const [copied, setCopied] = useState(false);
  const ordered = useMutation({ mutationFn: () => api.patch(`/admin/purchases/${order.id}`, { status: 'ORDERED' }), onSuccess: () => qc.invalidateQueries({ queryKey: ['purchases'] }) });
  const mark = () => { if (order.status === 'DRAFT') ordered.mutate(); };
  const text = q.data?.text ?? '';
  return (
    <Modal title={`Заказ ${order.code}`} onClose={onClose}>
      <div className="space-y-3">
        {q.data?.botLinked ? (
          <div className="space-y-2 rounded-xl border border-primary/30 bg-primary/5 p-3">
            <p className="text-sm">Заказ уйдёт поставщику в Telegram от нашего бота. У него будут кнопки «Принял» и «Нет в наличии» — ответ появится здесь.</p>
            <Button onClick={() => viaBot.mutate()} disabled={viaBot.isPending}><Bot size={16} aria-hidden /> {viaBot.isPending ? 'Отправляем…' : 'Отправить через бота'}</Button>
            {viaBot.isError && <ErrorState error={viaBot.error} />}
          </div>
        ) : order.supplier ? (
          <p className="rounded-xl bg-background p-3 text-sm text-muted">Чтобы отправлять заказы прямо отсюда, подключите поставщика к боту: «Поставщики» → «Подключить бота». А пока — скопируйте текст или откройте Telegram.</p>
        ) : null}
        <textarea readOnly value={text} rows={Math.min(14, text.split('\n').length + 1)} className="w-full rounded-lg border border-border bg-background p-3 text-sm" />
        <div className="flex flex-wrap gap-2">
          <Button onClick={async () => { await navigator.clipboard.writeText(text); setCopied(true); mark(); }}><Copy size={16} aria-hidden /> {copied ? 'Скопировано' : 'Скопировать'}</Button>
          <a className="inline-flex min-h-10 items-center gap-2 rounded-lg border border-border px-4 font-medium hover:bg-border/40" target="_blank" rel="noopener noreferrer" onClick={mark}
            href={q.data?.telegram ? `https://t.me/${q.data.telegram}` : `https://t.me/share/url?url=${encodeURIComponent(' ')}&text=${encodeURIComponent(text)}`}>
            <Send size={16} aria-hidden /> {q.data?.telegram ? `Открыть Telegram @${q.data.telegram}` : 'Отправить в Telegram'}
          </a>
          {q.data?.phone && <a className="inline-flex min-h-10 items-center rounded-lg border border-border px-4 font-medium hover:bg-border/40" href={`tel:${q.data.phone}`}>Позвонить {q.data.phone}</a>}
        </div>
        {q.data?.telegram && <p className="text-xs text-muted">Скопируйте текст и вставьте в чат поставщика.</p>}
      </div>
    </Modal>
  );
}

/** What really came, at what price: the stock goes up, the price becomes the material's purchase price. */
function ReceiveModal({ order, onClose }: { order: Purchase; onClose: () => void }) {
  const qc = useQueryClient();
  const [qty, setQty] = useState<Record<string, string>>(Object.fromEntries(order.items.map((i) => [i.id, String(i.quantity)])));
  const [price, setPrice] = useState<Record<string, string>>(Object.fromEntries(order.items.map((i) => [i.id, i.unitPrice ?? ''])));
  const receive = useMutation({
    mutationFn: () => api.post(`/admin/purchases/${order.id}/receive`, {
      items: order.items.map((i) => ({ itemId: i.id, quantity: (qty[i.id] || '0').replace(',', '.'), unitPrice: digits(price[i.id] ?? '') || null })),
    }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { for (const k of ['purchases', 'purchase-suggest', 'materials', 'stock-balances']) qc.invalidateQueries({ queryKey: [k] }); onClose(); },
  });
  return (
    <Modal title={`Принять ${order.code} на склад`} onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm text-muted">Укажите, сколько пришло на самом деле и по какой цене — склад увеличится, цена станет ценой закупки материала.</p>
        {order.items.map((i) => (
          <div key={i.id} className="grid grid-cols-[1fr_6rem_8rem] items-end gap-2">
            <p className="pb-2 text-sm font-medium">{i.material.name}</p>
            <Field label={`Пришло, ${i.unitLabel}`} htmlFor={`rq-${i.id}`}><Input id={`rq-${i.id}`} inputMode="decimal" value={qty[i.id]} onChange={(e) => setQty((v) => ({ ...v, [i.id]: e.target.value }))} /></Field>
            <Field label="Цена, сум" htmlFor={`rp-${i.id}`}><Input id={`rp-${i.id}`} inputMode="numeric" value={price[i.id]} onChange={(e) => setPrice((v) => ({ ...v, [i.id]: e.target.value }))} /></Field>
          </div>
        ))}
        {receive.isError && <ErrorState error={receive.error} />}
        <div className="flex justify-end gap-2 pt-1">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => receive.mutate()} disabled={receive.isPending}>Принять на склад</Button>
        </div>
      </div>
    </Modal>
  );
}

function SuppliersModal({ canManage, onClose }: { canManage: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['suppliers'], queryFn: () => api.get<{ items: Supplier[] }>('/admin/suppliers') });
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [telegram, setTelegram] = useState('');
  const [linking, setLinking] = useState<Supplier | null>(null);
  const unlink = useMutation({ mutationFn: (id: string) => api.delete(`/admin/suppliers/${id}/bot-link`), onSuccess: () => qc.invalidateQueries({ queryKey: ['suppliers'] }) });
  const add = useMutation({
    mutationFn: () => api.post('/admin/suppliers', { name: name.trim(), phone: phone.trim() || null, telegram: telegram.trim() || null }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['suppliers'] }); setName(''); setPhone(''); setTelegram(''); },
  });
  return (
    <Modal title="Поставщики" onClose={onClose}>
      <div className="space-y-3">
        {q.data?.items.length === 0 && <p className="text-sm text-muted">Пока никого. Добавьте, у кого покупаете ленту, бусины и нитки.</p>}
        <ul className="divide-y divide-border">
          {q.data?.items.map((s) => (
            <li key={s.id} className="py-2 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span><b>{s.name}</b>{s.phone ? ` · ${s.phone}` : ''}{s.telegram ? ` · @${s.telegram}` : ''} <span className="text-muted">· материалов: {s.materials}</span></span>
                {s.botLinked
                  ? <span className="inline-flex items-center gap-2"><span className="rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-semibold text-emerald-900">✓ Бот подключён</span>
                    {canManage && <button type="button" className="text-xs text-muted hover:underline" onClick={() => { if (confirm(`Отключить бота у «${s.name}»? Заказы перестанут приходить ему в Telegram.`)) unlink.mutate(s.id); }}>отключить</button>}</span>
                  : canManage && <Button variant="outline" onClick={() => setLinking(s)}><Bot size={16} aria-hidden /> Подключить бота</Button>}
              </div>
            </li>
          ))}
        </ul>
        {canManage && (
          <div className="space-y-2 rounded-xl border border-border p-3">
            <p className="text-sm font-semibold">Новый поставщик</p>
            <Input aria-label="Название" placeholder="Название, например «Бусы Чорсу»" value={name} onChange={(e) => setName(e.target.value)} />
            <div className="grid grid-cols-2 gap-2">
              <Input aria-label="Телефон" placeholder="Телефон" value={phone} onChange={(e) => setPhone(e.target.value)} />
              <Input aria-label="Telegram" placeholder="Telegram без @" value={telegram} onChange={(e) => setTelegram(e.target.value)} />
            </div>
            {add.isError && <ErrorState error={add.error} />}
            <Button onClick={() => add.mutate()} disabled={add.isPending || name.trim().length < 2}>Добавить</Button>
          </div>
        )}
        {linking && <BotLinkBox supplier={linking} onDone={() => setLinking(null)} />}
      </div>
    </Modal>
  );
}

/** A link for the supplier: they press «Старт» in our bot once, then orders go to their Telegram from the panel. */
function BotLinkBox({ supplier, onDone }: { supplier: Supplier; onDone: () => void }) {
  const q = useQuery({ queryKey: ['supplier-bot-link', supplier.id], queryFn: () => api.post<{ url: string; expiresInDays: number }>(`/admin/suppliers/${supplier.id}/bot-link`, {}), staleTime: Infinity, gcTime: 0 });
  const [copied, setCopied] = useState(false);
  const invite = q.data ? `Здравствуйте! Это Diamoraa. Чтобы получать наши заказы в Telegram, нажмите на ссылку и «Старт»:\n${q.data.url}` : '';
  return (
    <div className="space-y-2 rounded-xl border border-primary/30 bg-primary/5 p-3 text-sm">
      <p className="font-semibold">Подключить «{supplier.name}» к боту</p>
      <p>Отправьте поставщику эту ссылку. Он нажмёт её и «Старт» — и заказы будут приходить ему прямо в Telegram, а его ответ — сюда. Ссылка работает 7 дней.</p>
      {q.error && <ErrorState error={q.error} />}
      {q.data && (
        <>
          <Input readOnly value={q.data.url} aria-label="Ссылка для поставщика" onFocus={(e) => e.currentTarget.select()} />
          <div className="flex flex-wrap gap-2">
            <Button onClick={async () => { await navigator.clipboard.writeText(invite); setCopied(true); }}><Copy size={16} aria-hidden /> {copied ? 'Скопировано' : 'Скопировать приглашение'}</Button>
            <a className="inline-flex min-h-10 items-center gap-2 rounded-lg border border-border px-4 font-medium hover:bg-border/40" target="_blank" rel="noopener noreferrer"
              href={`https://t.me/share/url?url=${encodeURIComponent(q.data.url)}&text=${encodeURIComponent('Это Diamoraa: нажмите ссылку и «Старт», чтобы получать наши заказы в Telegram')}`}>
              <Send size={16} aria-hidden /> Отправить в Telegram
            </a>
            <Button variant="ghost" onClick={onDone}>Готово</Button>
          </div>
          <p className="text-xs text-muted">Когда поставщик нажмёт «Старт», здесь появится «✓ Бот подключён».</p>
        </>
      )}
    </div>
  );
}

interface Line { key: string; materialId: string; quantity: string; price: string }
const newLine = (): Line => ({ key: crypto.randomUUID(), materialId: '', quantity: '', price: '' });

/** Any order, whenever it is needed - not only what «Что пора купить» suggests. */
function NewPurchaseModal({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const suppliers = useQuery({ queryKey: ['suppliers'], queryFn: () => api.get<{ items: Supplier[] }>('/admin/suppliers') });
  const materials = useQuery({ queryKey: ['materials', 'all'], queryFn: () => api.get<{ items: MaterialRow[] }>('/admin/materials', { limit: 100 }) });
  const [supplierId, setSupplierId] = useState('');
  const [note, setNote] = useState('');
  const [lines, setLines] = useState<Line[]>(() => [newLine()]);
  const mats = (materials.data?.items ?? []).filter((m) => m.isActive);
  const byId = new Map(mats.map((m) => [m.id, m]));
  // the supplier's own materials first
  const sorted = supplierId ? [...mats].sort((a, b) => Number(b.supplierId === supplierId) - Number(a.supplierId === supplierId)) : mats;
  const set = (key: string, patch: Partial<Line>) => setLines((ls) => ls.map((l) => (l.key === key ? { ...l, ...patch } : l)));
  const ready = lines.filter((l) => l.materialId && Number(l.quantity.replace(',', '.')) > 0);
  const save = useMutation({
    mutationFn: () => api.post('/admin/purchases', {
      supplierId: supplierId || null, note: note.trim() || undefined,
      items: ready.map((l) => ({ materialId: l.materialId, quantity: l.quantity.replace(',', '.'), unitPrice: digits(l.price) || null })),
    }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['purchases'] }); qc.invalidateQueries({ queryKey: ['purchase-suggest'] }); onClose(); },
  });
  return (
    <Modal title="Новый заказ поставщику" onClose={onClose}>
      <div className="space-y-3">
        <Field label="Поставщик" htmlFor="np-s">
          <Select id="np-s" value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
            <option value="">— не выбран —</option>
            {suppliers.data?.items.filter((x) => x.isActive).map((x) => <option key={x.id} value={x.id}>{x.name}{x.botLinked ? ' · бот ✓' : ''}</option>)}
          </Select>
        </Field>
        {materials.error && <ErrorState error={materials.error} />}
        <div className="space-y-2">
          {lines.map((l, i) => {
            const m = byId.get(l.materialId);
            const unit = m ? UNIT[m.unit] ?? '' : '';
            return (
              <div key={l.key} className="grid grid-cols-[1fr_1fr_auto] gap-2 rounded-xl border border-border p-2 sm:grid-cols-[1fr_6rem_8rem_auto] sm:items-center sm:border-0 sm:p-0">
                <Select aria-label={`Материал ${i + 1}`} value={l.materialId} className="col-span-3 sm:col-span-1"
                  onChange={(e) => { const x = byId.get(e.target.value); set(l.key, { materialId: e.target.value, price: l.price || x?.unitCost || '' }); }}>
                  <option value="">— материал —</option>
                  {sorted.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                </Select>
                <Input aria-label="Сколько" placeholder={unit ? `кол-во, ${unit}` : 'кол-во'} inputMode="decimal" value={l.quantity} onChange={(e) => set(l.key, { quantity: e.target.value.replace(/[^\d.,]/g, '') })} />
                <Input aria-label="Цена за единицу" placeholder="цена, сум" inputMode="numeric" value={l.price} onChange={(e) => set(l.key, { price: digits(e.target.value) })} />
                <button type="button" aria-label="Убрать строку" disabled={lines.length === 1} onClick={() => setLines((ls) => ls.filter((x) => x.key !== l.key))}
                  className="grid h-10 w-10 place-items-center rounded-lg text-muted hover:bg-border/40 disabled:opacity-30"><Trash2 size={16} aria-hidden /></button>
              </div>
            );
          })}
          <Button variant="outline" onClick={() => setLines((ls) => [...ls, newLine()])} disabled={lines.length >= 100}><Plus size={16} aria-hidden /> Ещё материал</Button>
        </div>
        <Field label="Комментарий для поставщика" htmlFor="np-n"><Input id="np-n" value={note} onChange={(e) => setNote(e.target.value)} placeholder="Срок, доставка, цвет…" /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex justify-end gap-2 pt-1">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || !ready.length}>Создать заказ</Button>
        </div>
        <p className="text-xs text-muted">Потом нажмите у заказа «Отправить поставщику».</p>
      </div>
    </Modal>
  );
}
