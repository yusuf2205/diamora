import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/features/map/route_plan.dart';

/// Route planning: the shortest round of pickups / deliveries, opened in Yandex Maps.
void main() {
  RouteStop s(String id, double lat, double lng) => RouteStop(id: id, name: id, lat: lat, lng: lng);
  const start = (lat: 41.30, lng: 69.20);

  test('stops along a line are visited in line order, not in the order they were given', () {
    final r = planRoute(start, [s('far', 41.34, 69.20), s('near', 41.31, 69.20), s('mid', 41.32, 69.20)]);
    expect(r.order.map((x) => x.id), ['near', 'mid', 'far']);
    expect(r.km, closeTo(4.45, 0.1)); // 0.04° of latitude ≈ 4.45 km
  });

  test('the planned round is never longer than the given order (2-opt untangles crossings)', () {
    final stops = [s('a', 41.31, 69.21), s('b', 41.33, 69.19), s('c', 41.31, 69.19), s('d', 41.33, 69.21), s('e', 41.32, 69.25)];
    final given = planRoute(start, stops.take(1).toList()).km; // (smoke) one stop
    expect(given, greaterThan(0));
    final r = planRoute(start, stops);
    var manual = 0.0;
    var lat = start.lat, lng = start.lng;
    for (final x in stops) { manual += distanceKm(lat, lng, x.lat, x.lng); lat = x.lat; lng = x.lng; }
    expect(r.km, lessThanOrEqualTo(manual));
    expect(r.order.toSet().length, 5);
  });

  test('the Yandex link has every stop in order, from my place', () {
    final u = yandexRouteUrl(start, [s('a', 41.31, 69.21), s('b', 41.33, 69.19)]);
    expect(u.toString(), 'https://yandex.ru/maps/?rtext=41.3,69.2~41.31,69.21~41.33,69.19&rtt=auto');
    expect(yandexRouteUrl(null, [s('a', 41.31, 69.21)]).toString(), 'https://yandex.ru/maps/?rtext=~41.31,69.21&rtt=auto'); // «from here»
  });
}
