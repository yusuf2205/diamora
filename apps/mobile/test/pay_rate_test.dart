import 'dart:async';

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
import 'package:yusmus_mobile/core/realtime/realtime_client.dart';
import 'package:yusmus_mobile/core/storage/token_store.dart';
import 'package:yusmus_mobile/core/ui/widgets.dart' show formatUzs;
import 'package:yusmus_mobile/features/auth/auth_controller.dart';
import 'package:yusmus_mobile/features/auth/models.dart';
import 'package:yusmus_mobile/features/settings/pay_rate.dart';

import 'app_flow_test.dart' show FakeAuth, MockApi;
import 'fakes/fake_geo.dart';
import 'models_test.dart' show workerListItem;

/// amounts use a non-breaking space between thousands (formatUzs), so the tests build their expectations with it
String sum(String digits) => '${formatUzs(digits)} сум';

Map<String, dynamic> rate(String v) => {'ratePerKit': v, 'kitMeters': 9, 'updatedAt': '2026-09-21T12:00:00.000Z'};

Future<ProviderScope> app(Session session, MockApi api, StreamController<RealtimeEvent> events) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      apiClientProvider.overrideWithValue(api),
      authControllerProvider.overrideWith(() => FakeAuth(session)),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      geoProvider.overrideWithValue(const FakeGeo()),
      realtimeEventsProvider.overrideWith((ref) => events.stream),
    ],
    child: const YusmusApp(),
  );
}

RealtimeEvent rateChanged(String v) =>
    RealtimeEvent(id: 'e-$v', type: 'pay_rate.changed', occurredAt: DateTime.utc(2026, 9, 21, 12), data: {'ratePerKit': v, 'previousRatePerKit': '30000', 'changedAt': '2026-09-21T12:00:00.000Z'});

/// drift's stream cleanup uses a zero-length timer: dispose the tree and let it fire before the test ends
Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MockApi api;
  late StreamController<RealtimeEvent> events;
  setUp(() {
    api = MockApi();
    events = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => events.close());

  test('the price parses: money stays a decimal string, history knows who/when/from/to', () {
    final r = PayRate.fromJson(rate('30000'));
    expect(r.ratePerKit, '30000');
    expect(r.kitMeters, 9);
    final h = PayRateChange.fromJson({'id': 'h1', 'ratePerKit': '35000', 'previousRatePerKit': '30000', 'changedBy': 'Owner', 'note': 'Индексация', 'createdAt': '2026-09-21T12:00:00.000Z'});
    expect(h.previousRatePerKit, '30000');
    expect(h.changedBy, 'Owner');
    expect(PayRateChange.fromJson({'id': 'h0', 'ratePerKit': '30000', 'createdAt': '2026-09-21T09:00:00.000Z'}).previousRatePerKit, isNull);
  });

  testWidgets('ADMIN opens the price from the profile, changes 30 000 -> 35 000; the server call is idempotent and the screen shows the new price', (tester) async {
    var current = '30000';
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [workerListItem], 'nextCursor': null});
    when(() => api.getList('/auth/sessions')).thenAnswer((_) async => []);
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => rate(current));
    when(() => api.getJson('/settings/pay-rate/history')).thenAnswer((_) async => {
          'items': [
            if (current != '30000') {'id': 'h2', 'ratePerKit': current, 'previousRatePerKit': '30000', 'changedBy': 'Owner', 'note': null, 'createdAt': '2026-09-21T12:00:00.000Z'},
            {'id': 'h1', 'ratePerKit': '30000', 'previousRatePerKit': null, 'changedBy': null, 'note': 'Начальная ставка', 'createdAt': '2026-09-21T09:00:00.000Z'},
          ]
        });
    when(() => api.putJson('/settings/pay-rate', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((inv) async {
      current = (inv.namedArguments[#body] as Map)['ratePerKit'] as String;
      return {...rate(current), 'changed': true};
    });

    final admin = Session.fromJson({'id': 'u1', 'fullName': 'Owner', 'phone': '+998901112233', 'role': 'ADMIN', 'permissions': ['PAY_RATE_MANAGE']});
    await tester.pumpWidget(await app(admin, api, events));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('payRateTile')), matching: find.text(sum('30000'))), findsOneWidget);

    await tester.tap(find.byKey(const Key('payRateTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payRateValue')), findsOneWidget);
    expect(find.text(sum('30000')), findsOneWidget);
    expect(find.textContaining('сразу меняется у всех мастериц'), findsOneWidget);

    await tester.tap(find.byKey(const Key('changePayRate')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('payRateInput')), '0');
    await tester.tap(find.byKey(const Key('savePayRate')));
    await tester.pumpAndSettle();
    expect(find.text('Введите сумму от 1 до 10 000 000'), findsOneWidget); // rejected on the phone, nothing sent
    verifyNever(() => api.putJson(any(), body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')));

    await tester.enterText(find.byKey(const Key('payRateInput')), '35000');
    await tester.tap(find.byKey(const Key('savePayRate')));
    await tester.pumpAndSettle();
    final call = verify(() => api.putJson('/settings/pay-rate', body: captureAny(named: 'body'), idempotencyKey: captureAny(named: 'idempotencyKey'))).captured;
    expect(call[0], {'ratePerKit': '35000'}); // digits as a string: never a float
    expect((call[1] as String).length, greaterThanOrEqualTo(8)); // a retry-safe key
    expect(find.text(sum('35000')), findsWidgets);
    expect(find.text('${formatUzs('30000')} → ${sum('35000')}'), findsOneWidget); // history row
    expect(find.textContaining('Ставка обновлена: ${sum('35000')}'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('WORKER sees the current price on the home screen and it follows an ADMIN change in realtime', (tester) async {
    var current = '30000';
    when(() => api.getJson('/workers/me')).thenAnswer((_) async => {...workerListItem, 'status': 'ACTIVE', 'collaterals': []});
    when(() => api.getJson('/workers/me/collateral')).thenAnswer((_) async => {'items': []});
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => rate(current));
    when(() => api.getJson('/catalog')).thenAnswer((_) async => {'items': []});
    final worker = Session.fromJson({'id': 'u2', 'fullName': 'Малика', 'phone': '+998901234567', 'role': 'WORKER', 'workerId': 'w1'});
    await tester.pumpWidget(await app(worker, api, events));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Главная')); // the worker's default screen is now the catalog (§18)
    await tester.pumpAndSettle();
    expect(find.text('Оплата за 9 метров'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('workerPayRate'))).data, sum('30000'));

    current = '40000'; // ADMIN changed it on the server; the phone is only TOLD, then refetches
    events.add(rateChanged('40000'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('workerPayRate'))).data, sum('40000'));
    verify(() => api.getJson('/settings/pay-rate')).called(2);
    expect(find.byKey(const Key('changePayRate')), findsNothing); // a worker has no way to edit it
    await tearDownApp(tester);
  });
}
