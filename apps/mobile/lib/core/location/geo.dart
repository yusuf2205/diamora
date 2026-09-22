import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// What is still missing before background location can work (D-030, §19-22). The app checks EVERY step itself - it never
/// pretends it can silently turn on a system service, and it never enters the working part of the app until this is [ok].
enum LocationGap {
  /// The user must turn Location Services (GPS) on themselves — the app opens the system screen for it, nothing more.
  servicesDisabled,
  /// "While using the app" was denied or not asked yet.
  foregroundDenied,
  /// Denied "for good" (Android) / by Settings (iOS) — a request will no longer show a dialog; only Settings can fix it.
  foregroundDeniedForever,
  /// Foreground is granted but background ("Always") is not — needed so the position stays fresh while the app is not open.
  backgroundDenied,
  backgroundDeniedForever,
  none,
}

class LocationStatus {
  const LocationStatus(this.gap);
  final LocationGap gap;
  bool get ok => gap == LocationGap.none;
}

/// Thin, testable wrapper over `geolocator` + `permission_handler` (both are static-method plugins with no fake for tests).
abstract class Geo {
  const Geo();

  Future<bool> servicesEnabled();
  Future<LocationGap> foregroundStatus();
  Future<LocationGap> backgroundStatus();
  Future<LocationGap> requestForeground();
  Future<LocationGap> requestBackground();
  Future<void> openLocationSettings();
  Future<void> openAppSettings();
  Future<Position> current();
  Stream<Position> watch();

  /// The single source of truth for "is the app allowed to track right now" (§20's ordered checklist).
  Future<LocationStatus> status() async {
    if (!await servicesEnabled()) return const LocationStatus(LocationGap.servicesDisabled);
    final fg = await foregroundStatus();
    if (fg != LocationGap.none) return LocationStatus(fg);
    final bg = await backgroundStatus();
    return LocationStatus(bg);
  }
}

class GeolocatorGeo extends Geo {
  const GeolocatorGeo();

  @override
  Future<bool> servicesEnabled() => Geolocator.isLocationServiceEnabled();

  LocationGap _fromPermission(ph.PermissionStatus s, {required bool background}) {
    if (s.isGranted || s.isLimited) return LocationGap.none;
    if (s.isPermanentlyDenied) return background ? LocationGap.backgroundDeniedForever : LocationGap.foregroundDeniedForever;
    return background ? LocationGap.backgroundDenied : LocationGap.foregroundDenied;
  }

  @override
  Future<LocationGap> foregroundStatus() async => _fromPermission(await ph.Permission.locationWhenInUse.status, background: false);

  @override
  Future<LocationGap> backgroundStatus() async => _fromPermission(await ph.Permission.locationAlways.status, background: true);

  @override
  Future<LocationGap> requestForeground() async => _fromPermission(await ph.Permission.locationWhenInUse.request(), background: false);

  @override
  Future<LocationGap> requestBackground() async => _fromPermission(await ph.Permission.locationAlways.request(), background: true);

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => ph.openAppSettings().then((_) {});

  @override
  Future<Position> current() => Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

  /// Movement-triggered updates (25 m) plus geolocator's own internal throttling — battery-conscious by construction (§21).
  /// A separate periodic heartbeat (BackgroundTracker) covers the "stayed still for a long time" case.
  @override
  Stream<Position> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
      );
}
