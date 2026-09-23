import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'models_test.dart' show workerListItem;
import 'pay_rate_test.dart' show app, rate, sum, tearDownApp;

Map<String, dynamic> ledger({required String balance, required String earned, required String paid, List<Map<String, Object?>> history = const []}) =>
    {'balance': balance, 'earned': earned, 'paid': paid, 'history': history};

Map<String, Object?> entry({required String type, required String amount, String id = 'e1'}) => {'id': id, 'type': type, 'amount': amount, 'createdAt': '2026-09-20T10:00:00.000Z'};

Future<void> openHome(WidgetTester tester, dynamic Function() build) async {
  await tester.pumpWidget(await build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Главная'));
  await tester.pumpAndSettle();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  late StreamController<RealtimeEvent> events;
  setUp(() {
    api = MockApi();
    events = StreamController<RealtimeEvent>.broadcast();
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'status': 'ACTIVE', 'collaterals': []});
    when(() => api.getJson('/workers/me/collateral')).thenAnswer((_) async => {'items': []});
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => rate('30000'));
    when(() => api.getJson('/catalog')).thenAnswer((_) async => {'items': []});
    when(() => api.getJson('/work/current')).thenAnswer((_) async => <String, dynamic>{});
  });
  tearDown(() => events.close());
  final worker = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});

  testWidgets('К получению / Заработано / Выплачено — plain totals, straight from the server, never computed on the phone', (tester) async {
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'status': 'ACTIVE', 'collaterals': [], 'balance': '15000'});
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => ledger(balance: '15000', earned: '105000', paid: '90000'));
    await openHome(tester, () => app(worker, api, events));

    expect(find.text(sum('15000')), findsOneWidget); // К получению (the headline balance)
    expect(find.text(sum('105000')), findsOneWidget); // Заработано
    expect(find.text(sum('90000')), findsOneWidget); // Выплачено
    await tearDownApp(tester);
  });

  testWidgets('history: plain-language labels only — never the raw ledger type (EARNING/PAYOUT_CASH) anywhere on screen', (tester) async {
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => ledger(
          balance: '0', earned: '90000', paid: '90000',
          history: [entry(id: 'h1', type: 'EARNING', amount: '60000'), entry(id: 'h2', type: 'PAYOUT_CASH', amount: '-90000')],
        ));
    await openHome(tester, () => app(worker, api, events));

    expect(find.text('История'), findsOneWidget);
    expect(find.text('Начисление'), findsOneWidget); // EARNING, in plain language
    expect(find.text('Выплатить наличными'), findsOneWidget); // PAYOUT_CASH, in plain language
    expect(find.text('+${sum('60000')}'), findsOneWidget);
    expect(find.text('-${sum('90000')}'), findsOneWidget);
    expect(find.text('EARNING'), findsNothing);
    expect(find.text('PAYOUT_CASH'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('empty history: no card, no "nothing here" placeholder in its place — the section simply does not exist yet', (tester) async {
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => ledger(balance: '0', earned: '0', paid: '0'));
    await openHome(tester, () => app(worker, api, events));
    expect(find.text('История'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('earnings API failure: degrades gracefully — the earned/paid breakdown and history simply do not render, the rest of the home screen (balance, profile, price) stays fully usable, no raw error anywhere', (tester) async {
    when(() => api.getJson('/work/earnings')).thenAnswer((_) async => throw Exception('boom'));
    await openHome(tester, () => app(worker, api, events));

    expect(find.text('Малика Каримова'), findsOneWidget); // the rest of the screen is unaffected (name comes from /workers/me)
    expect(find.text(sum('30000')), findsWidgets); // pay rate card still works
    expect(find.text('История'), findsNothing);
    expect(find.text('Заработано'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    await tearDownApp(tester);
  });
}
