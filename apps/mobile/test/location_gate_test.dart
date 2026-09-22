import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusmus_mobile/core/location/geo.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/features/location/location_gate.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'fakes/fake_geo.dart';

class _RecordingGeo extends FakeGeo {
  const _RecordingGeo({required super.gap, required this.calls});
  final List<String> calls;

  @override
  Future<LocationGap> requestForeground() async {
    calls.add('requestForeground');
    return LocationGap.none;
  }

  @override
  Future<LocationGap> requestBackground() async {
    calls.add('requestBackground');
    return LocationGap.none;
  }

  @override
  Future<void> openLocationSettings() async => calls.add('openLocationSettings');
  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');
}

Future<void> pump(WidgetTester tester, Geo geo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [geoProvider.overrideWithValue(geo)],
    child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LocationGate(child: Text('CHILD SCREEN')),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Location Services off: shows the right screen and opens the system settings, never pretends to switch it on', (tester) async {
    final calls = <String>[];
    await pump(tester, _RecordingGeo(gap: LocationGap.servicesDisabled, calls: calls));
    expect(find.text('CHILD SCREEN'), findsNothing);
    expect(find.text('Включите геолокацию'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locationGateAction')));
    await tester.pumpAndSettle();
    expect(calls, ['openLocationSettings']);
  });

  testWidgets('foreground denied: the action requests foreground permission, not background', (tester) async {
    final calls = <String>[];
    await pump(tester, _RecordingGeo(gap: LocationGap.foregroundDenied, calls: calls));
    expect(find.text('Разрешите доступ к геолокации'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locationGateAction')));
    await tester.pumpAndSettle();
    expect(calls, ['requestForeground']);
  });

  testWidgets('foreground denied forever: only Settings can fix it — the button opens app settings, not a request dialog', (tester) async {
    final calls = <String>[];
    await pump(tester, _RecordingGeo(gap: LocationGap.foregroundDeniedForever, calls: calls));
    expect(find.textContaining('Откройте настройки приложения'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locationGateAction')));
    await tester.pumpAndSettle();
    expect(calls, ['openAppSettings']);
  });

  testWidgets('background denied: asks for "Always", foreground is already fine', (tester) async {
    final calls = <String>[];
    await pump(tester, _RecordingGeo(gap: LocationGap.backgroundDenied, calls: calls));
    expect(find.text('Разрешите геолокацию в фоне'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locationGateAction')));
    await tester.pumpAndSettle();
    expect(calls, ['requestBackground']);
  });

  testWidgets('everything granted: the working part of the app is shown, no gate screen', (tester) async {
    await pump(tester, const FakeGeo());
    expect(find.text('CHILD SCREEN'), findsOneWidget);
    expect(find.byKey(const Key('locationGateAction')), findsNothing);
  });

  testWidgets('"Повторить" re-checks status without needing a system round-trip', (tester) async {
    final calls = <String>[];
    await pump(tester, _RecordingGeo(gap: LocationGap.foregroundDenied, calls: calls));
    expect(find.text('CHILD SCREEN'), findsNothing);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('CHILD SCREEN'), findsNothing); // the fake still reports the same gap: still blocked
    expect(calls, isEmpty); // "retry" itself calls neither request nor settings
  });
}
