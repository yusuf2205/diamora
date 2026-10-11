'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Check, ExternalLink, MapPin, Phone, Play } from 'lucide-react';
import { api } from '@/lib/api';

export interface PollView { question: string; multiple: boolean; voters: number; options: { text: string; count: number; mine: boolean }[] }
export interface LinkPreview { url: string; title: string | null; description: string | null; image: string | null; site: string | null }

/** «Опрос»: tap an answer (again to take it back); with several allowed - tick, then «Ответить». Results once answered. */
export function PollCard({ messageId, poll, onChanged }: { messageId: string; poll: PollView; onChanged: () => void }) {
  const [picking, setPicking] = useState<number[]>([]);
  const [busy, setBusy] = useState(false);
  const voted = poll.options.some((o) => o.mine);
  const vote = async (options: number[]) => {
    setBusy(true);
    try { await api.post(`/chat/messages/${messageId}/vote`, { options }); setPicking([]); onChanged(); } finally { setBusy(false); }
  };
  return (
    <div className="w-64 max-w-full">
      <p className="font-semibold">{poll.question}</p>
      <p className="mb-2 text-xs text-muted">{poll.multiple ? 'Можно выбрать несколько' : 'Один ответ'}</p>
      {poll.options.map((o, i) => {
        const pct = poll.voters ? Math.round((o.count * 100) / poll.voters) : 0;
        const ticked = o.mine || picking.includes(i);
        return (
          <button key={i} disabled={busy} type="button"
            onClick={() => (poll.multiple && !voted ? setPicking((p) => (p.includes(i) ? p.filter((x) => x !== i) : [...p, i])) : vote(o.mine ? [] : [i]))}
            className="mb-1.5 block w-full rounded-lg px-1 py-1 text-left hover:bg-border/40">
            <span className="flex items-center gap-2 text-sm">
              <span className={`flex h-4 w-4 shrink-0 items-center justify-center rounded-full border ${ticked ? 'border-primary bg-primary text-white' : 'border-muted'}`}>{ticked && <Check size={11} aria-hidden />}</span>
              <span className="flex-1">{o.text}</span>
              {voted && <span className="text-xs font-semibold">{pct}%</span>}
            </span>
            {voted && <span className="ml-6 mt-1 block h-1.5 overflow-hidden rounded-full bg-border/60"><span className="block h-full rounded-full bg-primary transition-all duration-500" style={{ width: `${pct}%` }} /></span>}
          </button>
        );
      })}
      {poll.multiple && !voted && picking.length > 0 && (
        <button type="button" disabled={busy} onClick={() => vote(picking)} className="mb-1 w-full rounded-lg bg-primary py-1.5 text-sm font-medium text-white">Ответить</button>
      )}
      <p className="text-xs text-muted">Ответили: {poll.voters}</p>
    </div>
  );
}

export function LocationCard({ data }: { data: { latitude: number; longitude: number; label?: string | null } }) {
  const href = `https://yandex.uz/maps/?pt=${data.longitude},${data.latitude}&z=16&l=map`;
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className="flex w-60 items-center gap-3 rounded-lg p-1 hover:bg-border/40">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-red-100 text-red-600"><MapPin size={22} aria-hidden /></span>
      <span className="min-w-0"><span className="block truncate font-medium">{data.label || 'Геопозиция'}</span><span className="block text-xs text-muted">Открыть на карте</span></span>
    </a>
  );
}

export function ContactCard({ data }: { data: { name: string; phone: string } }) {
  return (
    <div className="flex w-60 items-center gap-3 p-1">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary/15 text-sm font-semibold text-primary">{data.name.split(/\s+/).map((x) => x[0]).slice(0, 2).join('').toUpperCase()}</span>
      <span className="min-w-0 flex-1"><span className="block truncate font-medium">{data.name}</span><a href={`tel:${data.phone}`} className="flex items-center gap-1 text-sm text-primary"><Phone size={13} aria-hidden />{data.phone}</a></span>
    </div>
  );
}

/** a work / an order / a worker as a card with «Открыть» (the app's routes mapped to the panel's) */
export function WorkCard({ data }: { data: { type: string; id: string; title: string; subtitle?: string; link?: string } }) {
  const href = data.type === 'assignment' ? `/assignments/${data.id}` : data.type === 'worker' ? `/workers/${data.id}` : '/orders';
  return (
    <div className="w-64 max-w-full rounded-lg border-l-4 border-primary bg-border/30 p-2.5">
      <p className="line-clamp-2 font-semibold">{data.title}</p>
      {data.subtitle && <p className="text-sm text-muted">{data.subtitle}</p>}
      <Link href={href} className="mt-2 flex items-center justify-center gap-1.5 rounded-lg bg-primary/15 py-1.5 text-sm font-medium text-primary hover:bg-primary/25"><ExternalLink size={14} aria-hidden />Открыть</Link>
    </div>
  );
}

export function VideoNote({ thumb, onOpen }: { thumb: string | null; onOpen?: () => void }) {
  return (
    <button type="button" onClick={onOpen} aria-label="Видеосообщение" className="relative block h-48 w-48 overflow-hidden rounded-full bg-black">
      {thumb && <img src={thumb} alt="" className="absolute inset-0 h-full w-full object-cover" />}
      <span className="absolute inset-0 flex items-center justify-center"><span className="flex h-11 w-11 items-center justify-center rounded-full bg-black/55 text-white"><Play size={22} aria-hidden /></span></span>
    </button>
  );
}

export function LinkPreviewCard({ p }: { p: LinkPreview }) {
  return (
    <a href={p.url} target="_blank" rel="noopener noreferrer" className="mt-1.5 block max-w-72 rounded-md border-l-[3px] border-primary bg-border/30 px-2 py-1.5 hover:bg-border/50">
      {p.site && <p className="text-xs font-bold text-primary">{p.site}</p>}
      {p.title && <p className="line-clamp-2 text-sm font-semibold">{p.title}</p>}
      {p.description && <p className="line-clamp-3 text-xs text-muted">{p.description}</p>}
      {p.image && <img src={p.image} alt="" className="mt-1.5 max-h-36 w-full rounded object-cover" loading="lazy" />}
    </a>
  );
}
