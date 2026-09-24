'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { freshnessLabel, roleLabel } from '@/lib/format';
import type { LiveLocation } from '@/lib/types';
import { Button, Chips, EmptyState, ErrorState, Modal } from '@/components/ui';

const JS_KEY = process.env.NEXT_PUBLIC_YANDEX_MAPS_JS_KEY ?? '';
// Yandex draws the map without a key too (light use); a registered key removes the console warning and the limits.
const YMAPS_SRC = `https://api-maps.yandex.ru/2.1/?lang=ru_RU${JS_KEY ? `&apikey=${JS_KEY}` : ''}`;

const ROLE_COLOR: Record<string, string> = { WORKER: '#1B7F4B', MANAGER: '#7C3AED', ADMIN: '#2563EB', SUPER_ADMIN: '#A3324F' };
const STALE_COLOR = '#9CA3AF';
const FILTERS = [
  { value: 'all', label: 'Все' },
  { value: 'WORKER', label: 'Мастерицы' },
  { value: 'MANAGER', label: 'Менеджеры' },
  { value: 'ADMIN', label: 'Администраторы' },
  { value: 'online', label: 'В сети' },
] as const;
type Filter = (typeof FILTERS)[number]['value'];

interface YMap { geoObjects: { removeAll: () => void; add: (o: unknown) => void; getBounds: () => number[][] | null }; setBounds: (b: number[][], o: unknown) => void; setCenter: (c: number[], z: number) => void; destroy: () => void }
declare global {
  interface Window {
    ymaps?: { ready: (cb: () => void) => void; Map: new (...args: unknown[]) => YMap; Placemark: new (...args: unknown[]) => { events: { add: (t: string, cb: () => void) => void } } };
  }
}

/** Loads the Yandex Maps JS API once for the whole app (the script tag survives page changes). */
function useYmaps() {
  const [ready, setReady] = useState(() => typeof window !== 'undefined' && !!window.ymaps);
  useEffect(() => {
    if (window.ymaps) { window.ymaps.ready(() => setReady(true)); return; }
    let s = document.querySelector<HTMLScriptElement>('script[data-ymaps]');
    if (!s) {
      s = document.createElement('script');
      s.src = YMAPS_SRC;
      s.async = true;
      s.dataset.ymaps = '1';
      document.head.appendChild(s);
    }
    const onLoad = () => window.ymaps?.ready(() => setReady(true));
    s.addEventListener('load', onLoad);
    return () => s?.removeEventListener('load', onLoad);
  }, []);
  return ready;
}

/**
 * «Карта» (SUPER_ADMIN / ADMIN / MANAGER — never a worker): everyone whose position the viewer may see, on a real
 * Yandex map, coloured by role. Scope and hiding are decided by the SERVER (`GET /v1/locations`): a MANAGER only gets
 * her own workers, a person the SUPER_ADMIN hid never reaches anyone else. Refreshes every 15 s.
 */
export default function MapPage() {
  const { me } = useAuth();
  const { data, error, isLoading, refetch } = useQuery<{ items: LiveLocation[] }>({
    queryKey: ['map-locations'],
    queryFn: () => api.get<{ items: LiveLocation[] }>('/locations'),
    refetchInterval: 15_000,
  });
  const [filter, setFilter] = useState<Filter>('all');
  const [selected, setSelected] = useState<LiveLocation | null>(null);
  const all = useMemo(() => data?.items ?? [], [data]);
  const items = useMemo(() => all.filter((r) => {
    if (filter === 'all') return true;
    if (filter === 'online') return r.online;
    if (filter === 'ADMIN') return r.role === 'ADMIN' || r.role === 'SUPER_ADMIN';
    return r.role === filter;
  }), [all, filter]);
  const counts = { online: all.filter((r) => r.online).length, total: all.length };

  return (
    <div className="flex h-[calc(100dvh-7.5rem)] min-h-[420px] flex-col gap-3 lg:h-[calc(100dvh-4rem)]">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold sm:text-2xl">Карта</h1>
          <p className="text-sm text-muted">{me?.role === 'MANAGER' ? 'Ваши мастерицы' : 'Все, кого вам разрешено видеть'} · {counts.total} на карте, {counts.online} в сети</p>
        </div>
      </div>
      <Chips options={FILTERS} value={filter} onChange={setFilter} label="Кого показать" />
      {error && <ErrorState error={error} onRetry={() => refetch()} />}
      <div className="relative flex-1 overflow-hidden rounded-xl border border-border bg-card">
        <YandexMap items={items} onSelect={setSelected} />
        {!isLoading && !error && all.length === 0 && (
          <div className="absolute inset-x-3 top-3"><EmptyState title="Пока нет координат" hint="Точка появится, как только человек откроет приложение или панель и разрешит геолокацию" /></div>
        )}
        <Legend />
      </div>
      {selected && <DetailSheet row={selected} canHide={me?.role === 'SUPER_ADMIN'} onClose={() => setSelected(null)} />}
    </div>
  );
}

function Legend() {
  return (
    <div className="pointer-events-none absolute bottom-3 left-3 flex flex-wrap gap-x-3 gap-y-1 rounded-lg bg-card/90 px-3 py-2 text-xs shadow">
      {[['WORKER', 'Мастерица'], ['MANAGER', 'Менеджер'], ['ADMIN', 'Администратор'], ['SUPER_ADMIN', 'Главный']].map(([r, l]) => (
        <span key={r} className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full" style={{ background: ROLE_COLOR[r] }} />{l}</span>
      ))}
      <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full" style={{ background: STALE_COLOR }} />давно не обновлялась</span>
    </div>
  );
}

function YandexMap({ items, onSelect }: { items: LiveLocation[]; onSelect: (r: LiveLocation) => void }) {
  const ready = useYmaps();
  const box = useRef<HTMLDivElement>(null);
  const map = useRef<YMap | null>(null);
  const fitted = useRef(false);

  useEffect(() => {
    if (!ready || !box.current || !window.ymaps) return;
    if (!map.current) {
      map.current = new window.ymaps.Map(box.current, { center: [41.311, 69.279], zoom: 11, controls: ['zoomControl', 'geolocationControl', 'typeSelector', 'fullscreenControl'] }, { suppressMapOpenBlock: true });
    }
    const m = map.current;
    m.geoObjects.removeAll();
    for (const r of items) {
      const color = r.freshness === 'STALE' ? STALE_COLOR : ROLE_COLOR[r.role] ?? STALE_COLOR;
      const p = new window.ymaps.Placemark(
        [r.latitude, r.longitude],
        { iconCaption: r.fullName + (r.hidden ? ' (скрыт)' : ''), hintContent: `${r.fullName} · ${roleLabel(r.role)}` },
        { preset: r.online ? 'islands#circleDotIconWithCaption' : 'islands#circleIconWithCaption', iconColor: color },
      );
      p.events.add('click', () => onSelect(r));
      m.geoObjects.add(p);
    }
    // frame everyone once; later refreshes keep whatever the viewer zoomed to
    if (!fitted.current && items.length > 0) {
      fitted.current = true;
      if (items.length === 1) m.setCenter([items[0].latitude, items[0].longitude], 14);
      else { const b = m.geoObjects.getBounds(); if (b) m.setBounds(b, { checkZoomRange: true, zoomMargin: 40 }); }
    }
  }, [ready, items, onSelect]);

  useEffect(() => () => { map.current?.destroy(); map.current = null; }, []);

  return (
    <>
      <div ref={box} className="h-full w-full" aria-label="Карта" />
      {!ready && <div className="absolute inset-0 flex items-center justify-center text-sm text-muted">Загружаем карту…</div>}
    </>
  );
}

function DetailSheet({ row, canHide, onClose }: { row: LiveLocation; canHide: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const toggle = useMutation({
    mutationFn: (hidden: boolean) => api.put(`/users/${row.userId}/location-visibility`, { hidden }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['map-locations'] }); onClose(); },
  });
  const route = `https://yandex.uz/maps/?rtext=~${row.latitude},${row.longitude}&rtt=auto`;
  return (
    <Modal title={row.fullName} onClose={onClose}>
      <p className="-mt-3 mb-3 text-sm text-muted">{roleLabel(row.role)}{row.worker ? ` · ${row.worker.code}` : ''}{row.hidden ? ' · скрыт с карты для остальных' : ''}</p>
      <div className="space-y-1 text-sm">
        <p><span className="text-muted">Сейчас: </span>{row.online ? 'в сети' : 'не в сети'} · <span className={row.freshness === 'STALE' ? 'text-danger' : ''}>{freshnessLabel(row.ageSeconds)}</span></p>
        {row.phone && <p><span className="text-muted">Телефон: </span><a className="text-primary" href={`tel:${row.phone}`}>{row.phone}</a></p>}
      </div>
      <div className="mt-4 grid grid-cols-2 gap-2">
        {row.phone && <a href={`tel:${row.phone}`} className="inline-flex min-h-10 items-center justify-center rounded-lg border border-border px-3 text-sm font-medium hover:bg-border/40">Позвонить</a>}
        <a href={route} target="_blank" rel="noreferrer" className="inline-flex min-h-10 items-center justify-center rounded-lg border border-border px-3 text-sm font-medium hover:bg-border/40">Маршрут</a>
        <Link href={row.worker ? `/workers/${row.worker.id}` : `/team/${row.userId}`} className="col-span-2 inline-flex min-h-10 items-center justify-center rounded-lg bg-primary px-3 text-sm font-medium text-white">Открыть карточку</Link>
      </div>
      {canHide && (
        <div className="mt-4 border-t border-border pt-3">
          {toggle.isError && <ErrorState error={toggle.error} />}
          <Button variant="outline" className="w-full" disabled={toggle.isPending} onClick={() => toggle.mutate(!row.hidden)}>
            {row.hidden ? 'Показывать на карте всем, кому разрешено' : 'Скрыть с карты для остальных'}
          </Button>
          <p className="mt-1 text-xs text-muted">Видите только вы. Телефон продолжает отправлять позицию.</p>
        </div>
      )}
    </Modal>
  );
}
