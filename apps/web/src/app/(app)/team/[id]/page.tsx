'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { ago, formatDate, formatDay, roleLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import { AUDIT_USER_LABELS, PERMISSION_GROUPS, PERMISSION_LABELS } from '@/lib/permissions';
import { hasPerm } from '@/lib/types';
import type { AuditRow, Page, PermissionCatalog, UserDetail } from '@/lib/types';
import { Badge, Button, Card, EmptyState, ErrorState, Input, Modal, PageHeader } from '@/components/ui';

/** One staff user: facts, role, rights, disable/restore, new password, history. The server enforces every rule
 * (rank, "never yourself", "one SUPER_ADMIN always stays") - the page only hides what can't be done anyway. */
export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { me } = useAuth();
  const qc = useQueryClient();
  const user = useQuery<UserDetail>({ queryKey: ['user', id], queryFn: () => api.get<UserDetail>(`/users/${id}`) });
  const audit = useQuery<Page<AuditRow>>({ queryKey: ['audit', id], queryFn: () => api.get<Page<AuditRow>>('/audit', { entityId: id, limit: 50 }), enabled: hasPerm(me, 'AUDIT_VIEW') });
  const [confirm, setConfirm] = useState<null | { title: string; body: string; run: () => Promise<unknown>; danger?: boolean }>(null);
  const [role, setRole] = useState<string | null>(null);
  const [chosen, setChosen] = useState('');
  const [passwordSet, setPasswordSet] = useState(false);

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['user', id] });
    qc.invalidateQueries({ queryKey: ['users'] });
    qc.invalidateQueries({ queryKey: ['audit', id] });
  };
  const run = useMutation({ mutationFn: (f: () => Promise<unknown>) => f(), onSuccess: () => { refresh(); setConfirm(null); } });

  if (!hasPerm(me, 'USER_VIEW_ALL')) return <EmptyState title="Недостаточно прав для просмотра команды" />;
  if (user.isLoading) return <p className="text-muted">Загрузка…</p>;
  if (user.error || !user.data) return <ErrorState error={user.error} />;
  const u = user.data;
  const isMe = u.id === me?.id;
  const canRole = hasPerm(me, 'ROLE_ASSIGN') && !isMe;
  const canStatus = hasPerm(me, 'USER_DEACTIVATE') && !isMe;
  const canPerms = hasPerm(me, 'PERMISSION_MANAGE') && !isMe && (u.role === 'ADMIN' || u.role === 'MANAGER');
  const pickedRole = role ?? u.role;

  return (
    <div className="max-w-3xl space-y-6">
      <PageHeader
        back={{ href: '/team', label: 'Команда' }}
        title={u.fullName}
        subtitle={
          <span className="flex flex-wrap items-center gap-2">
            <Badge>{roleLabel(u.role)}</Badge>
            <Badge tone={u.status === 'ACTIVE' ? 'ok' : 'danger'}>{u.status === 'ACTIVE' ? 'Активен' : 'Отключён'}</Badge>
            {u.online ? <Badge tone="ok">в сети</Badge> : <span>не в сети</span>}
          </span>
        }
        actions={canStatus ? (u.status === 'ACTIVE'
          ? <Button variant="outline" className="text-danger" onClick={() => setConfirm({ title: 'Отключить пользователя', body: `Отключить ${u.fullName}? Вход будет запрещён сразу на всех устройствах. Вся история сохранится.`, danger: true, run: () => api.post(`/users/${u.id}/status`, { status: 'SUSPENDED' }, { idempotencyKey: crypto.randomUUID() }) })}>Отключить пользователя</Button>
          : <Button onClick={() => run.mutate(() => api.post(`/users/${u.id}/status`, { status: 'ACTIVE' }, { idempotencyKey: crypto.randomUUID() }))}>Восстановить</Button>) : undefined}
      />

      <Card>
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
          <dt className="text-muted">Телефон</dt><dd className="text-right"><a href={`tel:${u.phone}`} className="text-primary hover:underline">{u.phone}</a></dd>
          <dt className="text-muted">Был(а) в сети</dt><dd className="text-right">{u.online ? 'сейчас' : ago(u.lastSeenAt ?? u.lastLoginAt)}</dd>
          <dt className="text-muted">Создан(а)</dt><dd className="text-right">{formatDay(u.createdAt)}</dd>
        </dl>
      </Card>

      {canRole && (
        <Card>
          <h2 className="mb-3 text-sm font-medium text-muted">Роль</h2>
          <div className="flex flex-wrap items-center gap-2">
            {(['SUPER_ADMIN', 'ADMIN', 'MANAGER'] as const).map((r) => (
              <button key={r} onClick={() => setRole(r)} className={`rounded-full border px-3 py-1 text-sm ${pickedRole === r ? 'border-primary bg-primary text-white' : 'border-border hover:bg-border/30'}`}>{roleLabel(r)}</button>
            ))}
            <Button
              disabled={pickedRole === u.role}
              onClick={() => setConfirm({
                title: 'Изменить роль',
                body: `Изменить роль с «${roleLabel(u.role)}» на «${roleLabel(pickedRole)}»? Пользователь выйдет со всех устройств и войдёт заново с новыми правами.`,
                run: () => api.put(`/users/${u.id}/role`, { role: pickedRole }).then(() => setRole(null)),
              })}
            >Изменить роль</Button>
          </div>
        </Card>
      )}

      <PermissionsCard user={u} editable={canPerms} onSaved={refresh} />

      {hasPerm(me, 'PASSWORD_SET') && !isMe && u.role !== 'WORKER' && (
        <Card className="space-y-3">
          <div>
            <h2 className="text-sm font-medium">Пароль</h2>
            <p className="text-sm text-muted">Придумайте пароль сами и передайте его лично. Старый перестанет работать, пользователь выйдет со всех устройств.</p>
          </div>
          {(
            <div className="flex flex-col gap-2 sm:flex-row">
              <Input type="text" autoComplete="off" placeholder="Новый пароль (не меньше 8 символов)" aria-label="Новый пароль" value={chosen} onChange={(e) => setChosen(e.target.value)} />
              <Button
                disabled={chosen.length < 8}
                onClick={() => setConfirm({ title: 'Задать пароль', body: `Установить пароль «${chosen}» для ${u.fullName}? Передайте его лично.`, run: () => api.post(`/users/${u.id}/reset-password`, { password: chosen }, { idempotencyKey: crypto.randomUUID() }).then(() => { setChosen(''); setPasswordSet(true); }) })}
              >Задать пароль</Button>
            </div>
          )}
          {passwordSet && <p className="text-sm text-ok" role="status">✓ Пароль установлен</p>}
        </Card>
      )}

      {me?.role === 'SUPER_ADMIN' && (
        <Card>
          <div className="flex items-start justify-between gap-4">
            <span>
              <span className="block text-sm font-medium" id="map-visible">Показывать на карте</span>
              <span className="block text-sm text-muted">{u.locationHidden ? 'Скрыт: его позицию видите только вы.' : 'Видят все, кому разрешена карта.'}</span>
            </span>
            <button
              role="switch"
              aria-checked={!u.locationHidden}
              aria-labelledby="map-visible"
              disabled={run.isPending}
              onClick={() => run.mutate(() => api.put(`/users/${u.id}/location-visibility`, { hidden: !u.locationHidden }))}
              className={`relative mt-1 h-6 w-11 shrink-0 rounded-full transition ${u.locationHidden ? 'bg-border' : 'bg-primary'}`}
            >
              <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition ${u.locationHidden ? 'left-0.5' : 'left-[1.375rem]'}`} />
            </button>
          </div>
        </Card>
      )}

      {audit.data && (
        <Card>
          <h2 className="mb-3 text-sm font-medium text-muted">История</h2>
          {audit.data.items.length === 0 && <p className="text-sm text-muted">Пока ничего нет.</p>}
          <div className="space-y-2 text-sm">
            {audit.data.items.map((a) => (
              <div key={a.id} className="flex justify-between border-b border-border pb-2 last:border-0">
                <span>{AUDIT_USER_LABELS[a.action] ?? a.action}</span>
                <span className="text-muted">{formatDate(a.createdAt)}{a.actorRole ? ` · ${roleLabel(a.actorRole as UserDetail['role'])}` : ''}</span>
              </div>
            ))}
          </div>
        </Card>
      )}

      {confirm && (
        <Modal title={confirm.title} onClose={() => setConfirm(null)}>
          <p className="text-sm">{confirm.body}</p>
          {run.isError && <ErrorState error={run.error} />}
          <div className="flex gap-2 pt-4 [&>*]:flex-1 sm:justify-end sm:[&>*]:flex-none">
            <Button variant="ghost" onClick={() => setConfirm(null)}>Отмена</Button>
            <Button variant={confirm.danger ? 'danger' : 'primary'} disabled={run.isPending} onClick={() => run.mutate(confirm.run)}>Подтвердить</Button>
          </div>
        </Modal>
      )}
    </div>
  );
}

function PermissionsCard({ user: u, editable, onSaved }: { user: UserDetail; editable: boolean; onSaved: () => void }) {
  const catalog = useQuery<PermissionCatalog>({ queryKey: ['permission-catalog'], queryFn: () => api.get<PermissionCatalog>('/permissions'), enabled: u.role !== 'SUPER_ADMIN' });
  const [on, setOn] = useState<Set<string> | null>(null);
  const save = useMutation({
    mutationFn: (next: Set<string>) => {
      const defaults = new Set(u.permissionDetail.defaults);
      return api.put(`/users/${u.id}/permissions`, { grant: [...next].filter((p) => !defaults.has(p)), revoke: [...defaults].filter((p) => !next.has(p)) });
    },
    onSuccess: () => { setOn(null); onSaved(); },
  });

  if (u.role === 'SUPER_ADMIN') return <Card><h2 className="mb-1 text-sm font-medium text-muted">Права доступа</h2><p className="text-sm">У главного администратора есть все права. Их нельзя ограничить.</p></Card>;
  if (u.role === 'WORKER') return null;
  if (!catalog.data) return catalog.error ? <ErrorState error={catalog.error} /> : null;
  const editableSet = new Set([...(catalog.data.roleDefaults[u.role] ?? []), ...(catalog.data.grantable[u.role] ?? [])]);
  const current = on ?? new Set(u.permissionDetail.effective);
  const defaults = new Set(u.permissionDetail.defaults);
  const dirty = on !== null && (on.size !== u.permissionDetail.effective.length || u.permissionDetail.effective.some((p) => !on.has(p)));

  return (
    <Card>
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-medium text-muted">Права доступа · {current.size} из {editableSet.size}</h2>
        {editable && dirty && <Button disabled={save.isPending} onClick={() => save.mutate(current)}>Сохранить</Button>}
      </div>
      {save.isError && <ErrorState error={save.error} />}
      <div className="grid gap-4 sm:grid-cols-2">
        {PERMISSION_GROUPS.filter((g) => g.perms.some((p) => editableSet.has(p))).map((g) => (
          <div key={g.title}>
            <h3 className="mb-1 text-sm font-semibold">{g.title}</h3>
            {g.perms.filter((p) => editableSet.has(p)).map((p) => (
              <label key={p} className="flex items-center gap-2 py-1 text-sm">
                <input
                  type="checkbox"
                  checked={current.has(p)}
                  disabled={!editable || save.isPending}
                  onChange={(e) => { const n = new Set(current); if (e.target.checked) n.add(p); else n.delete(p); setOn(n); }}
                />
                {PERMISSION_LABELS[p] ?? p}
                {defaults.has(p) && <span className="text-xs text-muted">по умолчанию</span>}
              </label>
            ))}
          </div>
        ))}
      </div>
    </Card>
  );
}
