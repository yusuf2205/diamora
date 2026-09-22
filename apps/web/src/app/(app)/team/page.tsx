'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import { hasPerm } from '@/lib/types';
import { roleLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { Page, TeamUser } from '@/lib/types';
import { Badge, Button, EmptyState, ErrorState, Input, Modal, Select, Table, Td, Th } from '@/components/ui';

const ROLES = ['MANAGER', 'ADMIN', 'SUPER_ADMIN'] as const;

/** Users, roles, activation (§4-9, §34). Server-side rank rule: you can only create/manage a STRICTLY lower rank. */
export default function TeamPage() {
  const { me } = useAuth();
  const qc = useQueryClient();
  const [creating, setCreating] = useState(false);
  const { data, error, isLoading } = useQuery<Page<TeamUser>>({ queryKey: ['users'], queryFn: () => api.get<Page<TeamUser>>('/users', { limit: 200 }) });

  const setStatus = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => api.post(`/users/${id}/status`, { status: active ? 'ACTIVE' : 'SUSPENDED' }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['users'] }),
  });

  if (!hasPerm(me, 'USER_VIEW_ALL')) return <EmptyState title="Недостаточно прав для просмотра команды" />;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Команда</h1>
          <p className="text-sm text-muted">Администраторы и менеджеры. Мастерицы регистрируются в Telegram.</p>
        </div>
        {hasPerm(me, 'USER_CREATE') && <Button onClick={() => setCreating(true)}>Добавить пользователя</Button>}
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {data && (
        <Table>
          <thead>
            <tr>
              <Th>Имя</Th><Th>Телефон</Th><Th>Роль</Th><Th>Онлайн</Th><Th>Статус</Th><Th />
            </tr>
          </thead>
          <tbody>
            {data.items.map((u) => (
              <tr key={u.id}>
                <Td className="font-medium">{u.fullName}</Td>
                <Td>{u.phone}</Td>
                <Td>{roleLabel(u.role)}</Td>
                <Td>{u.online ? <Badge tone="ok">в сети</Badge> : <span className="text-muted">—</span>}</Td>
                <Td><Badge tone={u.status === 'ACTIVE' ? 'ok' : 'danger'}>{u.status === 'ACTIVE' ? 'Активен' : 'Отключён'}</Badge></Td>
                <Td>
                  {hasPerm(me, 'USER_DEACTIVATE') && u.id !== me?.id && (
                    <Button variant="outline" onClick={() => setStatus.mutate({ id: u.id, active: u.status !== 'ACTIVE' })} disabled={setStatus.isPending}>
                      {u.status === 'ACTIVE' ? 'Отключить' : 'Включить'}
                    </Button>
                  )}
                </Td>
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
  const qc = useQueryClient();
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState<(typeof ROLES)[number]>('MANAGER');
  const [password, setPassword] = useState<string | null>(null);
  const create = useMutation({
    mutationFn: () => api.post<{ user: TeamUser; temporaryPassword?: string }>('/users', { fullName: fullName.trim(), phone: phone.trim(), role }, { idempotencyKey: crypto.randomUUID() }),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ['users'] });
      if (res.temporaryPassword) setPassword(res.temporaryPassword);
      else onClose();
    },
  });

  if (password) {
    return (
      <Modal title="Пользователь создан" onClose={onClose}>
        <p className="text-sm text-muted">Пароль показывается один раз — передайте его лично.</p>
        <p className="mt-3 select-all rounded-lg bg-border/40 p-3 text-center text-lg font-semibold">{password}</p>
        <div className="flex justify-end pt-4"><Button onClick={onClose}>Готово</Button></div>
      </Modal>
    );
  }

  return (
    <Modal title="Новый пользователь" onClose={onClose}>
      <div className="space-y-3">
        <Input placeholder="ФИО" value={fullName} onChange={(e) => setFullName(e.target.value)} autoFocus />
        <Input placeholder="Телефон" value={phone} onChange={(e) => setPhone(e.target.value)} />
        <Select value={role} onChange={(e) => setRole(e.target.value as typeof role)}>
          {ROLES.map((r) => <option key={r} value={r}>{roleLabel(r)}</option>)}
        </Select>
        {create.isError && <ErrorState error={create.error} />}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose}>Отмена</Button>
          <Button onClick={() => create.mutate()} disabled={!fullName.trim() || !phone.trim() || create.isPending}>Создать</Button>
        </div>
      </div>
    </Modal>
  );
}
