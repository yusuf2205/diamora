import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/core/realtime/realtime_client.dart';
import 'package:diamoraa_mobile/features/auth/auth_controller.dart';
import 'package:diamoraa_mobile/features/chat/chat_list_screen.dart';
import 'package:diamoraa_mobile/features/chat/chat_room_screen.dart';
import 'package:diamoraa_mobile/l10n/app_localizations.dart';

import 'app_flow_test.dart' show FakeAuth, MockApi;
import 'overview_test.dart' show staff;

Map<String, Object?> msg(String id, String text, {String sender = 'u2', String name = 'Нигора Азимова', String kind = 'TEXT', Map<String, Object?>? file, bool deleted = false}) => {
      'id': id, 'roomId': 'r1', 'kind': kind, 'text': text, 'deleted': deleted, 'file': file, 'clientId': null,
      'sender': {'id': sender, 'fullName': name, 'role': 'WORKER'}, 'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  late MockApi api;
  late StreamController<RealtimeEvent> events;
  setUp(() {
    api = MockApi();
    events = StreamController<RealtimeEvent>.broadcast();
    when(() => api.postJson(any(that: endsWith('/read')))).thenAnswer((_) async => {'ok': true});
    when(() => api.getJson('/chat/unread')).thenAnswer((_) async => {'count': 0});
  });
  tearDown(() => events.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(() => FakeAuth(staff('MANAGER').copyWith(id: 'me'))),
        realtimeEventsProvider.overrideWith((ref) => events.stream),
        realtimeConnectedProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('«Чат»: the company chat first, then conversations with the last message and unread count', (tester) async {
    when(() => api.getJson('/chat/rooms')).thenAnswer((_) async => {
          'items': [
            {'id': 'c', 'kind': 'COMPANY', 'title': null, 'memberCount': 12, 'unread': 0, 'lastMessage': null, 'lastMessageAt': '2026-09-29T08:00:00Z'},
            {
              'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора Азимова', 'memberCount': 2, 'unread': 3,
              'peer': {'id': 'u2', 'fullName': 'Нигора Азимова', 'role': 'WORKER', 'online': true},
              'lastMessage': msg('m1', '', kind: 'VOICE', file: {'url': 'https://x/f', 'durationMs': 3000}), 'lastMessageAt': '2026-09-29T09:00:00Z',
            },
          ],
        });
    await pump(tester, const ChatListScreen());
    expect(find.text('Общий чат'), findsOneWidget);
    expect(find.text('Все сотрудники и мастерицы'), findsOneWidget);
    expect(find.text('Нигора Азимова'), findsOneWidget);
    expect(find.text('🎤 Голосовое сообщение'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // unread
    expect(tester.getTopLeft(find.text('Общий чат')).dy, lessThan(tester.getTopLeft(find.text('Нигора Азимова')).dy));
  });

  testWidgets('a conversation: messages, a new one arrives live, I send text (shown at once), my own gets ✓✓ when read', (tester) async {
    when(() => api.getJson('/chat/rooms/r1')).thenAnswer((_) async => {
          'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора Азимова', 'memberCount': 2,
          'peer': {'id': 'u2', 'fullName': 'Нигора Азимова', 'role': 'WORKER', 'online': true, 'lastReadAt': DateTime.now().add(const Duration(minutes: 1)).toUtc().toIso8601String()},
          'members': <Object>[],
        });
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 40})).thenAnswer((_) async => {
          'items': [msg('0190a000-0000-7000-8000-000000000002', 'Мой ответ', sender: 'me', name: 'Я'), msg('0190a000-0000-7000-8000-000000000001', 'Работа готова')],
          'hasMore': false,
        });
    await pump(tester, const ChatRoomScreen(roomId: 'r1'));
    expect(find.text('Работа готова'), findsOneWidget);
    expect(find.text('в сети'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget); // she read my message
    verify(() => api.postJson('/chat/rooms/r1/read')).called(greaterThanOrEqualTo(1));

    // live: the socket says there is a new message -> only the new ones are fetched
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 100, 'after': '0190a000-0000-7000-8000-000000000002'}))
        .thenAnswer((_) async => {'items': [msg('0190a000-0000-7000-8000-000000000003', 'Когда заберёте?')], 'hasMore': false});
    events.add(RealtimeEvent(id: 'e1', type: 'chat.message', occurredAt: DateTime.now(), data: {'roomId': 'r1', 'messageId': 'x'}));
    await tester.pumpAndSettle();
    expect(find.text('Когда заберёте?'), findsOneWidget);

    final sent = Completer<Map<String, dynamic>>();
    when(() => api.postJson('/chat/rooms/r1/messages', body: any(named: 'body'))).thenAnswer((i) => sent.future);
    await tester.enterText(find.byKey(const Key('chatInput')), 'Завтра в 10');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chatSend')));
    await tester.pump();
    expect(find.text('Завтра в 10'), findsOneWidget); // on screen before the server answers
    final body = verify(() => api.postJson('/chat/rooms/r1/messages', body: captureAny(named: 'body'))).captured.single as Map;
    expect(body['text'], 'Завтра в 10');
    sent.complete({...msg('0190a000-0000-7000-8000-000000000004', 'Завтра в 10', sender: 'me'), 'clientId': body['clientId']});
    await tester.pumpAndSettle();
    expect(find.text('Завтра в 10'), findsOneWidget); // replaced by the server copy, not doubled
  });

  testWidgets('a deleted message reads «Сообщение удалено»; the mic button explains how to record', (tester) async {
    when(() => api.getJson('/chat/rooms/r1')).thenAnswer((_) async => {'id': 'r1', 'kind': 'COMPANY', 'title': null, 'memberCount': 30, 'members': <Object>[]});
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 40})).thenAnswer((_) async => {'items': [msg('m1', '', deleted: true)], 'hasMore': false});
    await pump(tester, const ChatRoomScreen(roomId: 'r1'));
    expect(find.text('Общий чат'), findsOneWidget);
    expect(find.text('Участников: 30'), findsOneWidget);
    expect(find.text('Сообщение удалено'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chatMic')));
    await tester.pump();
    expect(find.text('Удерживайте кнопку микрофона, чтобы записать'), findsOneWidget);
  });

  test('a picked file is sent as what it is (by name; the server checks the bytes)', () {
    expect(chatKindForName('IMG_0001.JPG'), 'IMAGE');
    expect(chatKindForName('clip.mov'), 'VIDEO');
    expect(chatKindForName('song.mp3'), 'AUDIO');
    expect(chatKindForName('Отчёт.pdf'), 'FILE');
    expect(chatKindForName('noext'), 'FILE');
  });
}
