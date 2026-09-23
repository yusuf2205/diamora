import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/features/work/acceptance_screen.dart';
import 'package:yusmus_mobile/features/work/assignment_models.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;
import 'pay_rate_test.dart' show sum;

Map<String, dynamic> assignmentJson({double planned = 9, double reported = 0, String status = 'UNDER_REVIEW'}) => {
      'id': 'a1', 'code': 'A-0001', 'status': status, 'kitCount': 1, 'plannedMeters': planned, 'reportedMeters': reported,
      'worker': {'id': 'w1', 'fullName': 'Малика Каримова', 'phone': '+998901234567'},
      'product': {'name': 'Комплект «Роза»'}, 'color': {'name': 'Розовое золото'},
      'materials': <Object>[], 'statusHistory': <Object>[], 'deliveries': <Object>[],
    };

AssignmentDetail assignment({double planned = 9, double reported = 0}) => AssignmentDetail.fromJson(assignmentJson(planned: planned, reported: reported));

/// Pushed via a real Navigator (the screen itself calls the classic `Navigator.of(context).pop()`, not go_router),
/// exactly like `AssignmentDetailScreen`'s "Принять работу" button does it.
Widget harness(MockApi api, AssignmentDetail a) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(
              body: Center(child: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AcceptanceScreen(assignment: a))), child: const Text('open'))),
            )),
      ),
    );

Future<void> open(WidgetTester tester, MockApi api, AssignmentDetail a) async {
  tester.view.physicalSize = const Size(1080, 2400); // tall enough that the ListView never needs a scroll to find its own content
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(harness(api, a));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/settings/pay-rate')).thenAnswer((_) async => {'ratePerKit': '30000', 'kitMeters': 9, 'updatedAt': '2026-09-23T12:00:00.000Z'});
  });

  testWidgets('brought = accepted (nothing wrong with the batch): live earning preview, submit sends exact values, success pops and shows a plain-language result', (tester) async {
    when(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async => assignmentJson(status: 'ACCEPTED'));
    await open(tester, api, assignment());

    expect(find.text('Принято: 9.0 м'), findsOneWidget);
    expect(find.text('Начисление: ${sum('30000')}'), findsOneWidget);

    await tester.tap(find.text('Принять работу'));
    await tester.pump();
    await tester.pump();
    verify(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: {
          'broughtMeters': '9.00', 'acceptedMeters': '9.00', 'defectiveMeters': '0.00', 'reworkMeters': '0.00',
        })).called(1);
    expect(find.text('Работа принята'), findsOneWidget); // the SnackBar, caught before its own auto-dismiss timer clears it
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget); // fully settled: back on the caller's screen
  });

  testWidgets('defective units: accepted + defective = brought is valid, the preview and the payload both use the reduced accepted figure', (tester) async {
    when(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async => assignmentJson(status: 'ACCEPTED'));
    await open(tester, api, assignment());

    await tester.enterText(find.byType(TextField).at(1), '7'); // accepted
    await tester.enterText(find.byType(TextField).at(2), '2'); // defective
    await tester.pumpAndSettle();

    expect(find.text('Принято: 7.0 м'), findsOneWidget);
    expect(find.text('Брак: 2.0 м'), findsOneWidget);
    expect(find.text('Начисление: ${sum('23333')}'), findsOneWidget); // round_half_up(30000*7/9)

    await tester.tap(find.text('Принять работу'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: {
          'broughtMeters': '9.00', 'acceptedMeters': '7.00', 'defectiveMeters': '2.00', 'reworkMeters': '0.00',
        })).called(1);
  });

  testWidgets('rework units: accepted + rework = brought is valid too', (tester) async {
    when(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async => assignmentJson(status: 'ACCEPTED'));
    await open(tester, api, assignment());

    await tester.enterText(find.byType(TextField).at(1), '5'); // accepted
    await tester.enterText(find.byType(TextField).at(3), '4'); // rework
    await tester.pumpAndSettle();

    expect(find.text('На доработку: 4.0 м'), findsOneWidget);
    expect(find.text('Начисление: ${sum('16667')}'), findsOneWidget); // round_half_up(30000*5/9)

    when(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => assignmentJson(status: 'ACCEPTED'));
    await tester.tap(find.text('Принять работу'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: {
          'broughtMeters': '9.00', 'acceptedMeters': '5.00', 'defectiveMeters': '0.00', 'reworkMeters': '4.00',
        })).called(1);
  });

  testWidgets('validation: accepted + defective + rework must equal brought exactly, or the submit button is disabled and a plain message explains why', (tester) async {
    await open(tester, api, assignment());
    await tester.enterText(find.byType(TextField).at(1), '5'); // accepted 5, defective 0, rework 0 -> 5 != brought(9)
    await tester.pumpAndSettle();

    expect(find.text('Принято + брак + доработка должно равняться принесено'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Принять работу'));
    expect(button.onPressed, isNull);
    verifyNever(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')));
  });

  testWidgets('submit protection: the busy indicator replaces the button so a second tap cannot send a second request', (tester) async {
    when(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return {};
    });
    await open(tester, api, assignment());

    await tester.tap(find.text('Принять работу'));
    await tester.pump();
    expect(find.text('Принять работу'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/assignments/a1/accept', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).called(1);
  });
}
