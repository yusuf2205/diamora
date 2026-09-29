import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import 'chat_models.dart';

/// The largest file a message may carry (the server refuses more).
const chatMaxFileBytes = 50 * 1024 * 1024;

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<ChatRoomSummary>> rooms() async =>
      ((await _api.getJson('/chat/rooms'))['items'] as List).map((j) => ChatRoomSummary.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<int> unread() async => ((await _api.getJson('/chat/unread'))['count'] as num?)?.toInt() ?? 0;

  Future<List<ChatPerson>> contacts([String q = '']) async => ((await _api.getJson('/chat/contacts', query: {if (q.trim().isNotEmpty) 'q': q.trim()}))['items'] as List)
      .map((j) => ChatPerson.fromJson((j as Map).cast<String, dynamic>()))
      .toList();

  Future<ChatRoomDetail> room(String id) async => ChatRoomDetail.fromJson(await _api.getJson('/chat/rooms/$id'));

  Future<ChatRoomDetail> direct(String userId) async => ChatRoomDetail.fromJson(await _api.postJson('/chat/direct', body: {'userId': userId}));

  Future<ChatRoomDetail> createGroup(String title, List<String> memberIds) async =>
      ChatRoomDetail.fromJson(await _api.postJson('/chat/groups', body: {'title': title, 'memberIds': memberIds}));

  Future<ChatRoomDetail> updateGroup(String id, {String? title, String? description, List<String>? addIds, List<String>? removeIds, List<String>? adminIds, List<String>? unadminIds, bool? onlyAdminsWrite}) async =>
      ChatRoomDetail.fromJson(await _api.patchJson('/chat/rooms/$id', body: {
        'title': ?title, 'description': ?description, 'addIds': ?addIds, 'removeIds': ?removeIds, 'adminIds': ?adminIds, 'unadminIds': ?unadminIds, 'onlyAdminsWrite': ?onlyAdminsWrite,
      }));

  /// An announcement channel (administrators). [audience]: ALL | STAFF | WORKERS | CUSTOM (then [memberIds]).
  Future<ChatRoomDetail> createChannel(String title, {String? description, required String audience, List<String> memberIds = const []}) async => ChatRoomDetail.fromJson(
      await _api.postJson('/chat/channels', body: {'title': title, 'description': ?description, 'audience': audience, 'memberIds': memberIds}));

  Future<ChatRoomDetail> setPhoto(String id, String path) async {
    try {
      final res = await _api.dio.post<dynamic>('/chat/rooms/$id/photo', data: FormData.fromMap({'file': await MultipartFile.fromFile(path, filename: 'photo.jpg')}));
      return ChatRoomDetail.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// media | files | voice | links, newest first.
  Future<List<ChatMessage>> media(String roomId, String kind) async =>
      ((await _api.getJson('/chat/rooms/$roomId/media', query: {'kind': kind}))['items'] as List).map((m) => ChatMessage.fromJson((m as Map).cast<String, dynamic>())).toList();

  Future<void> leave(String id) => _api.postJson('/chat/rooms/$id/leave');

  /// Newest first. [before]: older than this message; [after]: only what arrived after it.
  Future<ChatPage> messages(String roomId, {String? before, String? after, int limit = 40}) async {
    final j = await _api.getJson('/chat/rooms/$roomId/messages', query: {'limit': limit, 'before': ?before, 'after': ?after});
    return ChatPage(((j['items'] as List).map((m) => ChatMessage.fromJson((m as Map).cast<String, dynamic>()))).toList(), j['hasMore'] as bool? ?? false);
  }

  Future<ChatMessage> sendText(String roomId, String text, String clientId, {String? replyToId}) async =>
      ChatMessage.fromJson(await _api.postJson('/chat/rooms/$roomId/messages', body: {'text': text, 'clientId': clientId, 'replyToId': ?replyToId}));

  Future<ChatMessage> edit(String id, String text) async => ChatMessage.fromJson(await _api.patchJson('/chat/messages/$id', body: {'text': text}));

  Future<ChatMessage> react(String id, String emoji) async => ChatMessage.fromJson(await _api.postJson('/chat/messages/$id/reactions', body: {'emoji': emoji}));

  Future<void> forward(String id, List<String> roomIds) => _api.postJson('/chat/messages/$id/forward', body: {'roomIds': roomIds});

  Future<ChatRoomDetail> pin(String roomId, String? messageId) async => ChatRoomDetail.fromJson(await _api.postJson('/chat/rooms/$roomId/pin', body: {'messageId': messageId}));

  /// My own settings for a chat (keep on top / no notifications).
  Future<void> prefs(String roomId, {bool? pinned, bool? muted}) => _api.patchJson('/chat/rooms/$roomId/me', body: {'pinned': ?pinned, 'muted': ?muted});

  Future<ChatSearchResult> search(String q) async {
    final j = await _api.getJson('/chat/search', query: {'q': q});
    Map<String, dynamic> m(Object? x) => (x as Map).cast<String, dynamic>();
    return ChatSearchResult(
      rooms: (j['rooms'] as List).map((x) => ChatRoomSummary.fromJson(m(x))).toList(),
      people: (j['people'] as List).map((x) => ChatPerson.fromJson(m(x))).toList(),
      messages: (j['messages'] as List).map((x) {
        final room = m(m(x)['room']);
        return ChatSearchHit(ChatMessage.fromJson(m(x)), room['id'] as String, room['kind'] as String? ?? 'DIRECT', room['title'] as String?);
      }).toList(),
    );
  }

  /// Streams the file from disk (up to 50 MB) with progress; [kind] IMAGE | VIDEO | VOICE | AUDIO | FILE.
  Future<ChatMessage> sendFile(String roomId, {required String path, required String filename, required String kind, required String clientId, String? text, int? durationMs, String? replyToId, void Function(double)? onProgress}) async {
    try {
      final res = await _api.dio.post<dynamic>(
        '/chat/rooms/$roomId/files',
        data: FormData.fromMap({
          'kind': kind,
          'clientId': clientId,
          if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
          if (durationMs != null) 'durationMs': '$durationMs',
          'replyToId': ?replyToId,
          'file': await MultipartFile.fromFile(path, filename: filename),
        }),
        options: Options(sendTimeout: const Duration(minutes: 10), receiveTimeout: const Duration(minutes: 2)),
        onSendProgress: (sent, total) { if (total > 0) onProgress?.call(sent / total); },
      );
      return ChatMessage.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> read(String roomId) => _api.postJson('/chat/rooms/$roomId/read');

  Future<void> deleteMessage(String id) => _api.delete('/chat/messages/$id');
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

/// Refetched whenever something happens in any of my chats (realtime hint) — the list stays live.
final chatRoomsProvider = FutureProvider.autoDispose<List<ChatRoomSummary>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && t.startsWith('chat.')) ref.invalidateSelf();
  });
  return ref.watch(chatRepositoryProvider).rooms();
});

/// The badge on the «Чат» tab.
final chatUnreadProvider = FutureProvider<int>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t == 'chat.message' || t == 'chat.read' || t == 'chat.room') ref.invalidateSelf();
  });
  ref.listen(realtimeConnectedProvider, (_, next) { if (next.value == true) ref.invalidateSelf(); });
  return ref.watch(chatRepositoryProvider).unread().catchError((_) => 0);
});

/// The chat on screen right now: its pushes are not shown as system notifications (the messages are already there).
String? openChatRoomId;
