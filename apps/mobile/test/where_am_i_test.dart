import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:diamoraa_mobile/core/location/where_am_i.dart';

import 'fakes/fake_geo.dart';

Position _p(double lat, DateTime at) => Position(latitude: lat, longitude: 69.2, timestamp: at, accuracy: 50, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);

class _Geo extends FakeGeo {
  _Geo({this.last, this.rough});
  final Position? last;
  final Future<Position> Function()? rough;
  @override
  Future<Position?> lastKnown() async => last;
  @override
  Future<Position> approximate() => rough?.call() ?? Future.error('no fix');
}

/// «Где я» must answer fast on a tablet without GPS (it used to wait for a precise fix and gave up).
void main() {
  final now = DateTime(2026, 10, 1, 12);

  test('a recent last known place is used at once (no waiting for GPS)', () async {
    final r = await locate(_Geo(last: _p(41.31, now.subtract(const Duration(minutes: 3))), rough: () => Completer<Position>().future), () => null, now: now);
    expect(r?.lat, 41.31);
  });

  test('an old last known place: a rough network fix is preferred', () async {
    final r = await locate(_Geo(last: _p(41.31, now.subtract(const Duration(hours: 5))), rough: () async => _p(41.35, now)), () => null, now: now);
    expect(r?.lat, 41.35);
  });

  test('no fix at all: my point on the server, then the old place, then «unknown»', () async {
    expect((await locate(_Geo(), () => (lat: 41.4, lng: 69.3), now: now))?.lat, 41.4);
    expect((await locate(_Geo(last: _p(41.31, now.subtract(const Duration(days: 2)))), () => null, now: now))?.lat, 41.31);
    expect(await locate(_Geo(), () => null, now: now), isNull);
  });
}
