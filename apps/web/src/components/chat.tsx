'use client';

import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, ArrowLeft, ChevronLeft, ChevronRight, Play, Camera, Menu, PanelRight, ShieldOff, Shield, Eraser, FileDown, Wallpaper, CheckSquare, User as UserIcon, Megaphone, BellOff, Check, CheckCheck, Copy, Download, FileText, Forward, Info, Mic, MoreVertical, Paperclip, Pencil, Pin, Plus, Reply, Search, Send, Smile, Trash2, Users, X } from 'lucide-react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { accessToken, api, apiOrigin } from '@/lib/api';
const apiBaseUrl = () => (typeof window === 'undefined' ? '' : apiOrigin());
import { emitLive, onLiveEvent } from '@/lib/live';
import { ChatMainMenu, FloatingMenu, MenuItem, MyProfileModal, PersonAvatar, ProfileCard, VoicePlayer, WALLPAPERS, albumsOf, useWallpaper, waveformRecorder } from './chat-extras';
import { AudioBar } from './audio-player';
import { useAuth } from '@/lib/auth';
import { errorMessage, initials, roleLabel } from '@/lib/format';
import { Button, ErrorState, Input, Modal, Spinner } from '@/components/ui';

// ---- types (GET /v1/chat/...) ------------------------------------------------------------------------------------------
export interface ChatPerson { id: string; fullName: string; role: string; online?: boolean; isOwner?: boolean; lastReadAt?: string | null; lastSeenAt?: string | null; isAdmin?: boolean; avatar?: string | null; username?: string | null }
export interface ChatReaction { emoji: string; count: number; mine: boolean }
export const CHAT_REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥'] as const;
export interface ChatFile { url: string; thumbUrl: string | null; name: string | null; size: number | null; mimeType: string | null; durationMs: number | null; width: number | null; height: number | null }
export interface ChatMessage { id: string; roomId: string; kind: 'TEXT' | 'IMAGE' | 'VIDEO' | 'VOICE' | 'AUDIO' | 'FILE'; sender: ChatPerson | null; text: string | null; file: ChatFile | null; deleted: boolean; createdAt: string; clientId: string | null; waveform?: string | null;
  replyTo?: { id: string; sender: string | null; preview: string | null; deleted: boolean } | null; forwardedFrom?: string | null; editedAt?: string | null; reactions?: ChatReaction[] }
export interface ChatRoomSummary { id: string; kind: 'DIRECT' | 'GROUP' | 'COMPANY' | 'CHANNEL'; photo?: string | null; title: string | null; peer: ChatPerson | null; memberCount: number; isOwner: boolean; unread: number; lastMessage: ChatMessage | null; lastMessageAt: string; pinned?: boolean; muted?: boolean }
export interface ChatRoomDetail { id: string; kind: ChatRoomSummary['kind']; title: string | null; isOwner: boolean; canManage: boolean; memberCount: number; peer: ChatPerson | null; members: ChatPerson[];
  canPin?: boolean; pinned?: boolean; muted?: boolean; pinnedMessage?: ChatMessage | null;
  description?: string | null; photo?: { url: string; thumbUrl: string } | null; audience?: 'ALL' | 'STAFF' | 'WORKERS' | 'CUSTOM' | null;
  onlyAdminsWrite?: boolean; canWrite?: boolean; canEditAdmins?: boolean; isAdmin?: boolean; protectContent?: boolean; canProtect?: boolean }
interface ChatSearch { rooms: ChatRoomSummary[]; people: ChatPerson[]; messages: (ChatMessage & { room: { id: string; kind: string; title: string | null } })[] }

export const CHAT_MAX_BYTES = 50 * 1024 * 1024;
export const CHAT_MAX_VIDEO_BYTES = 150 * 1024 * 1024;
/** above this a file goes in 5 MB parts (Cloudflare takes ≤ 100 MB per request; a dropped connection resumes) */
const SINGLE_UPLOAD_BYTES = 8 * 1024 * 1024;
const fmtDuration = (ms: number) => { const s = Math.round(ms / 1000); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };

/** A video's first frame, length and size - made in the browser, so others see a preview before downloading anything. */
export function describeVideo(file: File): Promise<{ thumb?: Blob; durationMs?: number; width?: number; height?: number }> {
  return new Promise((resolve) => {
    if (typeof document === 'undefined' || typeof URL.createObjectURL !== 'function') return resolve({});
    const url = URL.createObjectURL(file);
    const v = document.createElement('video');
    const done = (x: { thumb?: Blob; durationMs?: number; width?: number; height?: number }) => { URL.revokeObjectURL(url); resolve(x); };
    const timer = setTimeout(() => done({}), 6_000);
    v.preload = 'metadata';
    v.muted = true;
    v.playsInline = true;
    v.onloadedmetadata = () => { v.currentTime = Math.min(0.1, (v.duration || 1) / 2); };
    v.onseeked = () => {
      const meta = { durationMs: Number.isFinite(v.duration) ? Math.round(v.duration * 1000) : undefined, width: v.videoWidth || undefined, height: v.videoHeight || undefined };
      try {
        const c = document.createElement('canvas');
        const scale = Math.min(1, 640 / (v.videoWidth || 640));
        c.width = Math.round((v.videoWidth || 640) * scale);
        c.height = Math.round((v.videoHeight || 360) * scale);
        c.getContext('2d')?.drawImage(v, 0, 0, c.width, c.height);
        c.toBlob((b) => { clearTimeout(timer); done({ ...meta, thumb: b ?? undefined }); }, 'image/jpeg', 0.7);
      } catch { clearTimeout(timer); done(meta); }
    };
    v.onerror = () => { clearTimeout(timer); done({}); };
    v.src = url;
  });
}

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
  // «Скрыть имена чатов»: the list shrinks to photos (remembered on this device)
  const [collapsed, setCollapsed] = useState(false);
  useEffect(() => { try { setCollapsed(localStorage.getItem('chat-collapsed') === '1'); } catch { /* ignore */ } }, []);
  const toggleCollapsed = () => setCollapsed((c) => { try { localStorage.setItem('chat-collapsed', c ? '0' : '1'); } catch { /* ignore */ } return !c; });
  const narrow = collapsed && !single;
  return (
    <div className={`flex overflow-hidden rounded-xl border border-border bg-card ${single ? 'h-[calc(100dvh-8.5rem)] min-h-[380px]' : 'h-[calc(100dvh-9rem)] min-h-[420px] lg:h-[calc(100vh-4rem)]'}`}>
      <div className={`${roomId ? (single ? 'hidden' : 'hidden md:flex') : 'flex'} w-full flex-col ${single ? '' : `border-r border-border md:shrink-0 ${narrow ? 'md:w-[76px]' : 'md:w-80'}`}`}>
        <RoomList selected={roomId} onOpen={open} collapsed={narrow && !!roomId} onToggleCollapsed={single ? undefined : toggleCollapsed} />
      </div>
      <div className={`${roomId ? 'flex' : single ? 'hidden' : 'hidden md:flex'} min-w-0 flex-1 flex-col`}>
        {roomId ? <Conversation key={roomId} roomId={roomId} onBack={() => open(null)} single={single} /> : <div className="m-auto p-6 text-center text-muted">Выберите чат слева</div>}
      </div>
    </div>
  );
}

function RoomList({ selected, onOpen, collapsed = false, onToggleCollapsed }: { selected: string | null; onOpen: (id: string) => void; collapsed?: boolean; onToggleCollapsed?: () => void }) {
  const { me } = useAuth();
  const [mainMenu, setMainMenu] = useState(false);
  const [profile, setProfile] = useState(false);
  const [newMode, setNewMode] = useState<null | 'chat' | 'group' | 'channel'>(null);
  const admin = me?.role === 'SUPER_ADMIN' || me?.role === 'ADMIN';
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
      {mainMenu && (
        <ChatMainMenu
          onClose={() => setMainMenu(false)}
          onProfile={() => setProfile(true)}
          onGroup={() => setNewMode('group')}
          onChannel={admin ? () => setNewMode('channel') : undefined}
          onContacts={() => setNewMode('chat')}
          collapsed={collapsed}
          onCollapse={() => onToggleCollapsed?.()}
        />
      )}
      {profile && <MyProfileModal onClose={() => setProfile(false)} />}
      {newMode === 'channel' && <NewChannelModal onClose={() => setNewMode(null)} onOpen={(id) => { setNewMode(null); onOpen(id); }} />}
      {(newMode === 'chat' || newMode === 'group') && <NewChatModal initialGroup={newMode === 'group'} onClose={() => setNewMode(null)} onOpen={(id) => { setNewMode(null); onOpen(id); }} />}
      <div className={`flex items-center gap-2 border-b border-border py-2.5 ${collapsed ? 'flex-col px-2' : 'px-3'}`}>
        <button aria-label="Меню" onClick={() => setMainMenu(true)} className="rounded-full p-2 text-muted hover:bg-border/50"><Menu size={22} aria-hidden /></button>
        {!collapsed && <h2 className="flex-1 text-lg font-semibold">Чат</h2>}
        <button aria-label="Новый чат" title="Новый чат" onClick={() => setCreating(true)} className="rounded-full bg-primary p-2 text-white shadow hover:opacity-90"><Pencil size={18} aria-hidden /></button>
      </div>
      {!collapsed && <div className="border-b border-border px-3 py-2">
        <label className="flex items-center gap-2 rounded-lg bg-background px-3 py-1.5">
          <Search size={16} className="text-muted" aria-hidden />
          <input aria-label="Поиск: чаты, люди, сообщения" placeholder="Поиск: чаты, люди, сообщения" value={search} onChange={(e) => setSearch(e.target.value)} className="w-full bg-transparent text-sm outline-none" />
          {search && <button aria-label="Очистить поиск" onClick={() => setSearch('')}><X size={14} aria-hidden /></button>}
        </label>
      </div>}
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
              <Avatar kind="DIRECT" name={p.fullName} online={p.online} size={34} photo={p.avatar} />
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
        {collapsed && q.data?.items.map((r) => (
          <button key={r.id} title={chatTitle(r)} aria-label={chatTitle(r)} onClick={() => onOpen(r.id)} className={`relative flex w-full justify-center py-2 hover:bg-border/40 ${selected === r.id ? 'bg-primary/15' : ''}`}>
            <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} photo={r.photo ?? r.peer?.avatar} size={48} />
            {r.unread > 0 && <span className={`absolute right-2 top-1 rounded-full px-1.5 text-[11px] font-bold text-white ${r.muted ? 'bg-muted' : 'bg-primary'}`}>{r.unread}</span>}
          </button>
        ))}
        {!collapsed && q.data?.items.map((r) => {
          const last = r.lastMessage;
          const who = !last || r.kind === 'DIRECT' || !last.sender ? '' : last.sender.id === me?.id ? 'Вы: ' : `${last.sender.fullName.split(' ')[0]}: `;
          const sub = last ? `${who}${chatPreview(last)}` : r.kind === 'COMPANY' ? 'Все сотрудники и мастерицы' : `Участников: ${r.memberCount}`;
          return (
            <div key={r.id} className={`group relative flex items-center hover:bg-border/40 ${selected === r.id ? 'bg-primary/10' : ''}`}>
            <button
              onClick={() => onOpen(r.id)}
              className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 text-left"
            >
              <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} photo={r.photo ?? r.peer?.avatar} size={48} />
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
function NewChatModal({ onClose, onOpen, pick, exclude = [], initialGroup = false }: { onClose: () => void; onOpen?: (id: string) => void; pick?: (ids: string[]) => void; exclude?: string[]; initialGroup?: boolean }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const [channel, setChannel] = useState(false);
  const [search, setSearch] = useState('');
  const [group, setGroup] = useState(!!pick || initialGroup);
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
      {!pick && !group && (
        <div className="-mx-2 mb-3">
          <button onClick={() => { setGroup(true); setTicked([]); }} className="flex w-full items-center gap-4 rounded-lg px-3 py-2.5 text-left hover:bg-border/40">
            <span className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/15 text-primary"><Users size={20} aria-hidden /></span>
            <span className="font-medium">Создать группу</span>
          </button>
          {(me?.role === 'SUPER_ADMIN' || me?.role === 'ADMIN') && (
            <button onClick={() => setChannel(true)} className="flex w-full items-center gap-4 rounded-lg px-3 py-2.5 text-left hover:bg-border/40">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-sky-100 text-sky-800"><Megaphone size={20} aria-hidden /></span>
              <span className="font-medium">Создать канал</span>
            </button>
          )}
          <p className="px-3 pt-2 text-xs font-semibold uppercase text-muted">Контакты</p>
        </div>
      )}
      {!pick && group && <button onClick={() => { setGroup(false); setTicked([]); }} className="mb-2 flex items-center gap-1 text-sm text-primary"><ArrowLeft size={15} aria-hidden /> Назад</button>}
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
            <Avatar kind="DIRECT" name={p.fullName} online={p.online} size={40} photo={p.avatar} />
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

interface Pending {
  clientId: string; kind: ChatMessage['kind']; text?: string; file?: File; durationMs?: number; replyToId?: string; progress: number; failed: boolean; createdAt: string;
  /** shown at once: the picture itself, or the video's first frame */
  preview?: string; thumb?: Blob; width?: number; height?: number; waveform?: string;
  /** ✕ cancels the upload */
  abort?: AbortController;
}

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
  const [viewing, setViewing] = useState<ChatMessage | null>(null);
  // Telegram-like tools: right panel, search in the chat, ⋮ menu, right-click menu, «Выделить», wallpaper
  const [panel, setPanel] = useState(false);
  const [panelTab, setPanelTab] = useState<'info' | 'media' | 'files' | 'voice' | 'links'>('info');
  const [searching, setSearching] = useState(false);
  const [sq, setSq] = useState('');
  const [sqd, setSqd] = useState('');
  useEffect(() => { const id = setTimeout(() => setSqd(sq.trim()), 300); return () => clearTimeout(id); }, [sq]);
  const inChat = useQuery({ queryKey: ['chat-room-search', roomId, sqd], queryFn: () => api.get<{ items: ChatMessage[] }>(`/chat/rooms/${roomId}/search`, { q: sqd }), enabled: searching && sqd.length >= 2 });
  const [menuAt, setMenuAt] = useState<{ x: number; y: number } | null>(null);
  const [ctx, setCtx] = useState<{ m: ChatMessage; x: number; y: number } | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [wall, setWall] = useWallpaper(roomId);
  const [wallPick, setWallPick] = useState(false);
  const [forwardMany, setForwardMany] = useState<ChatMessage[] | null>(null);
  const [flash, setFlash] = useState<string | null>(null);
  const jumpTo = (id: string) => {
    const el = document.getElementById(`msg-${id}`);
    if (el) { el.scrollIntoView({ block: 'center', behavior: 'smooth' }); setFlash(id); setTimeout(() => setFlash(null), 1600); }
    else setError('Это сообщение выше — прокрутите вверх («Показать раньше»)');
  };
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
        await uploadChatFile(roomId, p, (x) => setPending((xs) => xs.map((y) => (y.clientId === p.clientId ? { ...y, progress: x } : y))));
      } else {
        await api.post(`/chat/rooms/${roomId}/messages`, { text: p.text, clientId: p.clientId, replyToId: p.replyToId });
      }
      await qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] });
      setPending((xs) => xs.filter((x) => x.clientId !== p.clientId));
    } catch (e) {
      if (p.abort?.signal.aborted) { setPending((xs) => xs.filter((x) => x.clientId !== p.clientId)); return; } // ✕ pressed
      setPending((xs) => xs.map((x) => (x.clientId === p.clientId ? { ...x, failed: true } : x)));
      setError(errorMessage(e));
    }
  };
  /** ✕ on a photo / video being sent: stop and forget it (like Telegram) */
  const cancel = (p: Pending) => { p.abort?.abort(); setPending((xs) => xs.filter((x) => x.clientId !== p.clientId)); };
  const queue = (p: Omit<Pending, 'clientId' | 'progress' | 'failed' | 'createdAt' | 'replyToId'>) => {
    const item: Pending = { ...p, replyToId: replyTo?.id, clientId: newId(), progress: 0, failed: false, createdAt: new Date().toISOString(), abort: p.file ? new AbortController() : undefined };
    if (p.file && p.kind === 'IMAGE' && typeof URL.createObjectURL === 'function') item.preview = URL.createObjectURL(p.file);
    setReplyTo(null);
    setPending((xs) => [...xs, item]);
    if (p.file && p.kind === 'VIDEO') {
      // the first frame is shown (and sent as the preview) while the video uploads
      void describeVideo(p.file).then((d) => {
        const withMeta: Pending = { ...item, ...d, durationMs: item.durationMs ?? d.durationMs, preview: d.thumb && typeof URL.createObjectURL === 'function' ? URL.createObjectURL(d.thumb) : undefined };
        setPending((xs) => xs.map((x) => (x.clientId === item.clientId ? { ...withMeta, progress: x.progress } : x)));
        void send(withMeta);
      });
      return;
    }
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
  const [selecting, setSelecting] = useState(false);
  const canEdit = (m: ChatMessage) => m.sender?.id === me?.id && !!m.text && !m.forwardedFrom && !m.deleted && Date.now() - new Date(m.createdAt).getTime() < 48 * 3600_000;
  const canDelete = (m: ChatMessage) => !m.deleted && (m.sender?.id === me?.id || me?.role === 'SUPER_ADMIN' || me?.role === 'ADMIN' || !!room.data?.canManage);
  const toggleMute = () => act.mutate({ path: `/chat/rooms/${roomId}/me`, method: 'patch', body: { muted: !room.data?.muted } });
  const openInfo = () => { if (typeof window !== 'undefined' && window.innerWidth >= 1280) { setPanelTab('info'); setPanel(true); } else setInfo(true); };
  const exportHistory = async () => {
    try {
      const res = await fetch(`${apiBaseUrl()}/v1/chat/rooms/${roomId}/export`, { headers: { Authorization: `Bearer ${accessToken() ?? ''}` } });
      if (!res.ok) throw new Error(res.status === 403 ? 'Сохранение истории в этом чате запрещено' : 'Не удалось выгрузить историю');
      const url = URL.createObjectURL(await res.blob());
      const a = document.createElement('a'); a.href = url; a.download = `diamoraa-chat-${new Date().toISOString().slice(0, 10)}.txt`; a.click();
      setTimeout(() => URL.revokeObjectURL(url), 5_000);
    } catch (e) { setError(errorMessage(e)); }
  };
  const deleteChat = async () => {
    const r0 = room.data;
    if (!r0) return;
    if (!confirm(r0.kind === 'DIRECT' ? 'Удалить чат? Переписка исчезнет только у вас.' : 'Покинуть? Вы больше не будете видеть сообщения.')) return;
    try { await api.delete(`/chat/rooms/${roomId}`); await qc.invalidateQueries({ queryKey: ['chat-rooms'] }); onBack(); } catch (e) { setError(errorMessage(e)); }
  };
  const react = (m: ChatMessage, e: string) => act.mutate({ path: `/chat/messages/${m.id}/reactions`, body: { emoji: e } });
  const pin = (id: string | null) => act.mutate({ path: `/chat/rooms/${roomId}/pin`, body: { messageId: id } });
  const sendFiles = (files: FileList | null) => {
    setError(null);
    for (const f of Array.from(files ?? [])) {
      const kind = chatKindForFile(f);
      if (kind === 'VIDEO' ? f.size > CHAT_MAX_VIDEO_BYTES : f.size > CHAT_MAX_BYTES) {
        setError(kind === 'VIDEO' ? `«${f.name}» больше 150 МБ — видео нельзя отправить` : `«${f.name}» больше 50 МБ — его нельзя отправить`);
        continue;
      }
      queue({ kind, file: f });
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
    <div className="flex min-h-0 min-w-0 flex-1">
    <div className="flex min-w-0 flex-1 flex-col">
      <div className="flex items-center gap-3 border-b border-border px-3 py-2.5">
        <button aria-label="Назад" className={`rounded-lg p-1.5 hover:bg-border/50 ${single ? '' : 'md:hidden'}`} onClick={onBack}><ArrowLeft size={20} aria-hidden /></button>
        {r && <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} size={36} photo={r.photo?.thumbUrl} />}
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{r ? chatTitle(r) : ''}</p>
          <p className={`truncate text-xs ${typingText ? 'text-primary' : 'text-muted'}`}>{subtitle}</p>
        </div>
        {r && <button aria-label="Поиск в чате" title="Поиск" className="rounded-full p-2 text-muted hover:bg-border/50" onClick={() => { setSearching(!searching); setSq(''); }}><Search size={20} aria-hidden /></button>}
        {r && <button aria-label="Информация о чате" title="Информация" className={`rounded-full p-2 hover:bg-border/50 ${panel ? 'text-primary' : 'text-muted'}`} onClick={() => (panel ? setPanel(false) : openInfo())}><PanelRight size={20} aria-hidden /></button>}
        {r && <button aria-label="Ещё" title="Ещё" className="rounded-full p-2 text-muted hover:bg-border/50" onClick={(e) => { const b = e.currentTarget.getBoundingClientRect(); setMenuAt({ x: b.right - 240, y: b.bottom + 4 }); }}><MoreVertical size={20} aria-hidden /></button>}
      </div>
      <AudioBar />
      {selecting && (
        <div className="flex items-center gap-2 border-b border-border bg-primary/10 px-3 py-2 text-sm">
          <span className="flex-1 font-semibold">Выбрано: {selected.length}</span>
          {!r?.protectContent && <Button variant="outline" className="min-h-8 px-3 py-1 text-sm" disabled={!selected.length} onClick={() => setForwardMany(messages.filter((m) => selected.includes(m.id)))}><Forward size={15} aria-hidden /> Переслать</Button>}
          <Button variant="outline" className="min-h-8 px-3 py-1 text-sm text-danger" disabled={!selected.length || !messages.filter((m) => selected.includes(m.id)).every(canDelete)}
            onClick={() => { if (confirm(`Удалить ${selected.length} сообщ.? Они исчезнут у всех.`)) { for (const id of selected) del.mutate(id); setSelected([]); setSelecting(false); } }}>
            <Trash2 size={15} aria-hidden /> Удалить
          </Button>
          <button aria-label="Отменить выделение" className="rounded-full p-1.5 hover:bg-border/50" onClick={() => { setSelecting(false); setSelected([]); }}><X size={18} aria-hidden /></button>
        </div>
      )}
      {searching && (
        <div className="relative border-b border-border px-3 py-2">
          <label className="flex items-center gap-2 rounded-lg bg-background px-3 py-1.5">
            <Search size={16} className="text-muted" aria-hidden />
            <input autoFocus aria-label="Поиск в этом чате" placeholder="Поиск в этом чате" value={sq} onChange={(e) => setSq(e.target.value)} className="w-full bg-transparent text-sm outline-none" />
            <button aria-label="Закрыть поиск" onClick={() => { setSearching(false); setSq(''); }}><X size={14} aria-hidden /></button>
          </label>
          {sqd.length >= 2 && (
            <div className="absolute inset-x-3 top-full z-20 mt-1 max-h-72 overflow-y-auto rounded-lg border border-border bg-card shadow-lg">
              {inChat.isLoading && <div className="flex justify-center p-3"><Spinner /></div>}
              {inChat.data && !inChat.data.items.length && <p className="p-3 text-center text-sm text-muted">Ничего не найдено</p>}
              {inChat.data?.items.map((m) => (
                <button key={m.id} onClick={() => { setSearching(false); jumpTo(m.id); }} className="block w-full px-3 py-2 text-left text-sm hover:bg-border/40">
                  <span className="flex justify-between gap-2"><b className="truncate">{m.sender?.fullName}</b><span className="shrink-0 text-xs text-muted">{chatWhen(m.createdAt)}</span></span>
                  <span className="line-clamp-2 text-muted">{m.text}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {r?.pinnedMessage && (
        <div className="flex items-center gap-2 border-b border-border bg-primary/5 px-4 py-1.5 text-sm">
          <Pin size={15} className="shrink-0 text-primary" aria-hidden />
          <span className="min-w-0 flex-1"><span className="block text-xs font-semibold text-primary">Закреплённое сообщение</span><span className="block truncate">{chatPreview(r.pinnedMessage)}</span></span>
          {r.canPin && <button aria-label="Открепить" className="rounded p-1 hover:bg-border/50" onClick={() => pin(null)}><X size={15} aria-hidden /></button>}
        </div>
      )}
      <div className="flex-1 overflow-y-auto bg-background/60 px-3 py-3" style={WALLPAPERS[wall]?.css ? { background: WALLPAPERS[wall].css } : undefined}>
        {msgs.hasNextPage && (
          <div className="mb-2 text-center">
            <button className="text-sm text-primary underline" onClick={() => msgs.fetchNextPage()} disabled={msgs.isFetchingNextPage}>Показать раньше</button>
          </div>
        )}
        {(room.isError || msgs.isError) && <ErrorState error={room.error ?? msgs.error} />}
        {msgs.isLoading && <div className="flex justify-center p-6"><Spinner /></div>}
        {msgs.isSuccess && messages.length === 0 && pending.length === 0 && <p className="mt-10 text-center text-muted">Сообщений пока нет — напишите первым</p>}
        {albumsOf(messages).map((item, i, all) => {
          const first = Array.isArray(item) ? item[0] : item;
          const last = Array.isArray(item) ? item[item.length - 1] : item;
          const prev = i > 0 ? all[i - 1] : null;
          const prevLast = prev ? (Array.isArray(prev) ? prev[prev.length - 1] : prev) : null;
          const mine = first.sender?.id === me?.id;
          const newDay = !prevLast || new Date(prevLast.createdAt).toDateString() !== new Date(first.createdAt).toDateString();
          const group = !!r && r.kind !== 'DIRECT' && r.kind !== 'CHANNEL';
          const nextFirst = i + 1 < all.length ? (Array.isArray(all[i + 1]) ? (all[i + 1] as ChatMessage[])[0] : (all[i + 1] as ChatMessage)) : null;
          const lastOfRun = !nextFirst || nextFirst.sender?.id !== first.sender?.id;
          const ids = Array.isArray(item) ? item.map((x) => x.id) : [item.id];
          const isSel = ids.some((id) => selected.includes(id));
          const openCtx = (e: { clientX: number; clientY: number; preventDefault?: () => void }) => { e.preventDefault?.(); if (!last.deleted) setCtx({ m: last, x: e.clientX, y: e.clientY }); };
          return (
            <div key={first.id} id={`msg-${last.id}`} className={`rounded-lg transition ${flash && ids.includes(flash) ? 'bg-primary/20' : ''}`}>
              {newDay && <div className="my-3 text-center"><span className="rounded-full bg-card/80 px-3 py-1 text-xs shadow-sm">{dayLabel(first.createdAt)}</span></div>}
              <div className={`flex items-end gap-2 ${selecting ? 'cursor-pointer' : ''}`} onClick={selecting ? () => setSelected((xs) => (isSel ? xs.filter((x) => !ids.includes(x)) : [...xs, ...ids])) : undefined}>
                {selecting && <input type="checkbox" readOnly checked={isSel} aria-label="Выбрать сообщение" className="mb-3 h-4 w-4 shrink-0 accent-primary" />}
                {group && !mine && (lastOfRun ? <PersonAvatar name={first.sender?.fullName ?? ''} photo={first.sender?.avatar} size={32} /> : <span className="w-8 shrink-0" />)}
                <div className="min-w-0 flex-1">
                  {Array.isArray(item) ? (
                    <Album items={item} mine={mine} showSender={group && !mine} onOpen={(m) => setViewing(m)} onContext={openCtx} protect={!!r?.protectContent}
                      read={mine && peerRead >= new Date(last.createdAt).getTime()} />
                  ) : (
                    <Bubble
                      m={item}
                      mine={mine}
                      showSender={group && !mine}
                      read={mine && peerRead >= new Date(item.createdAt).getTime()}
                      onReact={(e) => react(item, e)}
                      pinned={r?.pinnedMessage?.id === item.id}
                      onOpenMedia={() => setViewing(item)}
                      onContext={openCtx}
                      onJump={jumpTo}
                      protect={!!r?.protectContent}
                    />
                  )}
                </div>
              </div>
            </div>
          );
        })}
        {pending.map((p) => (p.file && (p.kind === 'IMAGE' || p.kind === 'VIDEO')) ? (
          <div key={p.clientId} className="my-1 flex justify-end">
            <button onClick={() => p.failed && send(p)} className="relative overflow-hidden rounded-2xl bg-black/80" style={{ width: 240, aspectRatio: `${p.width ?? 4} / ${p.height ?? 3}`, maxHeight: 320 }} aria-label={p.failed ? 'Не отправлено — нажмите, чтобы повторить' : 'Отправка'}>
              {p.preview && <img src={p.preview} alt="" className="absolute inset-0 h-full w-full object-cover" />}
              <span className="absolute inset-0 flex items-center justify-center">
                <span className="flex h-14 w-14 items-center justify-center rounded-full bg-black/55 text-xs font-semibold text-white" style={{ background: p.failed ? undefined : `conic-gradient(white ${p.progress * 360}deg, rgba(0,0,0,.55) 0deg)` }}>
                  <span className="flex h-11 w-11 items-center justify-center rounded-full bg-black/70">{p.failed ? '↻' : `${Math.round(p.progress * 100)}%`}</span>
                </span>
              </span>
              {p.failed && <span className="absolute inset-x-0 bottom-0 bg-black/60 px-2 py-1 text-center text-xs text-white">Не отправлено — нажмите, чтобы повторить</span>}
            </button>
            {!p.failed && <button aria-label="Отменить отправку" onClick={() => cancel(p)} className="-ml-9 mt-2 h-7 w-7 self-start rounded-full bg-black/60 text-white hover:bg-black/80"><X size={16} className="mx-auto" aria-hidden /></button>}
          </div>
        ) : (
          <div key={p.clientId} className="my-1 flex justify-end">
            <button
              onClick={() => p.failed && send(p)}
              className="max-w-[80%] rounded-2xl bg-primary/10 px-3 py-2 text-left opacity-80"
            >
              <span className="block whitespace-pre-wrap break-words">{p.text ?? `${{ IMAGE: '📷', VIDEO: '🎬', VOICE: '🎤', AUDIO: '🎵', FILE: '📎', TEXT: '' }[p.kind]} ${p.file?.name ?? ''}`}</span>
              <span className={`block text-right text-xs ${p.failed ? 'font-semibold text-danger' : 'text-muted'}`}>{p.failed ? 'Не отправлено — нажмите, чтобы повторить' : p.file && p.progress > 0 ? `Отправка… ${Math.round(p.progress * 100)}%` : 'Отправка…'}</span>
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
          : <VoiceButton onRecorded={(file, durationMs, waveform) => queue({ kind: 'VOICE', file, durationMs, waveform })} onError={setError} onRecording={() => sendTyping('voice')} />}
      </div>
      )}
      {info && r && (r.kind === 'DIRECT' && r.peer
        ? <Modal title="Информация" onClose={() => setInfo(false)}><ProfileCard userId={r.peer.id} muted={r.muted} onToggleMute={() => toggleMute()} onOpenTab={(t) => { setInfo(false); setPanelTab(t); setPanel(true); }} /></Modal>
        : <RoomInfo room={r} onClose={() => setInfo(false)} onLeft={() => { setInfo(false); onBack(); }} onOpenMessage={() => setInfo(false)} />)}
      {menuAt && r && (
        <FloatingMenu x={menuAt.x} y={menuAt.y} onClose={() => setMenuAt(null)}>
          <MenuItem icon={r.muted ? <Bell size={16} aria-hidden /> : <BellOff size={16} aria-hidden />} label={r.muted ? 'Включить уведомления' : 'Выключить уведомления'} onClick={() => { setMenuAt(null); toggleMute(); }} />
          <MenuItem icon={<UserIcon size={16} aria-hidden />} label={r.kind === 'DIRECT' ? 'Показать профиль' : 'Информация'} onClick={() => { setMenuAt(null); openInfo(); }} />
          <MenuItem icon={<Wallpaper size={16} aria-hidden />} label="Установить обои" onClick={() => { setMenuAt(null); setWallPick(true); }} />
          {r.canProtect && <MenuItem icon={r.protectContent ? <ShieldOff size={16} aria-hidden /> : <Shield size={16} aria-hidden />} label={r.protectContent ? 'Разрешить копирование' : 'Запретить копирование'} onClick={() => { setMenuAt(null); act.mutate({ path: `/chat/rooms/${roomId}/protect`, body: { on: !r.protectContent } }); }} />}
          {(!r.protectContent || r.canProtect) && <MenuItem icon={<FileDown size={16} aria-hidden />} label="Экспорт истории чата" onClick={() => { setMenuAt(null); void exportHistory(); }} />}
          <MenuItem icon={<CheckSquare size={16} aria-hidden />} label="Выделить сообщения" onClick={() => { setMenuAt(null); setSelected([]); setSelecting(true); }} />
          <MenuItem icon={<Eraser size={16} aria-hidden />} label="Очистить историю" onClick={() => { setMenuAt(null); if (confirm('Очистить историю? Сообщения исчезнут только у вас.')) act.mutate({ path: `/chat/rooms/${roomId}/clear` }); }} />
          {r.kind !== 'COMPANY' && !(r.kind === 'CHANNEL' && r.audience !== 'CUSTOM') && (
            <MenuItem danger icon={<Trash2 size={16} aria-hidden />} label={r.kind === 'DIRECT' ? 'Удалить чат' : r.kind === 'CHANNEL' ? 'Покинуть канал' : 'Покинуть группу'} onClick={() => { setMenuAt(null); void deleteChat(); }} />
          )}
        </FloatingMenu>
      )}
      {ctx && (
        <FloatingMenu x={ctx.x} y={ctx.y} onClose={() => setCtx(null)}>
          <div className="flex justify-between gap-0.5 border-b border-border px-2 pb-1.5 pt-1">
            {CHAT_REACTIONS.map((e) => <button key={e} aria-label={`Реакция ${e}`} className="rounded-full p-1 text-xl transition hover:scale-125 hover:bg-border/50" onClick={() => { react(ctx.m, e); setCtx(null); }}>{e}</button>)}
          </div>
          <MenuItem icon={<Reply size={16} aria-hidden />} label="Ответить" onClick={() => { setReplyTo(ctx.m); setEditing(null); setCtx(null); }} />
          {canEdit(ctx.m) && <MenuItem icon={<Pencil size={16} aria-hidden />} label="Изменить" onClick={() => { setEditing(ctx.m); setReplyTo(null); setText(ctx.m.text ?? ''); setCtx(null); }} />}
          {r?.canPin && <MenuItem icon={<Pin size={16} aria-hidden />} label={r.pinnedMessage?.id === ctx.m.id ? 'Открепить' : 'Закрепить'} onClick={() => { pin(r.pinnedMessage?.id === ctx.m.id ? null : ctx.m.id); setCtx(null); }} />}
          {ctx.m.text && !r?.protectContent && <MenuItem icon={<Copy size={16} aria-hidden />} label="Копировать текст" onClick={() => { void navigator.clipboard?.writeText(ctx.m.text ?? ''); setCtx(null); }} />}
          {!r?.protectContent && <MenuItem icon={<Forward size={16} aria-hidden />} label="Переслать" onClick={() => { setForwarding(ctx.m); setCtx(null); }} />}
          {canDelete(ctx.m) && <MenuItem danger icon={<Trash2 size={16} aria-hidden />} label="Удалить" onClick={() => { const id = ctx.m.id; setCtx(null); if (confirm('Удалить сообщение? Оно исчезнет у всех участников.')) del.mutate(id); }} />}
          <MenuItem icon={<CheckSquare size={16} aria-hidden />} label="Выделить" onClick={() => { setSelecting(true); setSelected([ctx.m.id]); setCtx(null); }} />
          {ctx.m.sender?.id === me?.id && <ReadInfo message={ctx.m} room={r} />}
        </FloatingMenu>
      )}
      {wallPick && (
        <Modal title="Обои чата" onClose={() => setWallPick(false)}>
          <div className="grid grid-cols-3 gap-2">
            {Object.entries(WALLPAPERS).map(([k, w]) => (
              <button key={k} onClick={() => { setWall(k); setWallPick(false); }} className={`h-24 rounded-lg border text-xs font-medium ${wall === k ? 'border-primary ring-2 ring-primary' : 'border-border'}`} style={{ background: w.css || undefined }}>{w.label}</button>
            ))}
          </div>
        </Modal>
      )}
      {forwardMany && <ForwardModal messages={forwardMany} onClose={() => setForwardMany(null)} onDone={() => { setForwardMany(null); setSelecting(false); setSelected([]); }} />}
      {forwarding && <ForwardModal message={forwarding} onClose={() => setForwarding(null)} onDone={() => setForwarding(null)} />}
      {viewing && <MediaViewer items={messages.filter((m) => !m.deleted && m.file && (m.kind === 'IMAGE' || m.kind === 'VIDEO'))} start={viewing} onClose={() => setViewing(null)} protect={!!r?.protectContent} />}
    </div>
    {panel && r && (
      <aside className="hidden w-80 shrink-0 flex-col overflow-y-auto border-l border-border bg-card xl:flex" aria-label="Информация">
        <div className="flex items-center gap-2 border-b border-border px-4 py-3">
          {panelTab !== 'info' && <button aria-label="Назад" onClick={() => setPanelTab('info')} className="rounded-full p-1 hover:bg-border/50"><ArrowLeft size={18} aria-hidden /></button>}
          <p className="flex-1 font-semibold">{panelTab === 'info' ? 'Информация' : { media: 'Медиа', files: 'Файлы', voice: 'Голосовые', links: 'Ссылки' }[panelTab]}</p>
          <button aria-label="Закрыть панель" onClick={() => setPanel(false)} className="rounded-full p-1 hover:bg-border/50"><X size={18} aria-hidden /></button>
        </div>
        {panelTab === 'info' && r.kind === 'DIRECT' && r.peer
          ? <ProfileCard userId={r.peer.id} muted={r.muted} onToggleMute={toggleMute} onOpenTab={setPanelTab} />
          : <RoomInfo panel room={r} initialTab={panelTab === 'info' ? undefined : panelTab} onClose={() => setPanel(false)} onLeft={() => { setPanel(false); onBack(); }} onOpenMessage={() => undefined} />}
      </aside>
    )}
    </div>
  );
}

/** A photo's full size starts loading as soon as the bubble is on screen, so opening it is instant. */
function usePreload(url: string | undefined) {
  const ref = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!url || !el || typeof IntersectionObserver === 'undefined') return;
    const io = new IntersectionObserver((es) => { if (es.some((e) => e.isIntersecting)) { const img = new Image(); img.src = url; io.disconnect(); } }, { rootMargin: '400px' });
    io.observe(el);
    return () => io.disconnect();
  }, [url]);
  return ref;
}

function Stamp({ m, mine, read, pinned, light }: { m: ChatMessage; mine: boolean; read: boolean; pinned?: boolean; light?: boolean }) {
  const t = new Date(m.createdAt);
  return (
    <span className={`flex items-center justify-end gap-1 text-[11px] ${light ? 'text-white' : 'text-muted'}`}>
      {m.editedAt && !m.deleted && <span>изменено</span>}
      {pinned && <Pin size={11} aria-label="Закреплено" />}
      {two(t.getHours())}:{two(t.getMinutes())}
      {mine && !m.deleted && (read ? <CheckCheck size={14} className={light ? '' : 'text-primary'} aria-label="Прочитано" /> : <Check size={14} aria-hidden />)}
    </span>
  );
}

function Bubble({ m, mine, showSender, read, onReact, pinned, onOpenMedia, onContext, onJump, protect }: {
  m: ChatMessage; mine: boolean; showSender: boolean; read: boolean; onReact?: (e: string) => void; pinned?: boolean; onOpenMedia?: () => void;
  onContext: (e: { clientX: number; clientY: number; preventDefault?: () => void }) => void; onJump?: (id: string) => void; protect?: boolean;
}) {
  const f = m.file;
  const preload = usePreload(m.kind === 'IMAGE' ? f?.url : undefined);
  const mediaOnly = !m.deleted && !m.text && !m.replyTo && !m.forwardedFrom && (m.kind === 'IMAGE' || m.kind === 'VIDEO');
  return (
    <div className={`group my-0.5 flex ${mine ? 'justify-end' : 'justify-start'}`} onContextMenu={onContext}>
      <div className={`relative max-w-[80%] ${mediaOnly ? 'overflow-hidden rounded-2xl' : `rounded-2xl px-3 py-2 ${mine ? 'rounded-br-md bg-primary/15' : 'rounded-bl-md bg-card shadow-sm ring-1 ring-border'}`} ${protect ? 'select-none' : ''}`}>
        {showSender && m.sender && !mediaOnly && <p className="mb-0.5 text-xs font-bold text-primary">{m.sender.fullName}</p>}
        {!m.deleted && m.forwardedFrom && <p className="mb-1 text-xs italic text-muted">Переслано от {m.forwardedFrom}</p>}
        {!m.deleted && m.replyTo && (
          <button onClick={() => onJump?.(m.replyTo!.id)} className="mb-1.5 block w-full rounded-md border-l-[3px] border-primary bg-border/40 px-2 py-1 text-left text-sm hover:bg-border/60">
            {m.replyTo.sender && <p className="text-xs font-bold text-primary">{m.replyTo.sender}</p>}
            <p className="line-clamp-2 text-muted">{m.replyTo.deleted ? 'Сообщение удалено' : m.replyTo.preview}</p>
          </button>
        )}
        {m.deleted ? (
          <p className="italic text-muted">Сообщение удалено</p>
        ) : (
          <>
            {m.kind === 'IMAGE' && f && (
              <button ref={preload} onClick={onOpenMedia} aria-label="Открыть фото" className="relative block">
                <img src={f.thumbUrl ?? f.url} alt={m.text ?? 'Фото'} draggable={!protect} className={`max-h-80 max-w-full object-cover ${mediaOnly ? '' : 'rounded-lg'}`} style={{ aspectRatio: f.width && f.height ? `${f.width} / ${f.height}` : undefined, minWidth: 160 }} />
                {mediaOnly && <span className="absolute bottom-1.5 right-1.5 rounded-full bg-black/45 px-1.5 py-0.5"><Stamp m={m} mine={mine} read={read} pinned={pinned} light /></span>}
              </button>
            )}
            {m.kind === 'VIDEO' && f && (
              <button onClick={onOpenMedia} aria-label="Смотреть видео" className={`relative block overflow-hidden bg-black ${mediaOnly ? '' : 'rounded-lg'}`} style={{ width: 260, aspectRatio: `${f.width ?? 16} / ${f.height ?? 9}`, maxHeight: 340 }}>
                {f.thumbUrl && <img src={f.thumbUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />}
                <span className="absolute inset-0 flex items-center justify-center"><span className="flex h-12 w-12 items-center justify-center rounded-full bg-black/55 text-white"><Play size={24} aria-hidden /></span></span>
                <span className="absolute left-1.5 top-1.5 rounded bg-black/55 px-1.5 text-xs text-white">{f.durationMs ? `${fmtDuration(f.durationMs)} · ` : ''}{bytes(f.size)}</span>
                {mediaOnly && <span className="absolute bottom-1.5 right-1.5 rounded-full bg-black/45 px-1.5 py-0.5"><Stamp m={m} mine={mine} read={read} pinned={pinned} light /></span>}
              </button>
            )}
            {(m.kind === 'VOICE' || m.kind === 'AUDIO') && f && (
              <VoicePlayer id={m.id} url={f.url} waveform={m.waveform} durationMs={f.durationMs} size={f.size} name={m.kind === 'AUDIO' ? f.name : null} mine={mine} title={m.kind === 'AUDIO' && f.name ? f.name : (m.sender?.fullName ?? 'Голосовое')} roomId={m.roomId} createdAt={m.createdAt} />
            )}
            {m.kind === 'FILE' && f && (
              <a href={protect ? undefined : f.url} download={protect ? undefined : (f.name ?? undefined)} className="flex items-center gap-3 rounded-lg p-1 hover:bg-border/40">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary text-white"><FileText size={22} aria-hidden /></span>
                <span className="min-w-0">
                  <span className="block truncate font-medium">{f.name ?? 'Файл'}</span>
                  <span className="block text-xs text-muted">{bytes(f.size)}{protect ? ' · скачивание запрещено' : ''}</span>
                </span>
                {!protect && <Download size={18} className="shrink-0 text-muted" aria-hidden />}
              </a>
            )}
            {m.text && <p className={`whitespace-pre-wrap break-words ${f ? 'mt-1' : ''}`}><RichText text={m.text} /></p>}
          </>
        )}
        {!m.deleted && !!m.reactions?.length && (
          <div className={`mt-1 flex flex-wrap gap-1 ${mediaOnly ? 'absolute left-1.5 bottom-1.5' : ''}`}>
            {m.reactions.map((x) => (
              <button key={x.emoji} onClick={() => onReact?.(x.emoji)} aria-pressed={x.mine} className={`rounded-full px-2 py-0.5 text-xs ${x.mine ? 'bg-primary/20 ring-1 ring-primary' : 'bg-border/60'}`}>{x.emoji} {x.count}</button>
            ))}
          </div>
        )}
        {!mediaOnly && <p className="mt-0.5"><Stamp m={m} mine={mine} read={read} pinned={pinned} /></p>}
        {!m.deleted && (
          <button aria-label="Действия с сообщением" onClick={(e) => { const b = e.currentTarget.getBoundingClientRect(); onContext({ clientX: b.left, clientY: b.bottom }); }}
            className={`absolute -top-2 ${mine ? 'left-1' : 'right-1'} rounded-full bg-card p-1 text-muted opacity-0 shadow ring-1 ring-border group-hover:opacity-100 focus:opacity-100`}>
            <MoreVertical size={14} aria-hidden />
          </button>
        )}
      </div>
    </div>
  );
}

/** Photos / videos sent together: one tidy grid, like Telegram's albums. */
function Album({ items, mine, showSender, onOpen, onContext, protect, read }: {
  items: ChatMessage[]; mine: boolean; showSender: boolean; onOpen: (m: ChatMessage) => void;
  onContext: (e: { clientX: number; clientY: number; preventDefault?: () => void }) => void; protect: boolean; read: boolean;
}) {
  const n = items.length;
  const cols = n === 2 || n === 4 ? 2 : 3;
  const last = items[n - 1];
  return (
    <div className={`my-0.5 flex ${mine ? 'justify-end' : 'justify-start'}`} onContextMenu={onContext}>
      <div className={`relative w-[min(360px,80%)] overflow-hidden rounded-2xl ${protect ? 'select-none' : ''}`}>
        {showSender && items[0].sender && <p className="bg-card px-3 py-1 text-xs font-bold text-primary">{items[0].sender.fullName}</p>}
        <div className="grid gap-0.5" style={{ gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))` }}>
          {items.map((m) => (
            <button key={m.id} onClick={() => onOpen(m)} aria-label={m.kind === 'VIDEO' ? 'Смотреть видео' : 'Открыть фото'} className="relative aspect-square overflow-hidden bg-black/80">
              {(m.file?.thumbUrl || m.kind === 'IMAGE') && <img src={m.file?.thumbUrl ?? m.file?.url} alt="" draggable={!protect} className="h-full w-full object-cover" />}
              {m.kind === 'VIDEO' && <span className="absolute inset-0 flex items-center justify-center"><span className="flex h-9 w-9 items-center justify-center rounded-full bg-black/55 text-white"><Play size={18} aria-hidden /></span></span>}
            </button>
          ))}
        </div>
        <span className="absolute bottom-1.5 right-1.5 rounded-full bg-black/45 px-1.5 py-0.5"><Stamp m={last} mine={mine} read={read} light /></span>
      </div>
    </div>
  );
}

/** «прочитано когда?» (my own messages): the time in a direct chat, who read it in a group. */
function ReadInfo({ message, room }: { message: ChatMessage; room: ChatRoomDetail | undefined }) {
  const [open, setOpen] = useState(false);
  const q = useQuery({ queryKey: ['chat-reads', message.id], queryFn: () => api.get<{ items: (ChatPerson & { readAt: string })[] }>(`/chat/messages/${message.id}/reads`), enabled: open || room?.kind === 'DIRECT' });
  const hm = (iso: string) => { const d = new Date(iso); return `${two(d.getHours())}:${two(d.getMinutes())}`; };
  if (room?.kind === 'DIRECT') {
    const r0 = q.data?.items[0];
    return <p className="flex items-center gap-2 border-t border-border px-4 py-2 text-xs text-muted"><CheckCheck size={14} className="text-primary" aria-hidden />{r0 ? `прочитано в ${hm(r0.readAt)}` : q.isLoading ? '…' : 'ещё не прочитано'}</p>;
  }
  return (
    <div className="border-t border-border">
      <button onClick={() => setOpen(!open)} className="flex w-full items-center gap-2 px-4 py-2 text-left text-xs text-muted hover:bg-border/40"><CheckCheck size={14} className="text-primary" aria-hidden />Кто прочитал</button>
      {open && (
        <div className="max-h-40 overflow-y-auto pb-1">
          {q.isLoading && <p className="px-4 py-1 text-xs text-muted">…</p>}
          {q.data?.items.length === 0 && <p className="px-4 py-1 text-xs text-muted">Пока никто</p>}
          {q.data?.items.map((p) => <p key={p.id} className="flex justify-between gap-2 px-4 py-1 text-xs"><span className="truncate">{p.fullName}</span><span className="text-muted">{hm(p.readAt)}</span></p>)}
        </div>
      )}
    </div>
  );
}

/** Click to start recording, click again to send (a browser has no «hold»); the microphone permission is asked once. */
function VoiceButton({ onRecorded, onError, onRecording }: { onRecorded: (f: File, durationMs: number, waveform?: string) => void; onError: (m: string) => void; onRecording?: () => void }) {
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
      const wave = waveformRecorder(stream); // the bars other people will see on this voice message
      r.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      r.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        const ms = Date.now() - started;
        if (ms < 700) return;
        const mime = r.mimeType || 'audio/webm';
        const ext = mime.includes('mp4') ? 'm4a' : mime.includes('ogg') ? 'ogg' : 'webm';
        onRecorded(new File(chunks, `voice.${ext}`, { type: mime.split(';')[0] }), ms, wave.finish());
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
function RoomInfo({ room, onClose, onLeft, panel = false, initialTab }: { room: ChatRoomDetail; onClose: () => void; onLeft: () => void; onOpenMessage: () => void; panel?: boolean; initialTab?: 'media' | 'files' | 'voice' | 'links' }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState(room.title ?? '');
  const [description, setDescription] = useState(room.description ?? '');
  const managed = room.kind === 'GROUP' || room.kind === 'CHANNEL';
  const [tab, setTab] = useState<'members' | 'media' | 'files' | 'voice' | 'links'>(initialTab ?? (managed ? 'members' : 'media'));
  useEffect(() => { if (initialTab) setTab(initialTab); }, [initialTab]);
  const Frame = panel ? PanelFrame : Modal;
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
    <Frame title={room.kind === 'CHANNEL' ? 'О канале' : room.kind === 'GROUP' ? 'О группе' : 'Информация о чате'} onClose={onClose}>
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
    </Frame>
  );
}

function PanelFrame({ children }: { title: string; onClose: () => void; children: ReactNode }) {
  return <div className="p-4">{children}</div>;
}

/** «Переслать в…»: one of my chats. */
function ForwardModal({ message, messages, onClose, onDone }: { message?: ChatMessage; messages?: ChatMessage[]; onClose: () => void; onDone: () => void }) {
  const rooms = useQuery({ queryKey: ['chat-rooms'], queryFn: () => api.get<{ items: ChatRoomSummary[] }>('/chat/rooms') });
  const list = messages ?? (message ? [message] : []);
  const fwd = useMutation({
    mutationFn: async (roomId: string) => { for (const m of list) await api.post(`/chat/messages/${m.id}/forward`, { roomIds: [roomId] }); },
    onSuccess: onDone,
  });
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

/** Sends a file: one request when small, otherwise in 5 MB parts that resume (the same clientId continues). */
async function uploadChatFile(roomId: string, p: Pending, onProgress: (x: number) => void) {
  const f = p.file!;
  const meta = { kind: p.kind, clientId: p.clientId, durationMs: p.durationMs, replyToId: p.replyToId, width: p.width, height: p.height, waveform: p.waveform };
  const signal = p.abort?.signal;
  if (f.size <= SINGLE_UPLOAD_BYTES) {
    const form = new FormData();
    for (const [k, v] of Object.entries(meta)) if (v !== undefined && v !== null) form.set(k, String(v));
    form.set('file', f, f.name);
    if (p.thumb) form.set('thumb', p.thumb, 'thumb.jpg');
    await api.upload(`/chat/rooms/${roomId}/files`, form, { signal });
    onProgress(1);
    return;
  }
  const start = await api.post<{ done?: boolean; uploadId: string; chunkSize: number; parts: number; received: number[] }>(`/chat/rooms/${roomId}/uploads`, { name: f.name, size: f.size, ...meta });
  if (start.done) return;
  const have = new Set(start.received);
  let sent = have.size * start.chunkSize;
  onProgress(sent / f.size);
  for (let i = 0; i < start.parts; i++) {
    if (have.has(i)) continue;
    const blob = f.slice(i * start.chunkSize, Math.min(f.size, (i + 1) * start.chunkSize));
    for (let attempt = 1; ; attempt++) {
      try {
        const form = new FormData();
        form.set('chunk', blob, 'part');
        if (signal?.aborted) throw new DOMException('cancelled', 'AbortError');
        await api.upload(`/chat/uploads/${start.uploadId}/parts/${i}`, form, { signal });
        break;
      } catch (e) {
        if (attempt >= 3 || signal?.aborted) throw e; // «повторить» resumes from this part
        await new Promise((r) => setTimeout(r, attempt * 2_000));
      }
    }
    sent += blob.size;
    onProgress(Math.min(1, sent / f.size));
  }
  const done = new FormData();
  if (p.thumb) done.set('thumb', p.thumb, 'thumb.jpg');
  await api.upload(`/chat/uploads/${start.uploadId}/complete`, done);
}

/**
 * Photos and videos full screen, like in Telegram: the preview at once, the full photo over it; ← → (keys, buttons or a
 * swipe) to the neighbours; Esc, ✕ or a swipe down closes. A video plays while it downloads (the server answers byte ranges).
 */
export function MediaViewer({ items, start, onClose, protect = false }: { items: ChatMessage[]; start: ChatMessage; onClose: () => void; protect?: boolean }) {
  const list = items.length ? items : [start];
  const [i, setI] = useState(() => Math.max(0, list.findIndex((m) => m.id === start.id)));
  const [full, setFull] = useState<Record<string, boolean>>({});
  /** a drag like Telegram: up / down follows the finger (or mouse) and closes past ~100px; sideways flips photos */
  const drag = useRef<{ x: number; y: number; id: number; moved: boolean } | null>(null);
  const [dy, setDy] = useState(0);
  const dragged = useRef(false);
  const m = list[i];
  const f = m.file!;
  const go = (d: number) => setI((x) => Math.min(list.length - 1, Math.max(0, x + d)));
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); if (e.key === 'ArrowLeft') go(-1); if (e.key === 'ArrowRight') go(1); };
    document.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', onKey); document.body.style.overflow = prev; };
  });
  return (
    <div
      role="dialog" aria-modal="true" aria-label="Просмотр"
      className="fixed inset-0 z-[60] flex touch-none select-none flex-col text-white"
      style={{ backgroundColor: `rgba(0,0,0,${Math.max(0.35, 1 - Math.abs(dy) / 500)})` }}
      onPointerDown={(e) => {
        if (e.button !== 0 || (e.target as HTMLElement).closest('button,a')) return;
        drag.current = { x: e.clientX, y: e.clientY, id: e.pointerId, moved: false };
        dragged.current = false;
      }}
      onPointerMove={(e) => {
        const d = drag.current;
        if (!d || d.id !== e.pointerId) return;
        const mx = e.clientX - d.x; const my = e.clientY - d.y;
        if (!d.moved && Math.abs(my) > 12 && Math.abs(my) > Math.abs(mx)) d.moved = true;
        if (d.moved) setDy(my);
      }}
      onPointerUp={(e) => {
        const d = drag.current; drag.current = null;
        if (!d) return;
        const mx = e.clientX - d.x; const my = e.clientY - d.y;
        if (d.moved) { dragged.current = true; if (Math.abs(my) > 100) onClose(); else setDy(0); return; }
        if (Math.abs(mx) > 60 && Math.abs(mx) > Math.abs(my) && m.kind !== 'VIDEO') { dragged.current = true; go(mx < 0 ? 1 : -1); }
      }}
      onPointerCancel={() => { drag.current = null; setDy(0); }}
    >
      <div className="flex items-center gap-3 p-3">
        <button aria-label="Закрыть" onClick={onClose} className="rounded-full p-2 hover:bg-white/10"><X size={22} aria-hidden /></button>
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{m.sender?.fullName}</p>
          {list.length > 1 && <p className="text-xs text-white/70">{i + 1} / {list.length}</p>}
        </div>
        {!protect && <a href={f.url} download={f.name ?? undefined} aria-label="Скачать" className="rounded-full p-2 hover:bg-white/10"><Download size={20} aria-hidden /></a>}
      </div>
      {/* a click on the dark area around the photo / video closes, like Telegram */}
      <div className="relative flex min-h-0 flex-1 items-center justify-center" onClick={(e) => { if (dragged.current) { dragged.current = false; return; } if (e.target === e.currentTarget) onClose(); }}
        style={{ transform: `translateY(${dy}px)`, transition: drag.current ? 'none' : 'transform 0.2s' }}>
        {i > 0 && <button aria-label="Предыдущее" onClick={() => go(-1)} className="absolute left-2 z-10 hidden rounded-full bg-white/10 p-2 hover:bg-white/20 sm:block"><ChevronLeft size={28} aria-hidden /></button>}
        {m.kind === 'VIDEO' ? (
          <video key={m.id} src={f.url} poster={f.thumbUrl ?? undefined} controls autoPlay playsInline preload="auto" className="max-h-full max-w-full touch-auto" draggable={false} />
        ) : (
          <div className="relative flex max-h-full max-w-full items-center justify-center">
            {!full[m.id] && f.thumbUrl && <img src={f.thumbUrl} alt="" className="max-h-[80vh] max-w-full scale-100 object-contain blur-[1px]" />}
            <img key={m.id} draggable={false} src={f.url} alt={m.text ?? 'Фото'} onLoad={() => setFull((x) => ({ ...x, [m.id]: true }))}
              className={`max-h-[80vh] max-w-full object-contain ${full[m.id] ? '' : 'absolute inset-0 m-auto opacity-0'}`} />
          </div>
        )}
        {i < list.length - 1 && <button aria-label="Следующее" onClick={() => go(1)} className="absolute right-2 z-10 hidden rounded-full bg-white/10 p-2 hover:bg-white/20 sm:block"><ChevronRight size={28} aria-hidden /></button>}
      </div>
      {m.text && <p className="bg-black/60 p-3 text-sm">{m.text}</p>}
    </div>
  );
}
