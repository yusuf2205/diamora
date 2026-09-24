'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { hasPerm } from '@/lib/types';
import { formatDate, roleLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { Page, TeamUser } from '@/lib/types';
import { Badge, Button, EmptyState, ErrorState, Input, Modal, Select, Table, Td, Th } from '@/components/ui';

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
  const router = useRouter();
  const [creating, setCreating] = useState(false);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]['key']>('all');
  const [search, setSearch] = useState('');
  const [q, setQ] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setQ(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);
  const params = { limit: 100, ...FILTERS.find((f) => f.key === filter)!.query, ...(q ? { q } : {}) };
  const { data, error, isLoading } = useQuery<Page<TeamUser>>({ queryKey: ['users', params], queryFn: () => api.get<Page<TeamUser>>('/users', params) });

  if (!hasPerm(me, 'USER_VIEW_ALL')) return <EmptyState title="Недостаточно прав для просмотра команды" />;

  const open = (u: TeamUser) => router.push(u.role === 'WORKER' && u.workerId ? `/workers/${u.workerId}` : `/team/${u.id}`);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Команда</h1>
          <p className="text-sm text-muted">Сотрудники и мастерицы. Мастерицы регистрируются сами в Telegram.</p>
        </div>
        {hasPerm(me, 'USER_CREATE') && <Button onClick={() => setCreating(true)}>+ Добавить пользователя</Button>}
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Input className="max-w-xs" placeholder="Имя или телефон" value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Поиск" />
        {FILTERS.map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`rounded-full border px-3 py-1 text-sm ${filter === f.key ? 'border-primary bg-primary text-white' : 'border-border hover:bg-border/30'}`}
          >
            {f.label}
          </button>
        ))}
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && data.items.length === 0 && <EmptyState title="Никого не найдено" />}
      {data && data.items.length > 0 && (
        <Table>
          <thead>
            <tr>
              <Th>Имя</Th><Th>Телефон</Th><Th>Роль</Th><Th>Менеджер</Th><Th>В сети</Th><Th>Создан</Th><Th>Статус</Th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((u) => (
              <tr key={u.id} className="cursor-pointer hover:bg-border/20" onClick={() => open(u)}>
                <Td className="font-medium">{u.fullName}{u.id === me?.id && <span className="text-muted"> · это вы</span>}</Td>
                <Td>{u.phone}</Td>
                <Td>{roleLabel(u.role)}</Td>
                <Td>{u.role === 'WORKER' ? (u.managerName ?? <span className="text-muted">Без менеджера</span>) : ''}</Td>
                <Td>{u.online ? <Badge tone="ok">в сети</Badge> : <span className="text-muted">{u.lastSeenAt ?? u.lastLoginAt ? formatDate(u.lastSeenAt ?? u.lastLoginAt) : '—'}</span>}</Td>
                <Td className="text-muted">{u.createdAt ? u.createdAt.slice(0, 10) : '—'}</Td>
                <Td><Badge tone={u.status === 'ACTIVE' ? 'ok' : 'danger'}>{u.status === 'ACTIVE' ? 'Активен' : 'Отключён'}</Badge></Td>
              </tr>
            ))}
          </tbody>
        </Table>
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
  const [password, setPassword] = useState<string | null>(null);
  const create = useMutation({
    mutationFn: async () => {
      const res = await api.post<{ user: TeamUser; temporaryPassword?: string }>('/users', { fullName: fullName.trim(), phone: phone.trim(), role }, { idempotencyKey: crypto.randomUUID() });
      if (!active) await api.post(`/users/${res.user.id}/status`, { status: 'SUSPENDED' }, { idempotencyKey: crypto.randomUUID() });
      return res;
    },
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ['users'] });
      if (res.temporaryPassword) setPassword(res.temporaryPassword);
      else onClose();
    },
  });

  if (password) {
    return (
      <Modal title="Пользователь создан" onClose={onClose}>
        <p className="text-sm text-muted">Временный пароль показывается один раз — передайте его лично.</p>
        <p className="mt-3 select-all rounded-lg bg-border/40 p-3 text-center text-lg font-semibold">{password}</p>
        <div className="flex justify-end gap-2 pt-4">
          <Button variant="outline" onClick={() => navigator.clipboard?.writeText(password)}>Копировать</Button>
          <Button onClick={onClose}>Готово</Button>
        </div>
      </Modal>
    );
  }

  return (
    <Modal title="Новый пользователь" onClose={onClose}>
      <div className="space-y-3">
        <Input placeholder="ФИО" value={fullName} onChange={(e) => setFullName(e.target.value)} autoFocus />
        <Input placeholder="Телефон" value={phone} onChange={(e) => setPhone(e.target.value)} />
        <Select value={role} onChange={(e) => setRole(e.target.value as typeof role)} aria-label="Роль">
          {roles.map((r) => <option key={r} value={r}>{roleLabel(r)}</option>)}
        </Select>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Сразу активен
        </label>
        <p className="text-xs text-muted">Мастерицы здесь не создаются — они регистрируются через Telegram-бота.</p>
        {create.isError && <ErrorState error={create.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => create.mutate()} disabled={fullName.trim().length < 2 || phone.replace(/\D/g, '').length < 9 || create.isPending}>Создать</Button>
        </div>
      </div>
    </Modal>
  );
}
