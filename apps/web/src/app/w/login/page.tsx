'use client';

import { useQueryClient } from '@tanstack/react-query';
import { Send } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { api, ApiError, saveTokens } from '@/lib/api';
import { Logo } from '@/components/ui';

type Poll = { status: 'WAITING' | 'NOT_REGISTERED' | 'PENDING_APPROVAL' | 'REJECTED' | 'PAUSED'; rejectedReason?: string } | { accessToken: string; refreshToken: string };

function deviceId() {
  try {
    let id = localStorage.getItem('diamoraa.deviceId');
    if (!id) { id = crypto.randomUUID(); localStorage.setItem('diamoraa.deviceId', id); }
    return id;
  } catch { return crypto.randomUUID(); }
}

const TEXT: Record<string, string> = {
  WAITING: 'Откройте Telegram и нажмите «Старт» у бота Diamoraa. Потом вернитесь сюда — вход произойдёт сам.',
  NOT_REGISTERED: 'Ответьте на вопросы бота в Telegram. Как только заявку одобрят, вход произойдёт здесь сам.',
  PENDING_APPROVAL: 'Ваша заявка на рассмотрении. Мы сообщим, когда вас одобрят.',
  REJECTED: 'К сожалению, заявка отклонена.',
  PAUSED: 'Ваш профиль приостановлен. Свяжитесь с администратором.',
};

/** «Войти через Telegram» in a browser: open the bot, press Start, come back — this tab logs in by itself. */
export default function WorkerWebLogin() {
  const router = useRouter();
  const qc = useQueryClient();
  const [state, setState] = useState<{ token: string; link: string } | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const device = useRef({ installId: '', platform: 'WEB' as const, name: 'Браузер', appVersion: 'web' });

  const start = async () => {
    setError(null);
    device.current.installId = deviceId();
    try {
      const s = await api.post<{ deepLink: string }>('/auth/telegram/session', { device: device.current }, { skipAuth: true });
      const token = new URL(s.deepLink).searchParams.get('start')!;
      setState({ token, link: s.deepLink });
      setStatus('WAITING');
      window.location.href = s.deepLink.replace('https://t.me/', 'tg://resolve?domain=').replace('?start=', '&start=');
      setTimeout(() => { if (document.visibilityState === 'visible') window.open(s.deepLink, '_blank'); }, 1200); // no Telegram app: the web page
    } catch {
      setError('Нет связи с сервером. Попробуйте ещё раз.');
    }
  };

  useEffect(() => {
    if (!state) return;
    let stop = false;
    const tick = async () => {
      try {
        const r = await api.post<Poll>('/auth/telegram/poll', { sessionToken: state.token, device: device.current }, { skipAuth: true });
        if ('accessToken' in r) {
          saveTokens({ accessToken: r.accessToken, refreshToken: r.refreshToken });
          await qc.invalidateQueries({ queryKey: ['me'] });
          router.replace('/w');
          return;
        }
        setStatus(r.status);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) { setState(null); setStatus(null); setError('Время входа истекло. Нажмите кнопку ещё раз.'); return; }
      }
      if (!stop) setTimeout(tick, 2000);
    };
    const t = setTimeout(tick, 1500);
    return () => { stop = true; clearTimeout(t); };
  }, [state, qc, router]);

  return (
    <main className="flex min-h-screen flex-col px-6 pt-16 text-center">
      <Logo size={72} className="mx-auto mb-3" />
      <h1 className="text-2xl font-extrabold">Diamoraa</h1>
      <p className="mt-1 text-muted">Вход для мастериц</p>
      <button onClick={start} className="mt-10 flex min-h-16 items-center justify-center gap-3 rounded-2xl bg-primary px-5 text-lg font-bold text-white shadow-lg shadow-primary/25">
        <Send size={24} aria-hidden /> Войти через Telegram
      </button>
      {status && <p className="mt-6 rounded-xl bg-primary/10 p-4 text-sm">{TEXT[status] ?? ''}</p>}
      {state && <a href={state.link} target="_blank" rel="noreferrer" className="mt-3 text-sm text-primary underline">Открыть бота ещё раз</a>}
      {error && <p className="mt-6 rounded-xl bg-danger/10 p-4 text-sm text-danger">{error}</p>}
      <p className="mt-auto pb-8 text-xs text-muted">Без паролей: вход через ваш Telegram</p>
    </main>
  );
}
