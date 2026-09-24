import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/workers/worker_detail_screen.dart';
import 'package:yusmus_mobile/features/workers/worker_history_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'models_test.dart' show workerListItem;

Map<String, dynamic> row(String id, String status, {double reported = 0, String? dueAt}) => {
      'id': id, 'status': status, 'plannedMeters': 18.0, 'reportedMeters': reported, 'dueAt': dueAt,
      'worker': {'fullName': 'Малика Каримова'}, 'product': {'name': 'Комплект «Роза»'}, 'color': {'name': 'Розовое золото'},
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  setUp(() => api = MockApi());

  Future<AppDatabase> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api), appDatabaseProvider.overrideWithValue(db),
        sharedPrefsProvider.overrideWithValue(prefs), tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WorkerDetailScreen(workerId: 'w1'),
      ),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> dispose(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await db.close();
  }

  void stubCommon() {
    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {
          ...workerListItem, 'id': 'w1', 'status': 'ACTIVE', 'collaterals': <Object>[],
          'manager': {'id': 'm1', 'fullName': 'Дилноза Менеджер'},
        });
    when(() => api.getJson('/admin/workers/w1/ledger')).thenAnswer((_) async => {
          'workerId': 'w1', 'balance': '60000', 'earned': '90000', 'paid': '30000',
          'history': [
            {'id': 'l1', 'type': 'EARNING', 'amount': '90000', 'comment': null, 'createdAt': '2026-09-20T10:00:00Z'},
            {'id': 'l2', 'type': 'PAYOUT_CASH', 'amount': '-30000', 'comment': null, 'createdAt': '2026-09-21T10:00:00Z'},
          ],
        });
    when(() => api.getJson('/locations')).thenAnswer((_) async => {
          'items': [
            {'userId': 'u9', 'role': 'WORKER', 'fullName': 'Малика Каримова', 'worker': {'id': 'w1', 'code': 'W-0007', 'managerId': 'm1'},
             'latitude': 41.3, 'longitude': 69.28, 'ageSeconds': 30, 'stale': false, 'freshness': 'LIVE', 'online': true},
          ],
        });
  }

  testWidgets('the card shows her manager, that she is online, and her live location instead of the registration one', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    final db = await pump(tester);

    expect(find.textContaining('Дилноза Менеджер'), findsOneWidget);
    expect(find.textContaining('в сети'), findsOneWidget);
    expect(find.text('41.30000, 69.28000'), findsOneWidget);
    expect(find.text('Выдать работу'), findsOneWidget);
    await dispose(tester, db);
  });

  testWidgets('current work shows progress and deadline, and the one next action for its status', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [row('a1', 'READY_FOR_PICKUP', reported: 12, dueAt: '2026-10-05T12:00:00Z'), row('a2', 'COMPLETED', reported: 18)],
        });
    final db = await pump(tester);

    expect(find.text('Готово 12 из 18 м · Срок: 05.10'), findsOneWidget);
    expect(find.text('Забрал'), findsOneWidget); // READY_FOR_PICKUP -> the pickup action
    expect(find.text('Принять работу'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget); // the completed one is not "current work"
    await dispose(tester, db);
  });

  testWidgets('«История» lists every assignment (completed too) and every money movement', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [row('a1', 'IN_PROGRESS', reported: 6), row('a2', 'COMPLETED', reported: 18)],
        });
    final db = await pump(tester);

    await tester.tap(find.byTooltip('История'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkerHistoryScreen), findsOneWidget);
    expect(find.text('Завершено'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\+90\s000')), findsOneWidget);
    expect(find.textContaining(RegExp(r'-30\s000')), findsOneWidget);
    await dispose(tester, db);
  });
}
