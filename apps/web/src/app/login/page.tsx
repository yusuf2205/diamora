'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { ApiError } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { Button, Input } from '@/components/ui';

/** Staff sign-in (SUPER_ADMIN / ADMIN / MANAGER). WORKER has no password and does not use this panel (D-028). */
export default function LoginPage() {
  const { login, signedIn } = useAuth();
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (signedIn) router.replace('/dashboard');
  }, [signedIn, router]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(phone.trim(), password);
      router.replace('/dashboard');
    } catch (err) {
      setError(err instanceof ApiError && err.code === 'INVALID_CREDENTIALS' ? 'Неверный телефон или пароль' : err instanceof ApiError ? err.message : 'Не удалось войти');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <form onSubmit={submit} className="w-full max-w-sm space-y-4 rounded-xl border border-border bg-card p-6">
        <div>
          <h1 className="text-xl font-semibold">Yusmus</h1>
          <p className="text-sm text-muted">Панель управления</p>
        </div>
        <div className="space-y-1">
          <label className="text-sm text-muted" htmlFor="phone">Телефон</label>
          <Input id="phone" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+998 90 123 45 67" autoFocus />
        </div>
        <div className="space-y-1">
          <label className="text-sm text-muted" htmlFor="password">Пароль</label>
          <Input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>
        {error && <p className="text-sm text-danger">{error}</p>}
        <Button type="submit" disabled={busy || !phone || !password} className="w-full">{busy ? 'Входим…' : 'Войти'}</Button>
      </form>
    </main>
  );
}
