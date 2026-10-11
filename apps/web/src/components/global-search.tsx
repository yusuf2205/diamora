'use client';

import { useQuery } from '@tanstack/react-query';
import { Search, X } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { api } from '@/lib/api';

interface Found {
  workers: { id: string; fullName: string; code: string; phone: string }[];
  works: { id: string; code: string; worker: string; product: string; plannedMeters: number }[];
  orders: { id: string; code: string; name: string; phone: string }[];
  materials: { id: string; name: string }[];
  models: { id: string; name: string; code: string }[];
  staff: { id: string; fullName: string; phone: string }[];
}
interface Row { key: string; href: string; title: string; sub: string }

export function searchSections(d: Found): { title: string; rows: Row[] }[] {
  return [
    { title: 'Мастерицы', rows: d.workers.map((x) => ({ key: x.id, href: `/workers/${x.id}`, title: x.fullName, sub: `${x.code} · ${x.phone}` })) },
    { title: 'Работы', rows: d.works.map((x) => ({ key: x.id, href: `/assignments/${x.id}`, title: `${x.worker} · ${x.product}`, sub: `${x.code} · ${x.plannedMeters} м` })) },
    { title: 'Заказы клиентов', rows: d.orders.map((x) => ({ key: x.id, href: '/orders', title: x.name, sub: `${x.code} · ${x.phone}` })) },
    { title: 'Материалы', rows: d.materials.map((x) => ({ key: x.id, href: '/inventory', title: x.name, sub: '' })) },
    { title: 'Каталог', rows: d.models.map((x) => ({ key: x.id, href: `/catalog/${x.id}`, title: x.name, sub: x.code })) },
    { title: 'Сотрудники', rows: d.staff.map((x) => ({ key: x.id, href: `/team/${x.id}`, title: x.fullName, sub: x.phone })) },
  ].filter((s) => s.rows.length > 0);
}

function useFound(q: string) {
  const [debounced, setDebounced] = useState('');
  useEffect(() => { const t = setTimeout(() => setDebounced(q.trim()), 250); return () => clearTimeout(t); }, [q]);
  return useQuery<Found>({ queryKey: ['search', debounced], queryFn: () => api.get<Found>('/admin/search', { q: debounced }), enabled: debounced.length >= 2, staleTime: 30_000 });
}

function Results({ q, onPick }: { q: string; onPick: () => void }) {
  const found = useFound(q);
  if (q.trim().length < 2) return <p className="px-4 py-3 text-sm text-muted">Мастерицы, работы, заказы, материалы, модели, сотрудники — по имени, телефону или коду</p>;
  if (found.isLoading) return <p className="px-4 py-3 text-sm text-muted">Ищем…</p>;
  const sections = found.data ? searchSections(found.data) : [];
  if (!sections.length) return <p className="px-4 py-3 text-sm text-muted">Ничего не найдено</p>;
  return (
    <div className="max-h-[60vh] overflow-y-auto py-1">
      {sections.map((s) => (
        <div key={s.title} className="py-1">
          <p className="px-4 pb-1 pt-2 text-[11px] font-semibold uppercase tracking-wide text-primary">{s.title}</p>
          {s.rows.map((r) => (
            <Link key={r.key} href={r.href} onClick={onPick} className="block px-4 py-2 hover:bg-border/40">
              <span className="block truncate text-sm font-medium">{r.title}</span>
              {r.sub && <span className="block truncate text-xs text-muted">{r.sub}</span>}
            </Link>
          ))}
        </div>
      ))}
    </div>
  );
}

/**
 * «Поиск» at the top of every page (owner, 2026-10-11): a wide field, results drop down grouped (workers, works, orders,
 * materials, models, staff); «/» focuses it, Enter opens the full results, Esc closes. `compact`: just a magnifier that opens
 * the same search over the page (the chat, where there is no room for a field).
 */
export function GlobalSearch({ compact = false, className = '' }: { compact?: boolean; className?: string }) {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement | null;
      const typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable);
      if (e.key === '/' && !typing) { e.preventDefault(); setOpen(true); setTimeout(() => input.current?.focus(), 0); }
      if (e.key === 'Escape') setOpen(false);
    };
    const click = (e: MouseEvent) => { if (box.current && !box.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('keydown', key);
    document.addEventListener('mousedown', click);
    return () => { document.removeEventListener('keydown', key); document.removeEventListener('mousedown', click); };
  }, []);

  const close = () => { setOpen(false); setQ(''); };
  const field = (
    <label className="flex h-10 w-full items-center gap-2 rounded-full border border-border bg-background px-4 shadow-sm transition focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/15">
      <Search size={17} className="shrink-0 text-muted" aria-hidden />
      <input
        ref={input}
        value={q}
        onChange={(e) => { setQ(e.target.value); setOpen(true); }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => { if (e.key === 'Enter' && q.trim().length >= 2) { router.push(`/search?q=${encodeURIComponent(q.trim())}`); close(); } }}
        placeholder="Поиск: мастерица, работа, заказ…"
        aria-label="Поиск"
        className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-muted"
      />
      {q ? <button type="button" aria-label="Очистить" onClick={() => { setQ(''); input.current?.focus(); }} className="rounded-full p-0.5 text-muted hover:text-foreground"><X size={15} aria-hidden /></button>
        : !compact && <kbd className="hidden rounded border border-border px-1.5 text-[11px] text-muted sm:block">/</kbd>}
    </label>
  );

  if (compact) {
    return (
      <div ref={box} className={className}>
        <button type="button" aria-label="Поиск" title="Поиск ( / )" onClick={() => { setOpen(true); setTimeout(() => input.current?.focus(), 0); }}
          className="flex h-9 w-9 items-center justify-center rounded-full text-muted transition hover:bg-border/50 hover:text-foreground">
          <Search size={19} aria-hidden />
        </button>
        {open && (
          <div className="fixed inset-x-0 top-0 z-[80] flex justify-center bg-black/30 px-3 pt-3 sm:pt-16" style={{ bottom: 0 }} onMouseDown={(e) => { if (e.target === e.currentTarget) close(); }}>
            <div className="h-fit w-full max-w-xl overflow-hidden rounded-2xl border border-border bg-card shadow-2xl">
              <div className="p-3">{field}</div>
              <div className="border-t border-border"><Results q={q} onPick={close} /></div>
            </div>
          </div>
        )}
      </div>
    );
  }
  return (
    <div ref={box} className={`relative ${className}`}>
      {field}
      {open && (
        <div className="absolute inset-x-0 top-12 z-[70] overflow-hidden rounded-2xl border border-border bg-card shadow-2xl">
          <Results q={q} onPick={close} />
        </div>
      )}
    </div>
  );
}
