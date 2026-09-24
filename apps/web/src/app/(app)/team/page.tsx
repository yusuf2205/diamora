'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { hasPerm } from '@/lib/types';
import { ago, formatDay, initials, roleLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { Page, TeamUser } from '@/lib/types';
import { Badge, Button, Chips, DataList, EmptyState, ErrorState, Field, Input, ListSkeleton, Modal, PageHeader, Select } from '@/components/ui';

const FILTERS = [
  { key: 'all', label: 'Все', query: {} },
  { key: 'SUPER_ADMIN', label: 'Главные администраторы', query: { role: 'SUPER_ADMIN' } },
  { key: 'ADMIN', label: 'Администраторы', query: { role: 'ADMIN' } },
  { key: 'MANAGER', label: 'Менеджеры', query: { role: 'MANAGER' } },
  { key: 'WORKER', label: 'Мастерицы', query: { role: 'WORKER' } },
  { key: 'active', label: 'Активные', query: { status: 'ACTIVE' } },
  { key: 'disabled', label: 'Отключённые', query: { status: 'SUSPENDED' } },
] as const;

/** «Команда»: every account (staff and workers) in one table - filter by role or status, search by name or phone.
 * A staff row opens the user card (role, rights, disable/restore); a worker row opens her worker card. */
export default function TeamPage() {
  const { me } = useAuth();
  const [creating, setCreating] = useState(false);
  const [filter, setFilter] = useState<string>('all');
  const [search, setSearch] = useState('');
  const [q, setQ] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setQ(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);
  const params = { limit: 100, ...FILTERS.find((f) => f.key === filter)!.query, ...(q ? { q } : {}) };
  const { data, error, isLoading } = useQuery<Page<TeamUser>>({ queryKey: ['users', params], queryFn: () => api.get<Page<TeamUser>>('/users', params) });

  if (!hasPerm(me, 'USER_VIEW_ALL')) return <EmptyState title="Недостаточно прав для просмотра команды" />;

  const seen = (u: TeamUser) => (u.online ? <Badge tone="ok">в сети</Badge> : <span className="text-muted">{ago(u.lastSeenAt ?? u.lastLoginAt)}</span>);
  const href = (u: TeamUser) => (u.role === 'WORKER' && u.workerId ? `/workers/${u.workerId}` : `/team/${u.id}`);
  const status = (u: TeamUser) => <Badge tone={u.status === 'ACTIVE' ? 'ok' : 'danger'}>{u.status === 'ACTIVE' ? 'Активен' : 'Отключён'}</Badge>;

  return (
    <div className="space-y-4 sm:space-y-6">
      <PageHeader
        title="Команда"
        subtitle="Сотрудники и мастерицы. Мастерицы регистрируются сами в Telegram."
        actions={hasPerm(me, 'USER_CREATE') ? <Button onClick={() => setCreating(true)}>+ Добавить пользователя</Button> : undefined}
      />
      <div className="space-y-3">
        <Input type="search" className="md:max-w-sm" placeholder="Имя или телефон" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Поиск" />
        <Chips options={FILTERS.map((f) => ({ value: f.key, label: f.label }))} value={filter} onChange={setFilter} label="Фильтр" />
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <ListSkeleton />}
      {data && data.items.length === 0 && <EmptyState title="Никого не найдено" />}
      {data && data.items.length > 0 && (
        <DataList
          rows={data.items}
          rowKey={(u) => u.id}
          href={href}
          columns={[
            { header: 'Имя', cell: (u) => <span className="font-medium">{u.fullName}{u.id === me?.id && <span className="font-normal text-muted"> · это вы</span>}</span> },
            { header: 'Телефон', cell: (u) => <span className="whitespace-nowrap">{u.phone}</span> },
            { header: 'Роль', cell: (u) => roleLabel(u.role) },
            { header: 'Менеджер', cell: (u) => (u.role === 'WORKER' ? (u.managerName ?? <span className="text-muted">Без менеджера</span>) : '') },
            { header: 'В сети', cell: seen },
            { header: 'Создан', cell: (u) => <span className="whitespace-nowrap text-muted">{formatDay(u.createdAt)}</span> },
            { header: 'Статус', cell: status },
          ]}
          card={(u) => (
            <div className="flex items-start gap-3">
              <span className="relative mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
                {initials(u.fullName)}
                <span className={`absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-card ${u.online ? 'bg-ok' : 'bg-border'}`} />
              </span>
              <div className="min-w-0 flex-1 space-y-0.5">
                <div className="flex items-start justify-between gap-2">
                  <p className="font-medium leading-snug">{u.fullName}{u.id === me?.id && <span className="font-normal text-muted"> · это вы</span>}</p>
                  {u.status !== 'ACTIVE' && status(u)}
                </div>
                <p className="text-sm text-muted">{u.phone}</p>
                <p className="text-xs text-muted">
                  <span className="font-medium text-foreground/70">{roleLabel(u.role)}</span>
                  {u.role === 'WORKER' ? ` · ${u.managerName ? `менеджер ${u.managerName}` : 'без менеджера'}` : ''}
                  {` · ${u.online ? 'в сети' : ago(u.lastSeenAt ?? u.lastLoginAt)}`}
                </p>
              </div>
            </div>
          )}
        />
      )}
      {creating && <CreateUserDialog onClose={() => setCreating(false)} />}
    </div>
  );
}

function CreateUserDialog({ onClose }: { onClose: () => void }) {
  const { me } = useAuth();
  const qc = useQueryClient();
  const roles = me?.role === 'SUPER_ADMIN' ? (['MANAGER', 'ADMIN'] as const) : (['MANAGER'] as const);
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('+998');
  const [role, setRole] = useState<'MANAGER' | 'ADMIN'>('MANAGER');
  const [active, setActive] = useState(true);
  const [password, setPassword] = useState('');
  const create = useMutation({
    mutationFn: async () => {
      const res = await api.post<{ user: TeamUser }>('/users', { fullName: fullName.trim(), phone: phone.trim(), role, password }, { idempotencyKey: crypto.randomUUID() });
      if (!active) await api.post(`/users/${res.user.id}/status`, { status: 'SUSPENDED' }, { idempotencyKey: crypto.randomUUID() });
      return res;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['users'] });
      onClose();
    },
  });

  return (
    <Modal title="Новый пользователь" onClose={onClose}>
      <div className="space-y-3">
        <Field label="ФИО" htmlFor="nu-name"><Input id="nu-name" value={fullName} onChange={(e) => setFullName(e.target.value)} autoFocus /></Field>
        <Field label="Телефон" htmlFor="nu-phone"><Input id="nu-phone" type="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
        <Field label="Роль" htmlFor="nu-role">
          <Select id="nu-role" value={role} onChange={(e) => setRole(e.target.value as typeof role)} aria-label="Роль">
            {roles.map((r) => <option key={r} value={r}>{roleLabel(r)}</option>)}
          </Select>
        </Field>
        <Field label="Пароль для входа" htmlFor="nu-pass" hint="Придумайте сами (не меньше 8 символов) и передайте лично">
          <Input id="nu-pass" type="text" autoComplete="off" value={password} onChange={(e) => setPassword(e.target.value)} />
        </Field>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Сразу активен
        </label>
        <p className="text-xs text-muted">Мастерицы здесь не создаются — они регистрируются через Telegram-бота.</p>
        {create.isError && <ErrorState error={create.error} />}
        <div className="flex gap-2 pt-2 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => create.mutate()} disabled={fullName.trim().length < 2 || phone.replace(/\D/g, '').length < 9 || password.length < 8 || create.isPending}>Создать</Button>
        </div>
      </div>
    </Modal>
  );
}
