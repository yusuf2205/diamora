'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, MessageCircle, X } from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
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

/** Big, easy to hit: 🔔 notices (a centred window; a bottom sheet on phones) and 💬 chat, each with a clear counter.
 *  `sidebar`: the desktop / drawer look - a wide, coloured «Чат» button next to the bell, so the chat always stands out. */
export function HeaderBadges({ chatUnread, chatHref = '/chat', worker = false, sidebar = false }: { chatUnread: number; chatHref?: string; worker?: boolean; sidebar?: boolean }) {
  const qc = useQueryClient();
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const q = useQuery({ queryKey: ['me-notifications'], queryFn: () => api.get<{ unread: number; items: Notice[] }>('/me/notifications', { limit: 30 }), staleTime: 15_000 });
  const readAll = useMutation({ mutationFn: () => api.post('/me/notifications/read', { all: true }), onSuccess: () => qc.invalidateQueries({ queryKey: ['me-notifications'] }) });
  const readOne = useMutation({ mutationFn: (id: string) => api.post('/me/notifications/read', { ids: [id] }), onSuccess: () => qc.invalidateQueries({ queryKey: ['me-notifications'] }) });
  useEffect(() => {
    if (!open) return;
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('keydown', esc);
    return () => document.removeEventListener('keydown', esc);
  }, [open]);
  const unread = q.data?.unread ?? 0;
  const inChat = pathname.startsWith(chatHref);
  const badge = (n: number) => <span className="absolute -right-0.5 -top-0.5 min-w-6 rounded-full bg-danger px-1.5 text-center text-sm font-bold leading-6 text-white ring-2 ring-card">{count(n)}</span>;
  const bellButton = (
    <button aria-label={`Уведомления${unread ? `: непрочитанных ${unread}` : ''}`} onClick={() => setOpen(true)}
      className={`relative flex h-11 w-11 shrink-0 items-center justify-center rounded-full hover:bg-border/50 ${sidebar ? 'border border-border' : ''}`}>
      <Bell size={22} aria-hidden />
      {unread > 0 && badge(unread)}
    </button>
  );
  return (
    <>
      {sidebar ? (
        <div className="flex items-center gap-2">
          <Link href={chatHref} aria-label={`Чат${chatUnread ? `: непрочитанных ${chatUnread}` : ''}`}
            className={`flex h-11 flex-1 items-center gap-2.5 rounded-xl px-3.5 text-[15px] font-semibold shadow-sm transition ${inChat ? 'bg-primary text-white' : 'bg-primary/10 text-primary ring-1 ring-primary/25 hover:bg-primary/15'}`}>
            <MessageCircle size={20} aria-hidden />
            <span className="flex-1">Чат</span>
            {chatUnread > 0 && <span className="min-w-6 rounded-full bg-danger px-1.5 text-center text-sm font-bold leading-6 text-white">{count(chatUnread)}</span>}
          </Link>
          {bellButton}
        </div>
      ) : (
        <div className="flex items-center gap-1.5">
          {bellButton}
          <Link href={chatHref} aria-label={`Чат${chatUnread ? `: непрочитанных ${chatUnread}` : ''}`}
            className={`relative flex h-11 w-11 items-center justify-center rounded-full ${inChat ? 'bg-primary text-white' : 'bg-primary/10 text-primary'}`}>
            <MessageCircle size={22} aria-hidden />
            {chatUnread > 0 && badge(chatUnread)}
          </Link>
        </div>
      )}
      {open && createPortal(
        <div className="fixed inset-0 z-[60] flex items-end justify-center bg-black/40 sm:items-center sm:p-6" onClick={() => setOpen(false)}>
          <div role="dialog" aria-modal aria-label="Уведомления" onClick={(e) => e.stopPropagation()}
            className="flex max-h-[85vh] w-full flex-col overflow-hidden rounded-t-2xl bg-card shadow-2xl sm:max-h-[80vh] sm:max-w-lg sm:rounded-2xl">
            <div className="flex items-center gap-3 border-b border-border px-5 py-4">
              <p className="flex-1 text-lg font-semibold">Уведомления{unread > 0 && <span className="ml-2 text-sm font-normal text-muted">непрочитанных: {unread}</span>}</p>
              {unread > 0 && <button className="text-sm font-medium text-primary" onClick={() => readAll.mutate()}>Прочитать все</button>}
              <button aria-label="Закрыть" onClick={() => setOpen(false)} className="-mr-1 rounded-full p-1.5 text-muted hover:bg-border/50"><X size={20} aria-hidden /></button>
            </div>
            <div className="overflow-y-auto pb-[env(safe-area-inset-bottom)]">
              {q.data?.items.length === 0 && <p className="p-10 text-center text-muted">Пока ничего нет</p>}
              {q.data?.items.map((n) => (
                <button key={n.id} onClick={() => { setOpen(false); if (!n.read) readOne.mutate(n.id); const to = webLink(n.link, worker); if (to) router.push(to); }}
                  className="flex w-full gap-3 border-b border-border/60 px-5 py-3 text-left hover:bg-border/40">
                  <span className={`mt-2 h-2 w-2 shrink-0 rounded-full ${n.read ? 'bg-transparent' : 'bg-primary'}`} aria-hidden />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-start justify-between gap-2">
                      <span className={n.read ? '' : 'font-semibold'}>{n.title}</span>
                      <span className="shrink-0 text-xs text-muted">{when(n.createdAt)}</span>
                    </span>
                    {n.body && <span className="mt-0.5 block text-sm text-muted">{n.body}</span>}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>,
        document.body,
      )}
    </>
  );
}
