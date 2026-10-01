import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/features/orders/orders_screen.dart';

import 'app_flow_test.dart' show MockApi;
import 'job_request_test.dart' show app;

/// «Заказы клиентов» in the app: the notice about a new order opens it; one tap accepts the order.
void main() {
  testWidgets('a new order with two colours: where it came from, the metres of each, «Принять заказ» confirms it', (tester) async {
    final api = MockApi();
    final order = {
      'id': 'o1', 'code': 'CO-00002', 'name': 'Юсуф', 'phone': '+998901112233', 'status': 'NEW', 'source': 'BOT', 'followsInBot': true,
      'product': {'id': 'p1', 'name': 'Kokil lenta'}, 'colorName': 'Розовый, Синий', 'quantity': 15.5, 'comment': null, 'staffNote': null,
      'lines': [{'colorName': 'Розовый', 'quantity': 10}, {'colorName': 'Синий', 'quantity': 5.5}],
    };
    when(() => api.getJson('/admin/orders', query: any(named: 'query'))).thenAnswer((_) async => {'items': [order], 'counts': {'NEW': 1}});
    when(() => api.patchJson('/admin/orders/o1', body: any(named: 'body'))).thenAnswer((_) async => {...order, 'status': 'CONFIRMED'});

    await tester.pumpWidget(app(api, const OrdersScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Юсуф · CO-00002'), findsOneWidget);
    expect(find.text('✈️ из Telegram'), findsOneWidget);
    expect(find.text('• Розовый — 10 м'), findsOneWidget);
    expect(find.text('• Синий — 5.5 м'), findsOneWidget);
    expect(find.text('Всего: 15.5 м'), findsOneWidget);

    await tester.tap(find.text('Принять заказ'));
    await tester.pumpAndSettle();
    final call = verify(() => api.patchJson('/admin/orders/o1', body: captureAny(named: 'body')))..called(1);
    expect(call.captured.single, {'status': 'CONFIRMED'});
  });
}
