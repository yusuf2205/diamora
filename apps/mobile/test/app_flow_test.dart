import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/app/app.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/network/api_client.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';

import 'fakes/fake_geo.dart';
import 'models_test.dart' show workerListItem;

class MockApi extends Mock implements ApiClient {}

class FakeAuth extends AuthController {
  FakeAuth(this.initial);
  final Session? initial;
  @override
  Future<Session?> build() async => initial;
}

AppDatabase? lastDb;

Future<ProviderScope> appWith(Session? session, MockApi api) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = lastDb = AppDatabase.forTesting(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      apiClientProvider.overrideWithValue(api),
      authControllerProvider.overrideWith(() => FakeAuth(session)),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      geoProvider.overrideWithValue(const FakeGeo()), // real geolocator/permission_handler have no platform channel in tests
    ],
    child: const YusmusApp(),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('signed out: a single phone field only, no role selector of any kind', (tester) async {
    await tester.pumpWidget(await appWith(null, api));
    await tester.pumpAndSettle();
    expect(find.text('Я мастерица'), findsNothing);
    expect(find.text('Я администратор'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('Пароль'), findsNothing);
    expect(find.text('Продолжить'), findsOneWidget);
  });

  testWidgets('phone identifies as a WORKER: no code field appears — she is pointed at the Telegram button instead', (tester) async {
    when(() => api.postJson('/auth/identify', body: any(named: 'body'), skipAuth: true)).thenAnswer((_) async => {'method': 'TELEGRAM_ONLY'});
    await tester.pumpWidget(await appWith(null, api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '90 123 45 67');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/auth/identify', body: {'phone': '90 123 45 67'}, skipAuth: true)).called(1);
    expect(find.text('Мастерицы входят через Telegram — нажмите кнопку ниже.'), findsOneWidget);
    expect(find.text('Пароль'), findsNothing);
    expect(find.text('Код из Telegram (6 цифр)'), findsNothing);
    expect(find.text('Войти через Telegram'), findsOneWidget); // still on the phone step, button visible
  });

  testWidgets('phone identifies as STAFF: the password field appears, never a code field', (tester) async {
    when(() => api.postJson('/auth/identify', body: any(named: 'body'), skipAuth: true)).thenAnswer((_) async => {'method': 'PASSWORD'});
    await tester.pumpWidget(await appWith(null, api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '90 123 45 67');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Код из Telegram (6 цифр)'), findsNothing);
  });

  testWidgets('an unknown phone shows a friendly message, never a raw error code', (tester) async {
    when(() => api.postJson('/auth/identify', body: any(named: 'body'), skipAuth: true))
        .thenThrow(ApiException(code: 'USER_NOT_FOUND', message: 'No user with this phone', status: 404));
    await tester.pumpWidget(await appWith(null, api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '90 123 45 67');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Пользователь с таким номером не найден. Обратитесь к администратору.'), findsOneWidget);
    expect(find.text('USER_NOT_FOUND'), findsNothing);
  });

  testWidgets('a blocked/suspended account shows a friendly message, never a raw error code', (tester) async {
    when(() => api.postJson('/auth/identify', body: any(named: 'body'), skipAuth: true))
        .thenThrow(ApiException(code: 'ACCOUNT_DISABLED', message: 'This account is disabled', status: 403));
    await tester.pumpWidget(await appWith(null, api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '90 123 45 67');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Ваш аккаунт отключён. Обратитесь к администратору.'), findsOneWidget);
  });

  testWidgets('ADMIN sees the registrations tab with a pending worker from the server (cache-backed list)', (tester) async {
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => {'workers': null, 'work': null, 'finance': null});
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [workerListItem], 'nextCursor': null});
    final admin = Session.fromJson({'id': 'u1', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'ADMIN'});
    await tester.pumpWidget(await appWith(admin, api));
    await tester.pumpAndSettle();
    expect(find.text('Мастерицы'), findsWidgets); // bottom navigation, reachable from the new Dashboard home
    await tester.tap(find.text('Мастерицы').first);
    await tester.pumpAndSettle();
    expect(find.text('Заявки'), findsOneWidget);
    expect(find.text('Малика Каримова'), findsOneWidget);
    expect(find.textContaining('1 500 000'), findsOneWidget);
    // drift's stream cleanup uses a zero-length timer: dispose the tree, let it fire, then close the database
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await lastDb!.close();
  });

  testWidgets('WORKER role never lands in the ADMIN area; her default screen is the catalog (§18), not a dashboard', (tester) async {
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'status': 'ACTIVE', 'collaterals': []});
    when(() => api.getJson('/workers/me/collateral')).thenAnswer((_) async => {'items': []});
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-21T12:00:00.000Z'});
    when(() => api.getJson('/catalog')).thenAnswer((_) async => {'items': []});
    final worker = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(await appWith(worker, api));
    await tester.pumpAndSettle();
    expect(find.text('Наши работы'), findsWidgets); // default screen = catalog (app bar + bottom nav label)
    expect(find.text('Заявки'), findsNothing);
    expect(find.text('Мастерицы'), findsNothing);

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();
    expect(find.text('К получению'), findsOneWidget);
  });
}
