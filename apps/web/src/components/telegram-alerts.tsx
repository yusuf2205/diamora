'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { BellRing } from 'lucide-react';
import { api } from '@/lib/api';
import { Button, Card, ErrorState } from '@/components/ui';

/**
 * «Оповещения в Telegram» (admins): one tap opens the bot, «Start» there links this chat. Then the owner hears about it
 * when the site or the server stops answering, when it is back, and when the server's disk is filling up.
 */
export function TelegramAlertsCard() {
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['telegram-alerts'], queryFn: () => api.get<{ linked: boolean }>('/me/telegram-alerts'), refetchInterval: (s) => (s.state.data?.linked ? false : 5_000) });
  const link = useMutation({
    mutationFn: () => api.post<{ url: string }>('/me/telegram-alerts/link', {}),
    onSuccess: (r) => { window.open(r.url, '_blank', 'noopener'); },
  });
  const unlink = useMutation({ mutationFn: () => api.delete('/me/telegram-alerts'), onSuccess: () => qc.invalidateQueries({ queryKey: ['telegram-alerts'] }) });
  const linked = q.data?.linked;
  return (
    <Card className="space-y-3">
      <div className="flex items-start gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary"><BellRing size={20} aria-hidden /></span>
        <div className="min-w-0 flex-1">
          <h2 className="font-medium">Оповещения в Telegram</h2>
          <p className="text-sm text-muted">Бот напишет вам, если сайт или сервер перестал отвечать, когда он снова заработал и если на сервере заканчивается место.</p>
        </div>
      </div>
      {q.isError && <ErrorState error={q.error} onRetry={() => q.refetch()} />}
      {linked === true && (
        <div className="flex flex-wrap items-center gap-3">
          <p className="flex-1 text-sm text-ok" role="status">✓ Подключено — оповещения приходят в ваш Telegram</p>
          <Button variant="outline" onClick={() => unlink.mutate()} disabled={unlink.isPending}>Отключить</Button>
        </div>
      )}
      {linked === false && (
        <div className="space-y-2">
          <Button onClick={() => link.mutate()} disabled={link.isPending}>{link.isPending ? 'Открываем…' : 'Подключить оповещения'}</Button>
          {link.isSuccess && <p className="text-sm text-muted">Откроется бот @diamora1_bot — нажмите в нём «Запустить» (Start). Эта страница сама покажет «Подключено».</p>}
          {link.isError && <ErrorState error={link.error} />}
        </div>
      )}
    </Card>
  );
}
