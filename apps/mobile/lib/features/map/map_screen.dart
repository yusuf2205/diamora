import '../../core/ui/navigate.dart';
import 'dart:async';
import 'dart:math' as math;
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
import '../../core/providers.dart' show geoProvider;
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
  // MapKit does NOT retain tap listeners (see MapObject.addTapListener): without these strong references they get
  // garbage-collected and a tap on a person silently does nothing.
  final _tapListeners = <_TapListener>[];
  LiveLocationRow? _selected;
  final _markerImages = <String, Future<ymk.ImageProvider>>{};
  bool _centered = false;
  AppLifecycleListener? _life;
  MapWorkFilter _work = MapWorkFilter.any;
  String? _managerId;
  // Yandex-like controls: zoom, my place, compass (when turned), traffic, everyone in view, 3D
  ymk.TrafficLayer? _traffic;
  ymk.UserLocationLayer? _me;
  bool _trafficOn = false;
  bool _tilted = false;
  double _azimuth = 0;
  _CameraListener? _cameraListener;
  List<LiveLocationRow> _shown = const [];
  int _markerGeneration = 0;

  List<LiveLocationRow> _visible(List<LiveLocationRow> rows) => rows.where((r) => mapRowMatches(r, _work, _managerId)).toList();
  void _refilter() {
    final rows = ref.read(liveLocationsProvider).value;
    if (rows != null) _applyMarkers(_visible(rows));
  }

  /// the open card follows fresh data (position, online, work) and closes when the person is filtered out
  void _syncSelected(List<LiveLocationRow> visible) {
    final s = _selected;
    if (s == null || !mounted) return;
    setState(() => _selected = visible.where((r) => r.userId == s.userId && r.isHome == s.isHome).firstOrNull);
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
    final cl = _cameraListener;
    if (cl != null) _mapWindow?.map.removeCameraListener(cl);
    _me?.setVisible(false);
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
              Positioned.fill(
                top: 60,
                child: MapControls(
                  azimuth: _azimuth,
                  traffic: _trafficOn,
                  tilted: _tilted,
                  onZoom: _zoom,
                  onMyPlace: _myPlace,
                  onNorth: _north,
                  onTraffic: _toggleTraffic,
                  onShowAll: () => _showAll(_shown),
                  onTilt: _toggleTilt,
                  bottomInset: _selected != null && MediaQuery.sizeOf(context).width < 600 ? 250 : 0,
                ),
              ),
              if (_selected != null)
                Positioned(
                  left: 12, bottom: 12,
                  right: MediaQuery.sizeOf(context).width >= 600 ? null : 12,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _PersonCard(key: const Key('mapPersonCard'), row: _selected!, onClose: () => setState(() => _selected = null)),
                  ),
                ),
              if (async.hasValue && async.value!.isEmpty)
                Positioned(bottom: 24, left: 24, right: 24, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.mapEmpty)))),
            ]),
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    // the map follows the app's theme (dark app -> night map), like Yandex
    window.map.nightModeEnabled = Theme.of(context).brightness == Brightness.dark;
    try {
      _me = mapkit.createUserLocationLayer(window)..setVisible(true); // my own arrow on the map
    } catch (_) {/* no location permission yet */}
    _cameraListener = _CameraListener((position) {
      final a = position.azimuth;
      if (mounted && (a - _azimuth).abs() > 1) setState(() => _azimuth = a);
    });
    window.map.addCameraListener(_cameraListener!);
    final rows = ref.read(liveLocationsProvider).value;
    if (rows != null) _applyMarkers(_visible(rows));
  }

  Future<void> _applyMarkers(List<LiveLocationRow> rows) async {
    final window = _mapWindow;
    if (window == null) return;
    // fresh data can arrive while pins are still being drawn: only the newest call may touch the map (two overlapping
    // calls used to leave every person on it twice)
    final generation = ++_markerGeneration;
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final images = [for (final row in rows) await _pinImage(markerColor(row, scheme), row.isHome ? null : initialsOf(row.fullName), dpr)];
    if (!mounted || generation != _markerGeneration || !identical(window, _mapWindow)) return;
    final collection = window.map.mapObjects;
    collection.clear();
    _placemarks.clear();
    _tapListeners.clear();
    _shown = rows;
    for (final (i, row) in rows.indexed) {
      final image = images[i];
      final placemark = collection.addPlacemarkWithImageStyle(
        ymk.Point(latitude: row.latitude, longitude: row.longitude), image,
        // the pin's tip stands on the point; people waiting for something are drawn above the rest
        ymk.IconStyle(scale: 1.0, zIndex: row.overdue || row.toPickup || row.toDeliver ? 2 : 1, anchor: const math.Point(0.5, 1.0)),
      );
      // the name under the dot, readable on any background
      placemark.setTextWithStyle(const ymk.TextStyle(size: 11, placement: ymk.TextStylePlacement.Bottom, outlineWidth: 2), text: row.fullName);
      final listener = _TapListener((_, _) {
        _onTap(row);
        return true;
      });
      _tapListeners.add(listener);
      placemark.addTapListener(listener);
      _placemarks[placemark] = row;
    }
    _syncSelected(rows);
    if (!_centered && rows.isNotEmpty) {
      _centered = true;
      _showAll(rows, animate: false); // everyone in view at once
    }
  }

  static const _smooth = ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.3);

  ymk.CameraPosition? get _camera => _mapWindow?.map.cameraPosition;

  void _zoom(double by) {
    final c = _camera;
    if (c == null) return;
    _mapWindow!.map.move(ymk.CameraPosition(c.target, zoom: (c.zoom + by).clamp(2, 20), azimuth: c.azimuth, tilt: c.tilt), animation: _smooth);
  }

  void _north() {
    final c = _camera;
    if (c == null) return;
    _mapWindow!.map.move(ymk.CameraPosition(c.target, zoom: c.zoom, azimuth: 0, tilt: 0), animation: _smooth);
    setState(() { _azimuth = 0; _tilted = false; });
  }

  void _toggleTilt() {
    final c = _camera;
    if (c == null) return;
    setState(() => _tilted = !_tilted);
    _mapWindow!.map.move(ymk.CameraPosition(c.target, zoom: c.zoom, azimuth: c.azimuth, tilt: _tilted ? 50 : 0), animation: _smooth);
  }

  void _toggleTraffic() {
    final w = _mapWindow;
    if (w == null) return;
    _traffic ??= mapkit.createTrafficLayer(w);
    setState(() => _trafficOn = !_trafficOn);
    _traffic!.setTrafficVisible(_trafficOn);
  }

  /// the camera around every shown person (one person: close up on her)
  void _showAll(List<LiveLocationRow> rows, {bool animate = true}) {
    final w = _mapWindow;
    if (w == null || rows.isEmpty) return;
    final c = _camera;
    final anim = animate ? _smooth : const ymk.Animation();
    if (rows.length == 1) {
      w.map.move(ymk.CameraPosition(ymk.Point(latitude: rows.first.latitude, longitude: rows.first.longitude), zoom: 15, azimuth: c?.azimuth ?? 0, tilt: c?.tilt ?? 0), animation: anim);
      return;
    }
    final lats = rows.map((r) => r.latitude); final lons = rows.map((r) => r.longitude);
    final box = ymk.BoundingBox(ymk.Point(latitude: lats.reduce(math.min), longitude: lons.reduce(math.min)), ymk.Point(latitude: lats.reduce(math.max), longitude: lons.reduce(math.max)));
    final fit = w.map.cameraPositionForGeometry(ymk.Geometry.fromBoundingBox(box));
    // a little room around the edge pins, and never closer than a street
    w.map.move(ymk.CameraPosition(fit.target, zoom: math.min(fit.zoom - 0.6, 16), azimuth: fit.azimuth, tilt: fit.tilt), animation: anim);
  }

  Future<void> _myPlace() async {
    final l = AppLocalizations.of(context);
    try {
      final p = await ref.read(geoProvider).current().timeout(const Duration(seconds: 12));
      final c = _camera;
      _mapWindow?.map.move(ymk.CameraPosition(ymk.Point(latitude: p.latitude, longitude: p.longitude), zoom: 16, azimuth: c?.azimuth ?? 0, tilt: c?.tilt ?? 0), animation: _smooth);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.mapNoMyPlace)));
    }
  }

  /// A pin like Yandex's: a coloured circle with the person's initials (a house for a home address), a white rim, a
  /// soft shadow and a tip that stands on the point. Rendered straight with dart:ui at the phone's pixel density; cached.
  Future<ymk.ImageProvider> _pinImage(Color color, String? initials, double dpr) {
    final key = '${color.toARGB32().toRadixString(16)}|${initials ?? '⌂'}|$dpr';
    return _markerImages.putIfAbsent(key, () async {
      final w = 44 * dpr, h = 54 * dpr, r = 20 * dpr;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(w / 2, r + 2 * dpr);
      final pin = Path()
        ..addOval(Rect.fromCircle(center: center, radius: r))
        ..moveTo(w / 2 - 7 * dpr, center.dy + r - 4 * dpr)
        ..lineTo(w / 2, h - 1 * dpr)
        ..lineTo(w / 2 + 7 * dpr, center.dy + r - 4 * dpr)
        ..close();
      canvas.drawShadow(pin, Colors.black, 3 * dpr, false);
      canvas.drawPath(pin, Paint()..color = Colors.white);
      canvas.drawCircle(center, r - 3 * dpr, Paint()..color = color);
      final label = initials ?? String.fromCharCode(Icons.home_rounded.codePoint);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: (initials == null ? 20 : 14) * dpr,
            fontWeight: FontWeight.w800,
            fontFamily: initials == null ? Icons.home_rounded.fontFamily : null,
            package: initials == null ? Icons.home_rounded.fontPackage : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
      return ymk.ImageProvider(() async => image);
    });
  }

  void _onTap(LiveLocationRow row) {
    if (!mounted) return;
    setState(() => _selected = row);
  }
}

/// Who it is, right away: role, online / how fresh the point is, what is waiting at her place, and call / route /
/// profile — shown over the map at once on a tap (no extra loading).
class _PersonCard extends StatelessWidget {
  const _PersonCard({super.key, required this.row, required this.onClose});
  final LiveLocationRow row;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 6,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 8, backgroundColor: markerColor(row, scheme)),
            const SizedBox(width: 10),
            Expanded(child: Text(row.fullName, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
            IconButton(key: const Key('mapPersonClose'), icon: const Icon(Icons.close_rounded), tooltip: MaterialLocalizations.of(context).closeButtonTooltip, onPressed: onClose),
          ]),
          Text('${teamRoleLabel(l, row.role)}${row.workerCode != null ? ' · ${row.workerCode}' : ''}'),
          const SizedBox(height: 4),
          if (row.isHome)
            Text(l.mapAtHome, style: TextStyle(color: scheme.outline))
          else
            Row(children: [
              Icon(Icons.circle_rounded, size: 10, color: row.online ? AppTokens.ok : scheme.outline),
              const SizedBox(width: 6),
              Text(row.online ? l.onlineNow : l.offlineNow),
              const SizedBox(width: 12),
              Flexible(child: Text(freshnessLabel(l, row), style: TextStyle(color: row.freshness == LocationFreshness.stale ? scheme.error : null))),
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
                onPressed: () => context.push('/admin/workers/${row.workerId}'),
                icon: const Icon(Icons.badge_rounded), label: Text(l.mapOpenProfile),
              ),
          ]),
        ]),
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

class _CameraListener implements ymk.MapCameraListener {
  _CameraListener(this._on);
  final void Function(ymk.CameraPosition) _on;
  @override
  void onCameraPositionChanged(ymk.Map map, ymk.CameraPosition cameraPosition, ymk.CameraUpdateReason cameraUpdateReason, bool finished) => _on(cameraPosition);
}

/// «НА» for «Нигора Азимова»
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.characters.first;
  final b = parts.length > 1 ? parts[1].characters.first : '';
  return (a + b).toUpperCase();
}

/// The map's buttons, like Yandex Maps: on the right a column with zoom + / −, the compass (only when the map is turned
/// or tilted) and «моё место»; at the top right traffic, «все на карте» and 3D. Big round-cornered white buttons with a
/// soft shadow, easy to hit on a phone and a tablet.
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.azimuth,
    required this.traffic,
    required this.tilted,
    required this.onZoom,
    required this.onMyPlace,
    required this.onNorth,
    required this.onTraffic,
    required this.onShowAll,
    required this.onTilt,
    this.bottomInset = 0,
  });
  final double azimuth;
  final bool traffic;
  final bool tilted;
  final void Function(double by) onZoom;
  final VoidCallback onMyPlace;
  final VoidCallback onNorth;
  final VoidCallback onTraffic;
  final VoidCallback onShowAll;
  final VoidCallback onTilt;
  /// room for the person's card at the bottom (phones)
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final turned = azimuth.abs() > 1 && (360 - azimuth).abs() > 1;
    return Stack(children: [
      Positioned(
        top: 8, right: 12,
        child: Column(children: [
          MapButton(key: const Key('mapTraffic'), tooltip: l.mapTraffic, icon: Icons.traffic_rounded, active: traffic, onTap: onTraffic),
          const SizedBox(height: 10),
          MapButton(key: const Key('mapShowAll'), tooltip: l.mapShowAll, icon: Icons.groups_rounded, onTap: onShowAll),
          const SizedBox(height: 10),
          MapButton(key: const Key('mapTilt'), tooltip: l.map3d, label: tilted ? '2D' : '3D', active: tilted, onTap: onTilt),
        ]),
      ),
      Positioned(
        right: 12, bottom: 16 + bottomInset,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          MapButton(key: const Key('mapZoomIn'), tooltip: l.mapZoomIn, icon: Icons.add_rounded, onTap: () => onZoom(1)),
          const SizedBox(height: 10),
          MapButton(key: const Key('mapZoomOut'), tooltip: l.mapZoomOut, icon: Icons.remove_rounded, onTap: () => onZoom(-1)),
          const SizedBox(height: 24),
          if (turned || tilted) ...[
            MapButton(
              key: const Key('mapNorth'),
              tooltip: l.mapNorth,
              round: true,
              onTap: onNorth,
              child: Transform.rotate(angle: -azimuth * math.pi / 180, child: const _NorthArrow()),
            ),
            const SizedBox(height: 10),
          ],
          MapButton(key: const Key('mapMyPlace'), tooltip: l.mapMyPlace, icon: Icons.near_me_rounded, round: true, big: true, onTap: onMyPlace),
        ]),
      ),
    ]);
  }
}

class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.tooltip, required this.onTap, this.icon, this.label, this.child, this.active = false, this.round = false, this.big = false});
  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final bool active;
  final bool round;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = big ? 60.0 : 52.0;
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final shape = round ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? scheme.primary : scheme.surface,
        elevation: 4,
        shadowColor: Colors.black38,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: child ??
                  (label != null
                      ? Text(label!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: fg))
                      : Icon(icon, size: big ? 28 : 26, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The compass needle: red half points north.
class _NorthArrow extends StatelessWidget {
  const _NorthArrow();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(18, 30), painter: _NorthPainter(Theme.of(context).colorScheme.outline));
}

class _NorthPainter extends CustomPainter {
  _NorthPainter(this.south);
  final Color south;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h / 2)..lineTo(0, h / 2)..close(), Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(Path()..moveTo(0, h / 2)..lineTo(w, h / 2)..lineTo(w / 2, h)..close(), Paint()..color = south);
  }

  @override
  bool shouldRepaint(_NorthPainter old) => old.south != south;
}
