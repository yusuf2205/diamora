import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:diamoraa_mobile/core/providers.dart';
import 'package:diamoraa_mobile/core/realtime/realtime_client.dart';
import 'package:diamoraa_mobile/features/auth/auth_controller.dart';
import 'package:diamoraa_mobile/features/chat/chat_list_screen.dart';
import 'package:diamoraa_mobile/features/chat/chat_models.dart';
import 'package:diamoraa_mobile/features/chat/chat_profile.dart';
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

  testWidgets('stage 2: pinned message on top, a reply quote, reactions (tap = toggle), «печатает…», reply from the menu', (tester) async {
    when(() => api.getJson('/chat/rooms/r1')).thenAnswer((_) async => {
          'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора Азимова', 'memberCount': 2, 'canPin': true, 'members': <Object>[],
          'peer': {'id': 'u2', 'fullName': 'Нигора Азимова', 'role': 'WORKER', 'online': false, 'lastSeenAt': DateTime.now().toUtc().toIso8601String()},
          'pinnedMessage': msg('p1', 'Адрес: Чиланзар 5'),
        });
    final answer = {
      ...msg('0190a000-0000-7000-8000-000000000002', '12 метров'),
      'replyTo': {'id': '0190a000-0000-7000-8000-000000000001', 'sender': 'Юсуф', 'preview': 'Сколько осталось?'},
      'reactions': [{'emoji': '👍', 'count': 2, 'mine': false}],
      'editedAt': DateTime.now().toUtc().toIso8601String(),
    };
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 40})).thenAnswer((_) async => {'items': [answer], 'hasMore': false});
    await pump(tester, const ChatRoomScreen(roomId: 'r1'));

    expect(find.byKey(const Key('pinnedBar')), findsOneWidget);
    expect(find.text('Адрес: Чиланзар 5'), findsOneWidget);
    expect(find.text('Сколько осталось?'), findsOneWidget); // the quote
    expect(find.textContaining('изменено'), findsOneWidget);
    expect(find.textContaining('был(а) в сети'), findsOneWidget);

    when(() => api.postJson('/chat/messages/0190a000-0000-7000-8000-000000000002/reactions', body: {'emoji': '👍'}))
        .thenAnswer((_) async => {...answer, 'reactions': [{'emoji': '👍', 'count': 3, 'mine': true}]});
    await tester.tap(find.byKey(const Key('reaction-0190a000-0000-7000-8000-000000000002-👍')));
    await tester.pumpAndSettle();
    expect(find.text('👍 3'), findsOneWidget);

    events.add(RealtimeEvent(id: 't', type: 'chat.typing', occurredAt: DateTime.now(), data: {'roomId': 'r1', 'userId': 'u2', 'name': 'Нигора Азимова', 'kind': 'voice'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('записывает голосовое…'), findsOneWidget);

    await tester.longPress(find.text('12 метров'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('msgReply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composerContext')), findsOneWidget);
    when(() => api.postJson('/chat/rooms/r1/messages', body: any(named: 'body'))).thenAnswer((i) async => msg('0190a000-0000-7000-8000-000000000009', 'ок'));
    await tester.enterText(find.byKey(const Key('chatInput')), 'Хорошо');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chatSend')));
    await tester.pumpAndSettle();
    final body = verify(() => api.postJson('/chat/rooms/r1/messages', body: captureAny(named: 'body'))).captured.single as Map;
    expect(body['replyToId'], '0190a000-0000-7000-8000-000000000002');
    expect(find.byKey(const Key('composerContext')), findsNothing);
    await tester.pump(const Duration(seconds: 8)); // the typing indicator expires
  });

  testWidgets('search: chats, people and messages; a found message opens its chat', (tester) async {
    when(() => api.getJson('/chat/rooms')).thenAnswer((_) async => {'items': <Object>[]});
    when(() => api.getJson('/chat/search', query: {'q': 'круж'})).thenAnswer((_) async => {
          'rooms': <Object>[],
          'people': [{'id': 'u5', 'fullName': 'Кружкова Анна', 'role': 'MANAGER'}],
          'messages': [{...msg('m9', 'Кружево бежевое'), 'room': {'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора Азимова'}}],
        });
    await pump(tester, const ChatListScreen());
    await tester.tap(find.byKey(const Key('chatSearch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chatSearchField')), 'круж');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Кружкова Анна'), findsOneWidget);
    expect(find.textContaining('Кружево бежевое'), findsOneWidget);
    expect(find.text('Люди'), findsOneWidget);
    expect(find.text('Сообщения'), findsOneWidget);
  });

  testWidgets('stage 4: a channel reader has no input; «О канале» shows who reads it and the media tabs', (tester) async {
    when(() => api.getJson('/chat/rooms/ch')).thenAnswer((_) async => {
          'id': 'ch', 'kind': 'CHANNEL', 'title': 'Объявления', 'memberCount': 40, 'audience': 'WORKERS', 'canWrite': false, 'canManage': false,
          'description': 'Важное от компании', 'members': <Object>[],
        });
    when(() => api.getJson('/chat/rooms/ch/messages', query: {'limit': 40})).thenAnswer((_) async => {'items': [msg('m1', 'С понедельника новые расценки')], 'hasMore': false});
    when(() => api.postJson('/chat/rooms/ch/read')).thenAnswer((_) async => {'ok': true});
    when(() => api.getJson('/chat/rooms/ch/media', query: {'kind': 'files'})).thenAnswer((_) async => {'items': [{...msg('f1', '', kind: 'FILE', file: {'url': 'https://x/f', 'name': 'Прайс.pdf', 'size': 20480})}]});
    await pump(tester, const ChatRoomScreen(roomId: 'ch'));
    expect(find.byKey(const Key('readOnlyNotice')), findsOneWidget);
    expect(find.byKey(const Key('chatInput')), findsNothing);
    expect(find.text('Канал · подписчиков: 40'), findsOneWidget);

    await tester.tap(find.byKey(const Key('groupInfo')));
    await tester.pumpAndSettle();
    expect(find.text('Важное от компании'), findsOneWidget);
    expect(find.textContaining('Только мастерицы'), findsOneWidget);
    expect(find.byKey(const Key('groupLeave')), findsNothing); // an audience channel is muted, not left
    await tester.tap(find.byKey(const Key('tab-files')));
    await tester.pumpAndSettle();
    expect(find.text('Прайс.pdf'), findsOneWidget);
  });

  testWidgets('media: a tap on a photo opens the full-screen viewer (swipe between photo and video, close)', (tester) async {
    when(() => api.getJson('/chat/rooms/r1')).thenAnswer((_) async => {'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора', 'memberCount': 2, 'members': <Object>[]});
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 40})).thenAnswer((_) async => {
          'items': [
            msg('0190a000-0000-7000-8000-000000000002', '', kind: 'VIDEO', file: {'url': 'https://x/v', 'thumbUrl': 'https://x/vt', 'durationMs': 34000, 'size': 12000000, 'width': 1080, 'height': 1920}),
            msg('0190a000-0000-7000-8000-000000000001', 'образец', kind: 'IMAGE', file: {'url': 'https://x/p', 'thumbUrl': 'https://x/pt', 'width': 800, 'height': 600}),
          ],
          'hasMore': false,
        });
    await pump(tester, const ChatRoomScreen(roomId: 'r1'));
    expect(find.text('0:34 · 11.4 MB'), findsOneWidget); // the video bubble: length and size on its preview
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('image-0190a000-0000-7000-8000-000000000001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-0190a000-0000-7000-8000-000000000001')));
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: avoid_print
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('galleryPages')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget); // photo first (oldest), the video next to it
    await tester.tap(find.byKey(const Key('galleryClose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('galleryPages')), findsNothing);
  });

  testWidgets('Telegram-like: voice with a waveform and «00:02, 8.8 KB»; ⋮ menu; «прочитано в …» in my message menu', (tester) async {
    when(() => api.getJson('/chat/rooms/r1')).thenAnswer((_) async => {'id': 'r1', 'kind': 'DIRECT', 'title': 'Нигора', 'memberCount': 2, 'canProtect': true, 'members': <Object>[],
        'peer': {'id': 'u2', 'fullName': 'Нигора', 'role': 'WORKER', 'online': true}});
    when(() => api.getJson('/chat/rooms/r1/messages', query: {'limit': 40})).thenAnswer((_) async => {
          'items': [
            {...msg('0190a000-0000-7000-8000-000000000002', 'Мой ответ', sender: 'me', name: 'Я')},
            {...msg('0190a000-0000-7000-8000-000000000001', '', kind: 'VOICE', file: {'url': 'https://x/v.m4a', 'durationMs': 2000, 'size': 9011}), 'waveform': '5,10,31,20'},
          ],
          'hasMore': false,
        });
    when(() => api.getJson('/chat/messages/0190a000-0000-7000-8000-000000000002/reads')).thenAnswer((_) async => {'items': [{'id': 'u2', 'fullName': 'Нигора', 'role': 'WORKER', 'readAt': '2026-09-30T09:05:00Z'}]});
    await pump(tester, const ChatRoomScreen(roomId: 'r1'));
    expect(find.text('00:02, 8.8 KB'), findsOneWidget);
    expect(find.byType(Waveform), findsOneWidget);

    await tester.tap(find.byKey(const Key('chatMore')));
    await tester.pumpAndSettle();
    for (final t in ['Без уведомлений', 'Показать профиль', 'Запретить копирование', 'Экспорт истории чата', 'Очистить историю', 'Удалить чат']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Мой ответ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('readInfo')), findsOneWidget);
    expect(find.textContaining('прочитано в'), findsOneWidget);
  });

  test('albums: photos of one sender sent together are one row; a caption or another sender breaks it', () {
    ChatMessage img(String id, String sender, int sec, [String? text]) => ChatMessage.fromJson({
          ...msg(id, text ?? '', sender: sender, kind: 'IMAGE', file: {'url': 'u', 'thumbUrl': 't'}),
          'text': text,
          'createdAt': DateTime.utc(2026, 9, 30, 10, 0, sec).toIso8601String(),
        });
    // newest first, as the screen keeps them
    final rows = albumRows([img('5', 'b', 4, 'подпись'), img('4', 'b', 3), img('3', 'a', 2), img('2', 'a', 1), img('1', 'a', 0)]);
    expect(rows.map((r) => r is List<ChatMessage> ? r.map((m) => m.id).join('+') : (r as ChatMessage).id).toList(), ['5', '4', '3+2+1']);
  });

  test('waveform: recorded loudness -> 48 bars 0-31; a stable pattern for audio without one', () {
    expect(toBars([0, 0.5, 1, 0.25], n: 4), [1, 16, 31, 8]);
    expect(barsFor(null, 'abc'), barsFor(null, 'abc'));
    expect(barsFor([1, 31], 'x', n: 4), [1, 1, 31, 31]);
  });

  test('a picked file is sent as what it is (by name; the server checks the bytes)', () {
    expect(chatKindForName('IMG_0001.JPG'), 'IMAGE');
    expect(chatKindForName('clip.mov'), 'VIDEO');
    expect(chatKindForName('song.mp3'), 'AUDIO');
    expect(chatKindForName('Отчёт.pdf'), 'FILE');
    expect(chatKindForName('noext'), 'FILE');
  });
}
