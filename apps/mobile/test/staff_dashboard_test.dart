import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusmus_mobile/core/db/app_database.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/features/work/assignment_queue_screen.dart';
import 'package:yusmus_mobile/features/workers/worker_repository.dart';
import 'package:yusmus_mobile/features/workers/workers_due_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'models_test.dart' show workerListItem;

/// Drift's stream cleanup uses a zero-length timer: dispose the tree, let it fire, then close the database.
Future<void> _disposeDrift(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
  await db.close();
}

Widget harness(MockApi api, Widget child) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  group('AssignmentQueueScreen: merges several statuses into one soonest-first feed', () {
    Map<String, dynamic> row(String id, {DateTime? dueAt}) => {
          'id': id, 'status': 'IN_PROGRESS', 'plannedMeters': 18.0, 'reportedMeters': 9.0,
          'dueAt': dueAt?.toIso8601String(), 'worker': {'fullName': 'Работница $id'}, 'product': {'name': 'Модель'}, 'color': {'name': 'Цвет'},
        };

    testWidgets('overdueOnly drops anything not actually overdue and sorts the rest soonest-first', (tester) async {
      final now = DateTime.now();
      when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((inv) async {
        final q = inv.namedArguments[#query] as Map;
        return switch (q['status']) {
          'DELIVERED' => {'items': [row('overdue-2', dueAt: now.subtract(const Duration(days: 1))), row('not-due', dueAt: now.add(const Duration(days: 5)))]},
          'IN_PROGRESS' => {'items': [row('overdue-1', dueAt: now.subtract(const Duration(days: 3))), row('no-due-date')]},
          _ => {'items': <Object>[]},
        };
      });
      await tester.pumpWidget(harness(
        api,
        const AssignmentQueueScreen(title: 'Просрочено', statuses: ['DELIVERED', 'IN_PROGRESS'], overdueOnly: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Работница overdue-1'), findsOneWidget);
      expect(find.text('Работница overdue-2'), findsOneWidget);
      expect(find.text('Работница not-due'), findsNothing); // due in the future — not overdue
      expect(find.text('Работница no-due-date'), findsNothing); // no deadline at all — can't be overdue

      final positions = [tester.getCenter(find.text('Работница overdue-1')).dy, tester.getCenter(find.text('Работница overdue-2')).dy];
      expect(positions[0], lessThan(positions[1])); // overdue-1 (3 days late) sorts before overdue-2 (1 day late)
    });

    testWidgets('no matches: a plain empty state, not an error', (tester) async {
      when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
      await tester.pumpWidget(harness(api, const AssignmentQueueScreen(title: 'В работе', statuses: ['IN_PROGRESS'])));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });

  group('WorkersDueScreen: only workers who are actually owed money, biggest balance first', () {
    testWidgets('a zero balance is excluded; the rest sort descending', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {
            'items': [
              {...workerListItem, 'id': 'w1', 'fullName': 'Мало Должна', 'status': 'ACTIVE', 'balance': '10000'},
              {...workerListItem, 'id': 'w2', 'fullName': 'Много Должна', 'status': 'ACTIVE', 'balance': '90000'},
              {...workerListItem, 'id': 'w3', 'fullName': 'Ничего Не Должна', 'status': 'ACTIVE', 'balance': '0'},
            ],
            'nextCursor': null,
          });
      await WorkerRepository(api, db, prefs).refresh(full: true);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api), appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()), sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkersDueScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ничего Не Должна'), findsNothing);
      final positions = [tester.getCenter(find.text('Много Должна')).dy, tester.getCenter(find.text('Мало Должна')).dy];
      expect(positions[0], lessThan(positions[1])); // 90 000 above 10 000
      await _disposeDrift(tester, db);
    });

    testWidgets('nobody owed: a friendly empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[], 'nextCursor': null});
      await WorkerRepository(api, db, prefs).refresh(full: true);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api), appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()), sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkersDueScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Все выплаты закрыты'), findsOneWidget);
      await _disposeDrift(tester, db);
    });
  });
}
