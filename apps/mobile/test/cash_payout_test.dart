import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/features/work/cash_payout_sheet.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'pay_rate_test.dart' show sum;

Widget harness(MockApi api, {String balance = '100000'}) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(
              body: Center(child: FilledButton(onPressed: () => showCashPayoutSheet(context, workerId: 'w1', balance: balance), child: const Text('open'))),
            )),
      ),
    );

Future<void> open(WidgetTester tester, MockApi api, {String balance = '100000'}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(harness(api, balance: balance));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('full amount: preset fills the whole balance, confirmation shows the exact figure, success closes the sheet', (tester) async {
    when(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    await open(tester, api);

    expect(find.text('К выплате: ${sum('100000')}'), findsOneWidget);
    await tester.tap(find.text('Вся сумма'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    expect(find.text('Вы действительно выдали ${sum('100000')} наличными?'), findsOneWidget); // confirmation states the exact amount

    await tester.tap(find.text('Выплатить').last);
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: {'amount': '100000'})).called(1);
    expect(find.text('open'), findsOneWidget); // sheet closed
    expect(find.text('Выплата записана'), findsOneWidget);
  });

  testWidgets('half: preset fills exactly balance ÷ 2 (integer division)', (tester) async {
    when(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    await open(tester, api, balance: '100001'); // odd, to prove it floors rather than rounds
    await tester.tap(find.text('Половина'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    expect(find.text('Вы действительно выдали ${sum('50000')} наличными?'), findsOneWidget);
    await tester.tap(find.text('Выплатить').last);
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: {'amount': '50000'})).called(1);
  });

  testWidgets('manual amount: typed directly, confirmation echoes back exactly what was typed', (tester) async {
    await open(tester, api);
    await tester.enterText(find.byType(TextField), '25000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    expect(find.text('Вы действительно выдали ${sum('25000')} наличными?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    verifyNever(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')));
  });

  testWidgets('zero: the submit button is disabled, nothing can be sent', (tester) async {
    await open(tester, api);
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Выплатить'));
    expect(button.onPressed, isNull);
  });

  testWidgets('a typed minus sign never produces a negative amount: the field only ever keeps digits', (tester) async {
    await open(tester, api);
    await tester.enterText(find.byType(TextField), '-5000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    expect(find.text('Вы действительно выдали ${sum('5000')} наличными?'), findsOneWidget); // never "-5 000"
  });

  testWidgets('nothing owed: no preset buttons, no amount field, nothing to submit', (tester) async {
    await open(tester, api, balance: '0');
    expect(find.text('Вся сумма'), findsNothing);
    expect(find.text('Половина'), findsNothing);
    expect(find.text('Выплатить'), findsNothing);
  });

  testWidgets('over the balance: the server refuses (INVARIANT_VIOLATION) and the manager sees a plain reason, never the raw server sentence', (tester) async {
    when(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenThrow(ApiException(code: 'INVARIANT_VIOLATION', message: 'Payout exceeds balance: 100000 owed, 999000 requested (use forced:true to override)', status: 409));
    await open(tester, api);
    await tester.enterText(find.byType(TextField), '999000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить').last);
    await tester.pumpAndSettle();

    expect(find.text('Сумма больше, чем причитается мастерице'), findsOneWidget);
    expect(find.textContaining('use forced:true'), findsNothing); // the raw server sentence never reaches the screen
    expect(find.text('Выплатить'), findsOneWidget); // back to a usable state, not stuck busy
  });

  testWidgets('duplicate submit protection: the button turns into a spinner the instant it is tapped', (tester) async {
    when(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return {};
    });
    await open(tester, api);
    await tester.tap(find.text('Вся сумма'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выплатить').last);
    await tester.pump(); // one frame: busy=true is set as soon as the confirm dialog's own future resolves
    await tester.pump(const Duration(milliseconds: 300)); // let the dialog's own closing transition finish; still well inside the 500ms API delay
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // the spinner, not a tappable button, occupies that slot
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/workers/w1/payout', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).called(1);
  });
}
