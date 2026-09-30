import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/map/route_sheet.dart';
import 'package:diamoraa_mobile/features/team/models.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'fakes/fake_geo.dart';

/// «Маршрут»: those with work waiting are ticked; the round is numbered and opens in Yandex Maps.
void main() {
  LiveLocationRow w(String id, String name, double lat, {bool pickup = false, bool deliver = false}) => LiveLocationRow(
        userId: id, role: 'WORKER', fullName: name, workerId: 'w$id', latitude: lat, longitude: 69.2, ageSeconds: 0, stale: false,
        toPickup: pickup, toDeliver: deliver, isHome: true,
      );

  testWidgets('ticked = something waiting; «Построить» numbers the stops nearest first', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [geoProvider.overrideWithValue(const FakeGeo())],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RouteSheet(rows: [
          w('1', 'Салима', 41.34, pickup: true),
          w('2', 'Нигора', 41.31, deliver: true),
          w('3', 'Юнус', 41.32),
        ])),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('routeStop-1|true'))).value, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('routeStop-2|true'))).value, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('routeStop-3|true'))).value, isFalse); // nothing waiting
    expect(find.text('Построить маршрут (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('routeBuild')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Маршрут: 2 остановок'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('routeOrder-0')), matching: find.text('Нигора')), findsOneWidget); // nearer to the start
    expect(find.byKey(const Key('routeOpen')), findsOneWidget);
  });
}
