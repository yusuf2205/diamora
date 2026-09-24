'use client';

import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { api, ApiError } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { roleLabel } from '@/lib/format';
import { Button, Card, ErrorState, Field, Input, PageHeader } from '@/components/ui';

/** «Мой профиль»: who I am and my own password. Changing it signs out my OTHER devices; this one stays signed in. */
export default function ProfilePage() {
  const { me, logout } = useAuth();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [repeat, setRepeat] = useState('');
  const [done, setDone] = useState<number | null>(null);
  const change = useMutation({
    mutationFn: () => api.post<{ otherSessionsSignedOut: number }>('/auth/change-password', { currentPassword: current, newPassword: next }),
    onSuccess: (r) => { setDone(r.otherSessionsSignedOut); setCurrent(''); setNext(''); setRepeat(''); },
  });
  const mismatch = repeat.length > 0 && next !== repeat;
  const tooShort = next.length > 0 && next.length < 8;
  const wrongCurrent = change.error instanceof ApiError && change.error.code === 'WRONG_PASSWORD';

  return (
    <div className="max-w-xl space-y-4 sm:space-y-6">
      <PageHeader title="Мой профиль" subtitle={me ? `${me.fullName} · ${roleLabel(me.role)} · ${me.phone}` : undefined} />
      <Card className="space-y-3">
        <h2 className="font-medium">Сменить пароль</h2>
        <Field label="Текущий пароль" htmlFor="pw-cur"><Input id="pw-cur" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} /></Field>
        <Field label="Новый пароль" htmlFor="pw-new" hint="Не меньше 8 символов"><Input id="pw-new" type="password" autoComplete="new-password" value={next} onChange={(e) => setNext(e.target.value)} /></Field>
        <Field label="Новый пароль ещё раз" htmlFor="pw-rep"><Input id="pw-rep" type="password" autoComplete="new-password" value={repeat} onChange={(e) => setRepeat(e.target.value)} /></Field>
        {tooShort && <p className="text-sm text-danger">Слишком короткий пароль</p>}
        {mismatch && <p className="text-sm text-danger">Пароли не совпадают</p>}
        {wrongCurrent && <p className="text-sm text-danger">Текущий пароль неверный</p>}
        {change.isError && !wrongCurrent && <ErrorState error={change.error} />}
        {done !== null && <p className="text-sm text-ok" role="status">✓ Пароль изменён{done > 0 ? `. Другие устройства (${done}) вышли из аккаунта` : ''}.</p>}
        <Button onClick={() => { setDone(null); change.mutate(); }} disabled={change.isPending || !current || next.length < 8 || next !== repeat}>Сменить пароль</Button>
      </Card>
      <Button variant="outline" className="text-danger" onClick={() => logout()}>Выйти из аккаунта</Button>
    </div>
  );
}
