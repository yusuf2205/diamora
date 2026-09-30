import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/goals/goal_card.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// «Цель месяца» on the worker's home: progress, what is left, her place, badges (no money anywhere).
void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> goal) async {
    final api = MockApi();
    when(() => api.getJson('/work/goal')).thenAnswer((_) async => goal);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: GoalCard())),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final badges = [
    {'code': 'first_kit', 'title': 'Первый комплект', 'hint': '', 'earned': true},
    {'code': 'm100', 'title': '100 метров', 'hint': 'Всего принято 27 из 100 м', 'earned': false},
  ];

  testWidgets('27 of 90 m: the bar, «ещё 63 м», her place and badges', (tester) async {
    await pump(tester, {'goalMeters': 90, 'personal': false, 'doneMeters': 27, 'leftMeters': 63, 'percent': 30, 'daysLeft': 12, 'place': 3, 'of': 12, 'badges': badges});
    expect(find.text('27 из 90 м'), findsOneWidget);
    expect(find.textContaining('Ещё 63 м'), findsOneWidget);
    expect(find.text('3-е место из 12'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const Key('goalBar'))).value, closeTo(0.3, 0.001));
    expect(find.byKey(const Key('badge-first_kit')), findsOneWidget);
    expect(find.textContaining('сум'), findsNothing); // goals are never money
  });

  testWidgets('goal reached: «Цель выполнена!»; no goal set: just the metres of the month', (tester) async {
    await pump(tester, {'goalMeters': 27, 'personal': true, 'doneMeters': 27, 'leftMeters': 0, 'percent': 100, 'daysLeft': 3, 'place': 1, 'of': 5, 'badges': badges});
    expect(find.textContaining('Цель выполнена'), findsOneWidget);
    await pump(tester, {'goalMeters': 0, 'personal': false, 'doneMeters': 18, 'leftMeters': null, 'percent': null, 'daysLeft': 3, 'place': null, 'of': 0, 'badges': badges});
    expect(find.text('Принято в этом месяце: 18 м'), findsOneWidget);
    expect(find.byKey(const Key('goalBar')), findsNothing);
  });
}
