import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../network/api_client.dart';
import 'geo.dart';

const _heartbeatInterval = Duration(minutes: 5);

/// Sends the CURRENT position to the server (D-030): on every movement past 25 m (via [Geo.watch]) and on a fixed heartbeat
/// so a stationary phone never goes silent. Battery-conscious by construction — no fixed-interval polling while moving,
/// no per-second updates. Failures are swallowed: the next tick (or the next movement) simply retries.
class LocationTracker {
  LocationTracker(this._geo, this._api);
  final Geo _geo;
  final ApiClient _api;
  StreamSubscription<Position>? _movement;
  Timer? _heartbeat;
  bool get isRunning => _movement != null;

  void start() {
    if (isRunning) return;
    _movement = _geo.watch().listen((p) => _report(p, background: false), onError: (_) {}, cancelOnError: false);
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _tick());
    unawaited(_tick()); // report once immediately so the server is never left with a very stale point
  }

  void stop() {
    _movement?.cancel();
    _movement = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _tick() async {
    try {
      await _report(await _geo.current(), background: true);
    } catch (_) {
      /* offline or momentarily unavailable: the next heartbeat retries */
    }
  }

  Future<void> _report(Position p, {required bool background}) async {
    double? finite(double v) => v.isFinite && v >= 0 ? v : null;
    try {
      await _api.postJson('/location', body: {
        'latitude': p.latitude,
        'longitude': p.longitude,
        if (finite(p.accuracy) != null) 'accuracy': p.accuracy,
        if (finite(p.heading) != null && p.heading <= 360) 'heading': p.heading,
        if (finite(p.speed) != null && p.speed <= 120) 'speed': p.speed,
        'recordedAt': p.timestamp.toIso8601String(),
        'isBackground': background,
      });
    } catch (_) {
      /* best-effort: never blocks the UI, the next report retries */
    }
  }
}
