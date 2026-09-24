import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;

const _managerDefaults = ['WORKER_VIEW_ASSIGNED', 'ASSIGNMENT_VIEW_ASSIGNED', 'FINANCE_VIEW_ASSIGNED', 'MAP_VIEW_ASSIGNED', 'LIVE_LOCATION_VIEW_ASSIGNED'];
const _managerGrantable = ['COLLATERAL_VIEW', 'COLLATERAL_MANAGE', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT', 'CASH_PAYOUT', 'CATALOG_VIEW', 'INVENTORY_VIEW', 'WORKER_UPDATE'];

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
  });

  Session superAdmin() => Session.fromJson({
        'id': 'me', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'SUPER_ADMIN',
        'permissions': ['USER_VIEW_ALL', 'USER_DEACTIVATE', 'USER_CREATE', 'USER_UPDATE', 'ROLE_ASSIGN', 'PERMISSION_MANAGE', 'AUDIT_VIEW'],
      });
  Map<String, Object?> owner() => {'id': 'me', 'phone': '+998901112233', 'fullName': 'Owner', 'role': 'SUPER_ADMIN', 'status': 'ACTIVE', 'permissions': <String>[], 'createdAt': '2026-09-01T10:00:00Z'};
  Map<String, Object?> manager1({String status = 'ACTIVE', List<String> effective = _managerDefaults}) => {
        'id': 'a1', 'phone': '+998907001122', 'fullName': 'Manager One', 'role': 'MANAGER', 'status': status, 'online': true,
        'permissions': effective, 'createdAt': '2026-09-10T10:00:00Z',
        'permissionDetail': {'role': 'MANAGER', 'defaults': _managerDefaults, 'effective': effective, 'granted': <String>[], 'revoked': <String>[]},
      };
  Map<String, Object?> worker1() => {
        'id': 'u9', 'phone': '+998905550000', 'fullName': 'Малика Каримова', 'role': 'WORKER', 'status': 'ACTIVE', 'permissions': <String>[],
        'workerId': 'w9', 'managerName': 'Manager One', 'lastSeenAt': '2026-09-20T10:00:00Z',
      };

  void stubList() {
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': [owner(), manager1(), worker1()]});
    when(() => api.getJson('/users/a1')).thenAnswer((_) async => manager1());
    when(() => api.getJson('/managers')).thenAnswer((_) async => {'items': [{...manager1(), 'stats': {'workers': 3}}]});
    when(() => api.getJson('/permissions')).thenAnswer((_) async => {
          'permissions': [..._managerDefaults, ..._managerGrantable], 'superAdminOnly': ['ROLE_ASSIGN', 'PERMISSION_MANAGE'],
          'roleDefaults': {'MANAGER': _managerDefaults, 'ADMIN': <String>[]}, 'grantable': {'MANAGER': _managerGrantable, 'ADMIN': <String>[]},
        });
  }

  Future<void> openTeam(WidgetTester tester, Session s) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await appWith(s, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команда'));
    await tester.pumpAndSettle();
  }

  testWidgets('MANAGER without USER_VIEW_ALL sees "insufficient rights", never a partial/broken users list', (tester) async {
    final manager = Session.fromJson({'id': 'm1', 'fullName': 'Manager', 'phone': '+998907001122', 'role': 'MANAGER', 'permissions': <String>[]});
    await openTeam(tester, manager);
    expect(find.text('Недостаточно прав для просмотра команды'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tearDownDb(tester);
  });

  testWidgets('list: role badges, "это вы", a worker shows her manager; filters and search go to the server', (tester) async {
    stubList();
    await openTeam(tester, superAdmin());

    expect(find.text('Owner'), findsOneWidget);
    expect(find.textContaining('это вы'), findsOneWidget);
    expect(find.text('Manager One'), findsOneWidget);
    expect(find.textContaining('Менеджер: Manager One'), findsOneWidget); // the worker row
    expect(find.text('Мастерица'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Менеджер'));
    await tester.pumpAndSettle();
    verify(() => api.getJson('/users', query: {'limit': 100, 'role': 'MANAGER'})).called(1);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Отключённые'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Отключённые'));
    await tester.pumpAndSettle();
    verify(() => api.getJson('/users', query: {'limit': 100, 'status': 'SUSPENDED'})).called(1);

    await tester.enterText(find.byType(SearchBar), 'Mal');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    verify(() => api.getJson('/users', query: {'limit': 100, 'status': 'SUSPENDED', 'q': 'Mal'})).called(1);
    await tearDownDb(tester);
  });

  testWidgets('user card: facts + actions; «Отключить» asks first (danger) and only then calls the API', (tester) async {
    stubList();
    when(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();

    expect(find.text('+998907001122'), findsOneWidget);
    expect(find.text('Создан(а)'), findsOneWidget);
    expect(find.text('10.09.2026'), findsOneWidget);
    expect(find.text('Мастерицы менеджера'), findsOneWidget);
    expect(find.text('Изменить роль'), findsOneWidget);
    expect(find.text('Права доступа'), findsOneWidget);
    expect(find.text('5 из 13'), findsOneWidget); // 5 on, 13 possible for a MANAGER

    await tester.tap(find.text('Отключить пользователя'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Вся история сохранится'), findsOneWidget);
    verifyNever(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')));
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: {'status': 'SUSPENDED'})).called(1);
    expect(find.text('Пользователь отключён'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('a disabled user offers «Восстановить» (no confirm needed to give access back)', (tester) async {
    stubList();
    when(() => api.getJson('/users/a1')).thenAnswer((_) async => manager1(status: 'SUSPENDED'));
    when(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    expect(find.text('Отключить пользователя'), findsNothing);
    await tester.tap(find.text('Восстановить'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/users/a1/status', idempotencyKey: any(named: 'idempotencyKey'), body: {'status': 'ACTIVE'})).called(1);
    await tearDownDb(tester);
  });

  testWidgets('my own card: no role change, no disable - you never manage yourself', (tester) async {
    stubList();
    when(() => api.getJson('/users/me')).thenAnswer((_) async => {...owner(), 'permissionDetail': {'role': 'SUPER_ADMIN', 'defaults': <String>[], 'effective': <String>[]}});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Owner'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить роль'), findsNothing);
    expect(find.text('Отключить пользователя'), findsNothing);
    expect(find.text('У главного администратора есть все права. Их нельзя ограничить.'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('changing role: pick in a sheet, confirm naming both roles, only then the API', (tester) async {
    stubList();
    when(() => api.putJson('/users/a1/role', body: any(named: 'body'))).thenAnswer((_) async => {...manager1(), 'role': 'ADMIN'});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить роль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мастерицы, склад, выплаты, каталог')); // the ADMIN option, explained in words
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить роль с Менеджер на Администратор?'), findsOneWidget);
    verifyNever(() => api.putJson(any(), body: any(named: 'body')));
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    verify(() => api.putJson('/users/a1/role', body: {'role': 'ADMIN'})).called(1);
    expect(find.text('Роль изменена'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('«Права доступа»: plain words (never raw codes), grouped; saving sends grant/revoke against role defaults', (tester) async {
    stubList();
    when(() => api.putJson('/users/a1/permissions', body: any(named: 'body'))).thenAnswer((_) async => manager1());
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Права доступа'));
    await tester.pumpAndSettle();

    expect(find.text('Выдавать работу'), findsOneWidget);
    expect(find.text('Задания'), findsOneWidget);
    expect(find.textContaining('ASSIGNMENT_CREATE'), findsNothing);
    expect(find.text('Видеть всех мастериц'), findsNothing); // never grantable to a MANAGER: not even shown
    expect(find.text('Сохранить'), findsNothing); // nothing changed yet

    await tester.tap(find.widgetWithText(SwitchListTile, 'Выдавать работу'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Карта: свои мастерицы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => api.putJson('/users/a1/permissions', body: {'grant': ['ASSIGNMENT_CREATE'], 'revoke': ['MAP_VIEW_ASSIGNED']})).called(1);
    expect(find.text('Права сохранены'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('«+ Добавить пользователя»: staff roles only, then the one-time password with a copy button', (tester) async {
    stubList();
    when(() => api.postJson('/users', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async => {'user': {...manager1(), 'id': 'n1'}, 'temporaryPassword': 'Abc123xyzQWE45'});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Добавить пользователя'));
    await tester.pumpAndSettle();
    expect(find.textContaining('регистрируются сами через Telegram'), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Главный администратор')), findsNothing); // never created from here
    await tester.enterText(find.widgetWithText(TextField, 'ФИО'), 'Дилноза Юсупова');
    await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+998901234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить пользователя'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/users', idempotencyKey: any(named: 'idempotencyKey'), body: {'phone': '+998901234567', 'fullName': 'Дилноза Юсупова', 'role': 'MANAGER'})).called(1);
    expect(find.text('Abc123xyzQWE45'), findsOneWidget);
    expect(find.text('Копировать'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('editing details: phone taken by someone else shows a plain message, never the raw server sentence', (tester) async {
    stubList();
    when(() => api.patchJson('/users/a1', body: any(named: 'body')))
        .thenThrow(ApiException(code: 'CONFLICT', message: 'A user with this phone already exists', status: 409));
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить данные'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+998900000001');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Этот номер уже используется другим пользователем'), findsOneWidget);
    expect(find.textContaining('already exists'), findsNothing);
    await tearDownDb(tester);
  });

  testWidgets('SUPER_ADMIN: «Показывать на карте» switch and «Задать пароль» send exactly what was chosen', (tester) async {
    stubList();
    when(() => api.putJson('/users/a1/location-visibility', body: any(named: 'body'))).thenAnswer((_) async => {});
    when(() => api.postJson('/users/a1/reset-password', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {'passwordSet': true});
    await openTeam(tester, superAdmin());
    await tester.tap(find.text('Manager One'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Показывать на карте'));
    await tester.pumpAndSettle();
    verify(() => api.putJson('/users/a1/location-visibility', body: {'hidden': true})).called(1);

    await tester.tap(find.text('Задать пароль'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Chosen-Pass-1');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/users/a1/reset-password', idempotencyKey: any(named: 'idempotencyKey'), body: {'password': 'Chosen-Pass-1'})).called(1);
    expect(find.text('Пароль установлен'), findsOneWidget);
    await tearDownDb(tester);
  });

  testWidgets('«Сменить пароль» in the profile: a wrong current password is said plainly, nobody is signed out', (tester) async {
    when(() => api.getJson('/users', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getList('/auth/sessions')).thenAnswer((_) async => <Object>[]);
    when(() => api.postJson('/auth/change-password', body: any(named: 'body')))
        .thenThrow(ApiException(code: 'WRONG_PASSWORD', message: 'Current password is wrong', status: 400));
    await openTeam(tester, superAdmin());
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сменить пароль'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Текущий пароль'), 'old-one');
    await tester.enterText(find.widgetWithText(TextField, 'Новый пароль'), 'New-Pass-123');
    await tester.enterText(find.widgetWithText(TextField, 'Новый пароль ещё раз'), 'New-Pass-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Сменить пароль'));
    await tester.pumpAndSettle();
    expect(find.text('Текущий пароль неверный'), findsOneWidget);
    verify(() => api.postJson('/auth/change-password', body: {'currentPassword': 'old-one', 'newPassword': 'New-Pass-123'})).called(1);
    await tearDownDb(tester);
  });
}
