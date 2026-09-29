import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'chat_list_screen.dart';
import 'chat_media.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

const _uuid = Uuid();

/// What a picked file is, from its name (the server checks the real bytes anyway).
String chatKindForName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext)) return 'IMAGE';
  if (const {'mp4', 'mov', 'webm', '3gp', 'mkv'}.contains(ext)) return 'VIDEO';
  if (const {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'amr'}.contains(ext)) return 'AUDIO';
  return 'FILE';
}

/// A message on its way out: shown at once, then replaced by the server's copy (or marked «не отправлено»).
class _Outgoing {
  _Outgoing({required this.clientId, required this.kind, this.text, this.path, this.filename, this.durationMs, this.replyToId});
  final String clientId;
  final String? replyToId;
  final String kind;
  final String? text;
  final String? path;
  final String? filename;
  final int? durationMs;
  double progress = 0;
  bool failed = false;
  final createdAt = DateTime.now();
}

/// A conversation. Newest at the bottom; scrolling up loads older messages; new ones arrive live over the socket.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  ChatRoomDetail? _room;
  final _messages = <ChatMessage>[]; // newest first
  final _outgoing = <_Outgoing>[];
  bool _hasMore = false;
  bool _loadingMore = false;
  Object? _error;
  bool _loaded = false;

  /// the message the next one answers / the one being edited (shown above the input)
  ChatMessage? _replyTo;
  ChatMessage? _editing;
  /// who is typing / recording right now: userId -> (name, kind, until)
  final _typing = <String, (String, String, DateTime)>{};
  Timer? _typingSweep;
  DateTime _typingSentAt = DateTime(2000);

  String get _draftKey => 'chat_draft_${widget.roomId}';

  // voice
  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recStarted;
  Timer? _recTick;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    openChatRoomId = widget.roomId;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadOlder();
    });
    // the unsent text of this chat is kept (a draft), like in Telegram
    try {
      _text.text = ref.read(sharedPrefsProvider).getString(_draftKey) ?? '';
    } catch (_) {/* no prefs in some tests */}
    _text.addListener(_onTextChanged);
    _load();
  }

  void _onTextChanged() {
    if (_text.text.trim().isNotEmpty) _sendTyping('text');
  }

  /// «печатает…» to the others, at most every 2 s.
  void _sendTyping(String kind) {
    final now = DateTime.now();
    if (now.difference(_typingSentAt) < const Duration(seconds: 2)) return;
    _typingSentAt = now;
    try {
      ref.read(realtimeClientProvider).emit('chat:typing', {'roomId': widget.roomId, 'kind': kind});
    } catch (_) {/* no socket (tests) */}
  }

  void _saveDraft() {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final t = _text.text;
      t.trim().isEmpty || _editing != null ? prefs.remove(_draftKey) : prefs.setString(_draftKey, t);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (openChatRoomId == widget.roomId) openChatRoomId = null;
    _saveDraft();
    _typingSweep?.cancel();
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _scroll.dispose();
    _recTick?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.room(widget.roomId), _repo.messages(widget.roomId)]);
      if (!mounted) return;
      final page = results[1] as ChatPage;
      setState(() {
        _room = results[0] as ChatRoomDetail;
        _messages..clear()..addAll(page.items);
        _hasMore = page.hasMore;
        _loaded = true;
        _error = null;
      });
      _markRead();
    } catch (e) {
      if (mounted) setState(() { _error = e; _loaded = true; });
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingMore || _messages.isEmpty) return;
    _loadingMore = true;
    try {
      final page = await _repo.messages(widget.roomId, before: _messages.last.id);
      if (!mounted) return;
      setState(() { _merge(page.items); _hasMore = page.hasMore; });
    } catch (_) {/* next scroll tries again */} finally {
      _loadingMore = false;
    }
  }

  Future<void> _fetchNew() async {
    try {
      final page = _messages.isEmpty ? await _repo.messages(widget.roomId) : await _repo.messages(widget.roomId, after: _messages.first.id, limit: 100);
      if (!mounted) return;
      setState(() => _merge(page.items));
      _markRead();
    } catch (_) {/* the next event or reopen refetches */}
  }

  /// An edit or a reaction: the newest page again (where it almost always is) and the pinned message.
  Future<void> _refreshRecent() async {
    try {
      final page = await _repo.messages(widget.roomId);
      if (mounted) setState(() => _merge(page.items));
    } catch (_) {}
  }

  /// Adds messages by id (a socket hint and my own send can deliver the same one), newest first.
  void _merge(List<ChatMessage> items) {
    final byId = {for (final m in _messages) m.id: m};
    for (final m in items) {
      byId[m.id] = m;
      _outgoing.removeWhere((o) => o.clientId == m.clientId);
    }
    _messages
      ..clear()
      ..addAll(byId.values.toList()..sort((a, b) => b.id.compareTo(a.id)));
  }

  void _markRead() => _repo.read(widget.roomId).then((_) => ref.invalidate(chatUnreadProvider)).catchError((_) {});

  // ---- sending ------------------------------------------------------------------------------------------------------------
  Future<void> _sendOutgoing(_Outgoing o) async {
    setState(() { o.failed = false; o.progress = 0; });
    try {
      final m = o.path == null
          ? await _repo.sendText(widget.roomId, o.text!, o.clientId, replyToId: o.replyToId)
          : await _repo.sendFile(widget.roomId, path: o.path!, filename: o.filename!, kind: o.kind, clientId: o.clientId, text: o.text, durationMs: o.durationMs, replyToId: o.replyToId,
              onProgress: (p) { if (mounted) setState(() => o.progress = p); });
      if (!mounted) return;
      setState(() { _outgoing.remove(o); _merge([m]); });
    } catch (e) {
      if (!mounted) return;
      setState(() => o.failed = true);
      if (e is ApiException && e.code == 'FILE_REJECTED') {
        setState(() => _outgoing.remove(o));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
      }
    }
  }

  void _sendText() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    final editing = _editing;
    if (editing != null) {
      setState(() => _editing = null);
      _repo.edit(editing.id, text).then((m) { if (mounted) setState(() => _merge([m])); }).catchError((Object e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
      });
      return;
    }
    final o = _Outgoing(clientId: _uuid.v4(), kind: 'TEXT', text: text, replyToId: _replyTo?.id);
    setState(() { _outgoing.insert(0, o); _replyTo = null; });
    _saveDraft();
    _sendOutgoing(o);
    _scrollToBottom();
  }

  Future<void> _sendPath(String path, String filename, String kind, {int? durationMs}) async {
    final l = AppLocalizations.of(context);
    if (await File(path).length() > chatMaxFileBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatFileTooLarge)));
      return;
    }
    final o = _Outgoing(clientId: _uuid.v4(), kind: kind, path: path, filename: filename, durationMs: durationMs, replyToId: _replyTo?.id);
    if (!mounted) return;
    setState(() { _outgoing.insert(0, o); _replyTo = null; });
    _scrollToBottom();
    await _sendOutgoing(o);
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(key: const Key('attachPhoto'), leading: const Icon(Icons.photo_library_rounded), title: Text(l.chatPhoto), onTap: () => Navigator.pop(ctx, 'photo')),
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(l.chatCamera), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.video_library_rounded), title: Text(l.chatVideo), onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(leading: const Icon(Icons.videocam_rounded), title: Text(l.chatRecordVideo), onTap: () => Navigator.pop(ctx, 'recordVideo')),
          ListTile(key: const Key('attachFile'), leading: const Icon(Icons.attach_file_rounded), title: Text(l.chatFile), onTap: () => Navigator.pop(ctx, 'file')),
        ]),
      ),
    );
    if (choice == null) return;
    final picker = ImagePicker();
    switch (choice) {
      case 'photo':
        for (final x in await picker.pickMultiImage(imageQuality: 85, maxWidth: 2560, maxHeight: 2560)) {
          unawaited(_sendPath(x.path, x.name, 'IMAGE'));
        }
      case 'camera':
        final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2560, maxHeight: 2560);
        if (x != null) await _sendPath(x.path, x.name, 'IMAGE');
      case 'video':
        final x = await picker.pickVideo(source: ImageSource.gallery);
        if (x != null) await _sendPath(x.path, x.name, 'VIDEO');
      case 'recordVideo':
        final x = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 3));
        if (x != null) await _sendPath(x.path, x.name, 'VIDEO');
      case 'file':
        for (final f in await FilePicker.pickFiles()) {
          final len = f.lengthSync() ?? await f.length();
          if (len != null && len > chatMaxFileBytes) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatFileTooLarge)));
            continue;
          }
          final path = f.path ?? await _localCopy(f);
          unawaited(_sendPath(path, f.name, chatKindForName(f.name)));
        }
    }
  }

  /// A picked document that is not a plain file on disk (Android content://): copied into the cache, streamed.
  Future<String> _localCopy(PlatformFile f) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/chat-out');
    await dir.create(recursive: true);
    final out = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}-${f.name.replaceAll(RegExp(r'[^\w.\-]'), '_')}');
    final sink = out.openWrite();
    await sink.addStream(f.readAsByteStream());
    await sink.close();
    return out.path;
  }

  // ---- voice ----------------------------------------------------------------------------------------------------------------
  Future<void> _startRecording() async {
    final l = AppLocalizations.of(context);
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatMicPermission)));
      return;
    }
    final path = '${(await getTemporaryDirectory()).path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
    HapticFeedback.mediumImpact();
    setState(() { _recording = true; _recStarted = DateTime.now(); });
    _sendTyping('voice');
    _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
      _sendTyping('voice');
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    if (!_recording) return;
    _recTick?.cancel();
    final started = _recStarted;
    final path = await _recorder.stop();
    setState(() => _recording = false);
    final ms = started == null ? 0 : DateTime.now().difference(started).inMilliseconds;
    if (!send || path == null || ms < 700) return; // a tap, not a recording
    await _sendPath(path, 'voice.m4a', 'VOICE', durationMs: ms);
  }

  // ---- message actions ------------------------------------------------------------------------------------------------------
  Future<void> _messageMenu(ChatMessage m, bool mine) async {
    final l = AppLocalizations.of(context);
    final me = ref.read(authControllerProvider).value;
    final canDelete = mine || me?.role == 'SUPER_ADMIN' || me?.role == 'ADMIN';
    final canEdit = mine && (m.text ?? '').isNotEmpty && m.forwardedFrom == null && DateTime.now().difference(m.createdAt) < const Duration(hours: 48);
    final isPinned = _room?.pinnedMessage?.id == m.id;
    if (m.deleted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          // one tap = a reaction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (final e in chatReactions)
                InkWell(
                  key: Key('react-$e'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(ctx, 'react:$e'),
                  child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 26))),
                ),
            ]),
          ),
          const Divider(),
          ListTile(key: const Key('msgReply'), leading: const Icon(Icons.reply_rounded), title: Text(l.chatReply), onTap: () => Navigator.pop(ctx, 'reply')),
          if ((m.text ?? '').isNotEmpty) ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l.chatCopy), onTap: () => Navigator.pop(ctx, 'copy')),
          if (canEdit) ListTile(key: const Key('msgEdit'), leading: const Icon(Icons.edit_rounded), title: Text(l.chatEdit), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(key: const Key('msgForward'), leading: const Icon(Icons.forward_rounded), title: Text(l.chatForward), onTap: () => Navigator.pop(ctx, 'forward')),
          if (_room?.canPin ?? false)
            ListTile(key: const Key('msgPin'), leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded), title: Text(isPinned ? l.chatUnpin : l.chatPin), onTap: () => Navigator.pop(ctx, 'pin')),
          if (canDelete)
            ListTile(
              key: const Key('deleteMessage'),
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
              title: Text(l.chatDeleteMessage, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    void fail(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e)))); }
    if (choice.startsWith('react:')) {
      await _react(m, choice.substring(6));
    } else if (choice == 'reply') {
      setState(() { _replyTo = m; _editing = null; });
    } else if (choice == 'edit') {
      setState(() { _editing = m; _replyTo = null; _text.text = m.text ?? ''; });
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text ?? ''));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatCopied)));
    } else if (choice == 'forward') {
      final to = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _ForwardSheet(),
      );
      if (to == null) return;
      try {
        await _repo.forward(m.id, [to]);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatForwarded)));
      } catch (e) {
        fail(e);
      }
    } else if (choice == 'pin') {
      try {
        final r = await _repo.pin(widget.roomId, isPinned ? null : m.id);
        if (mounted) setState(() => _room = r);
      } catch (e) {
        fail(e);
      }
    } else if (choice == 'delete') {
      if (!await confirmDelete(context, title: l.chatDeleteMessage, body: l.chatDeleteMessageBody)) return;
      try {
        await _repo.deleteMessage(m.id);
        if (mounted) setState(() => _merge([m.asDeleted()]));
      } catch (e) {
        fail(e);
      }
    }
  }

  Future<void> _react(ChatMessage m, String emoji) async {
    try {
      final updated = await _repo.react(m.id, emoji);
      if (mounted) setState(() => _merge([updated]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Future<void> _groupInfo() async {
    final room = _room;
    if (room == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _RoomInfoSheet(room: room, onChanged: (r) { if (mounted) setState(() => _room = r); }, onLeft: () { if (mounted) Navigator.of(context).pop(); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    ref.listen(realtimeEventsProvider, (_, next) {
      final e = next.value;
      if (e == null || e.data['roomId'] != widget.roomId) return;
      switch (e.type) {
        case 'chat.message':
          _typing.remove(e.data['senderId']);
          _fetchNew();
        case 'chat.message_updated':
          _refreshRecent();
        case 'chat.typing':
          final uid = e.data['userId'] as String?;
          if (uid == null) return;
          setState(() => _typing[uid] = (e.data['name'] as String? ?? '', e.data['kind'] as String? ?? 'text', DateTime.now().add(const Duration(seconds: 6))));
          _typingSweep ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) return t.cancel();
            final now = DateTime.now();
            if (_typing.values.any((x) => x.$3.isBefore(now))) setState(() => _typing.removeWhere((_, x) => x.$3.isBefore(now)));
            if (_typing.isEmpty) { t.cancel(); _typingSweep = null; }
          });
        case 'chat.message_deleted':
          final id = e.data['messageId'];
          final i = _messages.indexWhere((m) => m.id == id);
          if (i >= 0) setState(() => _messages[i] = _messages[i].asDeleted());
        case 'chat.read':
        case 'chat.room':
          _repo.room(widget.roomId).then((r) { if (mounted) setState(() => _room = r); }).catchError((_) {});
      }
    });
    ref.listen(realtimeConnectedProvider, (_, next) { if (next.value == true) _fetchNew(); }); // missed while offline

    final room = _room;
    final title = room == null ? '' : chatTitle(l, kind: room.kind, title: room.title);
    final typing = _typing.values.toList();
    String? typingText;
    if (typing.isNotEmpty) {
      final t = typing.first;
      final direct = room?.kind == 'DIRECT';
      typingText = t.$2 == 'voice' ? (direct ? l.chatRecordingVoice : l.chatRecordingVoiceName(t.$1.split(' ').first)) : (direct ? l.chatTyping : l.chatTypingName(t.$1.split(' ').first));
    }
    final peer = room?.peer;
    final subtitle = room == null
        ? null
        : typingText ??
            (room.kind == 'DIRECT'
                ? (peer?.online ?? false)
                    ? l.onlineNow
                    : peer?.lastSeenAt != null
                        ? l.chatLastSeen(chatWhen(l, peer!.lastSeenAt!))
                        : (peer == null ? null : teamRoleLabel(l, peer.role))
                : room.kind == 'CHANNEL'
                    ? l.chatSubscribers(room.memberCount)
                    : l.chatMembers(room.memberCount));
    final showSender = room != null && room.kind != 'DIRECT';
    final peerRead = room?.peer?.lastReadAt;

    // the list, newest first (reverse: true), with a date line where the day changes
    final rows = <Object>[
      ..._outgoing,
      ..._messages,
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: room == null ? null : _groupInfo,
          child: Row(children: [
            if (room != null) ChatAvatar(kind: room.kind, name: title, online: room.peer?.online ?? false, radius: 18, photo: room.photoThumb),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle, key: const Key('chatSubtitle'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: typingText != null ? Theme.of(context).colorScheme.primary : null), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
        actions: [if (room != null) IconButton(key: const Key('groupInfo'), tooltip: l.chatInfo, icon: const Icon(Icons.info_outline_rounded), onPressed: _groupInfo)],
      ),
      body: Column(children: [
        if (room?.pinnedMessage != null)
          Material(
            key: const Key('pinnedBar'),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.push_pin_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(l.chatPinned, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              subtitle: Text(chatPreview(l, room!.pinnedMessage!), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: room.canPin
                  ? IconButton(tooltip: l.chatUnpin, icon: const Icon(Icons.close_rounded), onPressed: () => _repo.pin(widget.roomId, null).then((r) { if (mounted) setState(() => _room = r); }).catchError((_) {}))
                  : null,
            ),
          ),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, _error!))
                  : rows.isEmpty
                      ? EmptyState(icon: Icons.forum_outlined, title: l.chatEmpty)
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            final at = row is ChatMessage ? row.createdAt : (row as _Outgoing).createdAt;
                            final older = i + 1 < rows.length ? rows[i + 1] : null;
                            final olderAt = older == null ? null : older is ChatMessage ? older.createdAt : (older as _Outgoing).createdAt;
                            final newDay = olderAt == null || !DateUtils.isSameDay(at, olderAt);
                            final bubble = row is ChatMessage
                                ? _Bubble(
                                    message: row,
                                    mine: row.sender?.id == me?.id,
                                    showSender: showSender && row.sender?.id != me?.id,
                                    read: peerRead != null && !peerRead.isBefore(row.createdAt),
                                    onLongPress: () => _messageMenu(row, row.sender?.id == me?.id),
                                    onReact: (e) => _react(row, e),
                                    onSwipeReply: () => setState(() { _replyTo = row; _editing = null; }),
                                  )
                                : _OutgoingBubble(o: row as _Outgoing, onRetry: () => _sendOutgoing(row));
                            return Column(children: [if (newDay) _DayLine(at: at), bubble]);
                          },
                        ),
        ),
        if (_recording)
          Container(
            key: const Key('recordingBar'),
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.fiber_manual_record_rounded, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(formatDuration(DateTime.now().difference(_recStarted ?? DateTime.now()))),
              const SizedBox(width: 12),
              Expanded(child: Text(l.chatRecording, maxLines: 2)),
            ]),
          ),
        if (_replyTo != null || _editing != null)
          Material(
            key: const Key('composerContext'),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: ListTile(
              dense: true,
              leading: Icon(_editing != null ? Icons.edit_rounded : Icons.reply_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(
                _editing != null ? l.chatEditing : l.chatReplyTo(_replyTo!.sender?.fullName ?? ''),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(chatPreview(l, (_editing ?? _replyTo)!), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  if (_editing != null) _text.clear();
                  _editing = null;
                  _replyTo = null;
                }),
              ),
            ),
          ),
        if (room != null && !room.canWrite)
          SafeArea(
            top: false,
            child: Padding(
              key: const Key('readOnlyNotice'),
              padding: const EdgeInsets.all(16),
              child: Text(room.kind == 'CHANNEL' ? l.chatChannelReadOnly : l.chatGroupReadOnly, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ),
          )
        else
        _Composer(
          controller: _text,
          onSend: _sendText,
          onAttach: _attach,
          onRecordStart: _startRecording,
          onRecordEnd: () => _stopRecording(),
          onRecordCancel: () => _stopRecording(send: false),
        ),
      ]),
    );
  }
}

class _DayLine extends StatelessWidget {
  const _DayLine({required this.at});
  final DateTime at;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final text = DateUtils.isSameDay(at, now)
        ? l.chatToday
        : DateUtils.isSameDay(at, now.subtract(const Duration(days: 1)))
            ? l.chatYesterday
            : '${two(at.day)}.${two(at.month)}.${at.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );
  }
}

/// Text with tappable links (https://…, www.…) and highlighted @mentions.
class ChatRichText extends StatefulWidget {
  const ChatRichText(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  static final _pattern = RegExp(r'(https?://[^\s]+|www\.[^\s]+|@[\p{L}\p{N}_]+)', unicode: true);
  @override
  State<ChatRichText> createState() => _ChatRichTextState();
}

class _ChatRichTextState extends State<ChatRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in ChatRichText._pattern.allMatches(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final token = m.group(0)!;
      if (token.startsWith('@')) {
        spans.add(TextSpan(text: token, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)));
      } else {
        final url = token.startsWith('www.') ? 'https://$token' : token;
        final rec = TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        _recognizers.add(rec);
        spans.add(TextSpan(text: token, style: TextStyle(color: scheme.primary, decoration: TextDecoration.underline), recognizer: rec));
      }
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(TextSpan(style: TextStyle(color: widget.color, fontSize: 15.5), children: spans));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showSender, required this.read, required this.onLongPress, this.onReact, this.onSwipeReply});
  final ChatMessage message;
  final bool mine;
  final bool showSender;
  final bool read;
  final VoidCallback onLongPress;
  final ValueChanged<String>? onReact;
  final VoidCallback? onSwipeReply;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final m = message;
    final bg = mine ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(m.createdAt.hour)}:${two(m.createdAt.minute)}';

    Widget content;
    if (m.deleted) {
      content = Text(l.chatMessageDeleted, style: TextStyle(fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.7)));
    } else {
      final f = m.file;
      final text = (m.text ?? '').isEmpty ? null : ChatRichText(m.text!, color: fg);
      final media = switch (m.kind) {
        'IMAGE' when f != null => GestureDetector(
            key: Key('image-${m.id}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatImageScreen(url: f.url, caption: m.text))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: (f.width ?? 4) / (f.height ?? 3),
                  child: CachedNetworkImage(imageUrl: f.thumbUrl ?? f.url, fit: BoxFit.cover, placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
                ),
              ),
            ),
          ),
        'VIDEO' when f != null => InkWell(
            key: Key('video-${m.id}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatVideoScreen(message: m))),
            child: Container(
              width: 220,
              height: 140,
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
              child: Stack(alignment: Alignment.center, children: [
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
                Positioned(left: 8, bottom: 6, child: Text('🎬 ${formatBytes(f.size)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ]),
            ),
          ),
        'VOICE' || 'AUDIO' when f != null => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.kind == 'AUDIO' && f.name != null) Text(f.name!, style: TextStyle(color: fg, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ChatAudioBubble(message: m, color: fg),
          ]),
        'FILE' when f != null => InkWell(
            key: Key('file-${m.id}'),
            onTap: () => ChatFiles.open(context, m),
            child: SizedBox(
              width: 230,
              child: Row(children: [
                CircleAvatar(backgroundColor: fg.withValues(alpha: 0.12), foregroundColor: fg, child: const Icon(Icons.insert_drive_file_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name ?? l.chatFile, style: TextStyle(color: fg, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(formatBytes(f.size), style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        _ => null,
      };
      final reply = m.replyTo;
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (m.forwardedFrom != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l.chatForwardedFrom(m.forwardedFrom!), style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12.5, fontStyle: FontStyle.italic)),
          ),
        if (reply != null)
          Container(
            key: Key('quote-${m.id}'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: BoxDecoration(color: fg.withValues(alpha: 0.08), border: Border(left: BorderSide(color: scheme.primary, width: 3)), borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (reply.sender != null) Text(reply.sender!, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
              Text(reply.deleted ? l.chatMessageDeleted : (reply.preview ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 13)),
            ]),
          ),
        ?media,
        if (media != null && text != null) const SizedBox(height: 6),
        ?text,
      ]);
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: GestureDetector(
          onLongPress: onLongPress,
          onHorizontalDragEnd: onSwipeReply == null || m.deleted ? null : (d) { if ((d.primaryVelocity ?? 0) > 250) onSwipeReply!(); },
          child: Container(
            key: Key('msg-${m.id}'),
            margin: EdgeInsets.only(top: 3, bottom: 3, left: mine ? 40 : 0, right: mine ? 0 : 40),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (showSender && m.sender != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(m.sender!.fullName, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              content,
              if (m.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final r in m.reactions)
                      InkWell(
                        key: Key('reaction-${m.id}-${r.emoji}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: onReact == null ? null : () => onReact!(r.emoji),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: r.mine ? scheme.primary.withValues(alpha: 0.2) : fg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: r.mine ? Border.all(color: scheme.primary) : null,
                          ),
                          child: Text('${r.emoji} ${r.count}', style: TextStyle(fontSize: 13, color: fg)),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (m.editedAt != null && !m.deleted) Text('${l.chatEdited} ', style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6))),
                Text(time, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6))),
                if (mine && !m.deleted) ...[
                  const SizedBox(width: 4),
                  Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: read ? scheme.primary : fg.withValues(alpha: 0.6), semanticLabel: read ? l.chatRead : null),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({required this.o, required this.onRetry});
  final _Outgoing o;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = switch (o.kind) {
      'IMAGE' => '📷 ${l.chatPhoto}',
      'VIDEO' => '🎬 ${l.chatVideo}',
      'VOICE' => '🎤 ${l.chatVoice}',
      'AUDIO' => '🎵 ${o.filename ?? l.chatAudio}',
      'FILE' => '📎 ${o.filename ?? l.chatFile}',
      _ => o.text ?? '',
    };
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: o.failed ? onRetry : null,
        child: Container(
          margin: const EdgeInsets.only(top: 3, bottom: 3, left: 40),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 15.5)),
            const SizedBox(height: 4),
            if (o.failed)
              Text(l.chatSendFailed, style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w600))
            else if (o.path != null)
              SizedBox(width: 140, child: LinearProgressIndicator(value: o.progress > 0 ? o.progress : null, minHeight: 3))
            else
              Icon(Icons.schedule_rounded, size: 14, color: scheme.onPrimaryContainer.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }
}

/// Text field + attach; the right button is «send» while there is text, otherwise a hold-to-record microphone.
class _Composer extends StatefulWidget {
  const _Composer({required this.controller, required this.onSend, required this.onAttach, required this.onRecordStart, required this.onRecordEnd, required this.onRecordCancel});
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  static const _emojis = ['😀', '😂', '😊', '😍', '🥰', '😘', '😉', '😎', '🤔', '😅', '😢', '😭', '😡', '😱', '🙈', '👍', '👎', '👌', '🙏', '👏',
    '💪', '🤝', '❤️', '💔', '🔥', '✨', '🎉', '🌸', '🌹', '💎', '✅', '❌', '⏰', '📦', '🧵', '✂️', '📍', '🚗', '☕', '🍰'];

  Future<void> _pickEmoji(BuildContext context) async {
    final e = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          children: [for (final e in _emojis) InkWell(onTap: () => Navigator.pop(ctx, e), child: Center(child: Text(e, style: const TextStyle(fontSize: 26))))],
        ),
      ),
    );
    if (e == null) return;
    final c = widget.controller;
    final sel = c.selection;
    final at = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    c.value = TextEditingValue(text: c.text.replaceRange(at, end, e), selection: TextSelection.collapsed(offset: at + e.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Material(
      color: scheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(key: const Key('chatAttach'), tooltip: l.chatAttach, icon: const Icon(Icons.attach_file_rounded), onPressed: widget.onAttach),
            IconButton(key: const Key('chatEmoji'), tooltip: l.chatEmoji, icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () => _pickEmoji(context)),
            Expanded(
              child: TextField(
                key: const Key('chatInput'),
                controller: widget.controller,
                minLines: 1,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l.chatTypeMessage,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (hasText)
              IconButton.filled(key: const Key('chatSend'), tooltip: l.chatSend, icon: const Icon(Icons.send_rounded), onPressed: widget.onSend)
            else
              GestureDetector(
                key: const Key('chatMic'),
                onTap: () => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.chatHoldToRecord))),
                onLongPressStart: (_) => widget.onRecordStart(),
                onLongPressEnd: (_) => widget.onRecordEnd(),
                onLongPressCancel: widget.onRecordCancel,
                child: CircleAvatar(radius: 24, backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, child: const Icon(Icons.mic_rounded)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// «Информация о чате» / «О группе» / «О канале»: photo, name, description, «only admins write», members and admins
/// (managed by the chat's admins; admins chosen by its owner), and the chat's media, files, voice notes and links.
class _RoomInfoSheet extends ConsumerStatefulWidget {
  const _RoomInfoSheet({required this.room, required this.onChanged, required this.onLeft});
  final ChatRoomDetail room;
  final ValueChanged<ChatRoomDetail> onChanged;
  final VoidCallback onLeft;
  @override
  ConsumerState<_RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends ConsumerState<_RoomInfoSheet> {
  late ChatRoomDetail _room = widget.room;
  late String _tab = _managed ? 'members' : 'media';
  Future<List<ChatMessage>>? _media;

  bool get _managed => _room.kind == 'GROUP' || _room.kind == 'CHANNEL';
  bool get _audienceChannel => _room.kind == 'CHANNEL' && _room.audience != 'CUSTOM';

  Future<void> _run(Future<ChatRoomDetail> Function() op) async {
    try {
      final r = await op();
      if (!mounted) return;
      setState(() => _room = r);
      widget.onChanged(r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Future<void> _editText({required String label, required String? value, required Future<ChatRoomDetail> Function(String) save}) async {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: value);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, autofocus: true, maxLines: null, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    if (v != null) await _run(() => save(v));
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (x != null) await _run(() => ref.read(chatRepositoryProvider).setPhoto(_room.id, x.path));
  }

  Future<void> _add({bool admins = false}) async {
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => NewChatSheet(pickOnly: true, exclude: _room.members.map((m) => m.id).toSet()),
    );
    if (ids == null || ids.isEmpty) return;
    await _run(() => admins ? ref.read(chatRepositoryProvider).updateGroup(_room.id, adminIds: ids) : ref.read(chatRepositoryProvider).updateGroup(_room.id, addIds: ids));
  }

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    if (!await confirmDelete(context, title: _room.kind == 'CHANNEL' ? l.chatLeaveChannel : l.chatLeaveGroup, body: l.chatLeaveGroupBody)) return;
    try {
      await ref.read(chatRepositoryProvider).leave(_room.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onLeft();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  void _select(String tab) => setState(() {
        _tab = tab;
        _media = tab == 'members' ? null : ref.read(chatRepositoryProvider).media(_room.id, tab);
      });

  @override
  void initState() {
    super.initState();
    if (_tab != 'members') _media = ref.read(chatRepositoryProvider).media(_room.id, _tab);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    final repo = ref.read(chatRepositoryProvider);
    final title = chatTitle(l, kind: _room.kind, title: _room.title);
    final tabs = <String, String>{if (_managed) 'members': l.chatTabMembers, 'media': l.chatTabMedia, 'files': l.chatTabFiles, 'voice': l.chatTabVoice, 'links': l.chatTabLinks};
    final audience = {'ALL': l.chatAudienceAll, 'STAFF': l.chatAudienceStaff, 'WORKERS': l.chatAudienceWorkers, 'CUSTOM': l.chatAudienceCustom};
    final canLeave = _room.kind == 'GROUP' || (_room.kind == 'CHANNEL' && _room.audience == 'CUSTOM');
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Row(children: [
          GestureDetector(
            onTap: _room.canManage ? _photo : null,
            child: Stack(children: [
              ChatAvatar(kind: _room.kind, name: title, radius: 32, photo: _room.photoThumb, online: _room.peer?.online ?? false),
              if (_room.canManage) Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 11, child: Icon(Icons.photo_camera_rounded, size: 13, semanticLabel: l.chatChangePhoto))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (_room.kind == 'CHANNEL') Text(l.chatSubscribers(_room.memberCount)) else if (_managed) Text(l.chatMembers(_room.memberCount)),
            ]),
          ),
          if (_room.canManage)
            IconButton(tooltip: l.chatRename, icon: const Icon(Icons.edit_rounded), onPressed: () => _editText(label: l.chatRename, value: _room.title, save: (v) => repo.updateGroup(_room.id, title: v))),
        ]),
        if (_managed) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notes_rounded),
            title: Text(_room.description?.isNotEmpty == true ? _room.description! : l.chatDescription, style: _room.description?.isNotEmpty == true ? null : TextStyle(color: Theme.of(context).colorScheme.outline)),
            onTap: _room.canManage ? () => _editText(label: l.chatDescription, value: _room.description, save: (v) => repo.updateGroup(_room.id, description: v)) : null,
          ),
          if (_room.kind == 'CHANNEL' && _room.audience != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.visibility_rounded), title: Text('${l.chatAudience}: ${audience[_room.audience] ?? ''}')),
          if (_room.kind == 'GROUP' && _room.canManage)
            SwitchListTile(
              key: const Key('onlyAdminsWrite'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.chatOnlyAdminsWrite),
              value: _room.onlyAdminsWrite,
              onChanged: (v) => _run(() => repo.updateGroup(_room.id, onlyAdminsWrite: v)),
            ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final t in tabs.entries)
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(key: Key('tab-${t.key}'), label: Text(t.value), selected: _tab == t.key, onSelected: (_) => _select(t.key))),
          ]),
        ),
        const SizedBox(height: 8),
        if (_tab == 'members') ...[
          if (_room.canManage && !_audienceChannel)
            ListTile(key: const Key('groupAdd'), contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.person_add_rounded)), title: Text(l.chatAddMembers), onTap: _add),
          if (_room.canEditAdmins && _audienceChannel)
            ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings_rounded)), title: Text(l.chatAddAdmin), onTap: () => _add(admins: true)),
          for (final m in _room.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ChatAvatar(kind: 'DIRECT', name: m.fullName, online: m.online, radius: 20),
              title: Text(m.id == me?.id ? '${m.fullName} (${l.chatYou})' : m.fullName),
              subtitle: Text('${teamRoleLabel(l, m.role)}${m.isOwner ? ' · ${l.chatOwner}' : m.isAdmin ? ' · ${l.chatAdmin}' : ''}'),
              trailing: m.id == me?.id || m.isOwner || !(_room.canManage || _room.canEditAdmins)
                  ? null
                  : PopupMenuButton<String>(
                      key: Key('member-${m.id}'),
                      onSelected: (v) => _run(() => switch (v) {
                            'admin' => repo.updateGroup(_room.id, adminIds: [m.id]),
                            'unadmin' => repo.updateGroup(_room.id, unadminIds: [m.id]),
                            _ => repo.updateGroup(_room.id, removeIds: [m.id]),
                          }),
                      itemBuilder: (_) => [
                        if (_room.canEditAdmins) PopupMenuItem(value: m.isAdmin ? 'unadmin' : 'admin', child: Text(m.isAdmin ? l.chatRemoveAdmin : l.chatMakeAdmin)),
                        if (_room.canManage && !_audienceChannel) PopupMenuItem(value: 'remove', child: Text(l.chatRemoveMember)),
                      ],
                    ),
            ),
        ] else
          FutureBuilder<List<ChatMessage>>(
            future: _media,
            builder: (context, snap) {
              if (snap.hasError) return Text(errorText(context, snap.error!));
              final items = snap.data;
              if (items == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (items.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.chatNothingYet)));
              if (_tab == 'media') {
                return GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  children: [
                    for (final m in items)
                      if (m.file != null)
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => m.kind == 'IMAGE' ? ChatImageScreen(url: m.file!.url, caption: m.text) : ChatVideoScreen(message: m))),
                          child: m.kind == 'IMAGE'
                              ? CachedNetworkImage(imageUrl: m.file!.thumbUrl ?? m.file!.url, fit: BoxFit.cover)
                              : const ColoredBox(color: Colors.black87, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                        ),
                  ],
                );
              }
              return Column(children: [
                for (final m in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_tab == 'links' ? Icons.link_rounded : _tab == 'voice' ? Icons.mic_rounded : Icons.insert_drive_file_rounded),
                    title: _tab == 'links'
                        ? ChatRichText(m.text ?? '', color: Theme.of(context).colorScheme.onSurface)
                        : _tab == 'voice'
                            ? ChatAudioBubble(message: m, color: Theme.of(context).colorScheme.onSurface)
                            : Text(m.file?.name ?? l.chatFile, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${m.sender?.fullName ?? ''} · ${chatWhen(l, m.createdAt)}${_tab == 'files' ? ' · ${formatBytes(m.file?.size)}' : ''}'),
                    onTap: _tab == 'files' ? () => ChatFiles.open(context, m) : null,
                  ),
              ]);
            },
          ),
        if (canLeave) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('groupLeave'),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: _leave,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_room.kind == 'CHANNEL' ? l.chatLeaveChannel : l.chatLeaveGroup),
          ),
        ],
      ]),
    );
  }
}

/// «Переслать в…»: one of my chats.
class _ForwardSheet extends ConsumerWidget {
  const _ForwardSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rooms = ref.watch(chatRoomsProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text(l.chatForwardTo, style: Theme.of(context).textTheme.titleLarge))),
        Expanded(
          child: rooms.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(errorText(context, e))),
            data: (items) => ListView(children: [
              for (final r in items)
                ListTile(
                  key: Key('fwd-${r.id}'),
                  leading: ChatAvatar(kind: r.kind, name: chatTitle(l, kind: r.kind, title: r.title), radius: 20),
                  title: Text(chatTitle(l, kind: r.kind, title: r.title)),
                  onTap: () => Navigator.pop(context, r.id),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
