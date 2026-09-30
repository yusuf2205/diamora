'use client';

import { Pause, Play, SkipBack, SkipForward, Volume1, Volume2, VolumeX, X } from 'lucide-react';
import { useEffect, useState, useSyncExternalStore } from 'react';

/** One voice message / audio file the player knows about (every bubble on screen registers its own). */
export interface Track { id: string; roomId: string; url: string; title: string; createdAt: string; durationMs?: number | null }

interface State { track: Track | null; playing: boolean; pos: number; len: number; rate: number; volume: number; muted: boolean }

// ---- one shared <audio> for the whole chat, like Telegram: one thing plays at a time, the next voice starts by itself -------
const known = new Map<string, Track>();
let state: State = { track: null, playing: false, pos: 0, len: 0, rate: 1, volume: 1, muted: false };
const subs = new Set<() => void>();
const set = (p: Partial<State>) => { state = { ...state, ...p }; subs.forEach((f) => f()); };
let el: HTMLAudioElement | null = null;

function audio() {
  if (el) return el;
  el = new Audio();
  el.preload = 'auto';
  el.addEventListener('play', () => set({ playing: true }));
  el.addEventListener('pause', () => set({ playing: false }));
  el.addEventListener('timeupdate', () => set({ pos: el!.currentTime }));
  el.addEventListener('loadedmetadata', () => { if (Number.isFinite(el!.duration)) set({ len: el!.duration }); });
  el.addEventListener('ended', () => { const n = neighbour(1); if (n) player.play(n); else set({ playing: false, pos: 0 }); });
  return el;
}

/** the room's voices / audios in time order */
const queue = (roomId: string) => [...known.values()].filter((t) => t.roomId === roomId).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
function neighbour(d: number): Track | null {
  const t = state.track; if (!t) return null;
  const q = queue(t.roomId); const i = q.findIndex((x) => x.id === t.id);
  return i < 0 ? null : (q[i + d] ?? null);
}

export const player = {
  register(t: Track) { known.set(t.id, t); return () => { known.delete(t.id); }; },
  play(t: Track) {
    const a = audio();
    if (state.track?.id !== t.id) {
      a.src = t.url; a.playbackRate = state.rate;
      set({ track: t, pos: 0, len: (t.durationMs ?? 0) / 1000 });
    }
    try { void a.play()?.catch(() => set({ playing: false })); } catch { set({ playing: false }); }
  },
  toggle(t: Track) { if (state.track?.id === t.id && state.playing) audio().pause(); else player.play(t); },
  seek(sec: number) { const a = audio(); a.currentTime = Math.max(0, sec); set({ pos: a.currentTime }); },
  step(d: number) { const n = neighbour(d); if (n) player.play(n); else if (d < 0) player.seek(0); },
  rate() { const r = state.rate === 1 ? 1.5 : state.rate === 1.5 ? 2 : 1; audio().playbackRate = r; set({ rate: r }); },
  volume(v: number) { const a = audio(); a.volume = v; a.muted = v === 0; set({ volume: v, muted: v === 0 }); },
  mute() { const a = audio(); a.muted = !state.muted; set({ muted: !state.muted }); },
  close() { const a = audio(); a.pause(); a.removeAttribute('src'); a.load(); set({ track: null, playing: false, pos: 0 }); },
};

export function usePlayer() {
  return useSyncExternalStore((f) => { subs.add(f); return () => subs.delete(f); }, () => state, () => state);
}

const fmt = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const when = (iso: string) => {
  const d = new Date(iso); const t = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  const day = new Date(); day.setHours(0, 0, 0, 0);
  const diff = Math.round((day.getTime() - new Date(d).setHours(0, 0, 0, 0)) / 86_400_000);
  return diff === 0 ? `сегодня в ${t}` : diff === 1 ? `вчера в ${t}` : `${d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' })} в ${t}`;
};

/** The strip under the chat header while a voice / audio plays: ⏮ ▶ ⏭, who and when, time, volume, speed, ✕. */
export function AudioBar() {
  const s = usePlayer();
  const [vol, setVol] = useState(false);
  useEffect(() => { if (!s.track) setVol(false); }, [s.track]);
  if (!s.track) return null;
  const t = s.track;
  const VolIcon = s.muted || s.volume === 0 ? VolumeX : s.volume < 0.5 ? Volume1 : Volume2;
  const btn = 'rounded-full p-1.5 text-primary hover:bg-border/50 disabled:opacity-40';
  return (
    <div className="relative flex items-center gap-1 border-b border-border bg-card px-2 py-1 text-sm" role="region" aria-label="Проигрыватель">
      <button aria-label="Предыдущее" className={btn} onClick={() => player.step(-1)}><SkipBack size={18} fill="currentColor" aria-hidden /></button>
      <button aria-label={s.playing ? 'Пауза' : 'Слушать'} className={btn} onClick={() => player.toggle(t)}>
        {s.playing ? <Pause size={20} fill="currentColor" aria-hidden /> : <Play size={20} fill="currentColor" aria-hidden />}
      </button>
      <button aria-label="Следующее" className={btn} onClick={() => player.step(1)} disabled={!neighbour(1)}><SkipForward size={18} fill="currentColor" aria-hidden /></button>
      <p className="ml-1 min-w-0 flex-1 truncate"><b>{t.title}</b> <span className="text-muted">{when(t.createdAt)}</span></p>
      <span className="shrink-0 px-1 tabular-nums text-muted">{fmt(s.pos)}</span>
      <div className="relative" onMouseEnter={() => setVol(true)} onMouseLeave={() => setVol(false)}>
        <button aria-label={s.muted ? 'Включить звук' : 'Выключить звук'} className={btn} onClick={() => player.mute()}><VolIcon size={19} aria-hidden /></button>
        {vol && (
          <div className="absolute right-0 top-full z-30 rounded-lg border border-border bg-card p-3 shadow-lg">
            <input type="range" min={0} max={1} step={0.05} value={s.muted ? 0 : s.volume} aria-label="Громкость" onChange={(e) => player.volume(Number(e.target.value))} className="w-28 accent-primary" />
          </div>
        )}
      </div>
      <button aria-label={`Скорость ${s.rate}x`} title="Скорость" onClick={() => player.rate()}
        className={`rounded-md border-2 px-1 text-xs font-bold leading-4 ${s.rate === 1 ? 'border-muted/60 text-muted' : 'border-primary text-primary'}`}>{s.rate}X</button>
      <button aria-label="Закрыть проигрыватель" className="rounded-full p-1.5 text-muted hover:bg-border/50" onClick={() => player.close()}><X size={18} aria-hidden /></button>
      {/* thin progress line; a click seeks */}
      <div className="absolute inset-x-0 -bottom-px h-1 cursor-pointer" onClick={(e) => { const r = e.currentTarget.getBoundingClientRect(); if (s.len) player.seek(((e.clientX - r.left) / r.width) * s.len); }}>
        <div className="h-0.5 bg-primary" style={{ width: `${s.len ? Math.min(100, (s.pos / s.len) * 100) : 0}%` }} />
      </div>
    </div>
  );
}
