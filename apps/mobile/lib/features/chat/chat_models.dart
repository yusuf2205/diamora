/// Chat data as the API returns it (GET /v1/chat/...). Plain classes: small, read-only, rebuilt on every refetch.
library;

DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

class ChatPerson {
  const ChatPerson({required this.id, required this.fullName, required this.role, this.online = false, this.isOwner = false, this.lastReadAt, this.lastSeenAt});
  final String id;
  final String fullName;
  final String role;
  final bool online;
  final bool isOwner;
  final DateTime? lastReadAt;
  final DateTime? lastSeenAt;

  factory ChatPerson.fromJson(Map<String, dynamic> j) => ChatPerson(
        id: j['id'] as String,
        fullName: j['fullName'] as String? ?? '',
        role: j['role'] as String? ?? 'WORKER',
        online: j['online'] as bool? ?? false,
        isOwner: j['isOwner'] as bool? ?? false,
        lastReadAt: _dtn(j['lastReadAt']),
        lastSeenAt: _dtn(j['lastSeenAt']),
      );
}

class ChatReply {
  const ChatReply({required this.id, this.sender, this.preview, this.deleted = false});
  final String id;
  final String? sender;
  final String? preview;
  final bool deleted;
  factory ChatReply.fromJson(Map<String, dynamic> j) =>
      ChatReply(id: j['id'] as String, sender: j['sender'] as String?, preview: j['preview'] as String?, deleted: j['deleted'] as bool? ?? false);
}

class ChatReaction {
  const ChatReaction({required this.emoji, required this.count, required this.mine});
  final String emoji;
  final int count;
  final bool mine;
  factory ChatReaction.fromJson(Map<String, dynamic> j) => ChatReaction(emoji: j['emoji'] as String, count: (j['count'] as num).toInt(), mine: j['mine'] as bool? ?? false);
}

/// The reactions offered (same fixed set as the server).
const chatReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏', '👏', '🔥'];

class ChatFile {
  const ChatFile({required this.url, this.thumbUrl, this.name, this.size, this.mimeType, this.durationMs, this.width, this.height});
  final String url;
  final String? thumbUrl;
  final String? name;
  final int? size;
  final String? mimeType;
  final int? durationMs;
  final int? width;
  final int? height;

  factory ChatFile.fromJson(Map<String, dynamic> j) => ChatFile(
        url: j['url'] as String,
        thumbUrl: j['thumbUrl'] as String?,
        name: j['name'] as String?,
        size: (j['size'] as num?)?.toInt(),
        mimeType: j['mimeType'] as String?,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );
}

/// kind: TEXT | IMAGE | VIDEO | VOICE | AUDIO | FILE.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.kind,
    required this.createdAt,
    this.sender,
    this.text,
    this.file,
    this.deleted = false,
    this.clientId,
    this.replyTo,
    this.forwardedFrom,
    this.editedAt,
    this.reactions = const [],
  });
  final String id;
  final String roomId;
  final String kind;
  final ChatReply? replyTo;
  final String? forwardedFrom;
  final DateTime? editedAt;
  final List<ChatReaction> reactions;
  final ChatPerson? sender;
  final String? text;
  final ChatFile? file;
  final bool deleted;
  final DateTime createdAt;
  final String? clientId;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        roomId: j['roomId'] as String,
        kind: j['kind'] as String? ?? 'TEXT',
        sender: j['sender'] == null ? null : ChatPerson.fromJson((j['sender'] as Map).cast<String, dynamic>()),
        text: j['text'] as String?,
        file: j['file'] == null ? null : ChatFile.fromJson((j['file'] as Map).cast<String, dynamic>()),
        deleted: j['deleted'] as bool? ?? false,
        createdAt: _dt(j['createdAt']),
        clientId: j['clientId'] as String?,
        replyTo: j['replyTo'] == null ? null : ChatReply.fromJson((j['replyTo'] as Map).cast<String, dynamic>()),
        forwardedFrom: j['forwardedFrom'] as String?,
        editedAt: _dtn(j['editedAt']),
        reactions: ((j['reactions'] as List?) ?? const []).map((r) => ChatReaction.fromJson((r as Map).cast<String, dynamic>())).toList(),
      );

  ChatMessage asDeleted() => ChatMessage(id: id, roomId: roomId, kind: 'TEXT', createdAt: createdAt, sender: sender, deleted: true, clientId: clientId);
}

/// A row of «Чат»: kind DIRECT | GROUP | COMPANY.
class ChatRoomSummary {
  const ChatRoomSummary({
    required this.id,
    required this.kind,
    required this.lastMessageAt,
    this.title,
    this.peer,
    this.memberCount = 0,
    this.isOwner = false,
    this.unread = 0,
    this.lastMessage,
    this.pinned = false,
    this.muted = false,
  });
  final bool pinned;
  final bool muted;
  final String id;
  final String kind;
  final String? title;
  final ChatPerson? peer;
  final int memberCount;
  final bool isOwner;
  final int unread;
  final ChatMessage? lastMessage;
  final DateTime lastMessageAt;

  factory ChatRoomSummary.fromJson(Map<String, dynamic> j) => ChatRoomSummary(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String?,
        peer: j['peer'] == null ? null : ChatPerson.fromJson((j['peer'] as Map).cast<String, dynamic>()),
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        isOwner: j['isOwner'] as bool? ?? false,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        lastMessage: j['lastMessage'] == null ? null : ChatMessage.fromJson((j['lastMessage'] as Map).cast<String, dynamic>()),
        lastMessageAt: _dt(j['lastMessageAt']),
        pinned: j['pinned'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
      );
}

class ChatRoomDetail {
  const ChatRoomDetail({
    required this.id,
    required this.kind,
    this.title,
    this.isOwner = false,
    this.canManage = false,
    this.memberCount = 0,
    this.peer,
    this.members = const [],
    this.canPin = false,
    this.pinned = false,
    this.muted = false,
    this.pinnedMessage,
  });
  final String id;
  final String kind;
  final String? title;
  final bool isOwner;
  final bool canManage;
  final bool canPin;
  final bool pinned;
  final bool muted;
  final ChatMessage? pinnedMessage;
  final int memberCount;
  final ChatPerson? peer;
  final List<ChatPerson> members;

  factory ChatRoomDetail.fromJson(Map<String, dynamic> j) => ChatRoomDetail(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String?,
        isOwner: j['isOwner'] as bool? ?? false,
        canManage: j['canManage'] as bool? ?? false,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        peer: j['peer'] == null ? null : ChatPerson.fromJson((j['peer'] as Map).cast<String, dynamic>()),
        members: ((j['members'] as List?) ?? const []).map((m) => ChatPerson.fromJson((m as Map).cast<String, dynamic>())).toList(),
        canPin: j['canPin'] as bool? ?? false,
        pinned: j['pinned'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
        pinnedMessage: j['pinnedMessage'] == null ? null : ChatMessage.fromJson((j['pinnedMessage'] as Map).cast<String, dynamic>()),
      );
}

/// A search hit inside a message, with the chat it is in.
class ChatSearchHit {
  const ChatSearchHit(this.message, this.roomId, this.roomKind, this.roomTitle);
  final ChatMessage message;
  final String roomId;
  final String roomKind;
  final String? roomTitle;
}

class ChatSearchResult {
  const ChatSearchResult({this.rooms = const [], this.people = const [], this.messages = const []});
  final List<ChatRoomSummary> rooms;
  final List<ChatPerson> people;
  final List<ChatSearchHit> messages;
}

class ChatPage {
  const ChatPage(this.items, this.hasMore);
  /// newest first
  final List<ChatMessage> items;
  final bool hasMore;
}
