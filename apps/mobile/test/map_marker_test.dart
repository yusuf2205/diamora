import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/core/theme/app_theme.dart';
import 'package:diamoraa_mobile/features/map/map_screen.dart';
import 'package:diamoraa_mobile/features/team/models.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';
import 'package:diamoraa_mobile/l10n/app_localizations_ru.dart';

LiveLocationRow row({required String role, required LocationFreshness freshness, int ageSeconds = 0}) => LiveLocationRow(
      userId: 'u1', role: role, fullName: 'Тест', latitude: 41.3, longitude: 69.2, ageSeconds: ageSeconds,
      stale: freshness == LocationFreshness.stale, freshness: freshness,
    );

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  final l = AppLocalizationsRu();

  group('markerColor (M2 §14-17): role first, freshness second — a STALE point is never coloured as live', () {
    test('a STALE point is always the neutral "outline" colour, whatever the role', () {
      for (final role in ['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'WORKER']) {
        expect(markerColor(row(role: role, freshness: LocationFreshness.stale), scheme), scheme.outline, reason: role);
      }
    });

    test('SUPER_ADMIN/ADMIN share the primary colour; MANAGER gets tertiary; a LIVE worker gets the "ok" green', () {
      expect(markerColor(row(role: 'SUPER_ADMIN', freshness: LocationFreshness.live), scheme), scheme.primary);
      expect(markerColor(row(role: 'ADMIN', freshness: LocationFreshness.recent), scheme), scheme.primary);
      expect(markerColor(row(role: 'MANAGER', freshness: LocationFreshness.live), scheme), scheme.tertiary);
      expect(markerColor(row(role: 'WORKER', freshness: LocationFreshness.live), scheme), AppTokens.ok);
      expect(markerColor(row(role: 'WORKER', freshness: LocationFreshness.recent), scheme), scheme.secondary);
    });
  });

  group('freshnessLabel: never words a RECENT/STALE point as if it were happening right now', () {
    test('LIVE says "now"; RECENT/STALE carry the actual age in minutes', () {
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.live, ageSeconds: 30)), l.locationJustNow);
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.recent, ageSeconds: 300)), l.locationRecentMinutes(5));
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.stale, ageSeconds: 1200)), l.locationStaleMinutes(20));
    });
  });

  group('map filters: what is waiting at her place, whose manager', () {
    LiveLocationRow w({bool deliver = false, bool pickup = false, bool overdue = false, String? manager}) => LiveLocationRow(
          userId: 'u', role: 'WORKER', fullName: 'Нигора', latitude: 41, longitude: 69, ageSeconds: 0, stale: false,
          toDeliver: deliver, toPickup: pickup, overdue: overdue, managerId: manager,
        );
    test('each filter keeps only its rows; «Все» keeps everyone; manager narrows further', () {
      final rows = [w(deliver: true, manager: 'm1'), w(pickup: true, manager: 'm2'), w(overdue: true, manager: 'm1'), w()];
      expect(rows.where((r) => mapRowMatches(r, MapWorkFilter.any, null)).length, 4);
      expect(rows.where((r) => mapRowMatches(r, MapWorkFilter.toDeliver, null)).length, 1);
      expect(rows.where((r) => mapRowMatches(r, MapWorkFilter.toPickup, null)).length, 1);
      expect(rows.where((r) => mapRowMatches(r, MapWorkFilter.overdue, 'm1')).length, 1);
      expect(rows.where((r) => mapRowMatches(r, MapWorkFilter.any, 'm1')).length, 2);
    });
    test('what is waiting wins the colour: overdue red over ready green over deliver blue', () {
      expect(markerColor(w(deliver: true, pickup: true, overdue: true), scheme), workOverdueColor);
      expect(markerColor(w(deliver: true, pickup: true), scheme), workPickupColor);
      expect(markerColor(w(deliver: true), scheme), workDeliverColor);
    });
    test('a home point (no live position) parses from `homes[]` with its work flags', () {
      final r = LiveLocationRow.home({'worker': {'id': 'w1', 'code': 'W-1', 'fullName': 'Нигора', 'phone': '+998', 'managerId': 'm1'}, 'latitude': 41.3, 'longitude': 69.2, 'work': {'toDeliver': true, 'toPickup': false, 'overdue': false}});
      expect(r.isHome, isTrue);
      expect(r.toDeliver, isTrue);
      expect(r.workerId, 'w1');
    });
  });

  test('pins show initials', () {
    expect(initialsOf('Нигора Азимова'), 'НА');
    expect(initialsOf('  salima  '), 'S');
    expect(initialsOf(''), '?');
  });

  for (final size in [const Size(390, 800), const Size(1280, 800)]) {
    testWidgets('map buttons like Yandex (${size.width < 600 ? 'phone' : 'tablet'}): zoom, my place, traffic, everyone, 3D; the compass only when turned', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      Future<void> pump({double azimuth = 0, bool tilted = false}) => tester.pumpWidget(MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MapControls(
                azimuth: azimuth,
                traffic: false,
                tilted: tilted,
                onZoom: (by) => calls.add('zoom $by'),
                onMyPlace: () => calls.add('me'),
                onNorth: () => calls.add('north'),
                onTraffic: () => calls.add('traffic'),
                onShowAll: () => calls.add('all'),
                onTilt: () => calls.add('tilt'),
              ),
            ),
          ));
      await pump();
      expect(find.byKey(const Key('mapNorth')), findsNothing);
      for (final k in ['mapZoomIn', 'mapZoomOut', 'mapMyPlace', 'mapTraffic', 'mapShowAll', 'mapTilt']) {
        await tester.tap(find.byKey(Key(k)));
      }
      expect(calls, ['zoom 1.0', 'zoom -1.0', 'me', 'traffic', 'all', 'tilt']);
      expect(tester.getSize(find.byKey(const Key('mapZoomIn'))).width, greaterThanOrEqualTo(48)); // easy to hit
      await pump(azimuth: 45);
      await tester.tap(find.byKey(const Key('mapNorth')));
      expect(calls.last, 'north');
      expect(find.text('3D'), findsOneWidget);
      await pump(tilted: true);
      expect(find.text('2D'), findsOneWidget);
      expect(find.byKey(const Key('mapNorth')), findsOneWidget);
    });
  }
}