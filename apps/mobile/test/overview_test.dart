import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/dashboard/staff_dashboard_screen.dart';
import 'package:yusmus_mobile/features/work/assignment_queue_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show FakeAuth, MockApi;

Session staff(String role, {List<String> permissions = const []}) =>
    Session.fromJson({'id': 'u1', 'fullName': 'Юсуф Адилов', 'phone': '+998901112233', 'role': role, 'permissions': permissions});

Map<String, dynamic> dash({int overdue = 1, int workersDue = 2, bool finance = true}) => {
      'workers': {'total': 5, 'active': 4, 'withActiveAssignment': 2, 'withoutActiveAssignment': 2},
      'work': {'activeAssignments': 3, 'inProgress': 6, 'metersOnHand': 27, 'toDeliver': 3, 'toPickup': 1, 'needsAcceptance': 0, 'completed': 10, 'overdue': overdue, 'reworkRequired': 0},
      'finance': finance ? {'earned': '500000', 'paid': '200000', 'due': '180000', 'workersDue': workersDue, 'salesRevenue': null, 'expenses': null, 'netProfit': null} : null,
      'today': {'dueToday': 2, 'deliveredToday': 1, 'pickedUpToday': 0, 'paidToday': finance ? '60000' : null},
    };

void main() {
  late MockApi api;
  late StreamController<RealtimeEvent> events;
  setUp(() {
    api = MockApi();
    events = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => events.close());

  Future<void> pump(WidgetTester tester, Session session) async {
    tester.view.physicalSize = const Size(1200, 2600); // a tall tablet: every section on screen at once, no scrolling
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(() => FakeAuth(session)),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StaffDashboardScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('SUPER_ADMIN: greeting with first name and role, the counters, "требует внимания" and "сегодня" from real numbers', (tester) async {
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash());
    await pump(tester, staff('SUPER_ADMIN', permissions: ['ASSIGNMENT_CREATE', 'CASH_PAYOUT']));

    expect(find.text('Юсуф'), findsOneWidget);
    expect(find.text('Главный администратор'), findsOneWidget);
    expect(find.text('Активные мастерицы'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('6'), findsOneWidget); // в работе
    expect(find.textContaining(RegExp(r'180\s000')), findsOneWidget); // к выплате
    expect(find.text('1 просроченная работа'), findsOneWidget);
    expect(find.text('3 доставки'), findsOneWidget);
    expect(find.text('1 работа готова'), findsOneWidget);
    expect(find.text('2 мастерицы ждут выплату'), findsOneWidget);
    expect(find.text('Срок сегодня'), findsOneWidget);
    expect(find.textContaining(RegExp(r'60\s000')), findsOneWidget); // выплачено сегодня
    expect(find.text('Выдать работу'), findsOneWidget);
    expect(find.text('Выплатить наличными'), findsOneWidget);
  });

  testWidgets('MANAGER without finance/payout rights: her role, no money card, no payout action (the server already scopes her numbers)', (tester) async {
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash(finance: false));
    await pump(tester, staff('MANAGER'));

    expect(find.text('Менеджер'), findsOneWidget);
    expect(find.text('К выплате'), findsNothing);
    expect(find.text('Выплатить наличными'), findsNothing);
    expect(find.text('Выдать работу'), findsNothing); // no ASSIGNMENT_CREATE
    expect(find.text('В работе'), findsOneWidget);
  });

  testWidgets('nothing urgent: one calm line instead of an empty block', (tester) async {
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => {
          ...dash(overdue: 0, workersDue: 0),
          'work': {'activeAssignments': 0, 'inProgress': 0, 'metersOnHand': 0, 'toDeliver': 0, 'toPickup': 0, 'needsAcceptance': 0, 'completed': 0, 'overdue': 0, 'reworkRequired': 0},
        });
    await pump(tester, staff('ADMIN'));
    expect(find.text('Всё под контролем'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, then the data', (tester) async {
    final gate = Completer<Map<String, dynamic>>();
    when(() => api.getJson('/dashboard')).thenAnswer((_) => gate.future);
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(() => FakeAuth(staff('ADMIN'))),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StaffDashboardScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('Активные мастерицы'), findsNothing);
    gate.complete(dash());
    await tester.pumpAndSettle();
    expect(find.text('Активные мастерицы'), findsOneWidget);
  });

  testWidgets('a server error: a plain message and "Повторить", never the raw exception; retry refetches', (tester) async {
    var failing = true;
    when(() => api.getJson('/dashboard')).thenAnswer((_) async {
      if (failing) throw Exception('SocketException: boom');
      return dash();
    });
    await pump(tester, staff('ADMIN'));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Активные мастерицы'), findsOneWidget);
  });

  testWidgets('realtime: an event elsewhere refreshes the counters without a manual refresh', (tester) async {
    var overdue = 1;
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash(overdue: overdue));
    await pump(tester, staff('ADMIN'));
    expect(find.text('1 просроченная работа'), findsOneWidget);

    overdue = 3;
    events.add(RealtimeEvent(id: 'e1', type: 'assignment.status_changed', occurredAt: DateTime.now(), data: const {}));
    await tester.pumpAndSettle();
    expect(find.text('3 просроченные работы'), findsOneWidget);
  });

  testWidgets('an attention line opens the list behind it', (tester) async {
    when(() => api.getJson('/dashboard')).thenAnswer((_) async => dash());
    when(() => api.getJson('/admin/assignments', query: any(named: 'query'))).thenAnswer((_) async => {'items': <Object>[]});
    await pump(tester, staff('ADMIN'));
    await tester.tap(find.text('1 просроченная работа'));
    await tester.pumpAndSettle();
    expect(find.byType(AssignmentQueueScreen), findsOneWidget);
  });
}
