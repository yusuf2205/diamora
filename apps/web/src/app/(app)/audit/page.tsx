'use client';

import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import { assignmentStatusLabel, formatDate, formatUzs, roleLabel, statusLabel } from '@/lib/format';
import { AUDIT_ENTITY_LABELS, AUDIT_LABELS, PERMISSION_LABELS } from '@/lib/permissions';
import type { AuditEntry, Page } from '@/lib/types';
import { DataList, EmptyState, ErrorState, ListSkeleton, Modal, PageHeader } from '@/components/ui';

const action = (e: AuditEntry) => AUDIT_LABELS[e.action] ?? e.action;
const entity = (e: AuditEntry) => AUDIT_ENTITY_LABELS[e.entity] ?? e.entity;
const who = (e: AuditEntry) => (e.actorName ? `${e.actorName}${e.actorRole ? ` (${roleLabel(e.actorRole)})` : ''}` : e.actorRole ? roleLabel(e.actorRole) : 'Система');
const what = (e: AuditEntry) => e.targetName ?? entity(e);

/** Field names in plain words; anything unknown is shown as is rather than hidden. */
const FIELD: Record<string, string> = {
  fullName: 'ФИО', phone: 'Телефон', secondaryPhone: 'Доп. телефон', status: 'Статус', role: 'Роль', hidden: 'Скрыт на карте',
  managerId: 'Менеджер', managerName: 'Менеджер', ratePerKit: 'Ставка за 9 м', telegramUsername: 'Telegram', notes: 'Заметки',
  name: 'Название', description: 'Описание', quantity: 'Количество', minStock: 'Минимум', unit: 'Единица', comment: 'Комментарий',
  reason: 'Причина', amount: 'Сумма', acceptedMeters: 'Принято, м', broughtMeters: 'Принесено, м', defectiveMeters: 'Брак, м',
  reworkMeters: 'На доработку, м', reportedMeters: 'Сделано, м', kitCount: 'Комплектов', plannedMeters: 'Объём, м', dueAt: 'Срок',
  collateralReceived: 'Залог получен', grant: 'Добавлены права', revoke: 'Убраны права', effective: 'Права', availability: 'Наличие',
  isNew: 'Новинка', isActive: 'Включён', active: 'Включён', storageLocation: 'Место хранения', estimatedValue: 'Оценка',
};
const MONEY = new Set(['ratePerKit', 'amount', 'estimatedValue']);

function show(key: string, v: unknown): string {
  if (v === null || v === undefined || v === '') return '—';
  if (typeof v === 'boolean') return v ? 'да' : 'нет';
  if (Array.isArray(v)) return v.length ? v.map((x) => (typeof x === 'string' ? (PERMISSION_LABELS[x] ?? x) : JSON.stringify(x))).join(', ') : '—';
  if (typeof v === 'object') return JSON.stringify(v);
  const s = String(v);
  if (key === 'role') return roleLabel(s);
  if (key === 'status') return assignmentStatusLabel(s) !== s ? assignmentStatusLabel(s) : statusLabel(s) !== s ? statusLabel(s) : s === 'SUSPENDED' ? 'Отключён' : s;
  if (MONEY.has(key) && /^-?\d+$/.test(s)) return formatUzs(s);
  if (/^\d{4}-\d{2}-\d{2}T/.test(s)) return formatDate(s);
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-/.test(s)) return `#${s.slice(0, 8)}`;
  return s;
}

/** Every changed field: before → after. Rows only on one side are still shown (a creation, a removal). */
function changes(e: AuditEntry): { key: string; before: string; after: string }[] {
  const b = (e.before && typeof e.before === 'object' ? e.before : {}) as Record<string, unknown>;
  const a = (e.after && typeof e.after === 'object' ? e.after : {}) as Record<string, unknown>;
  const keys = [...new Set([...Object.keys(b), ...Object.keys(a)])].filter((k) => !(k === 'managerId' && 'managerName' in a));
  return keys
    .filter((k) => JSON.stringify(b[k]) !== JSON.stringify(a[k]) || !(k in b))
    .map((k) => ({ key: FIELD[k] ?? k, before: k in b ? show(k, b[k]) : '', after: k in a ? show(k, a[k]) : '' }));
}

/** AUDIT_VIEW (§35): append-only, enforced by the database itself — nothing here can be edited or deleted. */
export default function AuditPage() {
  const { data, error, isLoading, refetch } = useQuery<Page<AuditEntry>>({ queryKey: ['audit'], queryFn: () => api.get<Page<AuditEntry>>('/audit', { limit: 100 }) });
  const [open, setOpen] = useState<AuditEntry | null>(null);

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader title="Журнал действий" subtitle="Кто, что и когда изменил. Нажмите на строку, чтобы увидеть, что было и что стало." />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton rows={8} />}
      {data && data.items.length === 0 && <EmptyState title="Записей пока нет" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(e) => e.id}
          onRowClick={setOpen}
          columns={[
            { header: 'Когда', cell: (e) => <span className="whitespace-nowrap text-muted">{formatDate(e.createdAt)}</span> },
            { header: 'Кто', cell: (e) => <span className="font-medium">{who(e)}</span> },
            { header: 'Действие', cell: (e) => <span title={e.action}>{action(e)}</span> },
            { header: 'Что', cell: (e) => <span>{what(e)}</span> },
          ]}
          card={(e) => (
            <div>
              <p className="font-medium leading-snug">{action(e)}</p>
              <p className="mt-0.5 text-sm">{what(e)}</p>
              <p className="mt-0.5 text-xs text-muted">{who(e)} · {formatDate(e.createdAt)}</p>
            </div>
          )}
        />
      )}
      {open && <AuditDetail entry={open} onClose={() => setOpen(null)} />}
    </div>
  );
}

function AuditDetail({ entry: e, onClose }: { entry: AuditEntry; onClose: () => void }) {
  const rows = changes(e);
  const meta = (k: string, v: React.ReactNode) => (
    <div className="flex justify-between gap-4 border-b border-border py-1.5 last:border-0"><span className="text-muted">{k}</span><span className="text-right">{v}</span></div>
  );
  return (
    <Modal title={action(e)} onClose={onClose}>
      <div className="text-sm">
        {meta('Когда', formatDate(e.createdAt))}
        {meta('Кто', who(e))}
        {meta('Что', `${entity(e)}${e.targetName ? ` · ${e.targetName}` : ''}`)}
        {e.ip && meta('Откуда', `${e.ip}${e.device ? ` · ${e.device.slice(0, 60)}` : ''}`)}
      </div>
      <h4 className="mb-2 mt-4 text-sm font-semibold">Изменения</h4>
      {rows.length === 0 ? (
        <p className="text-sm text-muted">Подробностей нет — событие без изменяемых полей (например, вход в систему).</p>
      ) : (
        <div className="divide-y divide-border rounded-lg border border-border text-sm">
          {rows.map((r) => (
            <div key={r.key} className="grid grid-cols-[7rem_1fr] gap-2 px-3 py-2 sm:grid-cols-[9rem_1fr]">
              <span className="text-muted">{r.key}</span>
              <span className="min-w-0 break-words">
                {r.before && <span className="text-danger line-through decoration-danger/50">{r.before}</span>}
                {r.before && r.after && <span className="text-muted"> → </span>}
                {r.after && <span className="font-medium text-ok">{r.after}</span>}
              </span>
            </div>
          ))}
        </div>
      )}
    </Modal>
  );
}
