import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/app/live_refresh.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/core/realtime/realtime_client.dart';
import 'package:diamoraa_mobile/features/chat/chat_watch_screen.dart';
import 'package:diamoraa_mobile/features/settings/company_contact.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// «Все переписки» for the owner, and «всё в реальном времени» (owner, 2026-10-11).
void main() {
  late MockApi api;
  late StreamController<RealtimeEvent> events;
  setUp(() {
    api = MockApi();
    events = StreamController<RealtimeEvent>.broadcast();
  });
  tearDown(() => events.close());

  Map<String, dynamic> room(String id, String kind, String title, String text) => {
        'id': id, 'kind': kind, 'title': title, 'memberCount': 2, 'messageCount': 7, 'lastMessageAt': '2026-10-11T10:00:00.000Z',
        'lastMessage': {'id': 'm$id', 'roomId': id, 'kind': 'TEXT', 'text': text, 'createdAt': '2026-10-11T10:00:00.000Z', 'sender': {'id': 'u1', 'fullName': 'Малика Каримова', 'role': 'MANAGER'}},
      };

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), realtimeEventsProvider.overrideWith((ref) => events.stream), realtimeConnectedProvider.overrideWith((ref) => Stream.value(true))],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('every conversation, who with whom and the last message; «Личные» filters; a new message refreshes the list', (tester) async {
    var calls = 0;
    when(() => api.getJson('/chat/watch/rooms', query: any(named: 'query'))).thenAnswer((_) async {
      calls++;
      return {'items': [room('a', 'DIRECT', 'Малика Каримова ↔ Азиз Админ', 'Поставщик завтра'), room('b', 'GROUP', 'Склад', 'Лента пришла')]};
    });
    await pump(tester, const ChatWatchScreen());
    expect(find.text('Все переписки'), findsOneWidget);
    expect(find.text('Малика Каримова ↔ Азиз Админ'), findsOneWidget);
    expect(find.text('Малика: Поставщик завтра'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.textContaining('7 сообщений'), findsNWidgets(2));

    await tester.tap(find.text('Личные'));
    await tester.pumpAndSettle();
    expect(find.text('Склад'), findsNothing);

    final before = calls;
    events.add(RealtimeEvent(id: 'e1', type: 'chat.message', occurredAt: DateTime.now(), data: {'roomId': 'b'}));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
  });

  testWidgets('live: a change on the server refreshes the open screen by itself (bursts merged); chat noise does not', (tester) async {
    var calls = 0;
    when(() => api.getJson('/settings/company-contact')).thenAnswer((_) async {
      calls++;
      return {'phone': '+998901112233', 'telegramUsername': null, 'telegramUrl': null};
    });
    await pump(tester, Consumer(builder: (_, ref, _) {
      ref.watch(liveRefreshProvider);
      final c = ref.watch(companyContactProvider);
      return Scaffold(body: Text(c.value?.phone ?? '…'));
    }));
    expect(calls, 1);

    events.add(RealtimeEvent(id: 'e1', type: 'chat.typing', occurredAt: DateTime.now(), data: {'roomId': 'r'}));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls, 1);

    for (var i = 0; i < 3; i++) {
      events.add(RealtimeEvent(id: 'p$i', type: 'assignment.updated', occurredAt: DateTime.now(), data: {'assignmentId': 'x', 'workerId': 'w'}));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
