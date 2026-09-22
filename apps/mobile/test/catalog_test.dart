import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/app/app.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/catalog/admin_catalog_screen.dart';
import 'package:yusmus_mobile/features/catalog/worker_catalog_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show FakeAuth, MockApi;
import 'fakes/fake_geo.dart';

Map<String, dynamic> catalogItem({String id = 'c1', bool isNew = false}) => {
      'id': id, 'name': 'Комплект «Роза»', 'isNew': isNew, 'availability': 'AVAILABLE',
      'coverPhoto': {'id': 'f1', 'url': 'https://files.example/f1', 'thumbUrl': 'https://files.example/f1_t'}, 'colors': <Object>[],
    };

Map<String, dynamic> catalogDetail({String id = 'c1'}) => {
      'id': id, 'name': 'Комплект «Роза»', 'description': 'Ручная работа, розовое золото', 'isNew': true, 'availability': 'AVAILABLE',
      'media': <Object>[],
      'variants': [
        {'id': 'v1', 'label': 'Классика', 'color': {'id': 'col1', 'name': 'Розовое золото'}},
      ],
    };

AppDatabase? lastDb;

/// drift's stream cleanup uses a zero-length timer: dispose the tree, let it fire, then close the database
/// (otherwise `flutter_test` fails the next test with "A Timer is still pending").
Future<void> tearDownDb(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
  await lastDb?.close();
  lastDb = null;
}

Future<ProviderScope> appWith(Session session, MockApi api) async {
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
      geoProvider.overrideWithValue(const FakeGeo()),
    ],
    child: const YusmusApp(),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('WORKER catalog: the default screen, with real cards and never a price anywhere on it', (tester) async {
    when(() => api.getJson('/catalog')).thenAnswer((_) async => {'items': [catalogItem()]});
    final worker = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(await appWith(worker, api));
    await tester.pumpAndSettle();

    expect(find.text('Наши работы'), findsWidgets); // default screen = catalog (app bar + bottom nav)
    expect(find.text('Комплект «Роза»'), findsOneWidget);
    expect(find.textContaining('сум'), findsNothing); // never a price in the worker catalog
  });

  testWidgets('WORKER catalog: nothing published yet shows the empty state, not an error', (tester) async {
    when(() => api.getJson('/catalog')).thenAnswer((_) async => {'items': []});
    final worker = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(await appWith(worker, api));
    await tester.pumpAndSettle();
    expect(find.text('Пока ничего не опубликовано'), findsOneWidget);
  });

  testWidgets('catalog item detail: description, colours and Call/Telegram — never a price', (tester) async {
    when(() => api.getJson('/catalog/c1')).thenAnswer((_) async => catalogDetail());
    when(() => api.getJson('/settings/company-contact')).thenAnswer((_) async => {'phone': '+998901234567', 'telegramUsername': 'yusmus_shop', 'telegramUrl': 'https://t.me/yusmus_shop'});
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CatalogItemDetailScreen(itemId: 'c1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Комплект «Роза»'), findsOneWidget);
    expect(find.text('Ручная работа, розовое золото'), findsOneWidget);
    expect(find.text('Розовое золото · Классика'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    expect(find.text('Написать в Telegram'), findsOneWidget);
    expect(find.textContaining('сум'), findsNothing);
  });

  testWidgets('catalog item detail: no company phone/Telegram configured -> no contact buttons shown (never a broken button)', (tester) async {
    when(() => api.getJson('/catalog/c1')).thenAnswer((_) async => catalogDetail());
    when(() => api.getJson('/settings/company-contact')).thenAnswer((_) async => {'phone': null, 'telegramUsername': null, 'telegramUrl': null});
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CatalogItemDetailScreen(itemId: 'c1'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Позвонить'), findsNothing);
    expect(find.text('Написать в Telegram'), findsNothing);
  });

  testWidgets('ADMIN catalog management: creating an item sends exactly the name typed, nothing else', (tester) async {
    when(() => api.getJson('/admin/catalog', query: any(named: 'query'))).thenAnswer((_) async => {'items': []});
    when(() => api.getJson('/admin/catalog/new1')).thenAnswer((_) async => {'id': 'new1', 'name': 'Серьги «Капля»', 'status': 'DRAFT', 'isNew': false, 'availability': 'AVAILABLE', 'media': <Object>[], 'variants': <Object>[]});
    when(() => api.postJson('/admin/catalog', body: any(named: 'body'))).thenAnswer((inv) async => {
          'id': 'new1', 'name': (inv.namedArguments[#body] as Map)['name'], 'status': 'DRAFT', 'isNew': false, 'availability': 'AVAILABLE', 'media': <Object>[], 'variants': <Object>[],
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminCatalogScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить работу'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Серьги «Капля»');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final captured = verify(() => api.postJson('/admin/catalog', body: captureAny(named: 'body'))).captured;
    expect(captured.single, {'name': 'Серьги «Капля»'});
    expect(find.text('Серьги «Капля»'), findsOneWidget); // navigated into the new item's detail screen
  });
}
