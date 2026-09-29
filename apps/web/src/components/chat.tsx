'use client';

import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Camera, Megaphone, BellOff, Check, CheckCheck, Copy, Download, FileText, Forward, Info, Mic, MoreVertical, Paperclip, Pencil, Pin, Plus, Reply, Search, Send, Smile, Trash2, Users, X } from 'lucide-react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';
import { emitLive, onLiveEvent } from '@/lib/live';
import { useAuth } from '@/lib/auth';
import { errorMessage, initials, roleLabel } from '@/lib/format';
import { Button, ErrorState, Input, Modal, Spinner } from '@/components/ui';

// ---- types (GET /v1/chat/...) ------------------------------------------------------------------------------------------
export interface ChatPerson { id: string; fullName: string; role: string; online?: boolean; isOwner?: boolean; lastReadAt?: string | null; lastSeenAt?: string | null; isAdmin?: boolean }
export interface ChatReaction { emoji: string; count: number; mine: boolean }
export const CHAT_REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥'] as const;
export interface ChatFile { url: string; thumbUrl: string | null; name: string | null; size: number | null; mimeType: string | null; durationMs: number | null; width: number | null; height: number | null }
export interface ChatMessage { id: string; roomId: string; kind: 'TEXT' | 'IMAGE' | 'VIDEO' | 'VOICE' | 'AUDIO' | 'FILE'; sender: ChatPerson | null; text: string | null; file: ChatFile | null; deleted: boolean; createdAt: string; clientId: string | null;
  replyTo?: { id: string; sender: string | null; preview: string | null; deleted: boolean } | null; forwardedFrom?: string | null; editedAt?: string | null; reactions?: ChatReaction[] }
export interface ChatRoomSummary { id: string; kind: 'DIRECT' | 'GROUP' | 'COMPANY' | 'CHANNEL'; photo?: string | null; title: string | null; peer: ChatPerson | null; memberCount: number; isOwner: boolean; unread: number; lastMessage: ChatMessage | null; lastMessageAt: string; pinned?: boolean; muted?: boolean }
export interface ChatRoomDetail { id: string; kind: ChatRoomSummary['kind']; title: string | null; isOwner: boolean; canManage: boolean; memberCount: number; peer: ChatPerson | null; members: ChatPerson[];
  canPin?: boolean; pinned?: boolean; muted?: boolean; pinnedMessage?: ChatMessage | null;
  description?: string | null; photo?: { url: string; thumbUrl: string } | null; audience?: 'ALL' | 'STAFF' | 'WORKERS' | 'CUSTOM' | null;
  onlyAdminsWrite?: boolean; canWrite?: boolean; canEditAdmins?: boolean; isAdmin?: boolean }
interface ChatSearch { rooms: ChatRoomSummary[]; people: ChatPerson[]; messages: (ChatMessage & { room: { id: string; kind: string; title: string | null } })[] }

export const CHAT_MAX_BYTES = 50 * 1024 * 1024;

export const chatTitle = (r: { kind: string; title: string | null }) => (r.kind === 'COMPANY' ? 'Общий чат' : (r.title ?? ''));

export function chatPreview(m: ChatMessage): string {
  if (m.deleted) return 'Сообщение удалено';
  const label = { IMAGE: '📷 Фото', VIDEO: '🎬 Видео', VOICE: '🎤 Голосовое сообщение', AUDIO: '🎵 Аудио', FILE: `📎 ${m.file?.name ?? 'Файл'}`, TEXT: null }[m.kind];
  const text = (m.text ?? '').trim();
  if (!label) return text;
  return text ? `${label} · ${text}` : label;
}

/** What a picked file is (the server checks the real bytes). */
export function chatKindForFile(f: { name: string; type: string }): ChatMessage['kind'] {
  if (/^image\/(jpeg|png|webp)$/.test(f.type)) return 'IMAGE';
  if (f.type.startsWith('video/')) return 'VIDEO';
  if (f.type.startsWith('audio/')) return 'AUDIO';
  return 'FILE';
}

const two = (v: number) => String(v).padStart(2, '0');
export function chatWhen(iso: string, now = new Date()): string {
  const t = new Date(iso);
  if (t.toDateString() === now.toDateString()) return `${two(t.getHours())}:${two(t.getMinutes())}`;
  const y = new Date(now); y.setDate(now.getDate() - 1);
  if (t.toDateString() === y.toDateString()) return 'Вчера';
  return `${two(t.getDate())}.${two(t.getMonth() + 1)}`;
}
const dayLabel = (iso: string) => {
  const t = new Date(iso); const now = new Date(); const y = new Date(now); y.setDate(now.getDate() - 1);
  if (t.toDateString() === now.toDateString()) return 'Сегодня';
  if (t.toDateString() === y.toDateString()) return 'Вчера';
  return `${two(t.getDate())}.${two(t.getMonth() + 1)}.${t.getFullYear()}`;
};
const bytes = (b: number | null) => (b == null ? '' : b < 1024 * 1024 ? `${Math.max(1, Math.round(b / 1024))} KB` : `${(b / 1024 / 1024).toFixed(1)} MB`);
const newId = () => (typeof crypto !== 'undefined' && 'randomUUID' in crypto ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`);

/** Links become tappable (new tab, no referrer), @mentions stand out; everything is plain React text (no HTML). */
export function RichText({ text }: { text: string }) {
  const parts = text.split(/(https?:\/\/[^\s]+|www\.[^\s]+|@[\p{L}\p{N}_]+)/u);
  return (
    <>
      {parts.map((part, i) => {
        if (i % 2 === 0) return part;
        if (part.startsWith('@')) return <b key={i} className="text-primary">{part}</b>;
        const href = part.startsWith('www.') ? `https://${part}` : part;
        return <a key={i} href={href} target="_blank" rel="noopener noreferrer" className="text-primary underline break-all">{part}</a>;
      })}
    </>
  );
}

const lastSeen = (iso: string) => `был(а) в сети ${chatWhen(iso)}`;
const EMOJIS = ['😀', '😂', '😊', '😍', '🥰', '😉', '😎', '🤔', '😅', '😢', '😭', '😡', '🙈', '👍', '👎', '👌', '🙏', '👏', '💪', '🤝', '❤️', '🔥', '✨', '🎉', '🌸', '💎', '✅', '❌', '⏰', '📦', '🧵', '✂️', '📍', '☕'];

/** The unread count for the menu badge (refetched by the live socket like everything else). */
export function useChatUnread(enabled = true) {
  return useQuery({ queryKey: ['chat-unread'], queryFn: () => api.get<{ count: number }>('/chat/unread'), enabled, staleTime: 10_000 }).data?.count ?? 0;
}

function Avatar({ kind, name, online, size = 40, photo }: { kind: string; name: string; online?: boolean; size?: number; photo?: string | null }) {
  if (photo) return <img src={photo} alt="" className="shrink-0 rounded-full object-cover" style={{ width: size, height: size }} />;
  const cls = kind === 'COMPANY' ? 'bg-primary text-white' : kind === 'GROUP' ? 'bg-amber-100 text-amber-800' : kind === 'CHANNEL' ? 'bg-sky-100 text-sky-800' : 'bg-primary/15 text-primary';
  return (
    <span className="relative inline-flex shrink-0">
      <span className={`flex items-center justify-center rounded-full font-semibold ${cls}`} style={{ width: size, height: size, fontSize: size * 0.36 }}>
        {kind === 'COMPANY' ? '💎' : kind === 'GROUP' ? <Users size={size * 0.5} aria-hidden /> : kind === 'CHANNEL' ? <Megaphone size={size * 0.5} aria-hidden /> : initials(name)}
      </span>
      {online && <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-card bg-ok" aria-label="в сети" />}
    </span>
  );
}

// ---- the whole chat: list + conversation (side by side on a wide screen, one at a time on a phone) ------------------------
/** `single`: always one pane (the worker web is phone-width even on a big screen). */
export function ChatApp({ single = false }: { single?: boolean }) {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const roomId = params.get('room');
  const open = (id: string | null) => router.push(id ? `${pathname}?room=${id}` : pathname);
  return (
    <div className={`flex overflow-hidden rounded-xl border border-border bg-card ${single ? 'h-[calc(100dvh-8.5rem)] min-h-[380px]' : 'h-[calc(100dvh-9rem)] min-h-[420px] lg:h-[calc(100vh-4rem)]'}`}>
      <div className={`${roomId ? (single ? 'hidden' : 'hidden md:flex') : 'flex'} w-full flex-col ${single ? '' : 'border-r border-border md:w-80 md:shrink-0'}`}>
        <RoomList selected={roomId} onOpen={open} />
      </div>
      <div className={`${roomId ? 'flex' : single ? 'hidden' : 'hidden md:flex'} min-w-0 flex-1 flex-col`}>
        {roomId ? <Conversation key={roomId} roomId={roomId} onBack={() => open(null)} single={single} /> : <div className="m-auto p-6 text-center text-muted">Выберите чат слева</div>}
      </div>
    </div>
  );
}

function RoomList({ selected, onOpen }: { selected: string | null; onOpen: (id: string) => void }) {
  const { me } = useAuth();
  const qc = useQueryClient();
  const q = useQuery({ queryKey: ['chat-rooms'], queryFn: () => api.get<{ items: ChatRoomSummary[] }>('/chat/rooms') });
  const [creating, setCreating] = useState(false);
  const [search, setSearch] = useState('');
  const [debounced, setDebounced] = useState('');
  useEffect(() => { const id = setTimeout(() => setDebounced(search.trim()), 300); return () => clearTimeout(id); }, [search]);
  const found = useQuery({ queryKey: ['chat-search', debounced], queryFn: () => api.get<ChatSearch>('/chat/search', { q: debounced }), enabled: debounced.length >= 2 });
  const prefs = useMutation({
    mutationFn: ({ id, ...b }: { id: string; pinned?: boolean; muted?: boolean }) => api.patch(`/chat/rooms/${id}/me`, b),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['chat-rooms'] }),
  });
  const direct = useMutation({ mutationFn: (userId: string) => api.post<ChatRoomDetail>('/chat/direct', { userId }), onSuccess: (r) => { setSearch(''); onOpen(r.id); } });
  const [menu, setMenu] = useState<string | null>(null);
  return (
    <>
      <div className="flex items-center justify-between gap-2 border-b border-border px-4 py-3">
        <h2 className="text-lg font-semibold">Чат</h2>
        <Button className="min-h-9 px-3 py-1.5 text-sm" onClick={() => setCreating(true)}><Plus size={16} aria-hidden /> Новый чат</Button>
      </div>
      <div className="border-b border-border px-3 py-2">
        <label className="flex items-center gap-2 rounded-lg bg-background px-3 py-1.5">
          <Search size={16} className="text-muted" aria-hidden />
          <input aria-label="Поиск: чаты, люди, сообщения" placeholder="Поиск: чаты, люди, сообщения" value={search} onChange={(e) => setSearch(e.target.value)} className="w-full bg-transparent text-sm outline-none" />
          {search && <button aria-label="Очистить поиск" onClick={() => setSearch('')}><X size={14} aria-hidden /></button>}
        </label>
      </div>
      {debounced.length >= 2 ? (
        <div className="flex-1 overflow-y-auto">
          {found.isLoading && <div className="flex justify-center p-6"><Spinner /></div>}
          {found.data && !found.data.rooms.length && !found.data.people.length && !found.data.messages.length && <p className="p-6 text-center text-muted">Ничего не найдено</p>}
          {!!found.data?.rooms.length && <p className="px-4 pt-3 text-xs font-semibold uppercase text-primary">Чаты</p>}
          {found.data?.rooms.map((r) => (
            <button key={r.id} onClick={() => { setSearch(''); onOpen(r.id); }} className="flex w-full items-center gap-3 px-4 py-2 text-left hover:bg-border/40">
              <Avatar kind={r.kind} name={chatTitle(r)} size={34} /><span className="truncate font-medium">{chatTitle(r)}</span>
            </button>
          ))}
          {!!found.data?.people.length && <p className="px-4 pt-3 text-xs font-semibold uppercase text-primary">Люди</p>}
          {found.data?.people.map((p) => (
            <button key={p.id} onClick={() => direct.mutate(p.id)} className="flex w-full items-center gap-3 px-4 py-2 text-left hover:bg-border/40">
              <Avatar kind="DIRECT" name={p.fullName} online={p.online} size={34} />
              <span className="min-w-0"><span className="block truncate font-medium">{p.fullName}</span><span className="block text-xs text-muted">{roleLabel(p.role)}</span></span>
            </button>
          ))}
          {!!found.data?.messages.length && <p className="px-4 pt-3 text-xs font-semibold uppercase text-primary">Сообщения</p>}
          {found.data?.messages.map((m) => (
            <button key={m.id} onClick={() => { setSearch(''); onOpen(m.room.id); }} className="flex w-full items-start gap-3 px-4 py-2 text-left hover:bg-border/40">
              <Avatar kind={m.room.kind} name={chatTitle(m.room)} size={34} />
              <span className="min-w-0 flex-1">
                <span className="flex justify-between gap-2"><span className="truncate font-medium">{chatTitle(m.room)}</span><span className="shrink-0 text-xs text-muted">{chatWhen(m.createdAt)}</span></span>
                <span className="line-clamp-2 text-sm text-muted">{m.sender?.fullName.split(' ')[0]}: {chatPreview(m)}</span>
              </span>
            </button>
          ))}
        </div>
      ) : (
      <div className="flex-1 overflow-y-auto">
        {q.isLoading && <div className="flex justify-center p-6"><Spinner /></div>}
        {q.isError && <div className="p-3"><ErrorState error={q.error} onRetry={() => q.refetch()} /></div>}
        {q.data?.items.map((r) => {
          const last = r.lastMessage;
          const who = !last || r.kind === 'DIRECT' || !last.sender ? '' : last.sender.id === me?.id ? 'Вы: ' : `${last.sender.fullName.split(' ')[0]}: `;
          const sub = last ? `${who}${chatPreview(last)}` : r.kind === 'COMPANY' ? 'Все сотрудники и мастерицы' : `Участников: ${r.memberCount}`;
          return (
            <div key={r.id} className={`group relative flex items-center hover:bg-border/40 ${selected === r.id ? 'bg-primary/10' : ''}`}>
            <button
              onClick={() => onOpen(r.id)}
              className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 text-left"
            >
              <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} photo={r.photo} />
              <span className="min-w-0 flex-1">
                <span className="flex items-baseline justify-between gap-2">
                  <span className={`flex min-w-0 items-center gap-1 truncate ${r.unread ? 'font-bold' : 'font-medium'}`}>
                    <span className="truncate">{chatTitle(r)}</span>
                    {r.muted && <BellOff size={13} className="shrink-0 text-muted" aria-label="Без уведомлений" />}
                    {r.pinned && <Pin size={13} className="shrink-0 text-muted" aria-label="Закреплён" />}
                  </span>
                  {last && <span className={`shrink-0 text-xs ${r.unread ? 'text-primary' : 'text-muted'}`}>{chatWhen(last.createdAt)}</span>}
                </span>
                <span className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm text-muted">{sub}</span>
                  {r.unread > 0 && <span className={`shrink-0 rounded-full px-2 text-xs font-bold text-white ${r.muted ? 'bg-muted' : 'bg-primary'}`}>{r.unread}</span>}
                </span>
              </span>
            </button>
            <button aria-label={`Действия: ${chatTitle(r)}`} onClick={() => setMenu(menu === r.id ? null : r.id)} className="mr-1 rounded p-1.5 text-muted opacity-60 hover:bg-border/60 group-hover:opacity-100"><MoreVertical size={16} aria-hidden /></button>
            {menu === r.id && (
              <div className="absolute right-2 top-12 z-20 w-56 rounded-lg border border-border bg-card p-1 text-sm shadow-lg">
                <button className="flex w-full items-center gap-2 rounded px-3 py-2 hover:bg-border/40" onClick={() => { setMenu(null); prefs.mutate({ id: r.id, pinned: !r.pinned }); }}><Pin size={15} aria-hidden />{r.pinned ? 'Открепить чат' : 'Закрепить чат'}</button>
                <button className="flex w-full items-center gap-2 rounded px-3 py-2 hover:bg-border/40" onClick={() => { setMenu(null); prefs.mutate({ id: r.id, muted: !r.muted }); }}><BellOff size={15} aria-hidden />{r.muted ? 'Включить уведомления' : 'Без уведомлений'}</button>
              </div>
            )}
            </div>
          );
        })}
      </div>
      )}
      {creating && <NewChatModal onClose={() => setCreating(false)} onOpen={(id) => { setCreating(false); onOpen(id); }} />}
    </>
  );
}

/** «Новый чат»: one person (a direct chat) or several with a name (a group). With `pick` it only returns the chosen ids. */
function NewChatModal({ onClose, onOpen, pick, exclude = [] }: { onClose: () => void; onOpen?: (id: string) => void; pick?: (ids: string[]) => void; exclude?: string[] }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const [channel, setChannel] = useState(false);
  const [search, setSearch] = useState('');
  const [group, setGroup] = useState(!!pick);
  const [title, setTitle] = useState('');
  const [ticked, setTicked] = useState<string[]>([]);
  const people = useQuery({ queryKey: ['chat-contacts', search], queryFn: () => api.get<{ items: ChatPerson[] }>('/chat/contacts', { q: search || undefined }) });
  const direct = useMutation({
    mutationFn: (userId: string) => api.post<ChatRoomDetail>('/chat/direct', { userId }),
    onSuccess: (r) => { qc.invalidateQueries({ queryKey: ['chat-rooms'] }); onOpen?.(r.id); },
  });
  const create = useMutation({
    mutationFn: () => api.post<ChatRoomDetail>('/chat/groups', { title: title.trim(), memberIds: ticked }),
    onSuccess: (r) => { qc.invalidateQueries({ queryKey: ['chat-rooms'] }); onOpen?.(r.id); },
  });
  const list = (people.data?.items ?? []).filter((p) => !exclude.includes(p.id));
  return (
    <Modal title={pick ? 'Добавить участников' : group ? 'Новая группа' : 'Новый чат'} onClose={onClose}>
      {!pick && (
        <div className="mb-3 flex flex-wrap gap-3 text-sm font-medium text-primary">
          <button className="underline" onClick={() => { setGroup(!group); setTicked([]); }}>{group ? 'Написать одному человеку' : 'Создать группу'}</button>
          {(me?.role === 'SUPER_ADMIN' || me?.role === 'ADMIN') && <button className="underline" onClick={() => setChannel(true)}>Создать канал</button>}
        </div>
      )}
      {channel && <NewChannelModal onClose={() => setChannel(false)} onOpen={(id) => { setChannel(false); onOpen?.(id); }} />}
      {group && !pick && <Input aria-label="Название группы" placeholder="Название группы" value={title} onChange={(e) => setTitle(e.target.value)} className="mb-2" />}
      <Input aria-label="Поиск по имени" placeholder="Поиск по имени" value={search} onChange={(e) => setSearch(e.target.value)} />
      <div className="mt-2 max-h-[45vh] overflow-y-auto">
        {people.isLoading && <div className="flex justify-center p-4"><Spinner /></div>}
        {list.map((p) => (
          <label key={p.id} className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-2 hover:bg-border/40">
            {group
              ? <input type="checkbox" checked={ticked.includes(p.id)} onChange={(e) => setTicked(e.target.checked ? [...ticked, p.id] : ticked.filter((x) => x !== p.id))} />
              : null}
            <Avatar kind="DIRECT" name={p.fullName} online={p.online} size={34} />
            <span className="min-w-0 flex-1">
              <span className="block truncate font-medium">{p.fullName}</span>
              <span className="block text-xs text-muted">{roleLabel(p.role)}</span>
            </span>
            {!group && <Button variant="outline" className="min-h-8 px-3 py-1 text-sm" disabled={direct.isPending} onClick={() => direct.mutate(p.id)}>Написать</Button>}
          </label>
        ))}
      </div>
      {(direct.isError || create.isError) && <div className="mt-2"><ErrorState error={direct.error ?? create.error} /></div>}
      {group && (
        <Button
          className="mt-3 w-full"
          disabled={!ticked.length || (!pick && !title.trim()) || create.isPending}
          onClick={() => (pick ? pick(ticked) : create.mutate())}
        >
          {pick ? `Добавить (${ticked.length})` : `Создать (${ticked.length})`}
        </Button>
      )}
    </Modal>
  );
}

interface Pending { clientId: string; kind: ChatMessage['kind']; text?: string; file?: File; durationMs?: number; replyToId?: string; progress: number; failed: boolean; createdAt: string }

function Conversation({ roomId, onBack, single }: { roomId: string; onBack: () => void; single?: boolean }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const room = useQuery({ queryKey: ['chat-room', roomId], queryFn: () => api.get<ChatRoomDetail>(`/chat/rooms/${roomId}`) });
  const msgs = useInfiniteQuery({
    queryKey: ['chat-msgs', roomId],
    initialPageParam: undefined as string | undefined,
    queryFn: ({ pageParam }) => api.get<{ items: ChatMessage[]; hasMore: boolean }>(`/chat/rooms/${roomId}/messages`, { before: pageParam, limit: 40 }),
    getNextPageParam: (last) => (last.hasMore ? last.items[last.items.length - 1]?.id : undefined),
  });
  const [pending, setPending] = useState<Pending[]>([]);
  const draftKey = `chat-draft-${roomId}`;
  const [text, setText] = useState(() => { try { return localStorage.getItem(draftKey) ?? ''; } catch { return ''; } });
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [editing, setEditing] = useState<ChatMessage | null>(null);
  const [typing, setTyping] = useState<Record<string, { name: string; kind: string; until: number }>>({});
  const [emoji, setEmoji] = useState(false);
  const [forwarding, setForwarding] = useState<ChatMessage | null>(null);
  // the unsent text of this chat is kept (a draft)
  useEffect(() => { try { if (text.trim() && !editing) localStorage.setItem(draftKey, text); else localStorage.removeItem(draftKey); } catch { /* private mode */ } }, [text, editing, draftKey]);
  // «печатает…» from the others (live, never stored), expiring after 6 s
  useEffect(() => onLiveEvent((e) => {
    if (e.data?.roomId !== roomId) return;
    const uid = e.data.userId as string | undefined;
    if (e.type === 'chat.typing' && uid) setTyping((t) => ({ ...t, [uid]: { name: String(e.data.name ?? ''), kind: String(e.data.kind ?? 'text'), until: Date.now() + 6_000 } }));
    if (e.type === 'chat.message') setTyping((t) => { const n = { ...t }; delete n[String(e.data.senderId)]; return n; });
  }), [roomId]);
  useEffect(() => {
    if (!Object.keys(typing).length) return;
    const id = setInterval(() => setTyping((t) => Object.fromEntries(Object.entries(t).filter(([, v]) => v.until > Date.now()))), 1_000);
    return () => clearInterval(id);
  }, [typing]);
  const lastTypingSent = useRef(0);
  const sendTyping = (kind: 'text' | 'voice') => {
    if (Date.now() - lastTypingSent.current < 2_000) return;
    lastTypingSent.current = Date.now();
    emitLive('chat:typing', { roomId, kind });
  };
  const [info, setInfo] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  // newest first from the server; shown oldest -> newest
  const messages = useMemo(() => {
    const seen = new Set<string>();
    const all: ChatMessage[] = [];
    for (const p of msgs.data?.pages ?? []) for (const m of p.items) if (!seen.has(m.id)) { seen.add(m.id); all.push(m); }
    return all.reverse();
  }, [msgs.data]);
  const newestId = messages[messages.length - 1]?.id;

  // read up to now whenever something new is on screen
  useEffect(() => {
    if (!newestId) return;
    api.post(`/chat/rooms/${roomId}/read`).then(() => { qc.invalidateQueries({ queryKey: ['chat-unread'] }); qc.invalidateQueries({ queryKey: ['chat-rooms'] }); }).catch(() => undefined);
  }, [newestId, roomId, qc]);

  const bottom = useRef<HTMLDivElement>(null);
  useEffect(() => { bottom.current?.scrollIntoView?.({ block: 'end' }); }, [newestId, pending.length]);

  const send = async (p: Pending) => {
    setPending((xs) => xs.map((x) => (x.clientId === p.clientId ? { ...x, failed: false } : x)));
    try {
      if (p.file) {
        const form = new FormData();
        form.set('kind', p.kind);
        form.set('clientId', p.clientId);
        if (p.durationMs) form.set('durationMs', String(p.durationMs));
        if (p.replyToId) form.set('replyToId', p.replyToId);
        form.set('file', p.file, p.file.name);
        await api.upload(`/chat/rooms/${roomId}/files`, form);
      } else {
        await api.post(`/chat/rooms/${roomId}/messages`, { text: p.text, clientId: p.clientId, replyToId: p.replyToId });
      }
      await qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] });
      setPending((xs) => xs.filter((x) => x.clientId !== p.clientId));
    } catch (e) {
      setPending((xs) => xs.map((x) => (x.clientId === p.clientId ? { ...x, failed: true } : x)));
      setError(errorMessage(e));
    }
  };
  const queue = (p: Omit<Pending, 'clientId' | 'progress' | 'failed' | 'createdAt' | 'replyToId'>) => {
    const item: Pending = { ...p, replyToId: replyTo?.id, clientId: newId(), progress: 0, failed: false, createdAt: new Date().toISOString() };
    setReplyTo(null);
    setPending((xs) => [...xs, item]);
    void send(item);
  };
  const sendText = () => {
    const t = text.trim();
    if (!t) return;
    setText('');
    if (editing) {
      const id = editing.id;
      setEditing(null);
      api.patch(`/chat/messages/${id}`, { text: t }).then(() => qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] })).catch((e) => setError(errorMessage(e)));
      return;
    }
    queue({ kind: 'TEXT', text: t });
  };
  const act = useMutation({
    mutationFn: ({ path, body, method = 'post' }: { path: string; body?: unknown; method?: 'post' | 'patch' }) => (method === 'post' ? api.post(path, body) : api.patch(path, body)),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] }); qc.invalidateQueries({ queryKey: ['chat-room', roomId] }); },
    onError: (e) => setError(errorMessage(e)),
  });
  const react = (m: ChatMessage, e: string) => act.mutate({ path: `/chat/messages/${m.id}/reactions`, body: { emoji: e } });
  const pin = (id: string | null) => act.mutate({ path: `/chat/rooms/${roomId}/pin`, body: { messageId: id } });
  const sendFiles = (files: FileList | null) => {
    setError(null);
    for (const f of Array.from(files ?? [])) {
      if (f.size > CHAT_MAX_BYTES) { setError(`«${f.name}» больше 50 МБ — его нельзя отправить`); continue; }
      queue({ kind: chatKindForFile(f), file: f });
    }
    if (fileInput.current) fileInput.current.value = '';
  };

  const del = useMutation({
    mutationFn: (id: string) => api.delete(`/chat/messages/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] }),
  });
  const canDeleteAny = me?.role === 'SUPER_ADMIN' || me?.role === 'ADMIN';

  const r = room.data;
  const typer = Object.values(typing)[0];
  const typingText = typer ? `${r?.kind === 'DIRECT' ? '' : `${typer.name.split(' ')[0]} `}${typer.kind === 'voice' ? 'записывает голосовое…' : 'печатает…'}` : null;
  const subtitle = typingText ?? (!r ? '' : r.kind === 'CHANNEL' ? `Канал · подписчиков: ${r.memberCount}` : r.kind === 'DIRECT' ? (r.peer?.online ? 'в сети' : r.peer?.lastSeenAt ? lastSeen(r.peer.lastSeenAt) : r.peer ? roleLabel(r.peer.role) : '') : `Участников: ${r.memberCount}`);
  const peerRead = r?.peer?.lastReadAt ? new Date(r.peer.lastReadAt).getTime() : 0;

  return (
    <>
      <div className="flex items-center gap-3 border-b border-border px-3 py-2.5">
        <button aria-label="Назад" className={`rounded-lg p-1.5 hover:bg-border/50 ${single ? '' : 'md:hidden'}`} onClick={onBack}><ArrowLeft size={20} aria-hidden /></button>
        {r && <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} size={36} photo={r.photo?.thumbUrl} />}
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{r ? chatTitle(r) : ''}</p>
          <p className={`truncate text-xs ${typingText ? 'text-primary' : 'text-muted'}`}>{subtitle}</p>
        </div>
        {r && <button aria-label="Информация о чате" className="rounded-lg p-2 hover:bg-border/50" onClick={() => setInfo(true)}><Info size={20} aria-hidden /></button>}
      </div>

      {r?.pinnedMessage && (
        <div className="flex items-center gap-2 border-b border-border bg-primary/5 px-4 py-1.5 text-sm">
          <Pin size={15} className="shrink-0 text-primary" aria-hidden />
          <span className="min-w-0 flex-1"><span className="block text-xs font-semibold text-primary">Закреплённое сообщение</span><span className="block truncate">{chatPreview(r.pinnedMessage)}</span></span>
          {r.canPin && <button aria-label="Открепить" className="rounded p-1 hover:bg-border/50" onClick={() => pin(null)}><X size={15} aria-hidden /></button>}
        </div>
      )}
      <div className="flex-1 overflow-y-auto bg-background/60 px-3 py-3">
        {msgs.hasNextPage && (
          <div className="mb-2 text-center">
            <button className="text-sm text-primary underline" onClick={() => msgs.fetchNextPage()} disabled={msgs.isFetchingNextPage}>Показать раньше</button>
          </div>
        )}
        {(room.isError || msgs.isError) && <ErrorState error={room.error ?? msgs.error} />}
        {msgs.isLoading && <div className="flex justify-center p-6"><Spinner /></div>}
        {msgs.isSuccess && messages.length === 0 && pending.length === 0 && <p className="mt-10 text-center text-muted">Сообщений пока нет — напишите первым</p>}
        {messages.map((m, i) => {
          const mine = m.sender?.id === me?.id;
          const newDay = i === 0 || new Date(messages[i - 1].createdAt).toDateString() !== new Date(m.createdAt).toDateString();
          return (
            <div key={m.id}>
              {newDay && <div className="my-3 text-center"><span className="rounded-full bg-border/70 px-3 py-1 text-xs">{dayLabel(m.createdAt)}</span></div>}
              <Bubble
                m={m}
                mine={mine}
                showSender={!!r && r.kind !== 'DIRECT' && !mine}
                read={mine && peerRead >= new Date(m.createdAt).getTime()}
                onDelete={!m.deleted && (mine || canDeleteAny) ? () => { if (confirm('Удалить сообщение? Оно исчезнет у всех участников.')) del.mutate(m.id); } : undefined}
                onReply={() => { setReplyTo(m); setEditing(null); }}
                onEdit={mine && m.text && !m.forwardedFrom && Date.now() - new Date(m.createdAt).getTime() < 48 * 3600_000 ? () => { setEditing(m); setReplyTo(null); setText(m.text ?? ''); } : undefined}
                onReact={(e) => react(m, e)}
                onForward={() => setForwarding(m)}
                onPin={r?.canPin ? () => pin(r.pinnedMessage?.id === m.id ? null : m.id) : undefined}
                pinned={r?.pinnedMessage?.id === m.id}
              />
            </div>
          );
        })}
        {pending.map((p) => (
          <div key={p.clientId} className="my-1 flex justify-end">
            <button
              onClick={() => p.failed && send(p)}
              className="max-w-[80%] rounded-2xl bg-primary/10 px-3 py-2 text-left opacity-80"
            >
              <span className="block whitespace-pre-wrap break-words">{p.text ?? `${{ IMAGE: '📷', VIDEO: '🎬', VOICE: '🎤', AUDIO: '🎵', FILE: '📎', TEXT: '' }[p.kind]} ${p.file?.name ?? ''}`}</span>
              <span className={`block text-right text-xs ${p.failed ? 'font-semibold text-danger' : 'text-muted'}`}>{p.failed ? 'Не отправлено — нажмите, чтобы повторить' : 'Отправка…'}</span>
            </button>
          </div>
        ))}
        <div ref={bottom} />
      </div>

      {error && <div className="flex items-center justify-between gap-2 bg-danger/10 px-3 py-1.5 text-sm text-danger" role="alert">{error}<button aria-label="Закрыть" onClick={() => setError(null)}><X size={16} aria-hidden /></button></div>}
      {(replyTo || editing) && (
        <div className="flex items-center gap-2 border-t border-border bg-primary/5 px-3 py-1.5 text-sm">
          {editing ? <Pencil size={15} className="text-primary" aria-hidden /> : <Reply size={15} className="text-primary" aria-hidden />}
          <span className="min-w-0 flex-1">
            <span className="block text-xs font-semibold text-primary">{editing ? 'Редактирование' : `Ответ: ${replyTo?.sender?.fullName ?? ''}`}</span>
            <span className="block truncate">{chatPreview((editing ?? replyTo)!)}</span>
          </span>
          <button aria-label="Отменить" onClick={() => { if (editing) setText(''); setEditing(null); setReplyTo(null); }}><X size={16} aria-hidden /></button>
        </div>
      )}
      {emoji && (
        <div className="grid grid-cols-9 gap-1 border-t border-border p-2" role="listbox" aria-label="Эмодзи">
          {EMOJIS.map((e) => <button key={e} className="rounded p-1 text-xl hover:bg-border/50" onClick={() => { setText((t) => t + e); setEmoji(false); }}>{e}</button>)}
        </div>
      )}
      {r && r.canWrite === false ? (
        <p className="border-t border-border p-3 text-center text-sm text-muted">{r.kind === 'CHANNEL' ? 'Это канал: публикуют только его администраторы' : 'Писать могут только администраторы группы'}</p>
      ) : (
      <div className="flex items-end gap-2 border-t border-border p-2 pb-[max(0.5rem,env(safe-area-inset-bottom))]">
        <input ref={fileInput} type="file" multiple className="hidden" aria-label="Файлы" onChange={(e) => sendFiles(e.target.files)} />
        <button aria-label="Прикрепить" title="Фото, видео, файл" className="rounded-full p-2.5 hover:bg-border/50" onClick={() => fileInput.current?.click()}><Paperclip size={20} aria-hidden /></button>
        <button aria-label="Эмодзи" className="rounded-full p-2.5 hover:bg-border/50" onClick={() => setEmoji(!emoji)}><Smile size={20} aria-hidden /></button>
        <textarea
          aria-label="Сообщение"
          placeholder="Сообщение"
          rows={1}
          value={text}
          onChange={(e) => { setText(e.target.value); if (e.target.value.trim()) sendTyping('text'); }}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendText(); } }}
          className="max-h-40 min-h-10 flex-1 resize-none rounded-2xl border border-border bg-background px-4 py-2.5 outline-none focus:border-primary"
        />
        {text.trim()
          ? <button aria-label="Отправить" className="rounded-full bg-primary p-2.5 text-white" onClick={sendText}><Send size={20} aria-hidden /></button>
          : <VoiceButton onRecorded={(file, durationMs) => queue({ kind: 'VOICE', file, durationMs })} onError={setError} onRecording={() => sendTyping('voice')} />}
      </div>
      )}
      {info && r && <RoomInfo room={r} onClose={() => setInfo(false)} onLeft={() => { setInfo(false); onBack(); }} onOpenMessage={() => setInfo(false)} />}
      {forwarding && <ForwardModal message={forwarding} onClose={() => setForwarding(null)} onDone={() => setForwarding(null)} />}
    </>
  );
}

function Bubble({ m, mine, showSender, read, onDelete, onReply, onEdit, onReact, onForward, onPin, pinned }: {
  m: ChatMessage; mine: boolean; showSender: boolean; read: boolean; onDelete?: () => void;
  onReply?: () => void; onEdit?: () => void; onReact?: (e: string) => void; onForward?: () => void; onPin?: () => void; pinned?: boolean;
}) {
  const t = new Date(m.createdAt);
  const f = m.file;
  const [menu, setMenu] = useState(false);
  const copy = () => { void navigator.clipboard?.writeText(m.text ?? ''); setMenu(false); };
  return (
    <div className={`group my-1 flex ${mine ? 'justify-end' : 'justify-start'}`}>
      <div className={`relative max-w-[80%] rounded-2xl px-3 py-2 ${mine ? 'rounded-br-md bg-primary/15' : 'rounded-bl-md bg-card shadow-sm ring-1 ring-border'}`}>
        {showSender && m.sender && <p className="mb-0.5 text-xs font-bold text-primary">{m.sender.fullName}</p>}
        {!m.deleted && m.forwardedFrom && <p className="mb-1 text-xs italic text-muted">Переслано от {m.forwardedFrom}</p>}
        {!m.deleted && m.replyTo && (
          <div className="mb-1.5 rounded-md border-l-[3px] border-primary bg-border/40 px-2 py-1 text-sm">
            {m.replyTo.sender && <p className="text-xs font-bold text-primary">{m.replyTo.sender}</p>}
            <p className="line-clamp-2 text-muted">{m.replyTo.deleted ? 'Сообщение удалено' : m.replyTo.preview}</p>
          </div>
        )}
        {m.deleted ? (
          <p className="italic text-muted">Сообщение удалено</p>
        ) : (
          <>
            {m.kind === 'IMAGE' && f && (
              <a href={f.url} target="_blank" rel="noreferrer"><img src={f.thumbUrl ?? f.url} alt={m.text ?? 'Фото'} className="max-h-72 max-w-full rounded-lg" /></a>
            )}
            {m.kind === 'VIDEO' && f && <video src={f.url} controls preload="metadata" className="max-h-72 max-w-full rounded-lg" />}
            {(m.kind === 'VOICE' || m.kind === 'AUDIO') && f && (
              <div>
                {m.kind === 'AUDIO' && f.name && <p className="mb-1 truncate text-sm font-medium">{f.name}</p>}
                <audio src={f.url} controls preload="none" className="h-10 w-64 max-w-full" />
              </div>
            )}
            {m.kind === 'FILE' && f && (
              <a href={f.url} download={f.name ?? undefined} className="flex items-center gap-3 rounded-lg p-1 hover:bg-border/40">
                <FileText size={28} className="shrink-0 text-primary" aria-hidden />
                <span className="min-w-0">
                  <span className="block truncate font-medium">{f.name ?? 'Файл'}</span>
                  <span className="block text-xs text-muted">{bytes(f.size)}</span>
                </span>
                <Download size={18} className="shrink-0 text-muted" aria-hidden />
              </a>
            )}
            {m.text && <p className={`whitespace-pre-wrap break-words ${f ? 'mt-1' : ''}`}><RichText text={m.text} /></p>}
          </>
        )}
        {!m.deleted && !!m.reactions?.length && (
          <div className="mt-1 flex flex-wrap gap-1">
            {m.reactions.map((x) => (
              <button key={x.emoji} onClick={() => onReact?.(x.emoji)} aria-pressed={x.mine} className={`rounded-full px-2 py-0.5 text-xs ${x.mine ? 'bg-primary/20 ring-1 ring-primary' : 'bg-border/50'}`}>{x.emoji} {x.count}</button>
            ))}
          </div>
        )}
        <p className="mt-0.5 flex items-center justify-end gap-1 text-[11px] text-muted">
          {m.editedAt && !m.deleted && <span>изменено</span>}
          {pinned && <Pin size={11} aria-label="Закреплено" />}
          {two(t.getHours())}:{two(t.getMinutes())}
          {mine && !m.deleted && (read ? <CheckCheck size={14} className="text-primary" aria-label="Прочитано" /> : <Check size={14} aria-hidden />)}
        </p>
        {!m.deleted && (
          <button aria-label="Действия с сообщением" onClick={() => setMenu(!menu)} className={`absolute -top-2 ${mine ? 'left-1' : 'right-1'} rounded-full bg-card p-1 text-muted shadow ring-1 ring-border opacity-0 group-hover:opacity-100 focus:opacity-100 ${menu ? 'opacity-100' : ''}`}>
            <MoreVertical size={14} aria-hidden />
          </button>
        )}
        {menu && (
          <div className={`absolute top-5 z-20 w-56 rounded-lg border border-border bg-card p-1 text-sm shadow-lg ${mine ? 'right-0' : 'left-0'}`} role="menu">
            <div className="flex justify-between px-1 pb-1">
              {CHAT_REACTIONS.map((e) => <button key={e} aria-label={`Реакция ${e}`} className="rounded p-0.5 text-lg hover:bg-border/50" onClick={() => { setMenu(false); onReact?.(e); }}>{e}</button>)}
            </div>
            <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 hover:bg-border/40" onClick={() => { setMenu(false); onReply?.(); }}><Reply size={15} aria-hidden />Ответить</button>
            {m.text && <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 hover:bg-border/40" onClick={copy}><Copy size={15} aria-hidden />Копировать</button>}
            {onEdit && <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 hover:bg-border/40" onClick={() => { setMenu(false); onEdit(); }}><Pencil size={15} aria-hidden />Изменить</button>}
            <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 hover:bg-border/40" onClick={() => { setMenu(false); onForward?.(); }}><Forward size={15} aria-hidden />Переслать</button>
            {onPin && <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 hover:bg-border/40" onClick={() => { setMenu(false); onPin(); }}><Pin size={15} aria-hidden />{pinned ? 'Открепить' : 'Закрепить'}</button>}
            {onDelete && <button role="menuitem" className="flex w-full items-center gap-2 rounded px-3 py-1.5 text-danger hover:bg-danger/10" onClick={() => { setMenu(false); onDelete(); }}><Trash2 size={15} aria-hidden />Удалить</button>}
          </div>
        )}
      </div>
    </div>
  );
}

/** Click to start recording, click again to send (a browser has no «hold»); the microphone permission is asked once. */
function VoiceButton({ onRecorded, onError, onRecording }: { onRecorded: (f: File, durationMs: number) => void; onError: (m: string) => void; onRecording?: () => void }) {
  const [rec, setRec] = useState<{ r: MediaRecorder; started: number } | null>(null);
  const [, tick] = useState(0);
  useEffect(() => {
    if (!rec) return;
    const id = setInterval(() => { tick((x) => x + 1); onRecording?.(); }, 500);
    return () => clearInterval(id);
  }, [rec]);
  const start = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus'].find((t) => MediaRecorder.isTypeSupported(t));
      const r = new MediaRecorder(stream, type ? { mimeType: type } : undefined);
      const chunks: Blob[] = [];
      const started = Date.now();
      r.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      r.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        const ms = Date.now() - started;
        if (ms < 700) return;
        const mime = r.mimeType || 'audio/webm';
        const ext = mime.includes('mp4') ? 'm4a' : mime.includes('ogg') ? 'ogg' : 'webm';
        onRecorded(new File(chunks, `voice.${ext}`, { type: mime.split(';')[0] }), ms);
      };
      r.start();
      setRec({ r, started });
    } catch {
      onError('Разрешите доступ к микрофону, чтобы записывать голосовые');
    }
  };
  const stop = () => { rec?.r.stop(); setRec(null); };
  if (rec) {
    const s = Math.floor((Date.now() - rec.started) / 1000);
    return (
      <button aria-label="Отправить голосовое" onClick={stop} className="flex items-center gap-2 rounded-full bg-danger px-3 py-2.5 text-sm font-semibold text-white">
        <span className="h-2 w-2 animate-pulse rounded-full bg-white" />
        {Math.floor(s / 60)}:{two(s % 60)} <Send size={16} aria-hidden />
      </button>
    );
  }
  return <button aria-label="Записать голосовое" title="Голосовое сообщение" className="rounded-full bg-primary p-2.5 text-white" onClick={start}><Mic size={20} aria-hidden /></button>;
}

/** «Новый канал» (administrators): who reads it; its admins post. */
function NewChannelModal({ onClose, onOpen }: { onClose: () => void; onOpen: (id: string) => void }) {
  const qc = useQueryClient();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [audience, setAudience] = useState<'ALL' | 'STAFF' | 'WORKERS' | 'CUSTOM'>('ALL');
  const [members, setMembers] = useState<string[]>([]);
  const [picking, setPicking] = useState(false);
  const create = useMutation({
    mutationFn: () => api.post<ChatRoomDetail>('/chat/channels', { title: title.trim(), description: description.trim() || undefined, audience, memberIds: members }),
    onSuccess: (r) => { qc.invalidateQueries({ queryKey: ['chat-rooms'] }); onOpen(r.id); },
  });
  return (
    <Modal title="Новый канал" onClose={onClose}>
      <div className="space-y-2">
        <Input aria-label="Название канала" placeholder="Название канала" value={title} onChange={(e) => setTitle(e.target.value)} />
        <Input aria-label="Описание" placeholder="Описание (необязательно)" value={description} onChange={(e) => setDescription(e.target.value)} />
        <label className="block text-sm font-medium">Кто читает
          <select aria-label="Кто читает" value={audience} onChange={(e) => setAudience(e.target.value as typeof audience)} className="mt-1 w-full rounded-lg border border-border bg-background px-3 py-2">
            <option value="ALL">Все сотрудники и мастерицы</option>
            <option value="STAFF">Только сотрудники</option>
            <option value="WORKERS">Только мастерицы</option>
            <option value="CUSTOM">Выбранные люди</option>
          </select>
        </label>
        {audience === 'CUSTOM' && <Button variant="outline" className="w-full" onClick={() => setPicking(true)}>Выбрать людей ({members.length})</Button>}
        <p className="text-xs text-muted">Публикуют только администраторы канала; читатели видят объявления и получают уведомления.</p>
        {create.isError && <ErrorState error={create.error} />}
        <Button className="w-full" disabled={!title.trim() || create.isPending || (audience === 'CUSTOM' && !members.length)} onClick={() => create.mutate()}>Создать канал</Button>
      </div>
      {picking && <NewChatModal onClose={() => setPicking(false)} pick={(ids) => { setPicking(false); setMembers(ids); }} />}
    </Modal>
  );
}

const AUDIENCE_LABEL = { ALL: 'все сотрудники и мастерицы', STAFF: 'только сотрудники', WORKERS: 'только мастерицы', CUSTOM: 'выбранные люди' } as const;

/** «Информация о чате»: members and admins, description, photo, settings; media, files, voice and links. */
function RoomInfo({ room, onClose, onLeft }: { room: ChatRoomDetail; onClose: () => void; onLeft: () => void; onOpenMessage: () => void }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState(room.title ?? '');
  const [description, setDescription] = useState(room.description ?? '');
  const managed = room.kind === 'GROUP' || room.kind === 'CHANNEL';
  const [tab, setTab] = useState<'members' | 'media' | 'files' | 'voice' | 'links'>(managed ? 'members' : 'media');
  const refresh = () => { qc.invalidateQueries({ queryKey: ['chat-room', room.id] }); qc.invalidateQueries({ queryKey: ['chat-rooms'] }); };
  const update = useMutation({ mutationFn: (b: Record<string, unknown>) => api.patch(`/chat/rooms/${room.id}`, b), onSuccess: refresh });
  const leave = useMutation({ mutationFn: () => api.post(`/chat/rooms/${room.id}/leave`), onSuccess: () => { refresh(); onLeft(); } });
  const photo = useMutation({
    mutationFn: (f: File) => { const form = new FormData(); form.set('file', f, f.name); return api.upload(`/chat/rooms/${room.id}/photo`, form); },
    onSuccess: refresh,
  });
  const media = useQuery({
    queryKey: ['chat-media', room.id, tab],
    queryFn: () => api.get<{ items: ChatMessage[] }>(`/chat/rooms/${room.id}/media`, { kind: tab }),
    enabled: tab !== 'members',
  });
  const canLeave = room.kind === 'GROUP' || (room.kind === 'CHANNEL' && room.audience === 'CUSTOM');
  const noun = room.kind === 'CHANNEL' ? 'канала' : 'группы';
  type Tab = 'members' | 'media' | 'files' | 'voice' | 'links';
  const tabs: [Tab, string][] = [...(managed ? [['members', 'Участники'] as [Tab, string]] : []), ['media', 'Медиа'], ['files', 'Файлы'], ['voice', 'Голосовые'], ['links', 'Ссылки']];
  return (
    <Modal title={room.kind === 'CHANNEL' ? 'О канале' : room.kind === 'GROUP' ? 'О группе' : 'Информация о чате'} onClose={onClose}>
      {managed && (
        <div className="mb-3 flex items-center gap-3">
          <Avatar kind={room.kind} name={room.title ?? ''} size={56} photo={room.photo?.thumbUrl} />
          {room.canManage && (
            <label className="flex cursor-pointer items-center gap-1 text-sm font-medium text-primary">
              <Camera size={16} aria-hidden /> Сменить фото
              <input type="file" accept="image/jpeg,image/png,image/webp" className="hidden" aria-label={`Фото ${noun}`} onChange={(e) => { const f = e.target.files?.[0]; if (f) photo.mutate(f); }} />
            </label>
          )}
        </div>
      )}
      {managed && (room.canManage ? (
        <div className="mb-3 space-y-2">
          <div className="flex gap-2">
            <Input aria-label={`Название ${noun}`} value={title} onChange={(e) => setTitle(e.target.value)} />
            <Button variant="outline" disabled={!title.trim() || title === room.title || update.isPending} onClick={() => update.mutate({ title: title.trim() })}>Сохранить</Button>
          </div>
          <div className="flex gap-2">
            <Input aria-label="Описание" placeholder="Описание" value={description} onChange={(e) => setDescription(e.target.value)} />
            <Button variant="outline" disabled={description === (room.description ?? '') || update.isPending} onClick={() => update.mutate({ description: description.trim() || null })}>Сохранить</Button>
          </div>
          {room.kind === 'GROUP' && (
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={!!room.onlyAdminsWrite} onChange={(e) => update.mutate({ onlyAdminsWrite: e.target.checked })} /> Писать могут только администраторы
            </label>
          )}
        </div>
      ) : (
        <div className="mb-3"><p className="font-semibold">{room.title}</p>{room.description && <p className="text-sm text-muted">{room.description}</p>}</div>
      ))}
      {room.kind === 'CHANNEL' && room.audience && <p className="mb-2 text-sm text-muted">Читают: {AUDIENCE_LABEL[room.audience]} · {room.memberCount}</p>}
      <div className="mb-2 flex flex-wrap gap-1" role="tablist">
        {tabs.map(([k, label]) => (
          <button key={k} role="tab" aria-selected={tab === k} onClick={() => setTab(k)} className={`rounded-full px-3 py-1 text-sm ${tab === k ? 'bg-primary text-white' : 'bg-border/50'}`}>{label}</button>
        ))}
      </div>
      {tab === 'members' ? (
        <>
          {room.kind !== 'CHANNEL' && <p className="mb-2 text-sm text-muted">Участников: {room.memberCount}</p>}
          {room.canManage && !(room.kind === 'CHANNEL' && room.audience !== 'CUSTOM') && <Button variant="outline" className="mb-2 w-full" onClick={() => setAdding(true)}><Plus size={16} aria-hidden /> Добавить участников</Button>}
          <ul className="max-h-[35vh] space-y-1 overflow-y-auto">
            {room.members.map((m) => (
              <li key={m.id} className="flex items-center gap-3 rounded-lg px-1 py-1.5">
                <Avatar kind="DIRECT" name={m.fullName} online={m.online} size={32} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-medium">{m.fullName}{m.id === me?.id ? ' (вы)' : ''}</span>
                  <span className="block text-xs text-muted">{roleLabel(m.role)}{m.isOwner ? ' · создатель' : m.isAdmin ? ' · администратор' : ''}</span>
                </span>
                {room.canEditAdmins && !m.isOwner && m.id !== me?.id && (
                  <button className="rounded px-2 py-1 text-xs text-primary hover:bg-primary/10" onClick={() => update.mutate(m.isAdmin ? { unadminIds: [m.id] } : { adminIds: [m.id] })}>
                    {m.isAdmin ? 'Снять админа' : 'Сделать админом'}
                  </button>
                )}
                {room.canManage && !m.isOwner && m.id !== me?.id && !(room.kind === 'CHANNEL' && room.audience !== 'CUSTOM') && (
                  <button aria-label={`Убрать ${m.fullName}`} className="rounded p-1 text-danger hover:bg-danger/10" onClick={() => update.mutate({ removeIds: [m.id] })}><X size={16} aria-hidden /></button>
                )}
              </li>
            ))}
          </ul>
          {room.canEditAdmins && room.kind === 'CHANNEL' && room.audience !== 'CUSTOM' && (
            <Button variant="outline" className="mt-2 w-full" onClick={() => setAdding(true)}><Plus size={16} aria-hidden /> Добавить администратора</Button>
          )}
        </>
      ) : (
        <div className="max-h-[45vh] overflow-y-auto">
          {media.isLoading && <div className="flex justify-center p-4"><Spinner /></div>}
          {media.data && !media.data.items.length && <p className="p-4 text-center text-sm text-muted">Пока ничего нет</p>}
          {tab === 'media' ? (
            <div className="grid grid-cols-3 gap-1">
              {media.data?.items.map((m) => m.file && (m.kind === 'IMAGE'
                ? <a key={m.id} href={m.file.url} target="_blank" rel="noreferrer"><img src={m.file.thumbUrl ?? m.file.url} alt="" className="aspect-square w-full rounded object-cover" /></a>
                : <video key={m.id} src={m.file.url} controls preload="metadata" className="aspect-square w-full rounded bg-black object-cover" />))}
            </div>
          ) : (
            <ul className="space-y-1">
              {media.data?.items.map((m) => (
                <li key={m.id} className="rounded-lg px-2 py-1.5 text-sm hover:bg-border/40">
                  {tab === 'links' ? <RichText text={m.text ?? ''} /> : tab === 'voice' && m.file ? <audio src={m.file.url} controls preload="none" className="h-9 w-full" />
                    : m.file && <a href={m.file.url} download={m.file.name ?? undefined} className="flex items-center gap-2"><FileText size={18} className="text-primary" aria-hidden /><span className="truncate">{m.file.name ?? 'Файл'}</span><span className="ml-auto text-xs text-muted">{bytes(m.file.size)}</span></a>}
                  <span className="block text-xs text-muted">{m.sender?.fullName} · {chatWhen(m.createdAt)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      {(update.isError || leave.isError || photo.isError) && <div className="mt-2"><ErrorState error={update.error ?? leave.error ?? photo.error} /></div>}
      {canLeave && <Button variant="danger" className="mt-4 w-full" onClick={() => { if (confirm(`Выйти из ${noun}? Вы больше не будете видеть его сообщения.`)) leave.mutate(); }}>Выйти из {noun}</Button>}
      {adding && (
        <NewChatModal
          onClose={() => setAdding(false)}
          exclude={room.members.map((m) => m.id)}
          pick={(ids) => { setAdding(false); update.mutate(room.kind === 'CHANNEL' && room.audience !== 'CUSTOM' ? { adminIds: ids } : { addIds: ids }); }}
        />
      )}
    </Modal>
  );
}

/** «Переслать в…»: one of my chats. */
function ForwardModal({ message, onClose, onDone }: { message: ChatMessage; onClose: () => void; onDone: () => void }) {
  const rooms = useQuery({ queryKey: ['chat-rooms'], queryFn: () => api.get<{ items: ChatRoomSummary[] }>('/chat/rooms') });
  const fwd = useMutation({ mutationFn: (roomId: string) => api.post(`/chat/messages/${message.id}/forward`, { roomIds: [roomId] }), onSuccess: onDone });
  return (
    <Modal title="Переслать в…" onClose={onClose}>
      <div className="max-h-[55vh] overflow-y-auto">
        {rooms.data?.items.map((r) => (
          <button key={r.id} disabled={fwd.isPending} onClick={() => fwd.mutate(r.id)} className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-border/40">
            <Avatar kind={r.kind} name={chatTitle(r)} size={34} /><span className="truncate font-medium">{chatTitle(r)}</span>
          </button>
        ))}
      </div>
      {fwd.isError && <div className="mt-2"><ErrorState error={fwd.error} /></div>}
    </Modal>
  );
}
