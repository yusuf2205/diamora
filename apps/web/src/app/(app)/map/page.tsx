'use client';

import Script from 'next/script';
import { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { freshnessLabel, roleLabel } from '@/lib/format';
import type { LiveLocation } from '@/lib/types';
import { Badge, Card, EmptyState, ErrorState } from '@/components/ui';

const JS_KEY = process.env.NEXT_PUBLIC_YANDEX_MAPS_JS_KEY ?? '';

const ROLE_TONE: Record<string, 'default' | 'ok' | 'warn' | 'danger'> = { SUPER_ADMIN: 'warn', ADMIN: 'warn', MANAGER: 'default', WORKER: 'ok' };

declare global {
  interface Window {
    ymaps?: { ready: (cb: () => void) => void; Map: new (...args: unknown[]) => unknown; Placemark: new (...args: unknown[]) => unknown };
  }
}

/**
 * SUPER_ADMIN/ADMIN/MANAGER live map (M2 §20). Data is `GET /v1/locations` — scoped server-side exactly like
 * everywhere else (a MANAGER only ever receives her own workers). Polls every 15 s (the same "auto-refresh" pattern
 * the dashboard already uses — this codebase has no WebSocket client on the web side yet, honest gap in the report).
 * Without `NEXT_PUBLIC_YANDEX_MAPS_JS_KEY` (a DIFFERENT key than the mobile MapKit one) the page falls back to a
 * real, fully working list — never a blank or broken map.
 */
export default function MapPage() {
  const { me } = useAuth();
  const { data, error, isLoading } = useQuery<{ items: LiveLocation[] }>({
    queryKey: ['map-locations'],
    queryFn: () => api.get<{ items: LiveLocation[] }>('/locations'),
    refetchInterval: 15_000,
  });
  const [selected, setSelected] = useState<LiveLocation | null>(null);
  const items = data?.items ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Карта</h1>
        <p className="text-sm text-muted">{me?.role === 'MANAGER' ? 'Только ваши мастерицы' : 'Все, кому разрешено видеть местоположение'} · обновляется каждые 15 сек</p>
      </div>
      {error && <ErrorState error={error} />}
      {isLoading && <p className="text-muted">Загрузка…</p>}
      {!isLoading && !error && items.length === 0 && <EmptyState title="Пока нет координат" hint="Как только кто-то откроет приложение, точка появится здесь" />}
      {!isLoading && items.length > 0 && (JS_KEY ? <YandexMapView items={items} onSelect={setSelected} /> : <FallbackList items={items} onSelect={setSelected} />)}
      {selected && <DetailPanel row={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

function FallbackList({ items, onSelect }: { items: LiveLocation[]; onSelect: (r: LiveLocation) => void }) {
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((row) => (
        <button key={row.userId} onClick={() => onSelect(row)} className="text-left">
          <Card className="transition hover:border-primary">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate font-medium">{row.fullName}</p>
                <p className="text-xs text-muted">{roleLabel(row.role)}{row.worker ? ` · ${row.worker.code}` : ''}</p>
              </div>
              <Badge tone={ROLE_TONE[row.role]}>{row.role}</Badge>
            </div>
            <div className="mt-3 flex items-center gap-2 text-xs">
              <span className={`h-2 w-2 rounded-full ${row.online ? 'bg-ok' : 'bg-border'}`} />
              <span className="text-muted">{row.online ? 'в сети' : 'не в сети'}</span>
              <span className={row.freshness === 'STALE' ? 'text-danger' : 'text-muted'}>· {freshnessLabel(row.ageSeconds)}</span>
            </div>
          </Card>
        </button>
      ))}
    </div>
  );
}

/** Loaded only when a JS API key is configured — no ymaps script/network call happens otherwise. */
function YandexMapView({ items, onSelect }: { items: LiveLocation[]; onSelect: (r: LiveLocation) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<unknown>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!ready || !containerRef.current || !window.ymaps) return;
    window.ymaps.ready(() => {
      const ymaps = window.ymaps!;
      if (!mapRef.current) {
        mapRef.current = new ymaps.Map(containerRef.current, { center: [items[0]?.latitude ?? 41.31, items[0]?.longitude ?? 69.28], zoom: 11 });
      }
      const map = mapRef.current as { geoObjects: { removeAll: () => void; add: (o: unknown) => void } };
      map.geoObjects.removeAll();
      for (const row of items) {
        const color = row.freshness === 'STALE' ? '#9CA3AF' : row.role === 'MANAGER' ? '#7C3AED' : row.role === 'WORKER' ? '#16A34A' : '#2563EB';
        const placemark = new ymaps.Placemark(
          [row.latitude, row.longitude],
          { hintContent: row.fullName },
          { preset: 'islands#circleIcon', iconColor: color },
        );
        (placemark as { events: { add: (t: string, cb: () => void) => void } }).events.add('click', () => onSelect(row));
        map.geoObjects.add(placemark);
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, items]);

  return (
    <>
      <Script src={`https://api-maps.yandex.ru/2.1/?apikey=${JS_KEY}&lang=ru_RU`} strategy="afterInteractive" onLoad={() => setReady(true)} />
      <div ref={containerRef} className="h-[600px] w-full overflow-hidden rounded-lg border border-border" />
    </>
  );
}

function DetailPanel({ row, onClose }: { row: LiveLocation; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="w-full max-w-sm rounded-lg border border-border bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <h3 className="text-lg font-semibold">{row.fullName}</h3>
        <p className="text-sm text-muted">{roleLabel(row.role)}{row.worker ? ` · ${row.worker.code}` : ''}</p>
        <div className="mt-3 space-y-1 text-sm">
          <p><span className="text-muted">Статус: </span>{row.online ? 'в сети' : 'не в сети'} · <span className={row.freshness === 'STALE' ? 'text-danger' : ''}>{freshnessLabel(row.ageSeconds)}</span></p>
          {row.phone && <p><span className="text-muted">Телефон: </span><a className="text-primary" href={`tel:${row.phone}`}>{row.phone}</a></p>}
          <p><span className="text-muted">Координаты: </span>{row.latitude.toFixed(5)}, {row.longitude.toFixed(5)}</p>
        </div>
        <div className="mt-4 flex justify-end">
          <button onClick={onClose} className="rounded-lg border border-border px-4 py-2 text-sm hover:bg-border/40">Закрыть</button>
        </div>
      </div>
    </div>
  );
}
