'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { api } from '@/lib/api';
import type { ManagerSummary, Page, Worker } from '@/lib/types';
import { Button, ErrorState, Field, Input, Modal } from '@/components/ui';

/**
 * «Назначить менеджера»: pick a manager, tick the workers, save — one request for all of them. Her whole scope (lists,
 * map, QR, notifications) moves on the server at once. Ticked by default: the workers this manager already has.
 */
export function AssignManagerDialog({ onClose, initialManagerId = '' }: { onClose: () => void; initialManagerId?: string }) {
  const qc = useQueryClient();
  const managers = useQuery<{ items: ManagerSummary[] }>({ queryKey: ['managers'], queryFn: () => api.get<{ items: ManagerSummary[] }>('/managers') });
  const [managerId, setManagerId] = useState(initialManagerId);
  const [search, setSearch] = useState('');
  const workers = useQuery<Page<Worker>>({
    queryKey: ['workers', 'assign', search.trim()],
    queryFn: () => api.get<Page<Worker>>('/workers', { q: search.trim() || undefined, limit: 100 }),
  });
  const list = useMemo(() => (workers.data?.items ?? []).filter((w) => w.status === 'ACTIVE' || w.status === 'PAUSED' || w.status === 'PENDING_APPROVAL'), [workers.data]);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  // switching the manager starts from «who is already hers»
  useEffect(() => {
    setPicked(new Set(list.filter((w) => (w.manager?.id ?? '') === managerId && managerId !== '').map((w) => w.id)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [managerId, workers.data]);

  const toggle = (id: string) => setPicked((s) => { const n = new Set(s); if (n.has(id)) n.delete(id); else n.add(id); return n; });
  const changedIds = list.filter((w) => picked.has(w.id) && (w.manager?.id ?? '') !== managerId).map((w) => w.id);

  const save = useMutation({
    mutationFn: () => api.post<{ changed: number }>('/workers/manager-bulk', { managerId: managerId || null, workerIds: changedIds }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['workers'] }); qc.invalidateQueries({ queryKey: ['managers'] }); onClose(); },
  });

  return (
    <Modal title="Назначить менеджера" onClose={onClose}>
      <div className="space-y-3">
        <Field label="Менеджер" htmlFor="bulk-manager">
          <select id="bulk-manager" className="min-h-10 w-full rounded-lg border border-border bg-card px-3 py-1.5" value={managerId} onChange={(e) => setManagerId(e.target.value)}>
            <option value="">Без менеджера</option>
            {managers.data?.items.filter((m) => m.status === 'ACTIVE').map((m) => <option key={m.id} value={m.id}>{m.fullName} · {m.stats.workers}</option>)}
          </select>
        </Field>
        <Input type="search" placeholder="Поиск: имя, телефон, код" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Поиск мастерицы" />
        <div className="max-h-[50vh] divide-y divide-border overflow-y-auto rounded-lg border border-border">
          {workers.isLoading && <p className="p-3 text-sm text-muted">Загрузка…</p>}
          {list.map((w) => (
            <label key={w.id} className="flex cursor-pointer items-center gap-3 px-3 py-2.5 hover:bg-border/20">
              <input type="checkbox" className="h-5 w-5 shrink-0 accent-[var(--color-primary)]" checked={picked.has(w.id)} onChange={() => toggle(w.id)} aria-label={w.fullName} />
              <span className="min-w-0 flex-1">
                <span className="block truncate font-medium">{w.fullName}</span>
                <span className="block truncate text-xs text-muted">{w.code} · {w.manager ? `сейчас: ${w.manager.fullName}` : 'без менеджера'}</span>
              </span>
            </label>
          ))}
          {!workers.isLoading && list.length === 0 && <p className="p-3 text-sm text-muted">Никого не найдено</p>}
        </div>
        {save.isError && <ErrorState error={save.error} />}
        <div className="flex gap-2 pt-1 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => save.mutate()} disabled={save.isPending || changedIds.length === 0}>
            {changedIds.length ? `Назначить (${changedIds.length})` : 'Назначить'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
