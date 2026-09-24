'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMemo, useState, type ReactNode } from 'react';
import { api, ApiError } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatDay, formatUzs } from '@/lib/format';
import type { AssignmentDetail, AssignmentSummary, CatalogItem, CatalogVariant, KitTemplate, Page, PayRate, Worker } from '@/lib/types';
import { Badge, Button, Chips, DataList, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select } from '@/components/ui';

const STATUS_FILTERS = [
  { value: '', label: 'Все' },
  { value: 'READY_TO_DELIVER', label: 'Нужно доставить' },
  { value: 'IN_PROGRESS', label: 'В работе' },
  { value: 'READY_FOR_PICKUP', label: 'Есть что забрать' },
  { value: 'UNDER_REVIEW', label: 'На приёмке' },
  { value: 'REWORK_REQUIRED', label: 'На доработке' },
  { value: 'COMPLETED', label: 'Завершено' },
] as const;

const progress = (a: AssignmentSummary) => (a.plannedMeters > 0 ? Math.min(100, (a.reportedMeters / a.plannedMeters) * 100) : 0);
const overdue = (a: AssignmentSummary) => !!a.dueAt && new Date(a.dueAt).getTime() < Date.now() && !['COMPLETED', 'CANCELLED', 'ACCEPTED'].includes(a.status);

/** Задания (M3) — same API and status machine as the mobile Staff app; this page never computes a status transition,
 * a payment, or a material requirement on its own (§28: the server is the only source of truth for all three). */
export default function AssignmentsPage() {
  const params = useSearchParams();
  const [status, setStatus] = useState<string>(() => params.get('status') ?? '');
  const [creating, setCreating] = useState(() => params.get('create') === '1');
  const { data, error, isLoading, refetch } = useQuery<Page<AssignmentSummary>>({
    queryKey: ['assignments', status],
    queryFn: () => api.get<Page<AssignmentSummary>>('/admin/assignments', { status: status || undefined, limit: 100 }),
  });

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader
        title="Задания"
        subtitle="Выдача работы, доставка, забор, приёмка и выплата."
        actions={<Button onClick={() => setCreating(true)}>+ Выдать работу</Button>}
      />
      <Chips options={STATUS_FILTERS} value={status as (typeof STATUS_FILTERS)[number]['value']} onChange={setStatus} label="Статус" />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Заданий нет" hint={status ? 'В этом статусе сейчас пусто' : 'Выдайте первую работу мастерице'} />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(a) => a.id}
          href={(a) => `/assignments/${a.id}`}
          columns={[
            { header: 'Мастерица', cell: (a) => <span className="font-medium">{a.worker.fullName}</span> },
            { header: 'Модель', cell: (a) => a.product?.name ?? '—' },
            { header: 'Цвет', cell: (a) => a.color?.name ?? '—' },
            { header: 'Готово', cell: (a) => <span className="whitespace-nowrap tabular-nums">{a.reportedMeters} / {a.plannedMeters} м</span> },
            { header: 'Статус', cell: (a) => <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge> },
            { header: 'Срок', cell: (a) => <span className={`whitespace-nowrap ${overdue(a) ? 'font-medium text-danger' : ''}`}>{a.dueAt ? formatDay(a.dueAt) : '—'}</span> },
          ]}
          card={(a) => (
            <div className="space-y-2">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-medium leading-snug">{a.worker.fullName}</p>
                  <p className="text-sm text-muted">{a.product?.name ?? '—'} · {a.color?.name ?? '—'}</p>
                </div>
                <Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge>
              </div>
              <div className="h-1.5 overflow-hidden rounded-full bg-border"><div className="h-full rounded-full bg-primary" style={{ width: `${progress(a)}%` }} /></div>
              <div className="flex justify-between text-sm">
                <span className="tabular-nums text-muted">{a.reportedMeters} из {a.plannedMeters} м</span>
                {a.dueAt && <span className={overdue(a) ? 'font-medium text-danger' : 'text-muted'}>{overdue(a) ? 'Просрочено · ' : 'Срок '}{formatDay(a.dueAt)}</span>}
              </div>
            </div>
          )}
        />
      )}
      {creating && <CreateAssignmentDialog onClose={() => setCreating(false)} />}
    </div>
  );
}

/** «Выдать работу»: pick worker → model → colour → volume → deadline, see the full summary (materials that will leave the
 * stock, estimated pay at today's rate), confirm. The server re-checks stock and computes the real payment. */
export function CreateAssignmentDialog({ onClose, workerId: presetWorker }: { onClose: () => void; workerId?: string }) {
  const router = useRouter();
  const qc = useQueryClient();
  const [workerId, setWorkerId] = useState(presetWorker ?? '');
  const [productId, setProductId] = useState('');
  const [variantId, setVariantId] = useState('');
  const [kitCount, setKitCount] = useState<1 | 2 | 3>(2);
  const [dueAt, setDueAt] = useState('');
  const [notes, setNotes] = useState('');
  const [reviewing, setReviewing] = useState(false);
  const [insufficientMaterial, setInsufficientMaterial] = useState<string | null>(null);

  const workers = useQuery<Page<Worker>>({ queryKey: ['workers', 'ACTIVE'], queryFn: () => api.get<Page<Worker>>('/workers', { status: 'ACTIVE', limit: 100 }) });
  const catalog = useQuery<Page<CatalogItem>>({ queryKey: ['admin-catalog'], queryFn: () => api.get<Page<CatalogItem>>('/admin/catalog', { limit: 100 }) });
  const kits = useQuery<Page<KitTemplate>>({ queryKey: ['admin-kits'], queryFn: () => api.get<Page<KitTemplate>>('/admin/kits') });
  const rate = useQuery<PayRate>({ queryKey: ['pay-rate'], queryFn: () => api.get<PayRate>('/settings/pay-rate') });

  const worker = workers.data?.items.find((w) => w.id === workerId);
  const product = catalog.data?.items.find((p) => p.id === productId);
  const variants = useMemo(() => (product?.variants ?? []).filter((v) => v.active && v.color), [product]);
  const variant: CatalogVariant | undefined = variants.find((v) => v.id === variantId);
  const kit = (kits.data?.items ?? []).find((k) => k.active && (k.variantId == null || k.variantId === variantId));
  const estimate = rate.data && /^\d+$/.test(rate.data.ratePerKit) ? String(BigInt(rate.data.ratePerKit) * BigInt(kitCount)) : null;

  const create = useMutation({
    mutationFn: async () => {
      if (!kit) throw new ApiError(422, 'NO_KIT', 'Нет комплекта материалов для этого цвета. Добавьте его на складе.');
      return api.post<AssignmentDetail>(
        '/admin/assignments',
        { workerId, productModelId: productId, productVariantId: variantId, colorId: variant!.color!.id, materialKitTemplateId: kit.id, kitCount, dueAt: dueAt || undefined, notes: notes.trim() || undefined },
        { idempotencyKey: crypto.randomUUID() },
      );
    },
    onSuccess: (a) => {
      qc.invalidateQueries({ queryKey: ['assignments'] });
      qc.invalidateQueries({ queryKey: ['dashboard'] });
      router.push(`/assignments/${a.id}`);
    },
    onError: async (err) => {
      if (err instanceof ApiError && err.code === 'INSUFFICIENT_STOCK') {
        const materialId = (err.details as { materialId?: string } | undefined)?.materialId;
        const item = kit?.items.find((i) => i.materialId === materialId);
        setInsufficientMaterial(item ? `На складе не хватает: ${item.materialName}` : 'На складе не хватает материалов');
      }
    },
  });

  const ready = !!(workerId && productId && variantId);

  if (reviewing && ready) {
    const row = (k: string, v: ReactNode) => (
      <div className="flex justify-between gap-4 border-b border-border py-2 last:border-0"><span className="text-muted">{k}</span><span className="text-right font-medium">{v}</span></div>
    );
    return (
      <Modal title="Проверьте перед выдачей" onClose={onClose}>
        <div className="text-sm">
          {row('Мастерица', worker?.fullName ?? '—')}
          {row('Модель', product?.name ?? '—')}
          {row('Цвет', variant?.color?.name ?? '—')}
          {row('Объём', `${kitCount * 9} м · ${kitCount} × комплект 9 м`)}
          {row('Срок', dueAt ? formatDay(dueAt) : 'без срока')}
          {notes.trim() && row('Комментарий', notes.trim())}
        </div>
        <div className="mt-3 rounded-lg bg-border/30 p-3 text-sm">
          <p className="mb-1 font-medium">Со склада спишется</p>
          {kit ? kit.items.map((i) => (
            <div key={i.materialId} className="flex justify-between gap-3"><span>{i.materialName}</span><span className="shrink-0 tabular-nums">{i.requiredQuantity * kitCount} {i.unit === 'METER' ? 'м' : 'шт'}</span></div>
          )) : <p className="text-danger">Нет комплекта материалов для этого цвета</p>}
        </div>
        {estimate && <p className="mt-3 text-sm">Оплата мастерице по текущей ставке: <span className="font-semibold">{formatUzs(estimate)}</span></p>}
        {insufficientMaterial && <div className="mt-3 rounded-lg bg-danger/10 p-3 text-sm text-danger">{insufficientMaterial}</div>}
        {create.isError && !insufficientMaterial && <div className="mt-3"><ErrorState error={create.error} /></div>}
        <div className="mt-4 flex gap-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="outline" onClick={() => setReviewing(false)}>Назад</Button>
          <Button onClick={() => { setInsufficientMaterial(null); create.mutate(); }} disabled={create.isPending || !kit}>{create.isPending ? 'Выдаём…' : 'Выдать работу'}</Button>
        </div>
      </Modal>
    );
  }

  return (
    <Modal title="Выдать работу" onClose={onClose}>
      <div className="space-y-3">
        <Field label="Мастерица" htmlFor="as-worker">
          <Select id="as-worker" value={workerId} onChange={(e) => setWorkerId(e.target.value)}>
            <option value="">Выберите мастерицу</option>
            {workers.data?.items.map((w) => <option key={w.id} value={w.id}>{w.fullName} · {w.phone}</option>)}
          </Select>
        </Field>
        <Field label="Модель" htmlFor="as-model">
          <Select id="as-model" value={productId} onChange={(e) => { setProductId(e.target.value); setVariantId(''); }}>
            <option value="">Выберите модель</option>
            {catalog.data?.items.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Select>
        </Field>
        {productId && (
          <Field label="Цвет" htmlFor="as-color">
            <Select id="as-color" value={variantId} onChange={(e) => setVariantId(e.target.value)}>
              <option value="">Выберите цвет</option>
              {variants.map((v) => <option key={v.id} value={v.id}>{v.color!.name}{v.label ? ` · ${v.label}` : ''}</option>)}
            </Select>
            {variants.length === 0 && <p className="text-xs text-danger">У этой модели нет доступных цветов.</p>}
          </Field>
        )}
        <Field label="Объём">
          <div className="grid grid-cols-3 gap-2">
            {([1, 2, 3] as const).map((c) => (
              <button
                key={c}
                onClick={() => setKitCount(c)}
                aria-pressed={kitCount === c}
                className={`min-h-11 rounded-lg border px-3 py-2 text-sm font-semibold transition ${kitCount === c ? 'border-primary bg-primary/10 text-primary' : 'border-border hover:bg-border/40'}`}
              >
                {c * 9} м
              </button>
            ))}
          </div>
        </Field>
        <Field label="Срок (необязательно)" htmlFor="as-due">
          <Input id="as-due" type="date" value={dueAt} onChange={(e) => setDueAt(e.target.value)} />
        </Field>
        <Field label="Комментарий (необязательно)" htmlFor="as-notes">
          <Input id="as-notes" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => setReviewing(true)} disabled={!ready}>Далее</Button>
        </div>
      </div>
    </Modal>
  );
}
