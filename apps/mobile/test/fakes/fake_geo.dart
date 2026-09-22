import 'package:geolocator/geolocator.dart';
import 'package:yusmus_mobile/core/location/geo.dart';

/// Test double for [Geo]: real `geolocator`/`permission_handler` calls hit platform channels that don't exist in the
/// widget-test harness. Defaults to "everything granted" so existing screens render normally; tests of the permission
/// gate itself pass a specific [gap] instead — [Geo.status] (inherited, unmodified) derives the same result from these
/// three low-level checks that the real implementation does.
class FakeGeo extends Geo {
  const FakeGeo({this.gap = LocationGap.none});
  final LocationGap gap;

  bool get _isForegroundGap => gap == LocationGap.foregroundDenied || gap == LocationGap.foregroundDeniedForever;
  bool get _isBackgroundGap => gap == LocationGap.backgroundDenied || gap == LocationGap.backgroundDeniedForever;

  @override
  Future<bool> servicesEnabled() async => gap != LocationGap.servicesDisabled;
  @override
  Future<LocationGap> foregroundStatus() async => _isForegroundGap ? gap : LocationGap.none;
  @override
  Future<LocationGap> backgroundStatus() async => _isBackgroundGap ? gap : LocationGap.none;
  @override
  Future<LocationGap> requestForeground() async => LocationGap.none;
  @override
  Future<LocationGap> requestBackground() async => LocationGap.none;
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<Position> current() async => _fixed;
  @override
  Stream<Position> watch() => const Stream.empty();

  static final _fixed = Position(
    latitude: 41.2995, longitude: 69.2401, timestamp: DateTime.utc(2026, 1, 1),
    accuracy: 5, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
  );
}
