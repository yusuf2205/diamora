import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/workers/visit_time.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// «Удобное время»: she picks days and hours; what she saved is exactly what is sent.
void main() {
  testWidgets('Пн–Пт by default, untick Пт, tick Сб, a note -> saved as days 1-4 and 6, 10:00-18:00', (tester) async {
    final api = MockApi();
    when(() => api.getJson('/work/visit-time')).thenAnswer((_) async => {'visitTime': null, 'visitText': null});
    when(() => api.putJson('/work/visit-time', body: any(named: 'body'))).thenAnswer((_) async => {'visitTime': null, 'visitText': 'x'});
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: VisitTimeSheet())),
      ),
    ));
    await tester.tap(find.byKey(const Key('visitDay-5')));
    await tester.tap(find.byKey(const Key('visitDay-6')));
    await tester.enterText(find.byType(TextField), 'звонить заранее');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('visitSave')));
    await tester.tap(find.byKey(const Key('visitSave')));
    await tester.pumpAndSettle();
    final sent = verify(() => api.putJson('/work/visit-time', body: captureAny(named: 'body'))).captured.single as Map;
    expect(sent['visitTime'], {'days': [1, 2, 3, 4, 6], 'from': '10:00', 'to': '18:00', 'note': 'звонить заранее'});
  });
}
