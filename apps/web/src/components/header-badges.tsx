'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, MessageCircle } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { api } from '@/lib/api';

interface Notice { id: string; title: string; body: string | null; link: string | null; read: boolean; createdAt: string }

const count = (n: number) => (n > 99 ? '99+' : String(n));
const when = (iso: string) => {
  const d = new Date(iso); const two = (v: number) => String(v).padStart(2, '0');
  return d.toDateString() === new Date().toDateString() ? `${two(d.getHours())}:${two(d.getMinutes())}` : `${two(d.getDate())}.${two(d.getMonth() + 1)}`;
};
/** app links of notices (/admin/..., /worker/...) -> the panel's own pages */
const webLink = (link: string | null, worker: boolean) => {
  if (!link) return null;
  if (link.startsWith('/chat/')) return `${worker ? '/w/chat' : '/chat'}?room=${link.slice(6)}`;
  return link.replace(/^\/admin\//, '/').replace(/^\/worker\//, '/w/');
};

/** Big, easy to hit: 🔔 notices (with a list) and 💬 chat, each with a clear counter. */
export function HeaderBadges({ chatUnread, chatHref = '/chat', worker = false }: { chatUnread: number; chatHref?: string; worker?: boolean }) {
  const qc = useQueryClient();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const q = useQuery({ queryKey: ['me-notifications'], queryFn: () => api.get<{ unread: number; items: Notice[] }>('/me/notifications', { limit: 30 }), staleTime: 15_000 });
  const readAll = useMutation({ mutationFn: () => api.post('/me/notifications/read', { all: true }), onSuccess: () => qc.invalidateQueries({ queryKey: ['me-notifications'] }) });
  const readOne = useMutation({ mutationFn: (id: string) => api.post('/me/notifications/read', { ids: [id] }), onSuccess: () => qc.invalidateQueries({ queryKey: ['me-notifications'] }) });
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [open]);
  const unread = q.data?.unread ?? 0;
  return (
    <div className="flex items-center gap-1.5" ref={box}>
      <div className="relative">
        <button aria-label={`Уведомления${unread ? `: непрочитанных ${unread}` : ''}`} onClick={() => setOpen(!open)} className="relative flex h-11 w-11 items-center justify-center rounded-full hover:bg-border/50">
          <Bell size={24} aria-hidden />
          {unread > 0 && <span className="absolute -right-0.5 -top-0.5 min-w-6 rounded-full bg-danger px-1.5 text-center text-sm font-bold leading-6 text-white ring-2 ring-card">{count(unread)}</span>}
        </button>
        {open && (
          <div className="absolute right-0 top-12 z-50 w-[min(360px,92vw)] overflow-hidden rounded-xl border border-border bg-card shadow-2xl" role="dialog" aria-label="Уведомления">
            <div className="flex items-center justify-between border-b border-border px-4 py-2.5">
              <p className="font-semibold">Уведомления</p>
              {unread > 0 && <button className="text-sm text-primary" onClick={() => readAll.mutate()}>Прочитать все</button>}
            </div>
            <div className="max-h-[60vh] overflow-y-auto">
              {q.data?.items.length === 0 && <p className="p-6 text-center text-sm text-muted">Пока ничего нет</p>}
              {q.data?.items.map((n) => (
                <button key={n.id} onClick={() => { setOpen(false); if (!n.read) readOne.mutate(n.id); const to = webLink(n.link, worker); if (to) router.push(to); }}
                  className={`block w-full border-b border-border/60 px-4 py-2.5 text-left hover:bg-border/40 ${n.read ? '' : 'bg-primary/5'}`}>
                  <span className="flex items-start justify-between gap-2">
                    <span className={`text-sm ${n.read ? '' : 'font-semibold'}`}>{n.title}</span>
                    <span className="shrink-0 text-xs text-muted">{when(n.createdAt)}</span>
                  </span>
                  {n.body && <span className="mt-0.5 block text-sm text-muted">{n.body}</span>}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
      <Link href={chatHref} aria-label={`Чат${chatUnread ? `: непрочитанных ${chatUnread}` : ''}`} className="relative flex h-11 w-11 items-center justify-center rounded-full hover:bg-border/50">
        <MessageCircle size={24} aria-hidden />
        {chatUnread > 0 && <span className="absolute -right-0.5 -top-0.5 min-w-6 rounded-full bg-danger px-1.5 text-center text-sm font-bold leading-6 text-white ring-2 ring-card">{count(chatUnread)}</span>}
      </Link>
    </div>
  );
}
