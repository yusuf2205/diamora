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
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
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

  Future<AppDatabase> pump(WidgetTester tester, {List<String> perms = const []}) async {
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
        authControllerProvider.overrideWith(() => _FixedAuth(Session(id: 'me', fullName: 'Owner', phone: '+998901112233', role: 'SUPER_ADMIN', permissions: perms))),
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

  testWidgets('«Сменить менеджера»: pick another manager in a sheet, the server call carries exactly that id', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getJson('/managers')).thenAnswer((_) async => {
          'items': [
            {'id': 'm1', 'phone': '+998901', 'fullName': 'Дилноза Менеджер', 'role': 'MANAGER', 'status': 'ACTIVE', 'stats': {'workers': 4}},
            {'id': 'm2', 'phone': '+998902', 'fullName': 'Гульнора Новая', 'role': 'MANAGER', 'status': 'ACTIVE', 'stats': {'workers': 1}},
            {'id': 'm3', 'phone': '+998903', 'fullName': 'Отключённый Менеджер', 'role': 'MANAGER', 'status': 'SUSPENDED', 'stats': {'workers': 0}},
          ],
        });
    when(() => api.postJson('/workers/w1/manager', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {
          ...workerListItem, 'id': 'w1', 'status': 'ACTIVE', 'manager': {'id': 'm2', 'fullName': 'Гульнора Новая'},
        });
    final db = await pump(tester, perms: ['WORKER_ASSIGN_MANAGER']);

    await tester.tap(find.text('Сменить менеджера'));
    await tester.pumpAndSettle();
    expect(find.text('Отключённый Менеджер'), findsNothing); // a disabled manager cannot take workers
    await tester.tap(find.text('Гульнора Новая'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/workers/w1/manager', idempotencyKey: any(named: 'idempotencyKey'), body: {'managerId': 'm2'})).called(1);
    expect(find.text('Менеджер изменён'), findsOneWidget);
    await dispose(tester, db);
  });

  testWidgets('without WORKER_ASSIGN_MANAGER / WORKER_UPDATE there is no «Сменить менеджера» and no «Архивировать»', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    final db = await pump(tester);
    expect(find.text('Сменить менеджера'), findsNothing);
    expect(find.text('Архивировать мастерицу'), findsNothing);
    await dispose(tester, db);
  });

  testWidgets('«Архивировать мастерицу» asks first (history stays) and sends ARCHIVED; an archived one offers «Восстановить»', (tester) async {
    stubCommon();
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.patchJson('/workers/w1', body: any(named: 'body'))).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ARCHIVED'});
    final db = await pump(tester, perms: ['WORKER_UPDATE']);

    await tester.tap(find.text('Архивировать мастерицу'));
    await tester.pumpAndSettle();
    expect(find.textContaining('История, выплаты и залог сохранятся'), findsOneWidget);
    verifyNever(() => api.patchJson(any(), body: any(named: 'body')));
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    verify(() => api.patchJson('/workers/w1', body: {'status': 'ARCHIVED'})).called(1);
    await dispose(tester, db);

    when(() => api.getJson('/workers/w1')).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ARCHIVED', 'collaterals': <Object>[]});
    when(() => api.patchJson('/workers/w1', body: any(named: 'body'))).thenAnswer((_) async => {...workerListItem, 'id': 'w1', 'status': 'ACTIVE'});
    final db2 = await pump(tester, perms: ['WORKER_UPDATE']);
    expect(find.text('Архивировать мастерицу'), findsNothing);
    await tester.tap(find.text('Восстановить мастерицу'));
    await tester.pumpAndSettle();
    verify(() => api.patchJson('/workers/w1', body: {'status': 'ACTIVE'})).called(1);
    expect(find.text('Мастерица восстановлена'), findsOneWidget);
    await dispose(tester, db2);
  });
}

class _FixedAuth extends AuthController {
  _FixedAuth(this._s);
  final Session _s;
  @override
  Future<Session?> build() async => _s;
}
