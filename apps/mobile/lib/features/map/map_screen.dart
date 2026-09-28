import '../../core/ui/navigate.dart';
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
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart' show mapkit;

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../team/models.dart';
import '../auth/auth_controller.dart';
import '../team/team_repository.dart' show liveLocationsProvider, managersProvider;
import '../team/team_screen.dart' show teamRoleLabel;

/// What is waiting there wins (red overdue, green ready to collect, blue to deliver); otherwise role first (who),
/// freshness second (how current) — never a STALE point drawn as if it were live (M2 §14-17).
Color markerColor(LiveLocationRow row, ColorScheme scheme) {
  if (row.overdue) return workOverdueColor;
  if (row.toPickup) return workPickupColor;
  if (row.toDeliver) return workDeliverColor;
  if (row.isHome) return scheme.outline;
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

const workOverdueColor = Color(0xFFDC2626);
const workPickupColor = Color(0xFF16A34A);
const workDeliverColor = Color(0xFF2563EB);

/// Map filters: what is waiting at the worker's, and whose manager she is.
enum MapWorkFilter { any, toDeliver, toPickup, overdue }

bool mapRowMatches(LiveLocationRow r, MapWorkFilter work, String? managerId) {
  final byWork = switch (work) { MapWorkFilter.any => true, MapWorkFilter.toDeliver => r.toDeliver, MapWorkFilter.toPickup => r.toPickup, MapWorkFilter.overdue => r.overdue };
  return byWork && (managerId == null || r.managerId == managerId || r.userId == managerId);
}

String freshnessLabel(AppLocalizations l, LiveLocationRow row) => positionAgeLabel(l, row.freshness, row.ageSeconds);

/// "сейчас" / "обновлено 12 мин назад" / "обновлено 4 ч 51 мин назад" / "от 24.09.2026, 17:05".
String positionAgeLabel(AppLocalizations l, LocationFreshness freshness, int ageSeconds, {DateTime? now, bool compact = false}) {
  if (freshness == LocationFreshness.live) return compact ? l.ageNow : l.locationJustNow;
  final minutes = ageSeconds ~/ 60;
  if (minutes < 60) return compact ? l.ageMinutes(minutes < 1 ? 1 : minutes) : l.locationRecentMinutes(minutes < 1 ? 1 : minutes);
  if (minutes < 24 * 60) return compact ? l.ageHours(minutes ~/ 60, minutes % 60) : l.locationUpdatedHours(minutes ~/ 60, minutes % 60);
  final at = (now ?? DateTime.now()).subtract(Duration(seconds: ageSeconds));
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(at.day)}.${two(at.month)}.${at.year}, ${two(at.hour)}:${two(at.minute)}';
  return compact ? date : l.locationUpdatedOn(date);
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
  AppLifecycleListener? _life;
  MapWorkFilter _work = MapWorkFilter.any;
  String? _managerId;

  List<LiveLocationRow> _visible(List<LiveLocationRow> rows) => rows.where((r) => mapRowMatches(r, _work, _managerId)).toList();
  void _refilter() {
    final rows = ref.read(liveLocationsProvider).value;
    if (rows != null) _applyMarkers(_visible(rows));
  }

  // MapKit draws only its empty grid ("squares") until it is STARTED: onStart while the map is on screen, onStop when
  // it leaves or the app goes to the background (Yandex MapKit lifecycle contract).
  @override
  void initState() {
    super.initState();
    if (AppConfig.yandexMapKitKey.isEmpty) return;
    mapkit.onStart();
    _life = AppLifecycleListener(onShow: mapkit.onStart, onHide: mapkit.onStop);
  }

  @override
  void dispose() {
    _life?.dispose();
    if (AppConfig.yandexMapKitKey.isNotEmpty) mapkit.onStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(liveLocationsProvider, (_, next) {
      final rows = next.value;
      if (rows != null) _applyMarkers(_visible(rows));
    });
    final async = ref.watch(liveLocationsProvider);
    final me = ref.watch(authControllerProvider).value;
    final managers = me?.role == 'MANAGER' ? const <ManagerSummary>[] : (ref.watch(managersProvider).value ?? const <ManagerSummary>[]);
    final chips = <(MapWorkFilter, String, Color?)>[
      (MapWorkFilter.any, l.mapFilterAll, null),
      (MapWorkFilter.toDeliver, l.mapFilterToDeliver, workDeliverColor),
      (MapWorkFilter.toPickup, l.mapFilterToPickup, workPickupColor),
      (MapWorkFilter.overdue, l.mapFilterOverdue, workOverdueColor),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.map),
        actions: [IconButton(icon: const Icon(Icons.list_rounded), tooltip: l.mapListView, onPressed: () => context.push('/admin/profile/locations'))],
      ),
      body: AppConfig.yandexMapKitKey.isEmpty
          ? EmptyState(icon: Icons.map_rounded, title: l.mapEmpty, hint: 'YANDEX_MAPKIT_KEY is not configured')
          : Stack(children: [
              YandexMap(onMapCreated: _onMapCreated),
              Positioned(
                top: 8, left: 0, right: 0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    for (final c in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          key: Key('mapFilter-${c.$1.name}'),
                          avatar: c.$3 == null ? null : CircleAvatar(backgroundColor: c.$3, radius: 6),
                          label: Text(c.$2),
                          selected: _work == c.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() { _work = c.$1; _refilter(); }),
                        ),
                      ),
                    if (managers.isNotEmpty)
                      PopupMenuButton<String?>(
                        key: const Key('mapFilterManager'),
                        tooltip: l.managerLabel,
                        onSelected: (v) => setState(() { _managerId = v == '' ? null : v; _refilter(); }),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: '', child: Text(l.mapFilterAllManagers)),
                          for (final m in managers) PopupMenuItem(value: m.user.id, child: Text(m.user.fullName)),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.person_rounded, size: 16),
                          label: Text(_managerId == null ? l.mapFilterAllManagers : managers.where((m) => m.user.id == _managerId).map((m) => m.user.fullName).firstOrNull ?? l.managerLabel),
                        ),
                      ),
                  ]),
                ),
              ),
              if (async.isLoading) const Positioned(top: 12, left: 0, right: 0, child: Center(child: LinearProgressIndicator())),
              if (async.hasValue && async.value!.isEmpty)
                Positioned(bottom: 24, left: 24, right: 24, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.mapEmpty)))),
            ]),
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    final rows = ref.read(liveLocationsProvider).value;
    if (rows != null) _applyMarkers(_visible(rows));
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
            if (row.isHome)
              Text(l.mapAtHome, style: TextStyle(color: Theme.of(ctx).colorScheme.outline))
            else
              Row(children: [
                Icon(Icons.circle_rounded, size: 10, color: row.online ? AppTokens.ok : Theme.of(ctx).colorScheme.outline),
                const SizedBox(width: 6),
                Text(row.online ? l.onlineNow : l.offlineNow),
                const SizedBox(width: 12),
                Flexible(child: Text(freshnessLabel(l, row), style: TextStyle(color: row.freshness == LocationFreshness.stale ? Theme.of(ctx).colorScheme.error : null))),
              ]),
            if (row.toDeliver) Text('● ${l.mapFilterToDeliver}', style: const TextStyle(color: workDeliverColor, fontWeight: FontWeight.w600)),
            if (row.toPickup) Text('● ${l.mapFilterToPickup}', style: const TextStyle(color: workPickupColor, fontWeight: FontWeight.w600)),
            if (row.overdue) Text('● ${l.mapFilterOverdue}', style: const TextStyle(color: workOverdueColor, fontWeight: FontWeight.w600)),
            if (row.phone != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(row.phone!)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (row.phone != null) FilledButton.tonalIcon(onPressed: () => launchUrl(Uri.parse('tel:${row.phone}')), icon: const Icon(Icons.call_rounded), label: Text(l.call)),
              OutlinedButton.icon(
                onPressed: () => openRoute(row.latitude, row.longitude),
                icon: const Icon(Icons.directions_rounded), label: Text(l.route),
              ),
              if (row.workerId != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/admin/workers/${row.workerId}');
                  },
                  icon: const Icon(Icons.badge_rounded), label: Text(l.mapOpenProfile),
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
