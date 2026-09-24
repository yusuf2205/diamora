'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { hasPerm } from '@/lib/types';
import type { KitTemplate, Page } from '@/lib/types';
import { Badge, Button, Card, Chips, DataList, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select } from '@/components/ui';

interface Material { id: string; name: string; unit: string; balance: number; minStock: number; low: boolean; isActive: boolean }

const UNITS: { value: string; label: string; short: string }[] = [
  { value: 'METER', label: 'Метры', short: 'м' },
  { value: 'PCS', label: 'Штуки', short: 'шт' },
  { value: 'GRAM', label: 'Граммы', short: 'г' },
  { value: 'ROLL', label: 'Рулоны', short: 'рул' },
  { value: 'PACKAGE', label: 'Упаковки', short: 'уп' },
  { value: 'SET', label: 'Наборы', short: 'наб' },
];
const unit = (u: string) => UNITS.find((x) => x.value === u)?.short ?? u;

/** «Склад»: what is in stock, a receipt when a delivery arrives, and the 9 m kit recipes «Выдать работу» takes
 * materials by. The server keeps the balances (movements are append-only); nothing here edits a number directly. */
export default function InventoryPage() {
  const { me } = useAuth();
  const canManage = hasPerm(me, 'INVENTORY_MANAGE');
  const [tab, setTab] = useState<'materials' | 'kits'>('materials');
  const [creatingMaterial, setCreatingMaterial] = useState(false);
  const [creatingKit, setCreatingKit] = useState(false);
  const [receiving, setReceiving] = useState<Material | null>(null);
  const materials = useQuery<Page<Material>>({ queryKey: ['materials'], queryFn: () => api.get<Page<Material>>('/admin/materials', { limit: 100 }) });
  const kits = useQuery<Page<KitTemplate>>({ queryKey: ['admin-kits'], queryFn: () => api.get<Page<KitTemplate>>('/admin/kits') });

  if (!hasPerm(me, 'INVENTORY_VIEW', 'INVENTORY_MANAGE')) return <EmptyState title="Недостаточно прав для просмотра склада" />;

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader
        title="Склад"
        subtitle="Остатки материалов, приход и комплекты на 9 м."
        actions={canManage ? (tab === 'materials'
          ? <Button onClick={() => setCreatingMaterial(true)}>+ Материал</Button>
          : <Button onClick={() => setCreatingKit(true)}>+ Комплект</Button>) : undefined}
      />
      <Chips options={[{ value: 'materials', label: 'Материалы' }, { value: 'kits', label: 'Комплекты 9 м' }] as const} value={tab} onChange={setTab} label="Раздел" />

      {tab === 'materials' && (
        <>
          {materials.error && <ErrorState error={materials.error} onRetry={() => materials.refetch()} />}
          {materials.isLoading && <ListSkeleton />}
          {materials.data && materials.data.items.length === 0 && <EmptyState title="Материалов пока нет" hint="Добавьте ленту, бусины и всё, из чего собирается комплект" />}
          {materials.data && materials.data.items.length > 0 && (
            <DataList
              rows={[...materials.data.items].sort((a, b) => Number(b.isActive) - Number(a.isActive))}
              rowKey={(m) => m.id}
              onRowClick={canManage ? (m) => setReceiving(m) : undefined}
              columns={[
                { header: 'Материал', cell: (m) => <span className="font-medium">{m.name}</span> },
                { header: 'Остаток', cell: (m) => <span className={`tabular-nums ${m.balance <= 0 ? 'font-semibold text-danger' : m.low ? 'font-semibold text-primary' : ''}`}>{m.balance} {unit(m.unit)}</span>, className: 'text-right' },
                { header: 'Минимум', cell: (m) => <span className="tabular-nums text-muted">{m.minStock} {unit(m.unit)}</span>, className: 'text-right' },
                { header: '', cell: (m) => (!m.isActive ? <Badge>Выключен</Badge> : m.balance <= 0 ? <Badge tone="danger">Закончился</Badge> : m.low ? <Badge tone="warn">Мало</Badge> : null) },
                ...(canManage ? [{ header: 'Приход', cell: () => <span className="text-primary">+ Приход</span> }] : []),
              ]}
              card={(m) => (
                <div className={`flex items-center justify-between gap-3 ${m.isActive ? '' : 'opacity-50'}`}>
                  <div className="min-w-0">
                    <p className="font-medium leading-snug">{m.name}</p>
                    <p className="text-xs text-muted">минимум {m.minStock} {unit(m.unit)}{canManage ? ' · нажмите для прихода' : ''}</p>
                  </div>
                  <div className="shrink-0 text-right">
                    <p className={`font-semibold tabular-nums ${m.balance <= 0 ? 'text-danger' : m.low ? 'text-primary' : ''}`}>{m.balance} {unit(m.unit)}</p>
                    {!m.isActive ? <Badge>Выключен</Badge> : m.balance <= 0 ? <Badge tone="danger">Закончился</Badge> : m.low ? <Badge tone="warn">Мало</Badge> : null}
                  </div>
                </div>
              )}
            />
          )}
        </>
      )}

      {tab === 'kits' && (
        <>
          {kits.error && <ErrorState error={kits.error} onRetry={() => kits.refetch()} />}
          {kits.isLoading && <ListSkeleton rows={2} />}
          {kits.data && kits.data.items.length === 0 && <EmptyState title="Комплектов пока нет" hint="Без комплекта нельзя выдать работу: он говорит, что списать со склада на каждые 9 м" />}
          <div className="grid gap-3 sm:grid-cols-2">
            {kits.data?.items.map((k) => (
              <Card key={k.id} className={k.active ? '' : 'opacity-60'}>
                <div className="flex items-start justify-between gap-3">
                  <p className="font-medium">{k.name}</p>
                  <Badge tone={k.active ? 'ok' : 'default'}>{k.active ? `${k.ribbonMeters} м` : 'Выключен'}</Badge>
                </div>
                <ul className="mt-2 divide-y divide-border text-sm">
                  {k.items.map((i) => (
                    <li key={i.materialId} className="flex justify-between gap-3 py-1.5"><span>{i.materialName}</span><span className="shrink-0 tabular-nums text-muted">{i.requiredQuantity} {unit(i.unit)}</span></li>
                  ))}
                </ul>
              </Card>
            ))}
          </div>
        </>
      )}

      {creatingMaterial && <MaterialDialog onClose={() => setCreatingMaterial(false)} />}
      {receiving && <ReceiptDialog material={receiving} onClose={() => setReceiving(null)} />}
      {creatingKit && <KitDialog materials={materials.data?.items ?? []} onClose={() => setCreatingKit(false)} />}
    </div>
  );
}

function MaterialDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const [name, setName] = useState('');
  const [u, setU] = useState('METER');
  const [min, setMin] = useState('');
  const [qty, setQty] = useState('');
  const save = useMutation({
    mutationFn: async () => {
      const m = await api.post<Material>('/admin/materials', { name: name.trim(), unit: u, minStock: min || '0' }, { idempotencyKey: crypto.randomUUID() });
      if (qty && Number(qty) > 0) await api.post('/admin/stock/receipt', { materialId: m.id, quantity: qty, comment: 'Начальный остаток' }, { idempotencyKey: crypto.randomUUID() });
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['materials'] }); onClose(); },
  });
  return (
    <Modal title="Новый материал" onClose={onClose}>
      <div className="space-y-3">
        <Field label="Название" htmlFor="m-name"><Input id="m-name" placeholder="Лента атласная розовая" value={name} onChange={(e) => setName(e.target.value)} autoFocus /></Field>
        <Field label="Единица" htmlFor="m-unit">
          <Select id="m-unit" value={u} onChange={(e) => setU(e.target.value)}>{UNITS.map((x) => <option key={x.value} value={x.value}>{x.label}</option>)}</Select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label={`Уже есть, ${unit(u)}`} htmlFor="m-qty"><Input id="m-qty" inputMode="decimal" placeholder="0" value={qty} onChange={(e) => setQty(e.target.value.replace(',', '.'))} /></Field>
          <Field label={`Минимум, ${unit(u)}`} htmlFor="m-min"><Input id="m-min" inputMode="decimal" placeholder="0" value={min} onChange={(e) => setMin(e.target.value.replace(',', '.'))} /></Field>
        </div>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || name.trim().length < 2}>Сохранить</Button>
        </div>
      </div>
    </Modal>
  );
}

function ReceiptDialog({ material, onClose }: { material: Material; onClose: () => void }) {
  const qc = useQueryClient();
  const [qty, setQty] = useState('');
  const [comment, setComment] = useState('');
  const save = useMutation({
    mutationFn: () => api.post('/admin/stock/receipt', { materialId: material.id, quantity: qty, comment: comment.trim() || undefined }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['materials'] }); qc.invalidateQueries({ queryKey: ['dashboard'] }); onClose(); },
  });
  return (
    <Modal title={`Приход: ${material.name}`} onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm text-muted">Сейчас на складе: <span className="font-semibold text-foreground">{material.balance} {unit(material.unit)}</span></p>
        <Field label={`Пришло, ${unit(material.unit)}`} htmlFor="r-qty"><Input id="r-qty" inputMode="decimal" value={qty} onChange={(e) => setQty(e.target.value.replace(',', '.'))} autoFocus /></Field>
        <Field label="Комментарий (необязательно)" htmlFor="r-comment"><Input id="r-comment" placeholder="Поставщик, накладная" value={comment} onChange={(e) => setComment(e.target.value)} /></Field>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || !(Number(qty) > 0)}>Добавить на склад</Button>
        </div>
      </div>
    </Modal>
  );
}

function KitDialog({ materials, onClose }: { materials: Material[]; onClose: () => void }) {
  const qc = useQueryClient();
  const [name, setName] = useState('Комплект 9 м');
  const [rows, setRows] = useState<{ materialId: string; qty: string }[]>([{ materialId: '', qty: '' }]);
  const set = (i: number, patch: Partial<{ materialId: string; qty: string }>) => setRows(rows.map((r, j) => (j === i ? { ...r, ...patch } : r)));
  const valid = rows.filter((r) => r.materialId && Number(r.qty) > 0);
  const save = useMutation({
    mutationFn: () => api.post('/admin/kits', { name: name.trim(), ribbonMeters: 9, items: valid.map((r) => ({ materialId: r.materialId, requiredQuantity: r.qty })) }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['admin-kits'] }); onClose(); },
  });
  return (
    <Modal title="Новый комплект на 9 м" onClose={onClose}>
      <div className="space-y-3">
        <p className="text-sm text-muted">Сколько каждого материала уходит на 9 м работы. При выдаче 18 м спишется вдвое больше.</p>
        <Field label="Название" htmlFor="k-name"><Input id="k-name" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        {rows.map((r, i) => {
          const m = materials.find((x) => x.id === r.materialId);
          return (
            <div key={i} className="grid grid-cols-[1fr_6rem] gap-2">
              <Select aria-label={`Материал ${i + 1}`} value={r.materialId} onChange={(e) => set(i, { materialId: e.target.value })}>
                <option value="">Материал</option>
                {materials.filter((x) => x.isActive).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
              </Select>
              <Input aria-label={`Количество ${i + 1}`} inputMode="decimal" placeholder={m ? unit(m.unit) : 'кол-во'} value={r.qty} onChange={(e) => set(i, { qty: e.target.value.replace(',', '.') })} />
            </div>
          );
        })}
        <Button variant="outline" onClick={() => setRows([...rows, { materialId: '', qty: '' }])}>+ Ещё материал</Button>
        {materials.filter((x) => x.isActive).length === 0 && <p className="text-sm text-danger">Нет включённых материалов — сначала добавьте материал на вкладке «Материалы».</p>}
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || name.trim().length < 2 || valid.length === 0}>Сохранить</Button>
        </div>
      </div>
    </Modal>
  );
}
