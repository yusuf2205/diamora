'use client';

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { api, clearTokens } from '@/lib/api';
import { Button, Card } from '@/components/ui';

/** Her profile on the web: name, phone, a link to the Android app, sign out. */
export default function WorkerProfile() {
  const router = useRouter();
  const qc = useQueryClient();
  const { data } = useQuery<{ fullName: string; phone: string; code: string }>({ queryKey: ['w-me'], queryFn: () => api.get('/workers/me') });
  const logout = async () => {
    await api.post('/auth/logout').catch(() => undefined);
    clearTokens();
    qc.clear();
    router.replace('/w/login');
  };
  return (
    <div className="space-y-3">
      <h1 className="text-2xl font-extrabold">Профиль</h1>
      <Card>
        <p className="text-lg font-bold">{data?.fullName}</p>
        <p className="text-sm text-muted">{data?.code} · {data?.phone}</p>
      </Card>
      <Card>
        <p className="text-sm">Есть Android? Приложение работает чуть удобнее:</p>
        <a href="/download" className="mt-2 block rounded-xl bg-primary py-3 text-center font-bold text-white">Скачать приложение</a>
      </Card>
      <Button variant="outline" className="w-full" onClick={logout}>Выйти</Button>
    </div>
  );
}
