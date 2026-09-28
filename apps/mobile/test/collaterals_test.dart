import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/features/auth/models.dart';

import 'app_flow_test.dart' show MockApi;
import 'catalog_test.dart' show appWith, tearDownDb;

void main() {
  late MockApi api;
  setUp(() {
    api = MockApi();
    when(() => api.getJson('/workers', query: any(named: 'query'))).thenAnswer((_) async => {'items': [], 'nextCursor': null});
  });

  testWidgets('«Залоги»: what is with us (total), «Вернуть» needs a note + her confirmation, then POST return', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    when(() => api.getJson('/collaterals', query: any(named: 'query'))).thenAnswer((_) async => {
          'items': [
            {'id': 'c1', 'type': 'MONEY', 'status': 'HELD', 'amount': '1500000', 'description': null, 'storageLocation': 'Сейф', 'worker': {'id': 'w1', 'code': 'W-0001', 'fullName': 'Нигора'}},
          ],
          'nextCursor': null, 'held': {'moneyTotal': '1500000', 'moneyCount': 1, 'itemCount': 2},
        });
    when(() => api.postJson('/collaterals/c1/return', idempotencyKey: any(named: 'idempotencyKey'), body: any(named: 'body'))).thenAnswer((_) async => {});
    final admin = Session.fromJson({'id': 'a1', 'fullName': 'Admin', 'phone': '+998901112233', 'role': 'ADMIN', 'permissions': ['WORKER_VIEW_ALL', 'COLLATERAL_VIEW', 'COLLATERAL_MANAGE']});
    await tester.pumpWidget(await appWith(admin, api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Залоги'));
    await tester.pumpAndSettle();

    expect(find.text('Нигора'), findsOneWidget);
    expect(find.textContaining('2 вещей'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-c1')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('collateralReturnSave'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('collateralReturnNote')), 'Отдали в руки');
    await tester.tap(find.byKey(const Key('collateralReturnConfirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collateralReturnSave')));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/collaterals/c1/return', idempotencyKey: any(named: 'idempotencyKey'), body: {'note': 'Отдали в руки', 'workerConfirmed': true})).called(1);
    await tearDownDb(tester);
  });
}
