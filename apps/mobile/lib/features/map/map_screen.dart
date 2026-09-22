import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
// Prefixed: mapkit.dart's barrel also exports Icon/TextStyle-like names that would otherwise collide with Flutter's
// own (Icon, TextStyle) — never import it unprefixed. image.dart (ImageProvider) merges into the same prefix.
import 'package:yandex_maps_mapkit_lite/image.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../team/models.dart';
import '../team/team_repository.dart' show liveLocationsProvider;
import '../team/team_screen.dart' show teamRoleLabel;

/// Marker colour: role first (who), freshness second (how current) — never a STALE point drawn as if it were live (M2 §14-17).
Color markerColor(LiveLocationRow row, ColorScheme scheme) {
  if (row.freshness == LocationFreshness.stale) return scheme.outline;
  switch (row.role) {
    case 'SUPER_ADMIN':
    case 'ADMIN':
      return scheme.primary;
    case 'MANAGER':
      return scheme.tertiary;
    default: // WORKER
      return row.freshness == LocationFreshness.live ? AppTokens.ok : scheme.secondary;
  }
}

String freshnessLabel(AppLocalizations l, LiveLocationRow row) {
  if (row.freshness == LocationFreshness.live) return l.locationJustNow;
  final minutes = row.ageSeconds ~/ 60;
  return row.freshness == LocationFreshness.recent ? l.locationRecentMinutes(minutes) : l.locationStaleMinutes(minutes);
}

/// SUPER_ADMIN / ADMIN / MANAGER live map (M2 §14-16, D-026). Data is `GET /v1/locations` — already scoped server-side
/// exactly like everywhere else (a MANAGER only ever receives her own workers' coordinates; nothing here re-filters on
/// the client, there is nothing broader to filter FROM). Markers differ by role and by freshness (never a stale point
/// drawn as if it were live). Native MapKit rendering itself needs a real device — not verified on-device in this round
/// (honest gap); the data layer and marker-colour/label logic above are plain Dart and unit-tested.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ymk.MapWindow? _mapWindow;
  final _placemarks = <ymk.PlacemarkMapObject, LiveLocationRow>{};
  final _markerImages = <String, Future<ymk.ImageProvider>>{};
  bool _centered = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(liveLocationsProvider, (_, next) {
      final rows = next.value;
      if (rows != null) _applyMarkers(rows);
    });
    final async = ref.watch(liveLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.map),
        actions: [IconButton(icon: const Icon(Icons.list), tooltip: l.mapListView, onPressed: () => context.push('/admin/profile/locations'))],
      ),
      body: AppConfig.yandexMapKitKey.isEmpty
          ? EmptyState(icon: Icons.map_outlined, title: l.mapEmpty, hint: 'YANDEX_MAPKIT_KEY is not configured')
          : Stack(children: [
              YandexMap(onMapCreated: _onMapCreated),
              if (async.isLoading) const Positioned(top: 12, left: 0, right: 0, child: Center(child: LinearProgressIndicator())),
              if (async.hasValue && async.value!.isEmpty)
                Positioned(bottom: 24, left: 24, right: 24, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.mapEmpty)))),
            ]),
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    final rows = ref.read(liveLocationsProvider).value;
    if (rows != null) _applyMarkers(rows);
  }

  Future<void> _applyMarkers(List<LiveLocationRow> rows) async {
    final window = _mapWindow;
    if (window == null) return;
    final collection = window.map.mapObjects;
    collection.clear();
    _placemarks.clear();
    final scheme = Theme.of(context).colorScheme;
    for (final row in rows) {
      final color = markerColor(row, scheme);
      final image = await _dotImage(color);
      final placemark = collection.addPlacemarkWithImageStyle(
        ymk.Point(latitude: row.latitude, longitude: row.longitude), image,
        const ymk.IconStyle(scale: 1.0, zIndex: 1),
      );
      placemark.setText(row.fullName);
      placemark.addTapListener(_TapListener((_, _) {
        _onTap(row);
        return true;
      }));
      _placemarks[placemark] = row;
    }
    if (!_centered && rows.isNotEmpty) {
      _centered = true;
      window.map.move(ymk.CameraPosition(ymk.Point(latitude: rows.first.latitude, longitude: rows.first.longitude), zoom: 11, azimuth: 0, tilt: 0));
    }
  }

  /// A small filled circle rendered straight with dart:ui (no widget tree needed) — cached per colour.
  Future<ymk.ImageProvider> _dotImage(Color color) {
    final key = color.toARGB32().toRadixString(16);
    return _markerImages.putIfAbsent(key, () async {
      const size = 72.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const center = Offset(size / 2, size / 2);
      canvas.drawCircle(center, size / 2, Paint()..color = Colors.white);
      canvas.drawCircle(center, size / 2 - 4, Paint()..color = color);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      return ymk.ImageProvider(() async => image);
    });
  }

  void _onTap(LiveLocationRow row) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.fullName, style: Theme.of(ctx).textTheme.titleMedium),
            Text('${teamRoleLabel(l, row.role)}${row.workerCode != null ? ' · ${row.workerCode}' : ''}'),
            const SizedBox(height: 4),
            Row(children: [
              Icon(row.online ? Icons.circle : Icons.circle_outlined, size: 10, color: row.online ? AppTokens.ok : Theme.of(ctx).colorScheme.outline),
              const SizedBox(width: 6),
              Text(row.online ? l.onlineNow : l.offlineNow),
              const SizedBox(width: 12),
              Text(freshnessLabel(l, row), style: TextStyle(color: row.freshness == LocationFreshness.stale ? Theme.of(ctx).colorScheme.error : null)),
            ]),
            if (row.phone != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(row.phone!)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (row.phone != null) FilledButton.tonalIcon(onPressed: () => launchUrl(Uri.parse('tel:${row.phone}')), icon: const Icon(Icons.call), label: Text(l.call)),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('yandexmaps://maps.yandex.ru/?rtext=~${row.latitude},${row.longitude}&rtt=auto'), mode: LaunchMode.externalApplication)
                    .catchError((_) => launchUrl(Uri.parse('https://yandex.uz/maps/?rtext=~${row.latitude},${row.longitude}&rtt=auto'))),
                icon: const Icon(Icons.directions_outlined), label: Text(l.route),
              ),
              if (row.workerId != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/admin/workers/${row.workerId}');
                  },
                  icon: const Icon(Icons.badge_outlined), label: Text(l.mapOpenProfile),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TapListener implements ymk.MapObjectTapListener {
  _TapListener(this._onTap);
  final bool Function(ymk.MapObject, ymk.Point) _onTap;
  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) => _onTap(mapObject, point);
}
