'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AtSign, Bell, BellOff, Camera, Image as ImageIcon, Link2, Megaphone, MessageCircle, Mic, Moon, Music, Pause, Phone, Play, User, Users, Video, FileText, X } from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { errorMessage, initials, roleLabel } from '@/lib/format';
import { Button, ErrorState, Input, Modal, Spinner } from '@/components/ui';

// ---- theme («Ночной режим») ------------------------------------------------------------------------------------------------
export type ThemeMode = 'light' | 'dark' | 'system';
const THEME_KEY = 'diamoraa-theme';
export function readTheme(): ThemeMode {
  try { return (localStorage.getItem(THEME_KEY) as ThemeMode) || 'system'; } catch { return 'system'; }
}
export function applyTheme(mode: ThemeMode) {
  if (typeof document === 'undefined') return;
  if (mode === 'system') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', mode);
  try { localStorage.setItem(THEME_KEY, mode); } catch { /* private mode */ }
}
export function isDark(): boolean {
  if (typeof document === 'undefined') return false;
  const t = document.documentElement.getAttribute('data-theme');
  if (t) return t === 'dark';
  return typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: dark)').matches;
}

// ---- wallpapers («Установить обои») ------------------------------------------------------------------------------------------
export const WALLPAPERS: Record<string, { label: string; css: string }> = {
  none: { label: 'Без обоев', css: '' },
  rose: { label: 'Розовый', css: 'linear-gradient(135deg,#fde2e7 0%,#f6c9d4 50%,#fbe7ec 100%)' },
  mint: { label: 'Мята', css: 'linear-gradient(135deg,#d9f2e6 0%,#b8e6cf 50%,#e6f7ee 100%)' },
  sky: { label: 'Небо', css: 'linear-gradient(135deg,#dbeafe 0%,#bfdbfe 50%,#e0f2fe 100%)' },
  sand: { label: 'Песок', css: 'linear-gradient(135deg,#f5ecd9 0%,#ead7b5 50%,#f8f1e3 100%)' },
  night: { label: 'Ночь', css: 'linear-gradient(135deg,#1f1b2e 0%,#2d2440 50%,#1a1726 100%)' },
};
export function useWallpaper(roomId: string): [string, (k: string) => void] {
  const key = `chat-wallpaper-${roomId}`;
  const [w, setW] = useState('none');
  useEffect(() => { try { setW(localStorage.getItem(key) ?? localStorage.getItem('chat-wallpaper') ?? 'none'); } catch { /* ignore */ } }, [key]);
  return [w, (k: string) => { setW(k); try { localStorage.setItem(key, k); } catch { /* ignore */ } }];
}

// ---- voice: waveform recorder + a Telegram-like player ------------------------------------------------------------------
/** Records loudness while the microphone is on; `finish()` gives 48 bars 0-31 (sent with the voice message). */
export function waveformRecorder(stream: MediaStream) {
  const samples: number[] = [];
  let ctx: AudioContext | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;
  try {
    const AC = (window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext)!;
    ctx = new AC();
    const src = ctx.createMediaStreamSource(stream);
    const an = ctx.createAnalyser();
    an.fftSize = 512;
    src.connect(an);
    const buf = new Uint8Array(an.fftSize);
    timer = setInterval(() => {
      an.getByteTimeDomainData(buf);
      let peak = 0;
      for (const v of buf) peak = Math.max(peak, Math.abs(v - 128));
      samples.push(peak / 128);
    }, 60);
  } catch { /* no Web Audio: bars are made up from the id */ }
  return {
    finish(): string | undefined {
      if (timer) clearInterval(timer);
      void ctx?.close().catch(() => undefined);
      if (samples.length < 4) return undefined;
      return toBars(samples, 48).join(',');
    },
  };
}
export function toBars(samples: number[], n: number): number[] {
  const out: number[] = [];
  const max = Math.max(0.05, ...samples);
  for (let i = 0; i < n; i++) {
    const from = Math.floor((i * samples.length) / n);
    const to = Math.max(from + 1, Math.floor(((i + 1) * samples.length) / n));
    let peak = 0;
    for (let j = from; j < to; j++) peak = Math.max(peak, samples[j] ?? 0);
    out.push(Math.max(1, Math.round((peak / max) * 31)));
  }
  return out;
}
/** Bars for a message: its recorded waveform, or a stable pattern from its id (uploaded audio has none). */
export function barsOf(waveform: string | null | undefined, id: string, n = 48): number[] {
  if (waveform) {
    const v = waveform.split(',').map((x) => Math.min(31, Math.max(1, Number(x) || 1)));
    return v.length >= n ? v.slice(0, n) : [...v, ...Array(n - v.length).fill(1)];
  }
  let h = 2166136261;
  for (const c of id) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return Array.from({ length: n }, (_, i) => { h = Math.imul(h ^ i, 16777619); return 6 + (Math.abs(h) % 22); });
}
const fmt = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const kb = (b: number | null | undefined) => (b == null ? '' : b < 1024 * 1024 ? `${(b / 1024).toFixed(1)} KB` : `${(b / 1024 / 1024).toFixed(1)} MB`);

/** ▶ + waveform (played part filled, click to seek) + «00:02, 8.8 KB» - streams, no waiting for the whole file. */
export function VoicePlayer({ id, url, waveform, durationMs, size, name, mine }: { id: string; url: string; waveform?: string | null; durationMs?: number | null; size?: number | null; name?: string | null; mine: boolean }) {
  const audio = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [pos, setPos] = useState(0);
  const [len, setLen] = useState((durationMs ?? 0) / 1000);
  const bars = barsOf(waveform, id);
  const played = len > 0 ? pos / len : 0;
  const toggle = () => { const a = audio.current; if (!a) return; if (a.paused) void a.play(); else a.pause(); };
  const seek = (e: React.MouseEvent<HTMLDivElement>) => {
    const a = audio.current; if (!a || !len) return;
    const r = e.currentTarget.getBoundingClientRect();
    a.currentTime = ((e.clientX - r.left) / r.width) * len;
    if (a.paused) void a.play();
  };
  const accent = mine ? 'bg-primary' : 'bg-primary';
  return (
    <div className="flex w-72 max-w-full items-center gap-3 py-1">
      <audio ref={audio} src={url} preload="none"
        onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onEnded={() => { setPlaying(false); setPos(0); }}
        onTimeUpdate={(e) => setPos(e.currentTarget.currentTime)}
        onLoadedMetadata={(e) => { if (Number.isFinite(e.currentTarget.duration)) setLen(e.currentTarget.duration); }} />
      <button aria-label={playing ? 'Пауза' : 'Слушать'} onClick={toggle} className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${accent} text-white shadow`}>
        {playing ? <Pause size={20} aria-hidden /> : <Play size={20} className="ml-0.5" aria-hidden />}
      </button>
      <div className="min-w-0 flex-1">
        {name && <p className="mb-0.5 truncate text-sm font-medium">{name}</p>}
        <div className="flex h-7 cursor-pointer items-center gap-[2px]" onClick={seek} role="slider" aria-label="Перемотка" aria-valuemin={0} aria-valuemax={Math.round(len)} aria-valuenow={Math.round(pos)}>
          {bars.map((b, i) => (
            <span key={i} className={`w-[3px] rounded-full ${i / bars.length <= played ? 'bg-primary' : 'bg-primary/35'}`} style={{ height: `${Math.max(3, (b / 31) * 26)}px` }} />
          ))}
        </div>
        <p className="mt-0.5 text-xs text-muted">{fmt(playing || pos > 0 ? pos : len)}{size ? `, ${kb(size)}` : ''}</p>
      </div>
    </div>
  );
}

// ---- a floating menu at the cursor (right click) ---------------------------------------------------------------------------
export function FloatingMenu({ x, y, onClose, children }: { x: number; y: number; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ left: x, top: y });
  useEffect(() => {
    const el = ref.current;
    if (el) {
      const w = el.offsetWidth; const h = el.offsetHeight;
      setPos({ left: Math.max(8, Math.min(x, window.innerWidth - w - 8)), top: Math.max(8, Math.min(y, window.innerHeight - h - 8)) });
    }
    const close = (e: Event) => { if (ref.current && !ref.current.contains(e.target as Node)) onClose(); };
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', esc);
    window.addEventListener('resize', onClose);
    return () => { document.removeEventListener('mousedown', close); document.removeEventListener('keydown', esc); window.removeEventListener('resize', onClose); };
  }, [x, y, onClose]);
  return (
    <div ref={ref} role="menu" className="fixed z-[70] min-w-60 overflow-hidden rounded-xl border border-border bg-card py-1 text-sm shadow-2xl" style={pos}>
      {children}
    </div>
  );
}
export function MenuItem({ icon, label, onClick, danger }: { icon: ReactNode; label: string; onClick: () => void; danger?: boolean }) {
  return (
    <button role="menuitem" onClick={onClick} className={`flex w-full items-center gap-3 px-4 py-2 text-left hover:bg-border/50 ${danger ? 'text-danger' : ''}`}>
      <span className="flex w-5 justify-center">{icon}</span>{label}
    </button>
  );
}

// ---- people cards ---------------------------------------------------------------------------------------------------------
export function PersonAvatar({ name, photo, size = 40, online }: { name: string; photo?: string | null; size?: number; online?: boolean }) {
  return (
    <span className="relative inline-flex shrink-0">
      {photo
        ? <img src={photo} alt="" className="rounded-full object-cover" style={{ width: size, height: size }} />
        : <span className="flex items-center justify-center rounded-full bg-primary/15 font-semibold text-primary" style={{ width: size, height: size, fontSize: size * 0.36 }}>{initials(name)}</span>}
      {online && <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-card bg-ok" aria-label="в сети" />}
    </span>
  );
}

interface Profile {
  id: string; fullName: string; role: string; online: boolean; lastSeenAt: string | null; avatar: string | null; avatarFull: string | null;
  username: string | null; bio: string | null; phone: string | null; active: boolean; directRoomId: string | null;
  counts: { photos: number; videos: number; files: number; audio: number; voice: number; links: number } | null;
}
const seen = (p: { online: boolean; lastSeenAt: string | null }) => {
  if (p.online) return 'в сети';
  if (!p.lastSeenAt) return 'был(а) недавно';
  const t = new Date(p.lastSeenAt); const two = (v: number) => String(v).padStart(2, '0');
  return t.toDateString() === new Date().toDateString() ? `был(а) в сети в ${two(t.getHours())}:${two(t.getMinutes())}` : `был(а) в сети ${two(t.getDate())}.${two(t.getMonth() + 1)}`;
};
const plural = (n: number, one: string, few: string, many: string) => {
  const m10 = n % 10; const m100 = n % 100;
  return `${n} ${m10 === 1 && m100 !== 11 ? one : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? few : many}`;
};

/** «Информация» about a person, like Telegram's right panel: photo, status, phone (staff), @username, «о себе», counts. */
export function ProfileCard({ userId, muted, onToggleMute, onOpenTab, onChat }: {
  userId: string; muted?: boolean; onToggleMute?: () => void; onOpenTab?: (tab: 'media' | 'files' | 'voice' | 'links') => void; onChat?: () => void;
}) {
  const q = useQuery({ queryKey: ['chat-profile', userId], queryFn: () => api.get<Profile>(`/chat/users/${userId}`) });
  const [big, setBig] = useState(false);
  if (q.isLoading) return <div className="flex justify-center p-8"><Spinner /></div>;
  if (q.isError || !q.data) return <div className="p-4"><ErrorState error={q.error} /></div>;
  const p = q.data;
  const c = p.counts;
  const rows: [ReactNode, string, 'media' | 'files' | 'voice' | 'links'][] = c ? [
    [<ImageIcon key="i" size={18} aria-hidden />, plural(c.photos, 'фотография', 'фотографии', 'фотографий'), 'media'],
    [<Video key="v" size={18} aria-hidden />, plural(c.videos, 'видео', 'видео', 'видео'), 'media'],
    [<FileText key="f" size={18} aria-hidden />, plural(c.files, 'файл', 'файла', 'файлов'), 'files'],
    [<Music key="a" size={18} aria-hidden />, plural(c.audio, 'аудиофайл', 'аудиофайла', 'аудиофайлов'), 'files'],
    [<Link2 key="l" size={18} aria-hidden />, plural(c.links, 'ссылка', 'ссылки', 'ссылок'), 'links'],
    [<Mic key="m" size={18} aria-hidden />, plural(c.voice, 'голосовое сообщение', 'голосовых сообщения', 'голосовых сообщений'), 'voice'],
  ] : [];
  return (
    <div>
      <div className="flex flex-col items-center gap-1 bg-border/30 px-4 py-5 text-center">
        <button onClick={() => p.avatarFull && setBig(true)} aria-label="Фото профиля"><PersonAvatar name={p.fullName} photo={p.avatar} size={96} /></button>
        <p className="mt-2 text-lg font-semibold">{p.fullName}</p>
        <p className={`text-sm ${p.online ? 'text-primary' : 'text-muted'}`}>{seen(p)}</p>
        <div className="mt-3 flex gap-2">
          {onChat && <ActionTile icon={<MessageCircle size={20} aria-hidden />} label="Чат" onClick={onChat} />}
          {onToggleMute && <ActionTile icon={muted ? <BellOff size={20} aria-hidden /> : <Bell size={20} aria-hidden />} label={muted ? 'Без звука' : 'Звук'} onClick={onToggleMute} />}
        </div>
      </div>
      <div className="divide-y divide-border/60 px-4">
        {p.phone && <InfoRow icon={<Phone size={18} aria-hidden />} value={<a href={`tel:${p.phone}`} className="hover:underline">{p.phone}</a>} label="Телефон" />}
        {p.username && <InfoRow icon={<AtSign size={18} aria-hidden />} value={<span className="text-primary">@{p.username}</span>} label="Имя пользователя" />}
        {p.bio && <InfoRow icon={<User size={18} aria-hidden />} value={p.bio} label="О себе" />}
        <InfoRow icon={<Users size={18} aria-hidden />} value={roleLabel(p.role)} label="Роль" />
      </div>
      {rows.length > 0 && (
        <div className="mt-2 border-t-8 border-border/30 py-1">
          {rows.map(([icon, text, tab]) => (
            <button key={text} onClick={() => onOpenTab?.(tab)} className="flex w-full items-center gap-4 px-5 py-2.5 text-left text-sm hover:bg-border/40">
              <span className="text-muted">{icon}</span>{text}
            </button>
          ))}
        </div>
      )}
      {big && p.avatarFull && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/90" onClick={() => setBig(false)} role="dialog" aria-label="Фото профиля">
          <img src={p.avatarFull} alt="" className="max-h-[85vh] max-w-[92vw] rounded-lg" />
        </div>
      )}
    </div>
  );
}
function ActionTile({ icon, label, onClick }: { icon: ReactNode; label: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="flex w-24 flex-col items-center gap-1 rounded-xl border border-border bg-card px-3 py-2 text-xs hover:bg-border/40">
      <span className="text-primary">{icon}</span>{label}
    </button>
  );
}
function InfoRow({ icon, value, label, onClick }: { icon: ReactNode; value: ReactNode; label: string; onClick?: () => void }) {
  return (
    <div className={`flex items-center gap-4 py-2.5 ${onClick ? 'cursor-pointer' : ''}`} onClick={onClick}>
      <span className="text-muted">{icon}</span>
      <span className="min-w-0 flex-1"><span className="block break-words">{value}</span><span className="block text-xs text-muted">{label}</span></span>
    </div>
  );
}

/** «Мой профиль», like Telegram's «Информация»: photo (tap the camera), status, «о себе» (140), name, phone, @username. */
export function MyProfileModal({ onClose }: { onClose: () => void }) {
  const qc = useQueryClient();
  const { me } = useAuth();
  const m = me as (typeof me & { avatar?: { thumbUrl: string; url: string } | null; bio?: string | null; username?: string | null }) | undefined;
  const [bio, setBio] = useState(m?.bio ?? '');
  const [name, setName] = useState(m?.fullName ?? '');
  const [username, setUsername] = useState(m?.username ?? '');
  const [saved, setSaved] = useState(false);
  const refresh = () => qc.invalidateQueries({ queryKey: ['me'] });
  const save = useMutation({
    mutationFn: () => api.patch('/auth/me', { fullName: name.trim() || undefined, bio: bio.trim() || null, username: username.trim() || '' }),
    onSuccess: () => { setSaved(true); void refresh(); },
  });
  const photo = useMutation({
    mutationFn: (f: File) => { const form = new FormData(); form.set('file', f, f.name); return api.upload('/auth/me/avatar', form); },
    onSuccess: refresh,
  });
  if (!m) return null;
  return (
    <Modal title="Информация" onClose={onClose}>
      <div className="flex flex-col items-center">
        <label className="relative cursor-pointer" aria-label="Сменить фото профиля">
          <PersonAvatar name={m.fullName} photo={m.avatar?.thumbUrl} size={104} />
          <span className="absolute bottom-0 right-0 flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white ring-4 ring-card">{photo.isPending ? <Spinner /> : <Camera size={18} aria-hidden />}</span>
          <input type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) photo.mutate(f); }} />
        </label>
        <p className="mt-2 text-lg font-semibold">{m.fullName}</p>
        <p className="text-sm text-primary">в сети</p>
      </div>
      <div className="mt-4 space-y-3">
        <div>
          <div className="flex items-center gap-2">
            <Input aria-label="О себе" placeholder="О себе" maxLength={140} value={bio} onChange={(e) => { setSaved(false); setBio(e.target.value); }} />
            <span className="w-8 text-right text-xs text-muted">{140 - bio.length}</span>
          </div>
          <p className="mt-1 text-xs text-muted">Любые подробности, например: должность, район или график работы.</p>
        </div>
        <label className="block text-sm"><span className="text-muted">Имя</span><Input aria-label="Имя" value={name} onChange={(e) => { setSaved(false); setName(e.target.value); }} /></label>
        <div className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm"><span className="text-muted">Номер телефона</span><span>{m.phone}</span></div>
        <label className="block text-sm">
          <span className="text-muted">Имя пользователя</span>
          <div className="flex items-center gap-1"><span className="text-muted">@</span><Input aria-label="Имя пользователя" placeholder="username" value={username} onChange={(e) => { setSaved(false); setUsername(e.target.value); }} /></div>
          <span className="mt-1 block text-xs text-muted">Латиница, цифры и _, от 5 символов. По нему вас найдут в чате.</span>
        </label>
        {(save.isError || photo.isError) && <p className="text-sm text-danger">{errorMessage(save.error ?? photo.error)}</p>}
        {saved && <p className="text-sm text-ok" role="status">✓ Сохранено</p>}
        <Button className="w-full" disabled={save.isPending} onClick={() => save.mutate()}>Сохранить</Button>
        {m.avatar && <button className="w-full text-sm text-danger" onClick={() => api.delete('/auth/me/avatar').then(refresh)}>Удалить фото</button>}
      </div>
    </Modal>
  );
}

/** Telegram's ☰ menu of the chat: me, «Создать группу», «Создать канал», «Контакты», «Ночной режим», «Свернуть список». */
export function ChatMainMenu({ onClose, onProfile, onGroup, onChannel, onContacts, collapsed, onCollapse }: {
  onClose: () => void; onProfile: () => void; onGroup: () => void; onChannel?: () => void; onContacts: () => void; collapsed: boolean; onCollapse: () => void;
}) {
  const { me } = useAuth();
  const m = me as (typeof me & { avatar?: { thumbUrl: string } | null; username?: string | null }) | undefined;
  const [dark, setDark] = useState(isDark());
  const item = (icon: ReactNode, label: string, go: () => void) => (
    <button onClick={() => { onClose(); go(); }} className="flex w-full items-center gap-4 px-5 py-2.5 text-left text-sm hover:bg-border/50"><span className="text-muted">{icon}</span>{label}</button>
  );
  return (
    <div className="fixed inset-0 z-[65]" onClick={onClose}>
      <div className="absolute left-0 top-0 h-full w-72 max-w-[85vw] overflow-y-auto border-r border-border bg-card shadow-2xl" onClick={(e) => e.stopPropagation()} role="menu" aria-label="Меню чата">
        <div className="px-5 pb-3 pt-6">
          <PersonAvatar name={m?.fullName ?? ''} photo={m?.avatar?.thumbUrl} size={56} />
          <p className="mt-3 font-semibold">{m?.fullName}</p>
          <p className="text-sm text-primary">{m?.username ? `@${m.username}` : roleLabel(m?.role ?? '')}</p>
        </div>
        <div className="border-t border-border py-1">
          {item(<User size={20} aria-hidden />, 'Мой профиль', onProfile)}
        </div>
        <div className="border-t border-border py-1">
          {item(<Users size={20} aria-hidden />, 'Создать группу', onGroup)}
          {onChannel && item(<Megaphone size={20} aria-hidden />, 'Создать канал', onChannel)}
          {item(<User size={20} aria-hidden />, 'Контакты', onContacts)}
          {item(<ImageIcon size={20} aria-hidden />, collapsed ? 'Показать имена чатов' : 'Скрыть имена чатов', onCollapse)}
          <label className="flex w-full cursor-pointer items-center gap-4 px-5 py-2.5 text-sm hover:bg-border/50">
            <span className="text-muted"><Moon size={20} aria-hidden /></span>
            <span className="flex-1">Ночной режим</span>
            <input type="checkbox" role="switch" aria-label="Ночной режим" checked={dark} onChange={(e) => { applyTheme(e.target.checked ? 'dark' : 'light'); setDark(e.target.checked); }} className="h-5 w-9 accent-primary" />
          </label>
        </div>
        <button aria-label="Закрыть меню" onClick={onClose} className="absolute right-3 top-3 rounded-full p-1.5 text-muted hover:bg-border/50"><X size={18} aria-hidden /></button>
      </div>
    </div>
  );
}

/** Group consecutive photos / videos of one sender (sent within 2 minutes, captions only on the first) into albums. */
export function albumsOf<T extends { id: string; kind: string; deleted: boolean; createdAt: string; text: string | null; sender: { id: string } | null; file: unknown }>(list: T[]): (T | T[])[] {
  const out: (T | T[])[] = [];
  let cur: T[] = [];
  const flush = () => { if (cur.length > 1) out.push(cur); else if (cur.length === 1) out.push(cur[0]); cur = []; };
  for (const m of list) {
    const media = !m.deleted && !!m.file && (m.kind === 'IMAGE' || m.kind === 'VIDEO');
    const prev = cur[cur.length - 1];
    const joins = media && prev && prev.sender?.id === m.sender?.id && new Date(m.createdAt).getTime() - new Date(prev.createdAt).getTime() < 120_000 && !m.text && cur.length < 10;
    if (joins) { cur.push(m); continue; }
    flush();
    if (media) cur = [m]; else out.push(m);
  }
  flush();
  return out;
}
