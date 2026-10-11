import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/features/chat/chat_folders.dart';
import 'package:diamoraa_mobile/features/chat/chat_models.dart';
import 'package:diamoraa_mobile/features/chat/chat_more.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show MockApi;

/// Chat like Telegram (owner, 2026-10-11): a poll answered in one tap, a contact / location card, swipe to reply, folders.
void main() {
  late MockApi api;
  setUp(() => api = MockApi());

  Future<void> pump(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api), sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> pollJson({bool voted = false}) => {
        'id': 'p1', 'roomId': 'r1', 'kind': 'POLL', 'createdAt': '2026-10-11T10:00:00.000Z',
        'data': {'question': 'Кто сможет в субботу?', 'options': ['Я', 'Не смогу'], 'multiple': false},
        'poll': {'question': 'Кто сможет в субботу?', 'multiple': false, 'voters': voted ? 1 : 0, 'options': [
          {'text': 'Я', 'count': voted ? 1 : 0, 'mine': voted},
          {'text': 'Не смогу', 'count': 0, 'mine': false},
        ]},
      };

  testWidgets('a poll: one tap answers it, the results show at once', (tester) async {
    when(() => api.postJson('/chat/messages/p1/vote', body: any(named: 'body'))).thenAnswer((_) async => pollJson(voted: true));
    ChatMessage? updated;
    await pump(tester, PollBubble(message: ChatMessage.fromJson(pollJson()), fg: Colors.black, onChanged: (m) => updated = m));
    expect(find.text('Кто сможет в субботу?'), findsOneWidget);
    expect(find.text('Ответили: 0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('poll-p1-0')));
    await tester.pumpAndSettle();
    verify(() => api.postJson('/chat/messages/p1/vote', body: {'options': [0]})).called(1);
    expect(updated?.poll?['voters'], 1);
  });

  testWidgets('a contact and a location card', (tester) async {
    await pump(tester, Column(children: [
      ContactBubble(data: const {'name': 'Поставщик ленты', 'phone': '+998901112233'}, fg: Colors.black),
      LocationBubble(data: const {'latitude': 41.31, 'longitude': 69.28, 'label': 'Склад'}, fg: Colors.black),
    ]));
    expect(find.text('Поставщик ленты'), findsOneWidget);
    expect(find.text('+998901112233'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('Открыть на карте'), findsOneWidget);
  });

  testWidgets('swipe to reply: past the mark it replies, a short nudge does not', (tester) async {
    var replies = 0;
    await pump(tester, SwipeToReply(onReply: () => replies++, child: Container(width: 200, height: 60, color: Colors.pink, child: const Text('сообщение'))));
    await tester.drag(find.text('сообщение'), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
    await tester.drag(find.text('сообщение'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
  });

  testWidgets('folders: no tabs until the first folder; then «Все» and the folder with its unread count', (tester) async {
    final rooms = [
      ChatRoomSummary.fromJson({'id': 'a', 'kind': 'DIRECT', 'title': 'Малика', 'lastMessageAt': '2026-10-11T10:00:00.000Z', 'unread': 2}),
      ChatRoomSummary.fromJson({'id': 'b', 'kind': 'GROUP', 'title': 'Склад', 'lastMessageAt': '2026-10-11T10:00:00.000Z', 'unread': 0}),
    ];
    await pump(tester, ChatFolderBar(selected: null, onSelect: (_) {}, rooms: rooms));
    expect(find.byKey(const Key('folder-all')), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(ChatFolderBar)));
    await container.read(chatFoldersProvider.notifier).put(ChatFolder(id: 'f1', name: 'Работа', roomIds: {'a'}));
    await tester.pumpAndSettle();
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Работа  2'), findsOneWidget);
  });
}
