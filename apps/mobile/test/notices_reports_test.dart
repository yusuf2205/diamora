import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/notifications/app_notifications.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/reports/reports_screen.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

Widget app(MockApi api, Widget home) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: const [NoticeBell()]), body: home),
      ),
    );

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('bell: unread count; the list shows unread first-class and «Прочитать все» clears it', (tester) async {
    var unread = 2;
    when(() => api.getJson('/me/notifications')).thenAnswer((_) async => {
          'unread': unread,
          'items': [
            {'id': 'n1', 'type': 'work.ready_for_pickup', 'title': 'Малика: работа готова', 'body': 'Oddiy tekis · 18 м — можно забирать', 'link': null, 'read': unread == 0 ? true : false, 'createdAt': '2026-09-28T10:00:00Z'},
            {'id': 'n2', 'type': 'stock.low', 'title': 'Заканчивается: Органза', 'body': 'Осталось 12', 'link': null, 'read': unread == 0, 'createdAt': '2026-09-28T09:00:00Z'},
          ],
        });
    when(() => api.postJson('/me/notifications/read', body: any(named: 'body'))).thenAnswer((_) async {
      unread = 0;
      return {'unread': 0};
    });
    await tester.pumpWidget(app(api, const SizedBox()));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // badge
    await tester.tap(find.byIcon(Icons.notifications_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Малика: работа готова'), findsOneWidget);
    expect(find.text('Заканчивается: Органза'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();
    final call = verify(() => api.postJson('/me/notifications/read', body: captureAny(named: 'body')))..called(1);
    expect(call.captured.single, {'all': true});
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('reports: week totals, per worker, low stock; switching to «Месяц» asks the server for the month', (tester) async {
    Map<String, dynamic> report(String period) => {
          'period': period, 'offset': 0, 'from': '2026-09-27T19:00:00Z', 'to': '2026-10-04T19:00:00Z',
          'total': {'issuedCount': 3, 'issuedMeters': 45, 'acceptedMeters': 36, 'defectiveMeters': 0, 'earned': '120000', 'paid': '90000', 'overdue': 1},
          'rows': [{'worker': {'id': 'w1', 'code': 'W-0001', 'fullName': 'Малика Каримова'}, 'issuedCount': 2, 'issuedMeters': 27, 'acceptedMeters': 18, 'defectiveMeters': 0, 'earned': '60000', 'paid': '30000', 'overdue': 1}],
          'lowStock': [{'materialId': 'm1', 'name': 'Органза', 'unit': 'METER', 'quantity': 12, 'minStock': 50}],
        };
    when(() => api.getJson('/me/notifications')).thenAnswer((_) async => {'unread': 0, 'items': <Object>[]});
    when(() => api.getJson('/admin/reports', query: any(named: 'query'))).thenAnswer((i) async => report((i.namedArguments[#query] as Map)['period'] as String));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(api, const ReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('3 · 45 м'), findsOneWidget);
    expect(find.text('Малика Каримова'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Органза'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Органза'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Месяц'), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Месяц'));
    await tester.pumpAndSettle();
    verify(() => api.getJson('/admin/reports', query: {'period': 'month', 'offset': 0})).called(1);
  });

  testWidgets('worker: «Мои заработки по месяцам»', (tester) async {
    when(() => api.getJson('/me/notifications')).thenAnswer((_) async => {'unread': 0, 'items': <Object>[]});
    when(() => api.getJson('/work/earnings/monthly')).thenAnswer((_) async => {'items': [
          {'month': '2026-09', 'acceptedMeters': 36, 'earned': '120000', 'paid': '90000'},
          {'month': '2026-08', 'acceptedMeters': 0, 'earned': '0', 'paid': '0'},
        ]});
    await tester.pumpWidget(app(api, const SingleChildScrollView(child: MyMonthsCard())));
    await tester.pumpAndSettle();
    expect(find.text('Мои заработки по месяцам'), findsOneWidget);
    expect(find.text('Сентябрь'), findsOneWidget);
    expect(find.text('36 м'), findsOneWidget);
  });
}
