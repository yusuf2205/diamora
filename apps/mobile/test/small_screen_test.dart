import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/team/team_screen.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;
import 'models_test.dart' show workerListItem;
import 'overview_test.dart' show dash;

/// The smallest phone we support in the field (Duoqin F22 Pro: 640×960 px at 2× = 320×480 dp) with long real names.
/// Any RenderFlex overflow ("yellow-black stripes") fails the test by itself - no extra assertions needed for that.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUp(() {
    api = MockApi();
    // anything not stubbed below answers "empty", so every screen renders its real empty state
    when(() => api.getJson(any(), query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getList(any())).thenAnswer((_) async => <Object>[]);
  });

  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(640, 960);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  const longName = 'Нигора Рахматуллаева-Исмаилова Абдурахмановна';

  testWidgets('staff on a 320 dp phone: Обзор, Мастерицы, a worker card, Ещё, Команда, a user card — nothing overflows', (tester) async {
    smallPhone(tester);
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash());
    final worker = {...workerListItem, 'id': 'w1', 'fullName': longName, 'status': 'ACTIVE', 'balance': '1250000', 'manager': {'id': 'm1', 'fullName': 'Гульнора Абдурахмановна Юсупова'}};
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [worker], 'nextCursor': null});
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...worker, 'collaterals': <Object>[]});
    when(() => api.getJson('/admin/workers/w1/ledger')).thenAnswer((_) async => {'workerId': 'w1', 'balance': '1250000', 'earned': '3600000', 'paid': '2350000', 'history': <Object>[]});
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'a1', 'status': 'READY_FOR_PICKUP', 'plannedMeters': 27.0, 'reportedMeters': 27.0, 'dueAt': '2026-10-05T12:00:00Z',
             'worker': {'fullName': longName}, 'product': {'name': 'Свадебный комплект «Роза» с жемчугом'}, 'color': {'name': 'Жемчужно-белый с золотом'}},
          ],
        });
    final users = [
      {'id': 'me', 'phone': '+998901112233', 'fullName': 'Юсуф Адилов', 'role': 'SUPER_ADMIN', 'status': 'ACTIVE', 'online': true, 'permissions': <String>[]},
      {'id': 'm1', 'phone': '+998901110002', 'fullName': 'Гульнора Абдурахмановна Юсупова', 'role': 'MANAGER', 'status': 'SUSPENDED', 'permissions': <String>[],
       'createdAt': '2026-09-10T10:00:00Z', 'permissionDetail': {'role': 'MANAGER', 'defaults': <String>[], 'effective': <String>[]}},
      {'id': 'u9', 'phone': '+998905550000', 'fullName': longName, 'role': 'WORKER', 'status': 'ACTIVE', 'permissions': <String>[], 'workerId': 'w1', 'managerName': 'Гульнора Абдурахмановна Юсупова'},
    ];
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': users});
    when(() => api.getJson('/users/m1')).thenAnswer((_) async => users[1]);

    final owner = Session.fromJson({
      'id': 'me', 'fullName': 'Юсуф Адилов', 'phone': '+998901112233', 'role': 'SUPER_ADMIN',
      'permissions': ['USER_VIEW_ALL', 'USER_CREATE', 'USER_UPDATE', 'USER_DEACTIVATE', 'ROLE_ASSIGN', 'PERMISSION_MANAGE', 'AUDIT_VIEW',
        'WORKER_VIEW_ALL', 'WORKER_UPDATE', 'WORKER_ASSIGN_MANAGER', 'ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_CREATE', 'FINANCE_VIEW_ALL', 'CASH_PAYOUT',
        'PAY_RATE_MANAGE', 'SETTINGS_MANAGE', 'MAP_VIEW_ALL', 'LIVE_LOCATION_VIEW_ALL', 'INVENTORY_VIEW', 'CATALOG_VIEW'],
    });
    await tester.pumpWidget(await appWith(owner, api));
    await tester.pumpAndSettle();
    expect(find.text('Юсуф'), findsOneWidget); // Обзор greets her

    await tester.tap(find.text('Мастерицы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(longName).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TeamScreen), matching: find.text('Гульнора Абдурахмановна Юсупова')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Восстановить'), findsOneWidget);

    // the API refuses a page bigger than 100 (400 VALIDATION_FAILED) - a list asking for more silently shows an error
    final queries = verify(() => api.getJson(any(), query: captureAny(named: 'query'))).captured.whereType<Map>();
    for (final q in queries) {
      final limit = q['limit'];
      if (limit != null) expect(int.parse('$limit'), lessThanOrEqualTo(100), reason: 'page size over the API maximum: $q');
    }
    await tearDownDb(tester);
  });

  testWidgets('worker on a 320 dp phone: her home with long product names and big sums — nothing overflows', (tester) async {
    smallPhone(tester);
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'fullName': longName, 'status': 'ACTIVE', 'collaterals': <Object>[], 'balance': '12500000'});
    when(() => api.getJson('/workers/me/collateral')).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-21T09:00:00Z'});
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => {'workerId': 'w1', 'balance': '12500000', 'earned': '36000000', 'paid': '23500000', 'history': <Object>[]});
    final worker = Session.fromJson({'id': 'u2', 'fullName': longName, 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(await appWith(worker, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tearDownDb(tester);
  });
}
