import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  _Outgoing({required this.clientId, required this.kind, this.text, this.path, this.filename, this.durationMs});
  final String clientId;
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
    _load();
  }

  @override
  void dispose() {
    if (openChatRoomId == widget.roomId) openChatRoomId = null;
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
          ? await _repo.sendText(widget.roomId, o.text!, o.clientId)
          : await _repo.sendFile(widget.roomId, path: o.path!, filename: o.filename!, kind: o.kind, clientId: o.clientId, text: o.text, durationMs: o.durationMs,
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
    final o = _Outgoing(clientId: _uuid.v4(), kind: 'TEXT', text: text);
    setState(() => _outgoing.insert(0, o));
    _sendOutgoing(o);
    _scrollToBottom();
  }

  Future<void> _sendPath(String path, String filename, String kind, {int? durationMs}) async {
    final l = AppLocalizations.of(context);
    if (await File(path).length() > chatMaxFileBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatFileTooLarge)));
      return;
    }
    final o = _Outgoing(clientId: _uuid.v4(), kind: kind, path: path, filename: filename, durationMs: durationMs);
    if (!mounted) return;
    setState(() => _outgoing.insert(0, o));
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
    _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) { if (mounted) setState(() {}); });
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
    if (m.deleted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          if ((m.text ?? '').isNotEmpty) ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l.chatCopy), onTap: () => Navigator.pop(ctx, 'copy')),
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
    if (!mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text ?? ''));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatCopied)));
    } else if (choice == 'delete') {
      if (!await confirmDelete(context, title: l.chatDeleteMessage, body: l.chatDeleteMessageBody)) return;
      try {
        await _repo.deleteMessage(m.id);
        if (mounted) setState(() => _merge([m.asDeleted()]));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
      }
    }
  }

  Future<void> _groupInfo() async {
    final room = _room;
    if (room == null || room.kind != 'GROUP') return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _GroupInfoSheet(room: room, onChanged: (r) { if (mounted) setState(() => _room = r); }, onLeft: () { if (mounted) Navigator.of(context).pop(); }),
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
          _fetchNew();
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
    final subtitle = room == null
        ? null
        : room.kind == 'DIRECT'
            ? (room.peer?.online ?? false) ? l.onlineNow : (room.peer == null ? null : teamRoleLabel(l, room.peer!.role))
            : l.chatMembers(room.memberCount);
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
          onTap: room?.kind == 'GROUP' ? _groupInfo : null,
          child: Row(children: [
            if (room != null) ChatAvatar(kind: room.kind, name: title, online: room.peer?.online ?? false, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
        actions: [if (room?.kind == 'GROUP') IconButton(key: const Key('groupInfo'), tooltip: l.chatGroupInfo, icon: const Icon(Icons.info_outline_rounded), onPressed: _groupInfo)],
      ),
      body: Column(children: [
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showSender, required this.read, required this.onLongPress});
  final ChatMessage message;
  final bool mine;
  final bool showSender;
  final bool read;
  final VoidCallback onLongPress;

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
      final text = (m.text ?? '').isEmpty ? null : SelectableText(m.text!, style: TextStyle(color: fg, fontSize: 15.5));
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
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
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
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
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

/// «О группе»: members; the owner (or an administrator) renames, adds and removes; anyone leaves.
class _GroupInfoSheet extends ConsumerStatefulWidget {
  const _GroupInfoSheet({required this.room, required this.onChanged, required this.onLeft});
  final ChatRoomDetail room;
  final ValueChanged<ChatRoomDetail> onChanged;
  final VoidCallback onLeft;
  @override
  ConsumerState<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<_GroupInfoSheet> {
  late ChatRoomDetail _room = widget.room;

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

  Future<void> _rename() async {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: _room.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.chatRename),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: l.chatGroupName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await _run(() => ref.read(chatRepositoryProvider).updateGroup(_room.id, title: name));
  }

  Future<void> _add() async {
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => NewChatSheet(pickOnly: true, exclude: _room.members.map((m) => m.id).toSet()),
    );
    if (ids != null && ids.isNotEmpty) await _run(() => ref.read(chatRepositoryProvider).updateGroup(_room.id, addIds: ids));
  }

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    if (!await confirmDelete(context, title: l.chatLeaveGroup, body: l.chatLeaveGroupBody)) return;
    try {
      await ref.read(chatRepositoryProvider).leave(_room.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onLeft();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Row(children: [
          Expanded(child: Text(_room.title ?? '', style: Theme.of(context).textTheme.titleLarge)),
          if (_room.canManage) IconButton(tooltip: l.chatRename, icon: const Icon(Icons.edit_rounded), onPressed: _rename),
        ]),
        Text(l.chatMembers(_room.memberCount)),
        const SizedBox(height: 8),
        if (_room.canManage)
          ListTile(key: const Key('groupAdd'), contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.person_add_rounded)), title: Text(l.chatAddMembers), onTap: _add),
        for (final m in _room.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ChatAvatar(kind: 'DIRECT', name: m.fullName, online: m.online, radius: 20),
            title: Text(m.id == me?.id ? '${m.fullName} (${l.chatYou})' : m.fullName),
            subtitle: Text('${teamRoleLabel(l, m.role)}${m.isOwner ? ' · ${l.chatOwner}' : ''}'),
            trailing: _room.canManage && m.id != me?.id
                ? IconButton(
                    tooltip: l.chatRemoveMember,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: () => _run(() => ref.read(chatRepositoryProvider).updateGroup(_room.id, removeIds: [m.id])),
                  )
                : null,
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('groupLeave'),
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: _leave,
          icon: const Icon(Icons.logout_rounded),
          label: Text(l.chatLeaveGroup),
        ),
      ]),
    );
  }
}
