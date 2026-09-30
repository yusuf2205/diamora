'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDate, formatUzs } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import { Button, Card, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select, Table } from '@/components/ui';
import { ConfirmDelete } from '@/components/confirm-delete';

interface Month { month: string; sales: string; labor: string; materials: string; expenses: string; profit: string; materialsWithoutPrice: number }
interface Sale { id: string; code: string; date: string; customer: string | null; total: string; notes: string | null; lines?: { name: string; quantity: number; unitPrice: string }[] }
interface ProductCost { productId: string; name: string; meters: number; labor: number; materials: number; cost: number; costPerMeter: number | null; soldQuantity: number; revenue: number; pricePerMeter: number | null; profitPerMeter: number | null; marginPercent: number | null; materialsWithoutPrice: number }
interface Line { productModelId: string; quantity: string; unitPrice: string }
interface Expense { id: string; category: string; date: string; amount: string; comment: string | null }
interface StockValue { warehouse: string; withWorkers: string; total: string; withoutPrice: { id: string; name: string }[] }

const MONTHS = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const monthLabel = (k: string) => { const [y, m] = k.split('-'); return `${MONTHS[Number(m) - 1]} ${y}`; };
const EXPENSE_LABEL: Record<string, string> = { DELIVERY_FUEL: 'Бензин / доставка', PACKAGING: 'Упаковка', OTHER: 'Другое' };
const sum = (v: string) => `${formatUzs(v)} сум`;

/** «Прибыль»: sales − paid for work − materials − expenses, per month; plus what the warehouse is worth. */
export default function FinancePage() {
  const { me } = useAuth();
  const [adding, setAdding] = useState<'sale' | 'expense' | null>(null);
  const [removing, setRemoving] = useState<{ kind: 'sales' | 'expenses'; id: string; label: string } | null>(null);
  const profit = useQuery<{ items: Month[] }>({ queryKey: ['profit'], queryFn: () => api.get<{ items: Month[] }>('/admin/finance/profit', { months: 6 }) });
  const sales = useQuery<{ items: Sale[] }>({ queryKey: ['sales'], queryFn: () => api.get<{ items: Sale[] }>('/admin/finance/sales', { limit: 20 }) });
  const expenses = useQuery<{ items: Expense[] }>({ queryKey: ['expenses'], queryFn: () => api.get<{ items: Expense[] }>('/admin/finance/expenses', { limit: 20 }) });
  const stock = useQuery<StockValue>({ queryKey: ['stock-value'], queryFn: () => api.get<StockValue>('/admin/stock/value') });

  if (!hasPerm(me, 'PROFIT_VIEW')) return <EmptyState title="Недостаточно прав для просмотра прибыли" />;
  const noPrice = profit.data?.items.some((m) => m.materialsWithoutPrice > 0);

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader
        title="Прибыль"
        subtitle="Продажи минус оплата мастерицам, материалы по цене закупки и расходы."
        actions={<div className="flex flex-wrap gap-2"><Button variant="outline" onClick={() => setAdding('expense')}>+ Расход</Button><Button onClick={() => setAdding('sale')}>+ Продажа</Button></div>}
      />

      <Card>
        <h2 className="mb-2 text-sm font-semibold">По месяцам</h2>
        {profit.error && <ErrorState error={profit.error} />}
        {profit.isLoading && <ListSkeleton rows={3} />}
        {profit.data && (
          <div className="overflow-x-auto">
            <Table>
              <thead><tr>{['Месяц', 'Продажи', 'Мастерицам', 'Материалы', 'Расходы', 'Прибыль'].map((h) => <th key={h} className="px-3 py-2 text-left text-xs font-medium uppercase text-muted">{h}</th>)}</tr></thead>
              <tbody>
                {profit.data.items.map((m) => (
                  <tr key={m.month} className="border-t border-border">
                    <td className="whitespace-nowrap px-3 py-2">{monthLabel(m.month)}</td>
                    <td className="whitespace-nowrap px-3 py-2 tabular-nums">{sum(m.sales)}</td>
                    <td className="whitespace-nowrap px-3 py-2 tabular-nums">−{sum(m.labor)}</td>
                    <td className="whitespace-nowrap px-3 py-2 tabular-nums">−{sum(m.materials)}{m.materialsWithoutPrice ? ' *' : ''}</td>
                    <td className="whitespace-nowrap px-3 py-2 tabular-nums">−{sum(m.expenses)}</td>
                    <td className={`whitespace-nowrap px-3 py-2 font-semibold tabular-nums ${BigInt(m.profit) < 0n ? 'text-danger' : 'text-ok'}`}>{sum(m.profit)}</td>
                  </tr>
                ))}
              </tbody>
            </Table>
          </div>
        )}
        {noPrice && <p className="mt-2 text-xs text-muted">* У части материалов не указана цена закупки — они не посчитаны. Укажите цену на <Link className="text-primary hover:underline" href="/inventory">складе</Link>.</p>}
      </Card>

      <ProductCosts />

      <Card>
        <h2 className="mb-2 text-sm font-semibold">Стоимость склада (по цене закупки)</h2>
        {stock.data && (
          <>
            <p className="text-lg font-semibold">{sum(stock.data.total)}</p>
            <p className="text-sm text-muted">на складе {sum(stock.data.warehouse)} · у мастериц {sum(stock.data.withWorkers)}</p>
            {stock.data.withoutPrice.length > 0 && <p className="mt-1 text-xs text-muted">Без цены: {stock.data.withoutPrice.map((m) => m.name).join(', ')}</p>}
          </>
        )}
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <h2 className="mb-2 text-sm font-semibold">Продажи</h2>
          {sales.data?.items.length === 0 && <p className="text-sm text-muted">Пока нет. Нажмите «+ Продажа».</p>}
          <ul className="divide-y divide-border text-sm">
            {sales.data?.items.map((s) => (
              <li key={s.id} className="flex items-center justify-between gap-3 py-2">
                <span className="min-w-0"><span className="font-medium">{sum(s.total)}</span> <span className="text-muted">· {s.customer ?? 'без покупателя'} · {formatDate(s.date)}</span>
                  {!!s.lines?.length && <span className="block text-xs text-muted">{s.lines.map((l) => `${l.name} ${l.quantity} м × ${formatUzs(l.unitPrice)}`).join('; ')}</span>}
                </span>
                <button type="button" aria-label={`Удалить продажу ${s.code}`} className="text-danger hover:underline" onClick={() => setRemoving({ kind: 'sales', id: s.id, label: `продажу на ${sum(s.total)}` })}>Удалить</button>
              </li>
            ))}
          </ul>
        </Card>
        <Card>
          <h2 className="mb-2 text-sm font-semibold">Расходы</h2>
          {expenses.data?.items.length === 0 && <p className="text-sm text-muted">Пока нет. Нажмите «+ Расход».</p>}
          <ul className="divide-y divide-border text-sm">
            {expenses.data?.items.map((e) => (
              <li key={e.id} className="flex items-center justify-between gap-3 py-2">
                <span className="min-w-0"><span className="font-medium">{sum(e.amount)}</span> <span className="text-muted">· {EXPENSE_LABEL[e.category] ?? e.category}{e.comment ? ` · ${e.comment}` : ''} · {formatDate(e.date)}</span></span>
                <button type="button" aria-label="Удалить расход" className="text-danger hover:underline" onClick={() => setRemoving({ kind: 'expenses', id: e.id, label: `расход на ${sum(e.amount)}` })}>Удалить</button>
              </li>
            ))}
          </ul>
        </Card>
      </div>

      {adding && <AddDialog kind={adding} onClose={() => setAdding(null)} />}
      {removing && (
        <ConfirmDelete title="Удалить запись" action={() => api.delete(`/admin/finance/${removing.kind}/${removing.id}`)} invalidate={[['profit'], [removing.kind]]} onClose={() => setRemoving(null)}>
          Удалить {removing.label}? Прибыль за этот месяц пересчитается.
        </ConfirmDelete>
      )}
    </div>
  );
}

function AddDialog({ kind, onClose }: { kind: 'sale' | 'expense'; onClose: () => void }) {
  const qc = useQueryClient();
  const [amount, setAmount] = useState('');
  const [text, setText] = useState('');
  const [category, setCategory] = useState('DELIVERY_FUEL');
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [lines, setLines] = useState<Line[]>([]);
  const products = useQuery({ queryKey: ['catalog-names'], queryFn: () => api.get<{ items: { id: string; name: string }[] }>('/admin/catalog', { limit: 100 }), enabled: kind === 'sale' });
  const price = (v: string) => Number(v.replace(/\D/g, ''));
  const filled = lines.filter((l) => l.productModelId && Number(l.quantity) > 0 && price(l.unitPrice) > 0);
  // with lines, the total is their sum (what the server stores too)
  const linesTotal = filled.reduce((a, l) => a + Math.round(Number(l.quantity) * price(l.unitPrice)), 0);
  const digits = filled.length ? String(linesTotal) : amount.replace(/\D/g, '');
  const setLine = (i: number, patch: Partial<Line>) => setLines((ls) => ls.map((l, j) => (j === i ? { ...l, ...patch } : l)));
  const save = useMutation({
    mutationFn: () => kind === 'sale'
      ? api.post('/admin/finance/sales', {
          total: digits, customer: text.trim() || undefined, date,
          items: filled.length ? filled.map((l) => ({ productModelId: l.productModelId, quantity: Number(l.quantity), unitPrice: String(price(l.unitPrice)) })) : undefined,
        }, { idempotencyKey: crypto.randomUUID() })
      : api.post('/admin/finance/expenses', { amount: digits, category, comment: text.trim() || undefined, date }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['profit'] }); qc.invalidateQueries({ queryKey: [kind === 'sale' ? 'sales' : 'expenses'] }); onClose(); },
  });
  return (
    <Modal title={kind === 'sale' ? 'Новая продажа' : 'Новый расход'} onClose={onClose}>
      <div className="space-y-3">
        {kind === 'sale' && (
          <div className="space-y-2">
            <p className="text-sm font-medium">Что продали <span className="font-normal text-muted">— по этим строкам считается прибыль с каждого изделия</span></p>
            {lines.map((l, i) => (
              <div key={i} className="grid grid-cols-[1fr_5rem_7rem_auto] items-center gap-2">
                <Select aria-label="Изделие" value={l.productModelId} onChange={(e) => setLine(i, { productModelId: e.target.value })}>
                  <option value="">Изделие…</option>
                  {products.data?.items.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                </Select>
                <Input aria-label="Метров" inputMode="decimal" placeholder="м" value={l.quantity} onChange={(e) => setLine(i, { quantity: e.target.value.replace(',', '.') })} />
                <Input aria-label="Цена за метр" inputMode="numeric" placeholder="сум за м" value={l.unitPrice} onChange={(e) => setLine(i, { unitPrice: e.target.value })} />
                <button type="button" aria-label="Убрать строку" className="px-1 text-muted hover:text-danger" onClick={() => setLines((ls) => ls.filter((_, j) => j !== i))}>✕</button>
              </div>
            ))}
            <Button variant="outline" onClick={() => setLines((ls) => [...ls, { productModelId: '', quantity: '', unitPrice: '' }])}>+ Изделие</Button>
          </div>
        )}
        {filled.length
          ? <p className="text-sm">Сумма: <b>{sum(String(linesTotal))}</b></p>
          : <Field label="Сумма, сум" htmlFor="f-amount"><Input id="f-amount" inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value)} autoFocus /></Field>}
        {kind === 'expense' && (
          <Field label="Что" htmlFor="f-cat">
            <Select id="f-cat" value={category} onChange={(e) => setCategory(e.target.value)}>
              {Object.entries(EXPENSE_LABEL).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </Select>
          </Field>
        )}
        <Field label={kind === 'sale' ? 'Покупатель (необязательно)' : 'Комментарий (необязательно)'} htmlFor="f-text"><Input id="f-text" value={text} onChange={(e) => setText(e.target.value)} /></Field>
        <Field label="Дата" htmlFor="f-date"><Input id="f-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button disabled={save.isPending || !(Number(digits) > 0)} onClick={() => save.mutate()}>Сохранить</Button>
        </div>
      </div>
    </Modal>
  );
}

/** «Себестоимость и прибыль по изделиям»: materials + work per metre, against the price per metre in the sales. */
function ProductCosts() {
  const [months, setMonths] = useState(3);
  const q = useQuery({ queryKey: ['product-costs', months], queryFn: () => api.get<{ items: ProductCost[] }>('/admin/finance/products', { months }) });
  const n = (v: number | null) => (v === null ? '—' : formatUzs(String(v)));
  return (
    <Card>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold">Себестоимость и прибыль по изделиям</h2>
        <Select aria-label="Период" value={String(months)} onChange={(e) => setMonths(Number(e.target.value))} className="w-auto">
          <option value="1">этот месяц</option><option value="3">3 месяца</option><option value="6">6 месяцев</option><option value="12">год</option>
        </Select>
      </div>
      {q.error && <ErrorState error={q.error} />}
      {q.isLoading && <ListSkeleton rows={3} />}
      {q.data?.items.length === 0 && <p className="text-sm text-muted">Пока нет принятых работ за этот период.</p>}
      {!!q.data?.items.length && (
        <div className="overflow-x-auto">
          <Table>
            <thead><tr>{['Изделие', 'Сделано, м', 'Себестоимость 1 м', 'Цена продажи 1 м', 'Прибыль с 1 м', 'Маржа'].map((h) => <th key={h} className="px-3 py-2 text-left text-xs font-medium uppercase text-muted">{h}</th>)}</tr></thead>
            <tbody>
              {q.data.items.map((p) => (
                <tr key={p.productId} className="border-t border-border">
                  <td className="px-3 py-2 font-medium">{p.name}</td>
                  <td className="whitespace-nowrap px-3 py-2 tabular-nums">{p.meters}</td>
                  <td className="whitespace-nowrap px-3 py-2 tabular-nums" title={`материалы ${formatUzs(String(p.materials))} + мастерицам ${formatUzs(String(p.labor))} сум`}>{n(p.costPerMeter)}{p.materialsWithoutPrice ? ' *' : ''}</td>
                  <td className="whitespace-nowrap px-3 py-2 tabular-nums">{n(p.pricePerMeter)}</td>
                  <td className={`whitespace-nowrap px-3 py-2 font-semibold tabular-nums ${p.profitPerMeter === null ? '' : p.profitPerMeter < 0 ? 'text-danger' : 'text-ok'}`}>{n(p.profitPerMeter)}</td>
                  <td className="whitespace-nowrap px-3 py-2 tabular-nums">{p.marginPercent === null ? '—' : `${p.marginPercent}%`}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        </div>
      )}
      <p className="mt-2 text-xs text-muted">
        Себестоимость = материалы по цене закупки + оплата мастерицам, на 1 принятый метр. Цена продажи — из продаж, где указано «Что продали».
        {q.data?.items.some((p) => p.materialsWithoutPrice) && <> * Часть материалов без цены закупки — себестоимость занижена, укажите цену на <Link className="text-primary hover:underline" href="/inventory">складе</Link>.</>}
      </p>
    </Card>
  );
}
