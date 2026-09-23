import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
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

  Session superAdminWithFullRights() => Session.fromJson({
        'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN',
        'permissions': ['USER_VIEW_ALL', 'USER_DEACTIVATE', 'USER_CREATE', 'USER_UPDATE', 'ROLE_ASSIGN'],
      });
  Map<String, Object?> manager1() => {'id': 'a1', 'phone': '+998907001122', 'fullName': 'Manager One', 'role': 'MANAGER', 'status': 'ACTIVE', 'permissions': <String>[]};

  testWidgets('opening a user: edit name/phone, save sends exactly what was changed', (tester) async {
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': [manager1()]});
    when(() => api.patchJson('/users/a1', body: any(named: 'body'))).thenAnswer((_) async => {...manager1(), 'fullName': 'Manager Renamed', 'phone': '+998907009999'});
    await tester.pumpWidget(await appWith(superAdminWithFullRights(), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    expect(find.text('Пользователь'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'ФИО'), 'Manager Renamed');
    await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+998907009999');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    verify(() => api.patchJson('/users/a1', body: {'fullName': 'Manager Renamed', 'phone': '+998907009999'})).called(1);
    expect(find.text('Изменения сохранены'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('phone already taken by someone else: a plain message, never the raw server sentence', (tester) async {
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': [manager1()]});
    when(() => api.patchJson('/users/a1', body: any(named: 'body')))
        .thenThrow(ApiException(code: 'CONFLICT', message: 'A user with this phone already exists', status: 409));
    await tester.pumpWidget(await appWith(superAdminWithFullRights(), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+998900000001');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Этот номер уже используется другим пользователем'), findsOneWidget);
    expect(find.textContaining('already exists'), findsNothing);
    await tearDownDb(tester);
  });

  testWidgets('changing role: asks for confirmation naming both roles, only calls the API after confirming', (tester) async {
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': [manager1()]});
    when(() => api.putJson('/users/a1/role', body: any(named: 'body'))).thenAnswer((_) async => {...manager1(), 'role': 'ADMIN'});
    await tester.pumpWidget(await appWith(superAdminWithFullRights(), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    expect(find.text('Изменить роль с Менеджер на Администратор?'), findsOneWidget);
    verifyNever(() => api.putJson('/users/a1/role', body: any(named: 'body')));

    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    verify(() => api.putJson('/users/a1/role', body: {'role': 'ADMIN'})).called(1);
    expect(find.text('Роль изменена'), findsOneWidget);
    await tearDownDb(tester);
  });
}
