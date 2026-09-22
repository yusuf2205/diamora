import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    when(() => api.getJson('/admin/kits')).thenAnswer((_) async => {'items': <Object>[]});
  });

  testWidgets('a MANAGER without INVENTORY_VIEW sees "insufficient rights", never a partial materials list', (tester) async {
    final manager = Session.fromJson({'id': 'm1', 'fullName': 'Manager', 'phone': '+998907001122', 'role': 'MANAGER', 'permissions': <String>[]});
    await tester.pumpWidget(await appWith(manager, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Склад'));
    await tester.pumpAndSettle();
    expect(find.text('Недостаточно прав для просмотра команды'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tearDownDb(tester);
  });

  testWidgets('SUPER_ADMIN sees the materials list; a below-minStock material is clearly flagged', (tester) async {
    when(() => api.getJson('/admin/materials', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'mat1', 'name': 'Лента Rose Gold', 'unit': 'METER', 'isActive': true, 'category': {'name': 'Лента'}, 'minStock': 50, 'balance': 3, 'low': true},
            {'id': 'mat2', 'name': 'Нить', 'unit': 'ROLL', 'isActive': true, 'minStock': 0, 'balance': 10, 'low': false},
          ]
        });
    final superAdmin = Session.fromJson({'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN', 'permissions': ['INVENTORY_VIEW', 'INVENTORY_MANAGE']});
    await tester.pumpWidget(await appWith(superAdmin, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Склад'));
    await tester.pumpAndSettle();

    expect(find.text('Лента Rose Gold'), findsOneWidget);
    expect(find.textContaining('мало'), findsOneWidget); // the low-stock material, and only that one
    expect(find.text('Нить'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('recording a receipt calls the server with the material id and the typed quantity', (tester) async {
    when(() => api.getJson('/admin/materials', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'mat1', 'name': 'Лента Rose Gold', 'unit': 'METER', 'isActive': true, 'minStock': 0, 'balance': 3, 'low': false},
          ]
        });
    when(() => api.postJson('/admin/stock/receipt', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    final superAdmin = Session.fromJson({'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN', 'permissions': ['INVENTORY_VIEW', 'INVENTORY_MANAGE']});
    await tester.pumpWidget(await appWith(superAdmin, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Склад'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Приход'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    verify(() => api.postJson('/admin/stock/receipt', idempotencyKey: any(named: 'idempotencyKey'), body: {'materialId': 'mat1', 'quantity': '25'})).called(1);
    await tearDownDb(tester);
  });
}
