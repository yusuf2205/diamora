import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/team/team_repository.dart' show liveLocationsProvider;
import '../providers.dart' show geoProvider;
import 'geo.dart';

typedef LatLng = ({double lat, double lng});

/// «Где я» for the map and routes, fast even on a tablet without GPS: the phone's recent last known place (instant),
/// else a rough network fix (a few seconds), else my own point the server already has, else an older last known place.
/// null = really unknown (the caller then starts from the first stop / says so).
Future<LatLng?> whereAmI(WidgetRef ref) {
  LatLng? serverPoint() {
    final me = ref.read(authControllerProvider).value;
    final rows = ref.read(liveLocationsProvider).value;
    if (me == null || rows == null) return null;
    for (final r in rows) {
      if (r.userId == me.id && !r.isHome) return (lat: r.latitude, lng: r.longitude);
    }
    return null;
  }

  return locate(ref.read(geoProvider), serverPoint);
}

/// The order of tries, testable without a widget tree.
Future<LatLng?> locate(Geo geo, LatLng? Function() serverPoint, {DateTime? now}) async {
  Position? last;
  try {
    last = await geo.lastKnown().timeout(const Duration(seconds: 2));
    if (last != null && (now ?? DateTime.now()).difference(last.timestamp) < const Duration(minutes: 15)) return (lat: last.latitude, lng: last.longitude);
  } catch (_) {}
  try {
    final p = await geo.approximate().timeout(const Duration(seconds: 9));
    return (lat: p.latitude, lng: p.longitude);
  } catch (_) {}
  final mine = serverPoint();
  if (mine != null) return mine;
  if (last != null) return (lat: last.latitude, lng: last.longitude);
  return null;
}
