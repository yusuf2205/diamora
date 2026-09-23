'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMemo, useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { assignmentStatusLabel, assignmentStatusTone, formatUzs } from '@/lib/format';
import type { AssignmentDetail, AssignmentSummary, CatalogItem, CatalogVariant, KitTemplate, Page, Worker } from '@/lib/types';
import { Badge, Button, EmptyState, ErrorState, Input, Modal, Select, Table, Td, Th } from '@/components/ui';

const STATUS_FILTERS: { value: string; label: string }[] = [
  { value: '', label: 'Все' },
  { value: 'READY_TO_DELIVER', label: 'Нужно доставить' },
  { value: 'READY_FOR_PICKUP', label: 'Есть что забрать' },
  { value: 'UNDER_REVIEW', label: 'На проверке' },
  { value: 'IN_PROGRESS', label: 'В работе' },
  { value: 'COMPLETED', label: 'Завершено' },
];

/** Задания (M3) — same API and status machine as the mobile Staff app; this page never computes a status transition,
 * a payment, or a material requirement on its own (§28: the server is the only source of truth for all three). */
export default function AssignmentsPage() {
  const params = useSearchParams();
  const [status, setStatus] = useState(() => params.get('status') ?? '');
  const [creating, setCreating] = useState(() => params.get('create') === '1');
  const { data, error, isLoading, refetch } = useQuery<Page<AssignmentSummary>>({
    queryKey: ['assignments', status],
    queryFn: () => api.get<Page<AssignmentSummary>>('/admin/assignments', { status: status || undefined, limit: 200 }),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Задания</h1>
          <p className="text-sm text-muted">Выдача работы, доставка, забор, приёмка, выплата — всё через тот же API, что и в приложении.</p>
        </div>
        <Button onClick={() => setCreating(true)}>Выдать работу</Button>
      </div>
      <div className="flex gap-2">
        {STATUS_FILTERS.map((f) => (
          <button
            key={f.value}
            onClick={() => setStatus(f.value)}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium transition ${status === f.value ? 'bg-primary text-white' : 'border border-border hover:bg-border/40'}`}
          >
            {f.label}
          </button>
        ))}
      </div>
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Заданий нет" />}
      {data && data.items.length > 0 && (
        <Table>
          <thead>
            <tr>
              <Th>Мастерица</Th><Th>Модель</Th><Th>Цвет</Th><Th>Объём</Th><Th>Статус</Th><Th>Срок</Th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((a) => (
              <tr key={a.id} className="cursor-pointer hover:bg-border/20">
                <Td className="font-medium"><Link href={`/assignments/${a.id}`} className="block">{a.worker.fullName}</Link></Td>
                <Td><Link href={`/assignments/${a.id}`} className="block">{a.product?.name ?? '—'}</Link></Td>
                <Td><Link href={`/assignments/${a.id}`} className="block">{a.color?.name ?? '—'}</Link></Td>
                <Td><Link href={`/assignments/${a.id}`} className="block">{a.plannedMeters} м{a.reportedMeters > 0 ? ` · сделано ${a.reportedMeters} м` : ''}</Link></Td>
                <Td><Link href={`/assignments/${a.id}`} className="block"><Badge tone={assignmentStatusTone(a.status)}>{assignmentStatusLabel(a.status)}</Badge></Link></Td>
                <Td><Link href={`/assignments/${a.id}`} className="block">{a.dueAt ? a.dueAt.slice(0, 10) : '—'}</Link></Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
      {creating && <CreateAssignmentDialog onClose={() => setCreating(false)} />}
    </div>
  );
}

export function CreateAssignmentDialog({ onClose }: { onClose: () => void }) {
  const router = useRouter();
  const qc = useQueryClient();
  const [workerId, setWorkerId] = useState('');
  const [productId, setProductId] = useState('');
  const [variantId, setVariantId] = useState('');
  const [kitCount, setKitCount] = useState<1 | 2 | 3>(1);
  const [dueAt, setDueAt] = useState('');
  const [notes, setNotes] = useState('');
  const [insufficientMaterial, setInsufficientMaterial] = useState<string | null>(null);

  const workers = useQuery<Page<Worker>>({ queryKey: ['workers', 'ACTIVE'], queryFn: () => api.get<Page<Worker>>('/workers', { status: 'ACTIVE', limit: 200 }) });
  const catalog = useQuery<Page<CatalogItem>>({ queryKey: ['admin-catalog'], queryFn: () => api.get<Page<CatalogItem>>('/admin/catalog', { limit: 100 }) });
  const kits = useQuery<Page<KitTemplate>>({ queryKey: ['admin-kits'], queryFn: () => api.get<Page<KitTemplate>>('/admin/kits') });

  const product = catalog.data?.items.find((p) => p.id === productId);
  const variants = useMemo(() => (product?.variants ?? []).filter((v) => v.active && v.color), [product]);
  const variant: CatalogVariant | undefined = variants.find((v) => v.id === variantId);

  const create = useMutation({
    mutationFn: async () => {
      const matches = (kits.data?.items ?? []).filter((k) => k.active && (k.variantId == null || k.variantId === variantId));
      if (matches.length === 0) throw new ApiError(422, 'NO_KIT', 'Нет доступного комплекта материалов для этого варианта.');
      const kit = matches[0];
      return api.post<AssignmentDetail>(
        '/admin/assignments',
        { workerId, productModelId: productId, productVariantId: variantId, colorId: variant!.color!.id, materialKitTemplateId: kit.id, kitCount, dueAt: dueAt || undefined, notes: notes.trim() || undefined },
        { idempotencyKey: crypto.randomUUID() },
      );
    },
    onSuccess: (a) => {
      qc.invalidateQueries({ queryKey: ['assignments'] });
      router.push(`/assignments/${a.id}`);
    },
    onError: async (err) => {
      if (err instanceof ApiError && err.code === 'INSUFFICIENT_STOCK') {
        const materialId = (err.details as { materialId?: string } | undefined)?.materialId;
        const kit = (kits.data?.items ?? []).find((k) => k.items.some((i) => i.materialId === materialId));
        const item = kit?.items.find((i) => i.materialId === materialId);
        setInsufficientMaterial(item ? `Не хватает материала: ${item.materialName}` : 'Не хватает материалов на складе');
      }
    },
  });

  const ready = workerId && productId && variantId && !create.isPending;

  return (
    <Modal title="Выдать работу" onClose={onClose}>
      <div className="space-y-3">
        <div>
          <label className="mb-1 block text-xs text-muted">Мастерица</label>
          <Select value={workerId} onChange={(e) => setWorkerId(e.target.value)}>
            <option value="">Выберите мастерицу</option>
            {workers.data?.items.map((w) => <option key={w.id} value={w.id}>{w.fullName} · {w.phone}</option>)}
          </Select>
        </div>
        <div>
          <label className="mb-1 block text-xs text-muted">Модель</label>
          <Select value={productId} onChange={(e) => { setProductId(e.target.value); setVariantId(''); }}>
            <option value="">Выберите модель</option>
            {catalog.data?.items.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Select>
        </div>
        {productId && (
          <div>
            <label className="mb-1 block text-xs text-muted">Цвет</label>
            <Select value={variantId} onChange={(e) => setVariantId(e.target.value)}>
              <option value="">Выберите цвет</option>
              {variants.map((v) => <option key={v.id} value={v.id}>{v.color!.name}{v.label ? ` · ${v.label}` : ''}</option>)}
            </Select>
            {variants.length === 0 && <p className="mt-1 text-xs text-danger">У этой модели нет доступных вариантов цвета.</p>}
          </div>
        )}
        <div>
          <label className="mb-1 block text-xs text-muted">Объём</label>
          <div className="flex gap-2">
            {([1, 2, 3] as const).map((c) => (
              <button
                key={c}
                onClick={() => setKitCount(c)}
                className={`flex-1 rounded-lg border px-3 py-2 text-sm font-medium ${kitCount === c ? 'border-primary bg-primary/10 text-primary' : 'border-border hover:bg-border/40'}`}
              >
                {c * 9} м
              </button>
            ))}
          </div>
        </div>
        <div>
          <label className="mb-1 block text-xs text-muted">Срок (необязательно)</label>
          <Input type="date" value={dueAt} onChange={(e) => setDueAt(e.target.value)} />
        </div>
        <Input placeholder="Комментарий (необязательно)" value={notes} onChange={(e) => setNotes(e.target.value)} />
        {insufficientMaterial && <div className="rounded-lg bg-danger/10 p-3 text-sm text-danger">{insufficientMaterial}</div>}
        {create.isError && !insufficientMaterial && <ErrorState error={create.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => { setInsufficientMaterial(null); create.mutate(); }} disabled={!ready}>Выдать работу</Button>
        </div>
      </div>
    </Modal>
  );
}
