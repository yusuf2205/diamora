'use client';

import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Check, CheckCheck, Download, FileText, Info, Mic, Paperclip, Plus, Send, Trash2, Users, X } from 'lucide-react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { errorMessage, initials, roleLabel } from '@/lib/format';
import { Button, ErrorState, Input, Modal, Spinner } from '@/components/ui';

// ---- types (GET /v1/chat/...) ------------------------------------------------------------------------------------------
export interface ChatPerson { id: string; fullName: string; role: string; online?: boolean; isOwner?: boolean; lastReadAt?: string | null }
export interface ChatFile { url: string; thumbUrl: string | null; name: string | null; size: number | null; mimeType: string | null; durationMs: number | null; width: number | null; height: number | null }
export interface ChatMessage { id: string; roomId: string; kind: 'TEXT' | 'IMAGE' | 'VIDEO' | 'VOICE' | 'AUDIO' | 'FILE'; sender: ChatPerson | null; text: string | null; file: ChatFile | null; deleted: boolean; createdAt: string; clientId: string | null }
export interface ChatRoomSummary { id: string; kind: 'DIRECT' | 'GROUP' | 'COMPANY'; title: string | null; peer: ChatPerson | null; memberCount: number; isOwner: boolean; unread: number; lastMessage: ChatMessage | null; lastMessageAt: string }
export interface ChatRoomDetail { id: string; kind: ChatRoomSummary['kind']; title: string | null; isOwner: boolean; canManage: boolean; memberCount: number; peer: ChatPerson | null; members: ChatPerson[] }

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

/** The unread count for the menu badge (refetched by the live socket like everything else). */
export function useChatUnread(enabled = true) {
  return useQuery({ queryKey: ['chat-unread'], queryFn: () => api.get<{ count: number }>('/chat/unread'), enabled, staleTime: 10_000 }).data?.count ?? 0;
}

function Avatar({ kind, name, online, size = 40 }: { kind: string; name: string; online?: boolean; size?: number }) {
  const cls = kind === 'COMPANY' ? 'bg-primary text-white' : kind === 'GROUP' ? 'bg-amber-100 text-amber-800' : 'bg-primary/15 text-primary';
  return (
    <span className="relative inline-flex shrink-0">
      <span className={`flex items-center justify-center rounded-full font-semibold ${cls}`} style={{ width: size, height: size, fontSize: size * 0.36 }}>
        {kind === 'COMPANY' ? '💎' : kind === 'GROUP' ? <Users size={size * 0.5} aria-hidden /> : initials(name)}
      </span>
      {online && <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-card bg-ok" aria-label="в сети" />}
    </span>
  );
}

// ---- the whole chat: list + conversation (side by side on a wide screen, one at a time on a phone) ------------------------
export function ChatApp() {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const roomId = params.get('room');
  const open = (id: string | null) => router.push(id ? `${pathname}?room=${id}` : pathname);
  return (
    <div className="flex h-[calc(100dvh-9rem)] min-h-[420px] overflow-hidden rounded-xl border border-border bg-card lg:h-[calc(100vh-4rem)]">
      <div className={`${roomId ? 'hidden md:flex' : 'flex'} w-full flex-col border-r border-border md:w-80 md:shrink-0`}>
        <RoomList selected={roomId} onOpen={open} />
      </div>
      <div className={`${roomId ? 'flex' : 'hidden md:flex'} min-w-0 flex-1 flex-col`}>
        {roomId ? <Conversation key={roomId} roomId={roomId} onBack={() => open(null)} /> : <div className="m-auto p-6 text-center text-muted">Выберите чат слева</div>}
      </div>
    </div>
  );
}

function RoomList({ selected, onOpen }: { selected: string | null; onOpen: (id: string) => void }) {
  const { me } = useAuth();
  const q = useQuery({ queryKey: ['chat-rooms'], queryFn: () => api.get<{ items: ChatRoomSummary[] }>('/chat/rooms') });
  const [creating, setCreating] = useState(false);
  return (
    <>
      <div className="flex items-center justify-between gap-2 border-b border-border px-4 py-3">
        <h2 className="text-lg font-semibold">Чат</h2>
        <Button className="min-h-9 px-3 py-1.5 text-sm" onClick={() => setCreating(true)}><Plus size={16} aria-hidden /> Новый чат</Button>
      </div>
      <div className="flex-1 overflow-y-auto">
        {q.isLoading && <div className="flex justify-center p-6"><Spinner /></div>}
        {q.isError && <div className="p-3"><ErrorState error={q.error} onRetry={() => q.refetch()} /></div>}
        {q.data?.items.map((r) => {
          const last = r.lastMessage;
          const who = !last || r.kind === 'DIRECT' || !last.sender ? '' : last.sender.id === me?.id ? 'Вы: ' : `${last.sender.fullName.split(' ')[0]}: `;
          const sub = last ? `${who}${chatPreview(last)}` : r.kind === 'COMPANY' ? 'Все сотрудники и мастерицы' : `Участников: ${r.memberCount}`;
          return (
            <button
              key={r.id}
              onClick={() => onOpen(r.id)}
              className={`flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-border/40 ${selected === r.id ? 'bg-primary/10' : ''}`}
            >
              <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} />
              <span className="min-w-0 flex-1">
                <span className="flex items-baseline justify-between gap-2">
                  <span className={`truncate ${r.unread ? 'font-bold' : 'font-medium'}`}>{chatTitle(r)}</span>
                  {last && <span className={`shrink-0 text-xs ${r.unread ? 'text-primary' : 'text-muted'}`}>{chatWhen(last.createdAt)}</span>}
                </span>
                <span className="flex items-center justify-between gap-2">
                  <span className="truncate text-sm text-muted">{sub}</span>
                  {r.unread > 0 && <span className="shrink-0 rounded-full bg-primary px-2 text-xs font-bold text-white">{r.unread}</span>}
                </span>
              </span>
            </button>
          );
        })}
      </div>
      {creating && <NewChatModal onClose={() => setCreating(false)} onOpen={(id) => { setCreating(false); onOpen(id); }} />}
    </>
  );
}

/** «Новый чат»: one person (a direct chat) or several with a name (a group). With `pick` it only returns the chosen ids. */
function NewChatModal({ onClose, onOpen, pick, exclude = [] }: { onClose: () => void; onOpen?: (id: string) => void; pick?: (ids: string[]) => void; exclude?: string[] }) {
  const qc = useQueryClient();
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
        <button className="mb-3 text-sm font-medium text-primary underline" onClick={() => { setGroup(!group); setTicked([]); }}>
          {group ? 'Написать одному человеку' : 'Создать группу'}
        </button>
      )}
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

interface Pending { clientId: string; kind: ChatMessage['kind']; text?: string; file?: File; durationMs?: number; progress: number; failed: boolean; createdAt: string }

function Conversation({ roomId, onBack }: { roomId: string; onBack: () => void }) {
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
  const [text, setText] = useState('');
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
        form.set('file', p.file, p.file.name);
        await api.upload(`/chat/rooms/${roomId}/files`, form);
      } else {
        await api.post(`/chat/rooms/${roomId}/messages`, { text: p.text, clientId: p.clientId });
      }
      await qc.invalidateQueries({ queryKey: ['chat-msgs', roomId] });
      setPending((xs) => xs.filter((x) => x.clientId !== p.clientId));
    } catch (e) {
      setPending((xs) => xs.map((x) => (x.clientId === p.clientId ? { ...x, failed: true } : x)));
      setError(errorMessage(e));
    }
  };
  const queue = (p: Omit<Pending, 'clientId' | 'progress' | 'failed' | 'createdAt'>) => {
    const item: Pending = { ...p, clientId: newId(), progress: 0, failed: false, createdAt: new Date().toISOString() };
    setPending((xs) => [...xs, item]);
    void send(item);
  };
  const sendText = () => {
    const t = text.trim();
    if (!t) return;
    setText('');
    queue({ kind: 'TEXT', text: t });
  };
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
  const subtitle = !r ? '' : r.kind === 'DIRECT' ? (r.peer?.online ? 'в сети' : r.peer ? roleLabel(r.peer.role) : '') : `Участников: ${r.memberCount}`;
  const peerRead = r?.peer?.lastReadAt ? new Date(r.peer.lastReadAt).getTime() : 0;

  return (
    <>
      <div className="flex items-center gap-3 border-b border-border px-3 py-2.5">
        <button aria-label="Назад" className="rounded-lg p-1.5 hover:bg-border/50 md:hidden" onClick={onBack}><ArrowLeft size={20} aria-hidden /></button>
        {r && <Avatar kind={r.kind} name={chatTitle(r)} online={r.peer?.online} size={36} />}
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{r ? chatTitle(r) : ''}</p>
          <p className="truncate text-xs text-muted">{subtitle}</p>
        </div>
        {r?.kind === 'GROUP' && <button aria-label="О группе" className="rounded-lg p-2 hover:bg-border/50" onClick={() => setInfo(true)}><Info size={20} aria-hidden /></button>}
      </div>

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
      <div className="flex items-end gap-2 border-t border-border p-2 pb-[max(0.5rem,env(safe-area-inset-bottom))]">
        <input ref={fileInput} type="file" multiple className="hidden" aria-label="Файлы" onChange={(e) => sendFiles(e.target.files)} />
        <button aria-label="Прикрепить" title="Фото, видео, файл" className="rounded-full p-2.5 hover:bg-border/50" onClick={() => fileInput.current?.click()}><Paperclip size={20} aria-hidden /></button>
        <textarea
          aria-label="Сообщение"
          placeholder="Сообщение"
          rows={1}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendText(); } }}
          className="max-h-40 min-h-10 flex-1 resize-none rounded-2xl border border-border bg-background px-4 py-2.5 outline-none focus:border-primary"
        />
        {text.trim()
          ? <button aria-label="Отправить" className="rounded-full bg-primary p-2.5 text-white" onClick={sendText}><Send size={20} aria-hidden /></button>
          : <VoiceButton onRecorded={(file, durationMs) => queue({ kind: 'VOICE', file, durationMs })} onError={setError} />}
      </div>
      {info && r && <GroupInfo room={r} onClose={() => setInfo(false)} onLeft={() => { setInfo(false); onBack(); }} />}
    </>
  );
}

function Bubble({ m, mine, showSender, read, onDelete }: { m: ChatMessage; mine: boolean; showSender: boolean; read: boolean; onDelete?: () => void }) {
  const t = new Date(m.createdAt);
  const f = m.file;
  return (
    <div className={`group my-1 flex ${mine ? 'justify-end' : 'justify-start'}`}>
      <div className={`relative max-w-[80%] rounded-2xl px-3 py-2 ${mine ? 'rounded-br-md bg-primary/15' : 'rounded-bl-md bg-card shadow-sm ring-1 ring-border'}`}>
        {showSender && m.sender && <p className="mb-0.5 text-xs font-bold text-primary">{m.sender.fullName}</p>}
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
            {m.text && <p className={`whitespace-pre-wrap break-words ${f ? 'mt-1' : ''}`}>{m.text}</p>}
          </>
        )}
        <p className="mt-0.5 flex items-center justify-end gap-1 text-[11px] text-muted">
          {two(t.getHours())}:{two(t.getMinutes())}
          {mine && !m.deleted && (read ? <CheckCheck size={14} className="text-primary" aria-label="Прочитано" /> : <Check size={14} aria-hidden />)}
        </p>
        {onDelete && (
          <button aria-label="Удалить сообщение" onClick={onDelete} className="absolute -top-2 right-1 hidden rounded-full bg-card p-1 text-danger shadow ring-1 ring-border group-hover:block">
            <Trash2 size={14} aria-hidden />
          </button>
        )}
      </div>
    </div>
  );
}

/** Click to start recording, click again to send (a browser has no «hold»); the microphone permission is asked once. */
function VoiceButton({ onRecorded, onError }: { onRecorded: (f: File, durationMs: number) => void; onError: (m: string) => void }) {
  const [rec, setRec] = useState<{ r: MediaRecorder; started: number } | null>(null);
  const [, tick] = useState(0);
  useEffect(() => {
    if (!rec) return;
    const id = setInterval(() => tick((x) => x + 1), 500);
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

function GroupInfo({ room, onClose, onLeft }: { room: ChatRoomDetail; onClose: () => void; onLeft: () => void }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState(room.title ?? '');
  const refresh = () => { qc.invalidateQueries({ queryKey: ['chat-room', room.id] }); qc.invalidateQueries({ queryKey: ['chat-rooms'] }); };
  const update = useMutation({ mutationFn: (b: { title?: string; addIds?: string[]; removeIds?: string[] }) => api.patch(`/chat/rooms/${room.id}`, b), onSuccess: refresh });
  const leave = useMutation({ mutationFn: () => api.post(`/chat/rooms/${room.id}/leave`), onSuccess: () => { refresh(); onLeft(); } });
  return (
    <Modal title="О группе" onClose={onClose}>
      {room.canManage ? (
        <div className="mb-3 flex gap-2">
          <Input aria-label="Название группы" value={title} onChange={(e) => setTitle(e.target.value)} />
          <Button variant="outline" disabled={!title.trim() || title === room.title || update.isPending} onClick={() => update.mutate({ title: title.trim() })}>Сохранить</Button>
        </div>
      ) : <p className="mb-3 font-semibold">{room.title}</p>}
      <p className="mb-2 text-sm text-muted">Участников: {room.memberCount}</p>
      {room.canManage && <Button variant="outline" className="mb-2 w-full" onClick={() => setAdding(true)}><Plus size={16} aria-hidden /> Добавить участников</Button>}
      <ul className="max-h-[40vh] space-y-1 overflow-y-auto">
        {room.members.map((m) => (
          <li key={m.id} className="flex items-center gap-3 rounded-lg px-1 py-1.5">
            <Avatar kind="DIRECT" name={m.fullName} online={m.online} size={32} />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-medium">{m.fullName}{m.id === me?.id ? ' (вы)' : ''}</span>
              <span className="block text-xs text-muted">{roleLabel(m.role)}{m.isOwner ? ' · создатель' : ''}</span>
            </span>
            {room.canManage && m.id !== me?.id && (
              <button aria-label={`Убрать ${m.fullName}`} className="rounded p-1 text-danger hover:bg-danger/10" onClick={() => update.mutate({ removeIds: [m.id] })}><X size={16} aria-hidden /></button>
            )}
          </li>
        ))}
      </ul>
      {(update.isError || leave.isError) && <div className="mt-2"><ErrorState error={update.error ?? leave.error} /></div>}
      <Button variant="danger" className="mt-4 w-full" onClick={() => { if (confirm('Выйти из группы? Вы больше не будете видеть её сообщения.')) leave.mutate(); }}>Выйти из группы</Button>
      {adding && (
        <NewChatModal
          onClose={() => setAdding(false)}
          exclude={room.members.map((m) => m.id)}
          pick={(ids) => { setAdding(false); update.mutate({ addIds: ids }); }}
        />
      )}
    </Modal>
  );
}
