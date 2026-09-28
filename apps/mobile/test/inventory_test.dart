import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/network/api_exception.dart';
import 'package:diamoraa_mobile/features/auth/models.dart';

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

  testWidgets('INVENTORY_DELETE: tap a material -> confirm -> DELETE; a kit row menu offers «Удалить»; IN_USE names the kit', (tester) async {
    when(() => api.getJson('/admin/materials', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'mat1', 'name': 'Лента тест', 'unit': 'METER', 'isActive': true, 'minStock': 0, 'balance': 155, 'low': false},
          ]
        });
    when(() => api.getJson('/admin/kits')).thenAnswer((_) async => {
          'items': [
            {'id': 'kit1', 'name': 'Комплект 9 м', 'ribbonMeters': 9, 'baseMeters': 9, 'active': true, 'items': <Object>[], 'createdAt': '2026-09-01T00:00:00Z'},
          ]
        });
    when(() => api.deleteJson('/admin/materials/mat1')).thenThrow(ApiException(code: 'IN_USE', message: 'in use', status: 409, details: {'kits': ['Комплект 9 м'], 'workers': <String>[]}));
    when(() => api.deleteJson('/admin/kits/kit1')).thenAnswer((_) async => {'deleted': true});
    final superAdmin = Session.fromJson({'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN', 'permissions': ['INVENTORY_VIEW', 'INVENTORY_MANAGE', 'INVENTORY_DELETE']});
    await tester.pumpWidget(await appWith(superAdmin, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Склад'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Лента тест'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(155'), findsOneWidget); // says what will be written off
    await tester.tap(find.byKey(const Key('confirmDelete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Материал есть в комплектах: Комплект 9 м'), findsOneWidget);

    await tester.tap(find.text('Комплекты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kitMenu-kit1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    verifyNever(() => api.deleteJson('/admin/kits/kit1')); // not before the confirm
    await tester.tap(find.byKey(const Key('confirmDelete')));
    await tester.pumpAndSettle();
    verify(() => api.deleteJson('/admin/kits/kit1')).called(1);
    await tearDownDb(tester);
  });
}
