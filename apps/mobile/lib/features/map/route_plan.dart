import 'dart:math' as math;

/// A place to drive to (a worker's home or live position).
class RouteStop {
  const RouteStop({required this.id, required this.name, required this.lat, required this.lng, this.note, this.visit});
  /// «Удобное время» in words
  final String? visit;
  final String id;
  final String name;
  final double lat;
  final double lng;
  /// «забрать» / «отвезти» - shown next to the name
  final String? note;
}

/// Straight-line distance in km (good enough to ORDER stops in one city; the map app then drives the real roads).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

double _length(({double lat, double lng}) start, List<RouteStop> order) {
  var total = 0.0;
  var lat = start.lat, lng = start.lng;
  for (final s in order) {
    total += distanceKm(lat, lng, s.lat, s.lng);
    lat = s.lat;
    lng = s.lng;
  }
  return total;
}

/// The order to visit the stops from [start]: nearest first, then untangled (2-opt) so the path never crosses itself.
/// A route with 10-20 stops is planned instantly; the result is the order and its length (km, straight lines).
({List<RouteStop> order, double km}) planRoute(({double lat, double lng}) start, List<RouteStop> stops) {
  if (stops.length <= 1) return (order: [...stops], km: _length(start, stops));
  final left = [...stops];
  final order = <RouteStop>[];
  var lat = start.lat, lng = start.lng;
  while (left.isNotEmpty) {
    left.sort((a, b) => distanceKm(lat, lng, a.lat, a.lng).compareTo(distanceKm(lat, lng, b.lat, b.lng)));
    final next = left.removeAt(0);
    order.add(next);
    lat = next.lat;
    lng = next.lng;
  }
  // 2-opt: reverse any piece that makes the path shorter, until nothing helps
  var best = _length(start, order);
  var improved = true;
  while (improved) {
    improved = false;
    for (var i = 0; i < order.length - 1; i++) {
      for (var k = i + 1; k < order.length; k++) {
        final candidate = [...order.sublist(0, i), ...order.sublist(i, k + 1).reversed, ...order.sublist(k + 1)];
        final len = _length(start, candidate);
        if (len + 1e-9 < best) {
          order
            ..clear()
            ..addAll(candidate);
          best = len;
          improved = true;
        }
      }
    }
  }
  return (order: order, km: best);
}

/// Yandex Maps with every stop in order (opens the app when installed, else the site); car route.
Uri yandexRouteUrl(({double lat, double lng})? start, List<RouteStop> order) {
  final points = [
    if (start != null) '${start.lat},${start.lng}' else '',
    for (final s in order) '${s.lat},${s.lng}',
  ];
  return Uri.parse('https://yandex.ru/maps/?rtext=${points.join('~')}&rtt=auto');
}
