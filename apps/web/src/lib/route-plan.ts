/** A place to drive to (a worker's home or live position). */
export interface RouteStop { id: string; name: string; lat: number; lng: number; note?: string; visit?: string | null }
type Pt = { lat: number; lng: number };

/** Straight-line km: enough to ORDER stops in one city; the map app then drives the real roads. */
export function distanceKm(a: Pt, b: Pt) {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

const length = (start: Pt, order: RouteStop[]) => order.reduce((acc, s, i) => acc + distanceKm(i === 0 ? start : order[i - 1], s), 0);

/** The order to visit the stops from `start`: nearest first, then untangled (2-opt). The same as in the app. */
export function planRoute(start: Pt, stops: RouteStop[]): { order: RouteStop[]; km: number } {
  if (stops.length <= 1) return { order: [...stops], km: length(start, stops) };
  const left = [...stops];
  let order: RouteStop[] = [];
  let at: Pt = start;
  while (left.length) {
    left.sort((a, b) => distanceKm(at, a) - distanceKm(at, b));
    const next = left.shift()!;
    order.push(next);
    at = next;
  }
  let best = length(start, order);
  let improved = true;
  while (improved) {
    improved = false;
    for (let i = 0; i < order.length - 1; i++) {
      for (let k = i + 1; k < order.length; k++) {
        const cand = [...order.slice(0, i), ...order.slice(i, k + 1).reverse(), ...order.slice(k + 1)];
        const len = length(start, cand);
        if (len + 1e-9 < best) { order = cand; best = len; improved = true; }
      }
    }
  }
  return { order, km: best };
}

/** Yandex Maps with every stop in order; an empty start = «from where I am». Car route. */
export function yandexRouteUrl(start: Pt | null, order: RouteStop[]) {
  const pts = [start ? `${start.lat},${start.lng}` : '', ...order.map((s) => `${s.lat},${s.lng}`)];
  return `https://yandex.ru/maps/?rtext=${pts.join('~')}&rtt=auto`;
}
