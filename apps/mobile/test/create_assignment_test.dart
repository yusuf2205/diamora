import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/work/create_assignment_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'models_test.dart' show workerListItem;
import 'pay_rate_test.dart' show sum;

Map<String, dynamic> product({String id = 'p1', String variantId = 'v1'}) => {
      'id': id, 'name': 'Комплект «Роза»', 'availability': 'AVAILABLE', 'isNew': false,
      'variants': [
        {'id': variantId, 'label': 'Классика', 'active': true, 'color': {'id': 'col1', 'name': 'Розовое золото', 'hex': '#E8B4B8'}},
      ],
    };

Map<String, dynamic> kit({String id = 'k1', String? variantId, bool active = true, List<Map<String, Object?>>? items}) => {
      'id': id, 'name': 'Комплект 9м', 'variantId': variantId, 'ribbonMeters': 9.0, 'baseMeters': 9, 'active': active,
      'items': items ?? [{'materialId': 'm1', 'materialName': 'Атлас 1000ток', 'unit': 'METER', 'requiredQuantity': 9.0}],
    };

Map<String, dynamic> assignmentJson({String id = 'a1', String status = 'READY_TO_DELIVER'}) => {
      'id': id, 'code': 'A-0001', 'status': status, 'kitCount': 1, 'plannedMeters': 9.0,
      'worker': {'id': 'w1', 'fullName': 'Малика Каримова', 'phone': '+998901234567'},
      'product': {'name': 'Комплект «Роза»'}, 'variant': {'label': 'Классика'}, 'color': {'name': 'Розовое золото', 'hex': '#E8B4B8'},
      'materials': <Object>[], 'statusHistory': <Object>[], 'deliveries': <Object>[],
    };

AppDatabase? _lastDb;

Future<void> tearDownDb(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
  await _lastDb?.close();
  _lastDb = null;
}

/// Wraps the screen with a real 2-deep GoRouter stack (a dummy "/" screen it can pop back to, and a dummy assignment
/// detail route to prove `context.push('/admin/assignments/:id')` after a successful submit), exactly mirroring how
/// Worker Detail actually reaches this screen — not a MaterialApp shortcut that would let a navigation bug hide.
Future<(Widget, GoRouter)> harness(MockApi api, {String? workerId, AppDatabase? db}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final theDb = _lastDb = db ?? AppDatabase.forTesting(NativeDatabase.memory());
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
    GoRoute(path: '/create', builder: (_, _) => CreateAssignmentScreen(workerId: workerId)),
    GoRoute(path: '/admin/assignments/:id', builder: (_, s) => Scaffold(body: Text('detail:${s.pathParameters['id']}'))),
  ]);
  final widget = ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      appDatabaseProvider.overrideWithValue(theDb),
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    ],
    child: MaterialApp.router(routerConfig: router, locale: const Locale('ru'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales),
  );
  return (widget, router);
}

Future<void> bigScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400); // tall enough that grid/list items never sit under the bottom bar
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-23T12:00:00.000Z'});
    when(() => api.getJson('/admin/catalog', query: any(named: 'query'))).thenAnswer((_) async => {'items': [product()]});
    when(() => api.getJson('/admin/kits')).thenAnswer((_) async => {'items': [kit()]});
  });

  testWidgets('full flow: pick worker, model, colour, 9 m, summary shows the calculated payment, submit succeeds and navigates to the new assignment', (tester) async {
    await bigScreen(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.cachedWorkers).insert(CachedWorkersCompanion.insert(
      id: 'w1', status: 'ACTIVE', name: 'Малика Каримова', search: 'малика +998901234567',
      json: jsonEncode({...workerListItem, 'id': 'w1', 'status': 'ACTIVE'}), cachedAt: DateTime.now(),
    ));
    when(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async => assignmentJson());

    final (widget, router) = await harness(api, db: db);
    await tester.pumpWidget(widget);
    router.push('/create');
    await tester.pumpAndSettle();

    expect(find.text('Выберите мастерицу'), findsOneWidget);
    await tester.tap(find.text('Малика Каримова'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('Комплект «Роза»'), findsOneWidget); // step: product
    await tester.tap(find.text('Комплект «Роза»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('Розовое золото · Классика'), findsOneWidget); // step: colour/variant
    await tester.tap(find.text('Розовое золото · Классика'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('9 м'), findsOneWidget); // step: volume (9/18/27)
    expect(find.text('18 м'), findsOneWidget);
    expect(find.text('27 м'), findsOneWidget);
    await tester.tap(find.text('9 м'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далее')); // step: due date/comment, both optional
    await tester.pumpAndSettle();

    expect(find.text('Малика Каримова'), findsOneWidget); // summary
    expect(find.text('9 м'), findsOneWidget);
    expect(find.text(sum('30000')), findsOneWidget); // 1 kit x 30 000 — the calculated payment, never left to the client to invent

    await tester.tap(find.text('Выдать работу'));
    await tester.pump(); // one frame: the catch-free success path pops and pushes immediately
    await tester.pump();

    verify(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: {
          'workerId': 'w1', 'productModelId': 'p1', 'productVariantId': 'v1', 'colorId': 'col1', 'materialKitTemplateId': 'k1', 'kitCount': 1,
        })).called(1);
    expect(find.text('detail:a1'), findsOneWidget); // navigated into the freshly created assignment
    expect(find.text('Работа выдана'), findsOneWidget); // the SnackBar is caught here, before its own auto-dismiss timer would clear it
    await tearDownDb(tester);
  });

  testWidgets('insufficient material: the friendly message names the exact material, never a raw error code', (tester) async {
    await bigScreen(tester);
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ACTIVE'});
    when(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenThrow(ApiException(code: 'INSUFFICIENT_STOCK', message: 'Not enough stock', status: 409, details: {'materialId': 'm1'}));

    final (widget, router) = await harness(api, workerId: 'w1');
    await tester.pumpWidget(widget);
    router.push('/create');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Комплект «Роза»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Розовое золото · Классика'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9 м'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выдать работу'));
    // the catch handler chains TWO awaits (the rejected create call, then a fresh kits() fetch to resolve the material
    // name) before it calls showError — enough pumps to flush both microtask hops, short of a full pumpAndSettle
    // (which would run out the SnackBar's own auto-dismiss timer and make it invisible to the assertion below)
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Не хватает материала: Атлас 1000ток'), findsOneWidget);
    expect(find.text('INSUFFICIENT_STOCK'), findsNothing);
    expect(find.text('detail:a1'), findsNothing); // stayed on the summary — nothing was created
    await tearDownDb(tester);
  });

  testWidgets('a generic API failure keeps the screen usable (no crash, the button reappears so the manager can retry)', (tester) async {
    await bigScreen(tester);
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ACTIVE'});
    when(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenThrow(ApiException.network());

    final (widget, router) = await harness(api, workerId: 'w1');
    await tester.pumpWidget(widget);
    router.push('/create');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Комплект «Роза»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Розовое золото · Классика'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9 м'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выдать работу'));
    await tester.pumpAndSettle();
    expect(find.text('Нет связи с сервером. Проверьте интернет.'), findsOneWidget);
    expect(find.text('Выдать работу'), findsOneWidget); // the button is back: nothing is stuck in a busy state forever
    await tearDownDb(tester);
  });

  testWidgets('double submit protection: the button disappears the instant it is tapped, the server sees exactly one request', (tester) async {
    await bigScreen(tester);
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ACTIVE'});
    when(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return assignmentJson();
    });

    final (widget, router) = await harness(api, workerId: 'w1');
    await tester.pumpWidget(widget);
    router.push('/create');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Комплект «Роза»'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Розовое золото · Классика'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9 м'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выдать работу'));
    await tester.pump(); // one frame: _busy is now true, the whole bottom bar (and its button) is gone
    expect(find.text('Выдать работу'), findsNothing);
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/assignments', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).called(1);
    await tearDownDb(tester);
  });
}
