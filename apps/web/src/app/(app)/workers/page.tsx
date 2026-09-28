'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import QRCode from 'qrcode';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { formatUzs, statusLabel } from '@/lib/format';
import { hasPerm } from '@/lib/types';
import type { ManagerSummary, Page, Worker } from '@/lib/types';
import { useAuth } from '@/lib/auth';
import { Badge, Button, Card, Chips, DataList, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader } from '@/components/ui';
import { AssignManagerDialog } from '@/components/assign-manager-dialog';

const STATUS_TONE: Record<Worker['status'], 'default' | 'ok' | 'danger' | 'warn'> = {
  PENDING_APPROVAL: 'warn', ACTIVE: 'ok', PAUSED: 'default', REJECTED: 'danger', ARCHIVED: 'default',
};
const FILTERS = [
  { value: '', label: 'Все' },
  { value: 'PENDING_APPROVAL', label: 'Заявки' },
  { value: 'ACTIVE', label: 'Активные' },
  { value: 'PAUSED', label: 'На паузе' },
  { value: 'ARCHIVED', label: 'Архив' },
  { value: 'REJECTED', label: 'Отклонённые' },
] as const;

const collateral = (w: Worker) => (w.collateral ? (w.collateral.type === 'MONEY' ? formatUzs(w.collateral.amount) : w.collateral.description) : '—');

/** Mirrors the Flutter ADMIN workers list — same API, same server-side scope (a MANAGER sees only her own, D-028). */
export default function WorkersPage() {
  const params = useSearchParams();
  const [status, setStatus] = useState<string>(() => params.get('status') ?? '');
  const [search, setSearch] = useState('');
  const [q, setQ] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setQ(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);
  const { me } = useAuth();
  const canInvite = hasPerm(me, 'WORKER_APPROVE');
  const [adding, setAdding] = useState(false);
  const canAssign = hasPerm(me, 'WORKER_ASSIGN_MANAGER');
  const [assigning, setAssigning] = useState(false);
  const { data, error, isLoading, refetch } = useQuery<Page<Worker>>({
    queryKey: ['workers', status, q],
    queryFn: () => api.get<Page<Worker>>('/workers', { status: status || undefined, q: q || undefined, limit: 100 }),
  });

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader
        title="Мастерицы"
        subtitle="Заявки, статус, менеджер и сколько кому выплатить."
        actions={canInvite || canAssign ? (
          <div className="flex flex-wrap gap-2">
            {canAssign && <Button variant="outline" onClick={() => setAssigning(true)}>Назначить менеджера</Button>}
            {canInvite && <Button onClick={() => setAdding(true)}>+ Добавить мастерицу</Button>}
          </div>
        ) : undefined}
      />
      {canInvite && <PendingInvites />}
      {adding && <AddWorkerDialog onClose={() => setAdding(false)} />}
      {assigning && <AssignManagerDialog onClose={() => setAssigning(false)} />}
      <div className="space-y-3">
        <Input type="search" placeholder="Поиск: имя, телефон, код" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Поиск" className="md:max-w-sm" />
        <Chips options={FILTERS} value={status as (typeof FILTERS)[number]['value']} onChange={setStatus} label="Статус" />
      </div>
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Никого не найдено" hint={q ? 'Попробуйте другое имя или номер' : 'Мастерицы появятся здесь после регистрации в Telegram'} />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(w) => w.id}
          href={(w) => `/workers/${w.id}`}
          columns={[
            { header: 'Мастерица', cell: (w) => <span className="font-medium">{w.fullName} <span className="font-normal text-muted">· {w.code}</span></span> },
            { header: 'Телефон', cell: (w) => <span className="whitespace-nowrap">{w.phone}</span> },
            { header: 'Статус', cell: (w) => <Badge tone={STATUS_TONE[w.status]}>{statusLabel(w.status)}</Badge> },
            { header: 'Менеджер', cell: (w) => w.manager?.fullName ?? <span className="text-muted">—</span> },
            { header: 'Залог', cell: collateral },
            { header: 'К получению', cell: (w) => <span className="whitespace-nowrap font-medium tabular-nums">{formatUzs(w.balance)}</span>, className: 'text-right' },
          ]}
          card={(w) => (
            <div className="space-y-1.5">
              <div className="flex items-start justify-between gap-3">
                <p className="min-w-0 font-medium leading-snug">{w.fullName}</p>
                <Badge tone={STATUS_TONE[w.status]}>{statusLabel(w.status)}</Badge>
              </div>
              <p className="text-sm text-muted">{w.code} · {w.phone}</p>
              <div className="flex items-center justify-between gap-3 text-sm">
                <span className="min-w-0 truncate text-muted">{w.manager ? `Менеджер: ${w.manager.fullName}` : 'Без менеджера'}</span>
                {w.balance !== '0' && <span className="shrink-0 font-semibold tabular-nums text-primary">{formatUzs(w.balance)}</span>}
              </div>
            </div>
          )}
        />
      )}
    </div>
  );
}

interface Invite { id: string; fullName: string; phone: string; createdAt: string; expiresAt: string; url?: string }

/** «Добавить мастерицу»: name + phone -> a Telegram link. She opens it and is active at once: no questionnaire, no approval. */
export function AddWorkerDialog({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const canManager = hasPerm(me, 'WORKER_ASSIGN_MANAGER');
  const managers = useQuery<{ items: ManagerSummary[] }>({ queryKey: ['managers'], queryFn: () => api.get<{ items: ManagerSummary[] }>('/managers'), enabled: canManager });
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('+998 ');
  const [managerId, setManagerId] = useState('');
  const [copied, setCopied] = useState(false);
  const create = useMutation({
    mutationFn: () => api.post<Invite>('/workers/invitations', { fullName: fullName.trim(), phone, managerId: managerId || null }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['invitations'] }),
  });
  const link = create.data?.url;
  const [qr, setQr] = useState<string | null>(null);
  useEffect(() => {
    if (!link) return;
    QRCode.toDataURL(link, { width: 640, margin: 2 }).then(setQr).catch(() => setQr(null));
  }, [link]);
  // the QR picture AND the link in one message where the browser can share files (phones); else Telegram's share page
  const share = async () => {
    if (!link) return;
    const text = `Здравствуйте, ${create.data!.fullName}! Вас добавили в Diamoraa. Откройте ссылку или отсканируйте QR камерой телефона:
${link}`;
    try {
      if (qr && typeof navigator !== 'undefined' && navigator.canShare) {
        const blob = await (await fetch(qr)).blob();
        const file = new File([blob], 'diamoraa-invite.png', { type: 'image/png' });
        if (navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], text }); return; }
      }
    } catch { /* cancelled or unsupported: fall through */ }
    window.open(`https://t.me/share/url?url=${encodeURIComponent(link)}&text=${encodeURIComponent(text)}`, '_blank', 'noreferrer');
  };
  const message = link ? `Здравствуйте, ${create.data!.fullName}! Вас добавили в Diamoraa. Откройте ссылку в Telegram: ${link}` : '';
  const valid = fullName.trim().length >= 2 && phone.replace(/\D/g, '').length >= 9;

  return (
    <Modal title="Добавить мастерицу" onClose={onClose}>
      {!link ? (
        <form className="space-y-3" onSubmit={(e) => { e.preventDefault(); if (valid) create.mutate(); }}>
          <Field label="Фамилия и имя" htmlFor="inv-name"><Input id="inv-name" autoFocus value={fullName} onChange={(e) => setFullName(e.target.value)} /></Field>
          <Field label="Телефон" htmlFor="inv-phone"><Input id="inv-phone" type="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
          {canManager && (
            <Field label="Менеджер" htmlFor="inv-manager">
              <select id="inv-manager" className="min-h-10 w-full rounded-lg border border-border bg-card px-3 py-1.5" value={managerId} onChange={(e) => setManagerId(e.target.value)}>
                <option value="">Без менеджера</option>
                {managers.data?.items.filter((m) => m.status === 'ACTIVE').map((m) => <option key={m.id} value={m.id}>{m.fullName}</option>)}
              </select>
            </Field>
          )}
          <p className="text-sm text-muted">Мы дадим ссылку. Мастерица открывает её в Telegram — и сразу в команде, без анкеты и без одобрения.</p>
          {create.isError && <ErrorState error={create.error} />}
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="ghost" onClick={onClose}>Отмена</Button>
            <Button type="submit" disabled={!valid || create.isPending}>{create.isPending ? 'Создаём…' : 'Получить ссылку'}</Button>
          </div>
        </form>
      ) : (
        <div className="space-y-3">
          <p className="text-sm">Отправьте эту ссылку <span className="font-semibold">{create.data!.fullName}</span>. Она действует 7 дней и открывается один раз.</p>
          {qr && <img src={qr} alt="QR приглашения" className="mx-auto h-48 w-48 rounded-lg bg-white p-2" />}
          <p className="break-all rounded-lg bg-border/40 p-3 font-mono text-sm">{link}</p>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Button className="flex-1" onClick={() => { navigator.clipboard?.writeText(message).then(() => setCopied(true)).catch(() => setCopied(false)); }}>{copied ? '✓ Скопировано' : 'Скопировать'}</Button>
            <Button variant="outline" className="flex-1" type="button" onClick={share}>Отправить в Telegram</Button>
          </div>
          <div className="flex justify-end pt-2"><Button variant="ghost" onClick={onClose}>Готово</Button></div>
        </div>
      )}
    </Modal>
  );
}

/** Links that were sent but not opened yet: seen at a glance, cancellable. */
function PendingInvites() {
  const qc = useQueryClient();
  const { data } = useQuery<{ items: Invite[] }>({ queryKey: ['invitations'], queryFn: () => api.get<{ items: Invite[] }>('/workers/invitations') });
  const revoke = useMutation({ mutationFn: (id: string) => api.delete(`/workers/invitations/${id}`), onSuccess: () => qc.invalidateQueries({ queryKey: ['invitations'] }) });
  if (!data?.items?.length) return null;
  return (
    <Card>
      <h2 className="mb-2 text-sm font-semibold">Приглашены — ещё не открыли ссылку</h2>
      <ul className="divide-y divide-border text-sm">
        {data.items.map((i) => (
          <li key={i.id} className="flex items-center justify-between gap-3 py-2">
            <span className="min-w-0"><span className="font-medium">{i.fullName}</span> <span className="text-muted">· {i.phone}</span></span>
            <Button variant="ghost" disabled={revoke.isPending} onClick={() => revoke.mutate(i.id)}>Отменить</Button>
          </li>
        ))}
      </ul>
    </Card>
  );
}
