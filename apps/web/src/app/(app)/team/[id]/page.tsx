'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { formatDate, roleLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import { AUDIT_USER_LABELS, PERMISSION_GROUPS, PERMISSION_LABELS } from '@/lib/permissions';
import { hasPerm } from '@/lib/types';
import type { AuditRow, Page, PermissionCatalog, UserDetail } from '@/lib/types';
import { Badge, Button, Card, EmptyState, ErrorState, Modal } from '@/components/ui';

/** One staff user: facts, role, rights, disable/restore, new password, history. The server enforces every rule
 * (rank, "never yourself", "one SUPER_ADMIN always stays") - the page only hides what can't be done anyway. */
export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { me } = useAuth();
  const qc = useQueryClient();
  const user = useQuery<UserDetail>({ queryKey: ['user', id], queryFn: () => api.get<UserDetail>(`/users/${id}`) });
  const audit = useQuery<Page<AuditRow>>({ queryKey: ['audit', id], queryFn: () => api.get<Page<AuditRow>>('/audit', { entityId: id, limit: 50 }), enabled: hasPerm(me, 'AUDIT_VIEW') });
  const [confirm, setConfirm] = useState<null | { title: string; body: string; run: () => Promise<unknown>; danger?: boolean }>(null);
  const [password, setPassword] = useState<string | null>(null);
  const [role, setRole] = useState<string | null>(null);

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
      <Link href="/team" className="text-sm text-muted hover:underline">← Команда</Link>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">{u.fullName}</h1>
          <p className="mt-1 flex flex-wrap items-center gap-2 text-sm text-muted">
            <Badge>{roleLabel(u.role)}</Badge>
            <Badge tone={u.status === 'ACTIVE' ? 'ok' : 'danger'}>{u.status === 'ACTIVE' ? 'Активен' : 'Отключён'}</Badge>
            {u.online ? <Badge tone="ok">в сети</Badge> : <span>не в сети</span>}
          </p>
        </div>
        {canStatus && (u.status === 'ACTIVE'
          ? <Button variant="outline" onClick={() => setConfirm({ title: 'Отключить пользователя', body: `Отключить ${u.fullName}? Вход будет запрещён сразу на всех устройствах. Вся история сохранится.`, danger: true, run: () => api.post(`/users/${u.id}/status`, { status: 'SUSPENDED' }, { idempotencyKey: crypto.randomUUID() }) })}>Отключить пользователя</Button>
          : <Button onClick={() => run.mutate(() => api.post(`/users/${u.id}/status`, { status: 'ACTIVE' }, { idempotencyKey: crypto.randomUUID() }))}>Восстановить</Button>)}
      </div>

      <Card>
        <dl className="grid grid-cols-2 gap-3 text-sm">
          <dt className="text-muted">Телефон</dt><dd><a href={`tel:${u.phone}`} className="hover:underline">{u.phone}</a></dd>
          <dt className="text-muted">Был(а) в сети</dt><dd>{u.online ? 'сейчас' : formatDate(u.lastSeenAt ?? u.lastLoginAt) === '—' ? 'ещё не входил(а)' : formatDate(u.lastSeenAt ?? u.lastLoginAt)}</dd>
          <dt className="text-muted">Создан(а)</dt><dd>{u.createdAt ? u.createdAt.slice(0, 10) : '—'}</dd>
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

      {hasPerm(me, 'USER_UPDATE') && !isMe && u.role !== 'WORKER' && (
        <Card>
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-sm font-medium">Пароль</h2>
              <p className="text-sm text-muted">Старый перестанет работать, пользователь выйдет со всех устройств.</p>
            </div>
            <Button variant="outline" onClick={() => setConfirm({ title: 'Выдать новый пароль', body: 'Старый пароль перестанет работать, пользователь выйдет со всех устройств.', run: () => api.post<{ temporaryPassword: string }>(`/users/${u.id}/reset-password`, {}, { idempotencyKey: crypto.randomUUID() }).then((r) => setPassword(r.temporaryPassword)) })}>Выдать новый пароль</Button>
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
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="ghost" onClick={() => setConfirm(null)}>Отмена</Button>
            <Button className={confirm.danger ? 'bg-danger' : ''} disabled={run.isPending} onClick={() => run.mutate(confirm.run)}>Подтвердить</Button>
          </div>
        </Modal>
      )}
      {password && (
        <Modal title="Временный пароль" onClose={() => setPassword(null)}>
          <p className="text-sm text-muted">Передайте пароль сотруднику лично. Он показывается только один раз.</p>
          <p className="mt-3 select-all rounded-lg bg-border/40 p-3 text-center text-lg font-semibold">{password}</p>
          <div className="flex justify-end pt-4"><Button onClick={() => setPassword(null)}>Готово</Button></div>
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
