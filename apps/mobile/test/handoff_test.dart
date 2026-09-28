import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/core/ui/widgets.dart' show formatUzs;
import 'package:yusmus_mobile/features/work/assignment_detail_screen.dart';
import 'package:yusmus_mobile/features/work/current_work_card.dart';
import 'package:yusmus_mobile/features/work/models.dart';
import 'package:yusmus_mobile/features/work/receive_work_screens.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'fakes/fake_geo.dart';

/// Phase 5: the two-sided QR handoff as the worker and the staff member see it.
Map<String, dynamic> work({String status = 'READY_TO_DELIVER', Map<String, dynamic>? handoff, List<Object> timeline = const []}) => {
      'id': 'a1', 'code': 'A-0001', 'status': status, 'kitCount': 2, 'plannedMeters': 18.0, 'reportedMeters': 0.0,
      'expectedPayment': '60000', 'dueAt': '2026-10-05T10:00:00.000Z',
      'worker': {'id': 'w1', 'fullName': 'Малика Каримова', 'phone': '+998901234567'},
      'product': {'name': 'Oddiy tekis'}, 'color': {'name': 'Pushti', 'hex': '#f4a6c0'},
      'materials': [
        {'materialId': 'm1', 'quantity': 18, 'name': 'Органза', 'unit': 'METER'},
        {'materialId': 'm2', 'quantity': 80, 'name': 'Бисер', 'unit': 'GRAM'},
      ],
      'statusHistory': <Object>[], 'deliveries': <Object>[], 'handoff': handoff, 'handoffTimeline': timeline,
    };

Map<String, dynamic> handoff({String status = 'AWAITING_WORKER', bool expired = false, String? scannedAt, String? reason}) => {
      'id': 'h1', 'status': status, 'startedAt': '2026-09-28T09:00:00.000Z', 'expiresAt': '2026-09-28T11:00:00.000Z', 'expired': expired,
      'staff': {'id': 's1', 'fullName': 'Менеджер Азиза', 'role': 'MANAGER'}, 'workerScannedAt': scannedAt, 'workerAcceptedAt': null,
      'problemReason': reason, 'problemComment': null, 'materialSnapshot': null, 'hasLocation': false,
    };

Widget app(MockApi api, Widget home) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), geoProvider.overrideWithValue(const FakeGeo())],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-01T00:00:00.000Z'});
  });

  group('worker: assigned ≠ received', () {
    testWidgets('before staff scans: «Вас ожидает новая работа», pay and materials shown, NO progress / ready / scan buttons', (tester) async {
      await tester.pumpWidget(app(api, SingleChildScrollView(child: CurrentWorkCard(work: CurrentWork.fromJson(work())))));
      await tester.pumpAndSettle();
      expect(find.text('Вас ожидает новая работа'), findsOneWidget);
      expect(find.text('Ожидает получения'), findsOneWidget);
      expect(find.textContaining(formatUzs('60000')), findsOneWidget);
      expect(find.text('Органза — 18 м'), findsOneWidget);
      expect(find.text('Бисер — 80 г'), findsOneWidget);
      expect(find.text('Обновить прогресс'), findsNothing);
      expect(find.text('Работа готова'), findsNothing);
      expect(find.text('Сканировать QR'), findsNothing);
    });

    testWidgets('after staff scans: «Ваш комплект готов к получению» + one big «Сканировать QR»', (tester) async {
      await tester.pumpWidget(app(api, SingleChildScrollView(child: CurrentWorkCard(work: CurrentWork.fromJson(work(handoff: handoff()))))));
      await tester.pumpAndSettle();
      expect(find.text('Ваш комплект готов к получению'), findsOneWidget);
      expect(find.text('Сканировать QR'), findsOneWidget);
      expect(find.text('Обновить прогресс'), findsNothing);
    });

    testWidgets('an expired handoff does not offer the scan button', (tester) async {
      await tester.pumpWidget(app(api, SingleChildScrollView(child: CurrentWorkCard(work: CurrentWork.fromJson(work(handoff: handoff(expired: true)))))));
      await tester.pumpAndSettle();
      expect(find.text('Сканировать QR'), findsNothing);
      expect(find.text('Вас ожидает новая работа'), findsOneWidget);
    });

    testWidgets('received (IN_PROGRESS): progress and «Работа готова» become available', (tester) async {
      await tester.pumpWidget(app(api, SingleChildScrollView(child: CurrentWorkCard(work: CurrentWork.fromJson(work(status: 'IN_PROGRESS', handoff: handoff(status: 'CONFIRMED')))))));
      await tester.pumpAndSettle();
      expect(find.text('Обновить прогресс'), findsOneWidget);
      expect(find.text('Работа готова'), findsOneWidget);
      expect(find.text('Осталось: '), findsOneWidget);
    });
  });

  group('worker QR scan', () {
    Widget scanner(void Function(void Function(String)) capture) => ReceiveScanScreen(scannerBuilder: (onCode) {
          capture(onCode);
          return const ColoredBox(color: Colors.black);
        });

    for (final (code, text) in [
      ('FOREIGN_KIT', 'Этот комплект предназначен другой мастерице.'),
      ('HANDOFF_NOT_STARTED', 'Сначала сотрудник должен отсканировать этот QR'),
      ('HANDOFF_EXPIRED', 'Время передачи истекло. Попросите сотрудника отсканировать QR ещё раз.'),
      ('NOT_FOUND', 'QR-код не найден или недоступен'),
    ]) {
      testWidgets('$code -> a plain sentence, nothing about the kit', (tester) async {
        void Function(String)? onCode;
        when(() => api.postJson('/work/handoff/scan', body: any(named: 'body'))).thenThrow(ApiException(code: code, message: 'raw', status: 403));
        await tester.pumpWidget(app(api, scanner((f) => onCode = f)));
        onCode!('YQ1.ABCDEFGHJKMN');
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(find.text('Получение работы'), findsNothing);
      });
    }

    testWidgets('already received -> «Вы уже получили эту работу» (duplicate scan never opens a second receipt)', (tester) async {
      void Function(String)? onCode;
      when(() => api.postJson('/work/handoff/scan', body: any(named: 'body'))).thenAnswer((_) async => {'handoffId': 'h1', 'state': 'CONFIRMED', 'assignment': work(status: 'IN_PROGRESS')});
      await tester.pumpWidget(app(api, scanner((f) => onCode = f)));
      onCode!('YQ1.ABCDEFGHJKMN');
      await tester.pumpAndSettle();
      expect(find.text('Вы уже получили эту работу'), findsOneWidget);
      expect(find.text('Получение работы'), findsNothing);
    });

    testWidgets('own kit -> the receipt review: photo band, name, colour, 18 м, 2 kits, pay, materials, both actions', (tester) async {
      void Function(String)? onCode;
      when(() => api.postJson('/work/handoff/scan', body: any(named: 'body'))).thenAnswer((_) async => {'handoffId': 'h1', 'state': 'AWAITING_WORKER', 'assignment': work(handoff: handoff())});
      await tester.pumpWidget(app(api, scanner((f) => onCode = f)));
      onCode!('YQ1.ABCDEFGHJKMN');
      await tester.pumpAndSettle();
      expect(find.text('Получение работы'), findsOneWidget);
      expect(find.text('Oddiy tekis'), findsOneWidget);
      expect(find.text('Pushti'), findsOneWidget);
      expect(find.text('18 м'), findsOneWidget);
      expect(find.text('Комплектов: 2'), findsOneWidget);
      expect(find.text('Органза — 18 м'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Проверьте работу и материалы перед подтверждением.'), 120);
      expect(find.text('Проверьте работу и материалы перед подтверждением.'), findsOneWidget);
      expect(find.text('Подтвердить получение'), findsOneWidget);
      expect(find.text('Есть проблема'), findsOneWidget);
    });
  });

  group('worker confirmation', () {
    Widget review() => ReceiptReviewScreen(scan: HandoffScan.fromJson({'handoffId': 'h1', 'state': 'AWAITING_WORKER', 'assignment': work(handoff: handoff())}));

    testWidgets('confirm: success ONLY after the server answers, with the fact-of-receipt location; a double tap is one request', (tester) async {
      when(() => api.getJson('/work/current')).thenAnswer((_) async => work(status: 'IN_PROGRESS'));
      when(() => api.postJson('/work/handoff/h1/confirm', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return work(status: 'IN_PROGRESS', handoff: handoff(status: 'CONFIRMED'));
      });
      await tester.pumpWidget(app(api, review()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить получение'));
      await tester.pump();
      await tester.tap(find.text('Подтвердить получение'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Работа получена!'), findsNothing); // not before the commit
      await tester.pumpAndSettle();
      expect(find.text('Работа получена!'), findsOneWidget);
      final call = verify(() => api.postJson('/work/handoff/h1/confirm', body: captureAny(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')))..called(1);
      expect((call.captured.single as Map).containsKey('latitude'), isTrue);
    });

    testWidgets('server refuses (expired): no success screen, a plain sentence, the button stays usable', (tester) async {
      when(() => api.postJson('/work/handoff/h1/confirm', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')))
          .thenThrow(ApiException(code: 'HANDOFF_EXPIRED', message: 'raw', status: 409));
      await tester.pumpWidget(app(api, review()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить получение'));
      await tester.pumpAndSettle();
      expect(find.text('Работа получена!'), findsNothing);
      expect(find.text('Время передачи истекло. Попросите сотрудника отсканировать QR ещё раз.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.ancestor(of: find.text('Подтвердить получение'), matching: find.byType(FilledButton))).onPressed, isNotNull);
    });

    testWidgets('«Есть проблема»: pick a reason, comment, send — nothing is confirmed', (tester) async {
      when(() => api.getJson('/work/current')).thenAnswer((_) async => work(handoff: handoff(status: 'PROBLEM', reason: 'WRONG_COLOR')));
      when(() => api.postJson('/work/handoff/h1/problem', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async => work());
      await tester.pumpWidget(app(api, Builder(builder: (c) => Center(child: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => review())), child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Есть проблема'));
      await tester.pumpAndSettle();
      expect(find.text('Что не так?'), findsOneWidget);
      await tester.tap(find.text('Неправильный цвет'));
      await tester.enterText(find.byType(TextField), 'розовый вместо синего');
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();
      final call = verify(() => api.postJson('/work/handoff/h1/problem', body: captureAny(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')))..called(1);
      expect(call.captured.single, {'reason': 'WRONG_COLOR', 'comment': 'розовый вместо синего'});
      verifyNever(() => api.postJson('/work/handoff/h1/confirm', body: any(named: 'body'), idempotencyKey: any(named: 'idempotencyKey')));
      expect(find.text('Сотрудник получил ваше сообщение. Работа пока не передана.'), findsOneWidget);
      expect(find.text('Получение работы'), findsNothing);
    });
  });

  group('staff', () {
    Widget detail() => const AssignmentDetailScreen(assignmentId: 'a1');

    testWidgets('prepared work: «Начать передачу» (never «Доставлено»); tapping starts the handoff, then «Ожидаем подтверждения мастерицы»', (tester) async {
      when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => work());
      when(() => api.postJson('/admin/assignments/a1/handoff', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async => work(handoff: handoff()));
      await tester.pumpWidget(app(api, detail()));
      await tester.pumpAndSettle();
      expect(find.text('Доставлено'), findsNothing);
      expect(find.text('Подготовленные материалы'), findsOneWidget);
      await tester.tap(find.text('Начать передачу'));
      await tester.pumpAndSettle();
      expect(find.text('Передать комплект мастерице?'), findsOneWidget);

      when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => work(handoff: handoff(), timeline: [
            {'kind': 'HANDOFF_STARTED', 'at': '2026-09-28T09:00:00.000Z', 'by': 'Менеджер Азиза'},
          ]));
      await tester.tap(find.widgetWithText(FilledButton, 'Начать передачу').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      verify(() => api.postJson('/admin/assignments/a1/handoff', idempotencyKey: any(named: 'idempotencyKey'))).called(1);
      expect(find.text('Ожидаем подтверждения мастерицы'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Начать передачу'), findsNothing); // nothing to press while she confirms
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Передача начата · Менеджер Азиза'), findsOneWidget);
    });

    testWidgets('she scanned -> «Мастерица отсканировала QR…»; she reported a problem -> the reason + «Начать передачу снова»', (tester) async {
      when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => work(handoff: handoff(scannedAt: '2026-09-28T09:01:00.000Z')));
      await tester.pumpWidget(app(api, detail()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Мастерица отсканировала QR и проверяет комплект'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // a fresh screen for the next state
      final api2 = MockApi();
      when(() => api2.getJson('/admin/assignments/a1')).thenAnswer((_) async => work(handoff: handoff(status: 'PROBLEM', reason: 'SHORTAGE')));
      await tester.pumpWidget(app(api2, detail()));
      await tester.pumpAndSettle();
      expect(find.text('Мастерица сообщила о проблеме'), findsOneWidget);
      expect(find.text('Не хватает материала'), findsOneWidget);
      expect(find.text('Начать передачу снова'), findsOneWidget);
    });

    testWidgets('confirmed: «Малика Каримова получила комплект», materials now «у мастерицы», human timeline, no raw enums', (tester) async {
      when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => work(status: 'IN_PROGRESS', handoff: handoff(status: 'CONFIRMED'), timeline: [
            {'kind': 'HANDOFF_STARTED', 'at': '2026-09-28T09:00:00.000Z', 'by': 'Менеджер Азиза'},
            {'kind': 'WORKER_SCANNED', 'at': '2026-09-28T09:01:00.000Z', 'by': 'Малика Каримова'},
            {'kind': 'WORKER_CONFIRMED', 'at': '2026-09-28T09:02:00.000Z', 'by': 'Малика Каримова'},
          ]));
      await tester.pumpWidget(app(api, detail()));
      await tester.pumpAndSettle();
      expect(find.text('Материалы у мастерицы'), findsOneWidget);
      expect(find.text('Мастерица отсканировала QR'), findsOneWidget);
      expect(find.text('Мастерица подтвердила получение'), findsOneWidget);
      expect(find.textContaining('WORKER_'), findsNothing);
      expect(find.textContaining('AWAITING'), findsNothing);
    });
  });
}
