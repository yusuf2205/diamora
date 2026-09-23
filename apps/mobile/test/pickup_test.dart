import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yusmus_mobile/core/network/api_exception.dart';
import 'package:yusmus_mobile/core/providers.dart';
import 'package:yusmus_mobile/features/qr/qr_repository.dart';
import 'package:yusmus_mobile/features/work/assignment_detail_screen.dart';
import 'package:yusmus_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

Map<String, dynamic> detail({String status = 'READY_FOR_PICKUP'}) => {
      'id': 'a1', 'code': 'A-0001', 'status': status, 'kitCount': 1, 'plannedMeters': 9.0, 'reportedMeters': 9.0,
      'worker': {'id': 'w1', 'fullName': 'Малика Каримова', 'phone': '+998901234567'},
      'product': {'name': 'Комплект «Роза»'}, 'color': {'name': 'Розовое золото'},
      'materials': <Object>[], 'statusHistory': <Object>[], 'deliveries': <Object>[],
    };

Widget harness(MockApi api) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AssignmentDetailScreen(assignmentId: 'a1'),
      ),
    );

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  group('QR resolution (what a scan of a valid/invalid code classifies to before pickup even starts)', () {
    test('a well-formed ASSIGNMENT payload classifies as an assignment to open', () {
      expect(classifyQr({'type': 'ASSIGNMENT', 'assignment': {'id': 'a1'}}), QrOutcomeType.assignment);
    });
    test('a QR that is not one of ours, or malformed, is always invalid — never guessed at', () {
      expect(classifyQr({'type': 'ASSIGNMENT'}), QrOutcomeType.invalid); // missing payload
      expect(classifyQr({}), QrOutcomeType.invalid);
      expect(classifyQr({'type': 'SOMETHING_ELSE', 'assignment': {'id': 'a1'}}), QrOutcomeType.invalid);
    });
  });

  testWidgets('ready for pickup: "Забрал" is the only action shown; tapping it confirms pickup and the screen reflects the new status', (tester) async {
    when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => detail());
    when(() => api.postJson('/admin/assignments/a1/pickup', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async => detail(status: 'PICKED_UP'));
    await tester.pumpWidget(harness(api));
    await tester.pumpAndSettle();

    expect(find.text('Забрал'), findsOneWidget);
    expect(find.text('Доставлено'), findsNothing); // never the wrong action for this status
    expect(find.text('Принять работу'), findsNothing);

    when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => detail(status: 'PICKED_UP'));
    await tester.tap(find.text('Забрал'));
    await tester.pumpAndSettle();

    verify(() => api.postJson('/admin/assignments/a1/pickup', idempotencyKey: any(named: 'idempotencyKey'))).called(1);
    expect(find.text('Забрал'), findsNothing); // PICKED_UP has no further quick action — it's gone, not disabled
  });

  testWidgets('already picked up elsewhere in the meantime: the server refuses the transition, the manager sees a plain reason, never the raw enum/message', (tester) async {
    when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => detail());
    when(() => api.postJson('/admin/assignments/a1/pickup', idempotencyKey: any(named: 'idempotencyKey')))
        .thenThrow(ApiException(code: 'INVALID_TRANSITION', message: 'assignment: STAFF may not perform PICKED_UP -> PICKED_UP', status: 409));
    await tester.pumpWidget(harness(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Забрал'));
    await tester.pumpAndSettle();
    expect(find.text('Это действие уже недоступно, потому что статус задания изменился.'), findsOneWidget);
    expect(find.textContaining('may not perform'), findsNothing);
    expect(find.text('Забрал'), findsOneWidget); // still usable — a refresh, not a dead end
  });

  testWidgets('success: the pickup call happens exactly once even if the button is tapped again before the response lands', (tester) async {
    when(() => api.getJson('/admin/assignments/a1')).thenAnswer((_) async => detail());
    when(() => api.postJson('/admin/assignments/a1/pickup', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return detail(status: 'PICKED_UP');
    });
    await tester.pumpWidget(harness(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Забрал'));
    await tester.pump(); // one frame: busy, the bottom bar now shows a spinner instead of the button
    expect(find.text('Забрал'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    verify(() => api.postJson('/admin/assignments/a1/pickup', idempotencyKey: any(named: 'idempotencyKey'))).called(1);
  });
}
