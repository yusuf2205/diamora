'use client';

import { Navigation, Route } from 'lucide-react';
import { useMemo, useState } from 'react';
import { planRoute, yandexRouteUrl, type RouteStop } from '@/lib/route-plan';
import type { LiveLocation } from '@/lib/types';
import { Button, Modal } from '@/components/ui';

const noteOf = (r: LiveLocation) => [r.work?.toPickup && 'забрать работу', r.work?.toDeliver && 'отвезти материалы', r.work?.overdue && 'просрочено'].filter(Boolean).join(' · ');

/**
 * «Маршрут» (web): tick whom to visit - those with work to collect or materials to deliver are ticked - get the shortest
 * round from where this computer is (or from the first stop) and open it in Yandex Maps. The same plan as in the app.
 */
export function RouteModal({ rows, onClose }: { rows: LiveLocation[]; onClose: () => void }) {
  const stops = useMemo(() => {
    const seen = new Set<string>();
    return rows
      .filter((r) => r.worker && !seen.has(r.worker.id) && seen.add(r.worker.id))
      .map((r): RouteStop => ({ id: r.worker!.id, name: r.fullName, lat: r.latitude, lng: r.longitude, note: noteOf(r) }))
      .sort((a, b) => Number(!!b.note) - Number(!!a.note) || a.name.localeCompare(b.name));
  }, [rows]);
  const [picked, setPicked] = useState<Set<string>>(() => new Set(stops.filter((s) => s.note).map((s) => s.id)));
  const [plan, setPlan] = useState<{ order: RouteStop[]; km: number; start: { lat: number; lng: number } | null } | null>(null);
  const [busy, setBusy] = useState(false);

  const build = async () => {
    setBusy(true);
    const chosen = stops.filter((s) => picked.has(s.id));
    const here = await new Promise<{ lat: number; lng: number } | null>((resolve) => {
      if (!navigator.geolocation) return resolve(null);
      navigator.geolocation.getCurrentPosition((p) => resolve({ lat: p.coords.latitude, lng: p.coords.longitude }), () => resolve(null), { timeout: 8000, maximumAge: 300_000 });
    });
    const r = planRoute(here ?? { lat: chosen[0].lat, lng: chosen[0].lng }, chosen);
    setPlan({ ...r, start: here });
    setBusy(false);
  };

  return (
    <Modal title={plan ? `Маршрут: ${plan.order.length} остановок, ≈ ${plan.km.toFixed(1)} км` : 'Маршрут'} onClose={onClose}>
      {stops.length === 0 && <p className="text-sm text-muted">На карте пока нет мастериц.</p>}
      {!plan ? (
        <div className="space-y-3">
          <p className="text-sm text-muted">Отмечены те, у кого нужно забрать работу или кому отвезти материалы.</p>
          <ul className="max-h-[50vh] divide-y divide-border overflow-y-auto">
            {stops.map((s) => (
              <li key={s.id}>
                <label className="flex cursor-pointer items-center gap-3 py-2">
                  <input type="checkbox" className="h-5 w-5 accent-primary" checked={picked.has(s.id)}
                    onChange={(e) => setPicked((p) => { const n = new Set(p); if (e.target.checked) n.add(s.id); else n.delete(s.id); return n; })} />
                  <span className="min-w-0">
                    <span className="block font-medium">{s.name}</span>
                    {s.note && <span className="block text-xs text-primary">{s.note}</span>}
                  </span>
                </label>
              </li>
            ))}
          </ul>
          <Button className="w-full" disabled={!picked.size || busy} onClick={build}><Route size={18} aria-hidden /> {busy ? 'Считаем…' : `Построить маршрут (${picked.size})`}</Button>
        </div>
      ) : (
        <div className="space-y-3">
          <ol className="space-y-2">
            {plan.order.map((s, i) => (
              <li key={s.id} className="flex items-center gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-primary text-sm font-bold text-white">{i + 1}</span>
                <span className="min-w-0"><span className="block font-medium">{s.name}</span>{s.note && <span className="block text-xs text-muted">{s.note}</span>}</span>
              </li>
            ))}
          </ol>
          <a href={yandexRouteUrl(plan.start, plan.order)} target="_blank" rel="noopener noreferrer"
            className="flex min-h-11 items-center justify-center gap-2 rounded-lg bg-primary px-4 font-semibold text-white hover:opacity-95">
            <Navigation size={18} aria-hidden /> Открыть в Яндекс Картах
          </a>
          <Button variant="ghost" className="w-full" onClick={() => setPlan(null)}>Изменить список</Button>
          {!plan.start && <p className="text-center text-xs text-muted">Место компьютера не определилось — маршрут начнётся от первой точки.</p>}
        </div>
      )}
    </Modal>
  );
}
