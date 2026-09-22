import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('MANAGER without USER_VIEW_ALL sees "insufficient rights", never a partial/broken users list', (tester) async {
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    final manager = Session.fromJson({'id': 'm1', 'fullName': 'Manager', 'phone': '+998907001122', 'role': 'MANAGER', 'permissions': <String>[]});
    await tester.pumpWidget(await appWith(manager, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();
    expect(find.text('Недостаточно прав для просмотра команды'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tearDownDb(tester);
  });

  testWidgets('SUPER_ADMIN sees the users list and can deactivate someone else (never herself)', (tester) async {
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'me', 'phone': '+998901112233', 'fullName': 'Owner', 'role': 'SUPER_ADMIN', 'status': 'ACTIVE', 'permissions': <String>[]},
            {'id': 'a1', 'phone': '+998907001122', 'fullName': 'Manager One', 'role': 'MANAGER', 'status': 'ACTIVE', 'permissions': <String>[]},
          ]
        });
    when(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    final superAdmin = Session.fromJson({'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN', 'permissions': ['USER_VIEW_ALL', 'USER_DEACTIVATE', 'USER_CREATE']});
    await tester.pumpWidget(await appWith(superAdmin, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Manager One'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget); // only for the OTHER user, never for herself
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: {'status': 'SUSPENDED'})).called(1);
    await tearDownDb(tester);
  });
}
