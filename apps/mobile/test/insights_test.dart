import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
  });
  final owner = Session.fromJson({'id': 's1', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN', 'permissions': ['WORKER_VIEW_ALL', 'PROFIT_VIEW', 'SETTINGS_MANAGE']});

  Future<void> open(WidgetTester tester, String item) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await appWith(owner, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(item), 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('«Рейтинг мастериц»: best first, with the score and a plain line', (tester) async {
    when(() => api.getJson('/admin/reports/rating', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'worker': {'id': 'w1', 'code': 'W-1', 'fullName': 'Нигора'}, 'acceptedMeters': 54, 'defectiveMeters': 0, 'defectRate': 0, 'works': 6, 'late': 0, 'withDeadline': 6, 'score': 92},
          ],
        });
    await open(tester, 'Рейтинг мастериц');
    expect(find.text('Нигора'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    expect(find.textContaining('54 м · брак 0%'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('«Прибыль»: month card; «Продажа или расход» posts the sale', (tester) async {
    when(() => api.getJson('/admin/finance/profit', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [{'month': '2026-09', 'sales': '1000000', 'labor': '300000', 'materials': '100000', 'expenses': '50000', 'profit': '550000', 'materialsWithoutPrice': 0}],
        });
    when(() => api.getJson('/admin/stock/value')).thenAnswer((_) async => {'warehouse': '200000', 'withWorkers': '50000', 'total': '250000', 'withoutPrice': <Object>[]});
    when(() => api.getJson('/admin/finance/sales', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getJson('/admin/finance/expenses', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.postJson('/admin/finance/sales', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {'id': 's1'});
    await open(tester, 'Прибыль');
    expect(find.textContaining('Сентябрь 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profitAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profitAmount')), '1200000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profitSave')));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/finance/sales', idempotencyKey: any(named: 'idempotencyKey'), body: {'total': '1200000'})).called(1);
    await tearDownDb(tester);
  });

  testWidgets('«Состояние системы»: services and the daily backup in words', (tester) async {
    when(() => api.getJson('/admin/system/status')).thenAnswer((_) async => {
          'now': DateTime.now().toIso8601String(), 'version': '1.0.0', 'uptimeSeconds': 7200,
          'database': {'ok': true, 'ms': 3, 'size': '40 MB'}, 'redis': {'ok': true, 'ms': 1}, 'backupsVisible': true,
          'backups': [{'job': 'pg_dump', 'ok': true, 'at': DateTime.now().toUtc().toIso8601String(), 'bytes': 5000000}],
        });
    await open(tester, 'Состояние системы');
    expect(find.text('База данных (каждый день)'), findsOneWidget);
    expect(find.text('в порядке'), findsWidgets);
    await tearDownDb(tester);
  });
}
