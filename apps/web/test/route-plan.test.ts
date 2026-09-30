import { describe, expect, it } from 'vitest';
import { planRoute, yandexRouteUrl } from '@/lib/route-plan';

const s = (id: string, lat: number, lng = 69.2) => ({ id, name: id, lat, lng });
const start = { lat: 41.3, lng: 69.2 };

describe('route planning (web)', () => {
  it('stops along a line are visited in line order; the length is right', () => {
    const r = planRoute(start, [s('far', 41.34), s('near', 41.31), s('mid', 41.32)]);
    expect(r.order.map((x) => x.id)).toEqual(['near', 'mid', 'far']);
    expect(r.km).toBeCloseTo(4.45, 1);
  });
  it('the Yandex link has every stop in order; no start = «from here»', () => {
    expect(yandexRouteUrl(start, [s('a', 41.31, 69.21)])).toBe('https://yandex.ru/maps/?rtext=41.3,69.2~41.31,69.21&rtt=auto');
    expect(yandexRouteUrl(null, [s('a', 41.31, 69.21)])).toBe('https://yandex.ru/maps/?rtext=~41.31,69.21&rtt=auto');
  });
});
