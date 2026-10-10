import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/manager/manager_tools.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// Managers' tools (owner, 2026-10-11): «Кто простаивает», «Напоминания», «Отпуск».
void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('«Кто простаивает»: who asks for work, how long without it, quality, «Выдать работу»', (tester) async {
    when(() => api.getJson('/admin/workers-idle')).thenAnswer((_) async => {
          'items': [
            {'workerId': 'w1', 'fullName': 'Малика Каримова', 'code': 'W-1', 'phone': '+998901', 'idleDays': 9, 'everWorked': true, 'wantsWork': true, 'qualityPercent': 99.0},
            {'workerId': 'w2', 'fullName': 'Нигора', 'code': 'W-2', 'phone': '+998902', 'idleDays': 0, 'everWorked': false, 'wantsWork': false, 'qualityPercent': null},
          ],
        });
    await pump(tester, const IdleWorkersScreen());
    expect(find.text('Малика Каримова'), findsOneWidget);
    expect(find.text('Просит работу'), findsOneWidget);
    expect(find.text('Без работы 9 дн. · без брака 99.0%'), findsOneWidget);
    expect(find.text('Ещё не брала работу'), findsOneWidget);
    expect(find.byKey(const Key('giveWork-w1')), findsOneWidget);
  });

  testWidgets('a reminder: text + «Завтра 9:00» -> sent with the time; the list shows it', (tester) async {
    when(() => api.getJson('/me/reminders')).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.postJson('/me/reminders', body: any(named: 'body'))).thenAnswer((_) async => <String, dynamic>{});
    await pump(tester, const RemindersScreen());
    expect(find.text('Напоминаний нет'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addReminder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reminderText')), 'Забрать работу у Нигоры');
    await tester.tap(find.byKey(const Key('saveReminder')));
    await tester.pumpAndSettle();
    final body = verify(() => api.postJson('/me/reminders', body: captureAny(named: 'body'))).captured.single as Map;
    expect(body['text'], 'Забрать работу у Нигоры');
    final due = DateTime.parse(body['dueAt'] as String).toLocal();
    final t = DateTime.now().add(const Duration(days: 1));
    expect([due.year, due.month, due.day, due.hour], [t.year, t.month, t.day, 9]);
  });

  testWidgets('holiday: on holiday -> «Я вернулся»; not -> pick who covers and until when', (tester) async {
    when(() => api.getJson('/me/away')).thenAnswer((_) async => {
          'away': true, 'until': '2026-10-20T03:00:00.000Z', 'substitute': {'id': 'm2', 'fullName': 'Азиза'}, 'myWorkers': 4, 'covering': <Object>[], 'substitutes': <Object>[],
        });
    await pump(tester, const AwayScreen());
    expect(find.textContaining('Ваших мастериц ведёт Азиза'), findsOneWidget);
    expect(find.byKey(const Key('awayBack')), findsOneWidget);
  });

  testWidgets('holiday, not away yet: pick who covers and until when; colleagues I cover are listed', (tester) async {
    when(() => api.getJson('/me/away')).thenAnswer((_) async => {
          'away': false, 'until': null, 'substitute': null, 'myWorkers': 4,
          'covering': [{'manager': {'id': 'm3', 'fullName': 'Дилноза'}, 'until': '2026-10-25T03:00:00.000Z', 'workers': 3}],
          'substitutes': [{'id': 'm2', 'fullName': 'Азиза'}],
        });
    await pump(tester, const AwayScreen());
    expect(find.textContaining('Ваши мастерицы (4)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('awayGo'))).onPressed, isNull); // nobody / no date picked yet
    expect(find.text('Дилноза'), findsOneWidget);
    expect(find.text('Мастериц: 3 · до 25.10.2026'), findsOneWidget);
  });
}
