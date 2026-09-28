import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/network/api_exception.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/catalog/models.dart';
import 'package:diamoraa_mobile/features/work/job_requests.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// «Заказать эту работу» (worker) and «Заявки на работу» (staff).
Map<String, dynamic> req({String status = 'PENDING', String? decisionNote}) => {
      'id': 'r1', 'status': status, 'kitCount': 2, 'meters': 18, 'note': 'к пятнице', 'decisionNote': decisionNote,
      'createdAt': DateTime.now().toUtc().toIso8601String(), 'decidedAt': null,
      'worker': {'id': 'w1', 'code': 'W-0001', 'fullName': 'Малика Каримова', 'phone': '+998901234567'},
      'product': {'id': 'p1', 'name': 'Oddiy tekis'}, 'variant': {'id': 'v1', 'label': null}, 'color': {'id': 'c1', 'name': 'Pushti', 'hex': '#f4a6c0'},
      'assignmentId': null,
    };

Widget app(MockApi api, Widget home) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  testWidgets('worker home: «Выбрать работу» and «Сканировать QR» are always there', (tester) async {
    await tester.pumpWidget(app(api, const WorkerQuickActions()));
    expect(find.text('Выбрать работу'), findsOneWidget);
    expect(find.text('Сканировать QR'), findsOneWidget);
  });

  testWidgets('order sheet: colour + 18 м + wish -> one request; nothing is sent before a colour is picked', (tester) async {
    when(() => api.postJson('/work/requests', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => req());
    when(() => api.getJson('/work/requests')).thenAnswer((_) async => {'items': [req()]});
    const item = CatalogItem(id: 'p1', name: 'Oddiy tekis', variants: [
      CatalogVariant(id: 'v1', color: CatalogColor(id: 'c1', name: 'Pushti', hex: '#f4a6c0')),
      CatalogVariant(id: 'v2', color: CatalogColor(id: 'c2', name: 'Oq', hex: '#ffffff')),
    ]);
    await tester.pumpWidget(app(api, const OrderWorkSheet(item: item)));
    final send = find.widgetWithText(FilledButton, 'Отправить заявку');
    expect(tester.widget<FilledButton>(send).onPressed, isNull); // two colours: she must choose
    await tester.tap(find.text('Pushti'));
    await tester.tap(find.text('18 м'));
    await tester.enterText(find.byType(TextField), 'к пятнице');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    final call = verify(() => api.postJson('/work/requests', idempotencyKey: any(named: 'idempotencyKey'), body: captureAny(named: 'body')))..called(1);
    expect(call.captured.single, {'productVariantId': 'v1', 'kitCount': 2, 'note': 'к пятнице'});
  });

  testWidgets('order sheet: a second request while one waits -> a plain sentence, not an error code', (tester) async {
    when(() => api.postJson('/work/requests', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body')))
        .thenThrow(ApiException(code: 'CONFLICT', message: 'You already have a request waiting', status: 409));
    const item = CatalogItem(id: 'p1', name: 'Oddiy tekis', variants: [CatalogVariant(id: 'v1', color: CatalogColor(id: 'c1', name: 'Pushti'))]);
    await tester.pumpWidget(app(api, const OrderWorkSheet(item: item)));
    await tester.tap(find.widgetWithText(FilledButton, 'Отправить заявку')); // one colour -> preselected
    await tester.pumpAndSettle();
    expect(find.textContaining('У вас уже есть заявка'), findsOneWidget);
    expect(find.textContaining('CONFLICT'), findsNothing);
  });

  testWidgets('her waiting request is on the home screen with «Отменить заявку»; a decline shows the reason', (tester) async {
    when(() => api.getJson('/work/requests')).thenAnswer((_) async => {'items': [req()]});
    when(() => api.postJson('/work/requests/r1/cancel', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async => req(status: 'CANCELLED'));
    await tester.pumpWidget(app(api, const MyJobRequestCard()));
    await tester.pumpAndSettle();
    expect(find.text('Заявка отправлена'), findsOneWidget);
    expect(find.text('Oddiy tekis · Pushti · 18 м'), findsOneWidget);
    when(() => api.getJson('/work/requests')).thenAnswer((_) async => {'items': [req(status: 'CANCELLED')]});
    await tester.tap(find.text('Отменить заявку'));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/work/requests/r1/cancel', idempotencyKey: any(named: 'idempotencyKey'))).called(1);
    expect(find.text('Заявка отправлена'), findsNothing);

    final api2 = MockApi();
    when(() => api2.getJson('/work/requests')).thenAnswer((_) async => {'items': [req(status: 'REJECTED', decisionNote: 'нет бисера')]});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(api2, const MyJobRequestCard()));
    await tester.pumpAndSettle();
    expect(find.text('Заявка не принята'), findsOneWidget);
    expect(find.text('нет бисера'), findsOneWidget);
  });

  testWidgets('staff «Заявки на работу»: who wants what; «Отклонить» sends the reason', (tester) async {
    when(() => api.getJson('/admin/job-requests')).thenAnswer((_) async => {'items': [req()]});
    when(() => api.postJson('/admin/job-requests/r1/reject', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => req(status: 'REJECTED'));
    await tester.pumpWidget(app(api, const JobRequestsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Малика Каримова'), findsOneWidget);
    expect(find.text('Oddiy tekis · Pushti · 18 м'), findsOneWidget);
    expect(find.text('«к пятнице»'), findsOneWidget);
    expect(find.text('Подготовить работу'), findsOneWidget);
    when(() => api.getJson('/admin/job-requests')).thenAnswer((_) async => {'items': <Object>[]});
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'нет бисера');
    await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
    await tester.pumpAndSettle();
    final call = verify(() => api.postJson('/admin/job-requests/r1/reject', idempotencyKey: any(named: 'idempotencyKey'), body: captureAny(named: 'body')))..called(1);
    expect(call.captured.single, {'note': 'нет бисера'});
    expect(find.text('Новых заявок нет'), findsOneWidget);
  });
}
