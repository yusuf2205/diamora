import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'chat_audio.dart';
import 'chat_list_screen.dart';
import 'chat_gallery.dart';
import 'chat_profile.dart';
import 'chat_media.dart';
import 'chat_models.dart';
import 'chat_more.dart';
import 'video_note.dart';
import '../manager/manager_tools.dart' show showReminderSheet;
import 'package:geolocator/geolocator.dart';
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
  /// a video's first frame (JPEG), shown at once and sent along as its preview
  Uint8List? thumb;
  int? width;
  int? height;
  List<int>? waveform;
  /// ✕ cancels the upload
  final cancel = CancelToken();
  final String? replyToId;
  final String kind;
  final String? text;
  final String? path;
  final String? filename;
  int? durationMs;
  double progress = 0;
  bool failed = false;
  /// «Отправить без звука»
  bool silent = false;
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
  /// messages that arrived while open: they pop in once
  final _fresh = <String>{};
  /// slid up onto the lock: the recording goes on without the finger
  bool _recLocked = false;
  DateTime? _recStarted;
  Timer? _recTick;
  StreamSubscription<Amplitude>? _ampSub;
  final _amps = <double>[];
  // search in this chat; message positions to jump to
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<ChatMessage>? _found;
  final _keys = <String, GlobalKey>{};
  String? _flash;

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
    _ampSub?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
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
    final firstLoad = _messages.isEmpty;
    for (final m in items) {
      // a message that arrives while the chat is open pops in (not the history loaded on opening)
      if (!firstLoad && !byId.containsKey(m.id)) _fresh.add(m.id);
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
          ? await _repo.sendText(widget.roomId, o.text!, o.clientId, replyToId: o.replyToId, silent: o.silent)
          : await _repo.sendFile(widget.roomId, path: o.path!, filename: o.filename!, kind: o.kind, clientId: o.clientId, text: o.text, durationMs: o.durationMs, replyToId: o.replyToId,
              width: o.width, height: o.height, thumb: o.thumb, waveform: o.waveform, cancel: o.cancel,
              onProgress: (p) { if (mounted) setState(() => o.progress = p); });
      if (!mounted) return;
      setState(() { _outgoing.remove(o); _merge([m]); });
    } catch (e) {
      if (!mounted) return;
      if (o.cancel.isCancelled) return setState(() => _outgoing.remove(o)); // ✕ pressed
      setState(() => o.failed = true);
      if (e is ApiException && e.code == 'FILE_REJECTED') {
        setState(() => _outgoing.remove(o));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
      }
    }
  }

  /// a poll / location / contact / card: sent at once, shown when the server answers
  Future<void> _sendSpecial(Future<ChatMessage> Function(String clientId) send) async {
    try {
      final m = await send(_uuid.v4());
      if (!mounted) return;
      setState(() => _merge([m]));
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Future<void> _sendMyLocation() async {
    final l = AppLocalizations.of(context);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatLocationDenied)));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      await _sendSpecial((id) => _repo.sendLocation(widget.roomId, latitude: pos.latitude, longitude: pos.longitude, label: l.chatMyLocation, clientId: id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatLocationFailed)));
    }
  }

  /// a long press on «send»: without sound, or later (like Telegram)
  Future<void> _sendOptions() async {
    final l = AppLocalizations.of(context);
    final text = _text.text.trim();
    if (text.isEmpty || _editing != null) return;
    final choice = await showAppSheet<String>(
      context: context, scrollable: true, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(key: const Key('sendSilent'), leading: const Icon(Icons.notifications_off_rounded), title: Text(l.chatSendSilent), onTap: () => Navigator.pop(ctx, 'silent')),
        ListTile(key: const Key('sendLater'), leading: const Icon(Icons.schedule_send_rounded), title: Text(l.chatSendLater), onTap: () => Navigator.pop(ctx, 'later')),
      ])),
    );
    if (choice == null || !mounted) return;
    if (choice == 'silent') {
      _text.clear();
      final o = _Outgoing(clientId: _uuid.v4(), kind: 'TEXT', text: text, replyToId: _replyTo?.id)..silent = true;
      setState(() { _outgoing.insert(0, o); _replyTo = null; });
      _saveDraft();
      await _sendOutgoing(o);
      return;
    }
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (t == null || !mounted) return;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (at.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatLaterInPast)));
      return;
    }
    try {
      await _repo.schedule(widget.roomId, text, at, replyToId: _replyTo?.id);
      _text.clear();
      _saveDraft();
      if (!mounted) return;
      setState(() => _replyTo = null);
      String two(int v) => v.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatLaterSaved('${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  /// «Отложенные»: what I scheduled here, cancellable
  Future<void> _showScheduled() async {
    final l = AppLocalizations.of(context);
    final items = await _repo.scheduled(widget.roomId).catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    String two(int v) => v.toString().padLeft(2, '0');
    await showAppSheet<void>(
      context: context, scrollable: true, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(l.chatScheduled, style: Theme.of(ctx).textTheme.titleMedium)),
        if (items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.chatScheduledNone)),
        for (final it in [...items])
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: Text('${it['text']}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Builder(builder: (_) { final d = DateTime.parse('${it['sendAt']}').toLocal(); return Text('${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}'); }),
            trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await _repo.unschedule('${it['id']}'); set(() => items.remove(it)); }),
          ),
      ]))),
    );
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

  void _cancelOutgoing(_Outgoing o) {
    o.cancel.cancel();
    setState(() => _outgoing.remove(o));
  }

  Future<void> _sendPath(String path, String filename, String kind, {int? durationMs, List<int>? waveform}) async {
    final l = AppLocalizations.of(context);
    final size = await File(path).length();
    if (size > (kind == 'VIDEO' ? chatMaxVideoBytes : chatMaxFileBytes)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(kind == 'VIDEO' ? l.chatVideoTooLarge : l.chatFileTooLarge)));
      return;
    }
    // shown in the chat at once (like Telegram), then it uploads with a progress ring
    final o = _Outgoing(clientId: _uuid.v4(), kind: kind, path: path, filename: filename, durationMs: durationMs, replyToId: _replyTo?.id)..waveform = waveform;
    if (!mounted) return;
    setState(() { _outgoing.insert(0, o); _replyTo = null; });
    _scrollToBottom();
    if (kind == 'VIDEO' || kind == 'VIDEO_NOTE') await _describeVideo(o);
    await _sendOutgoing(o);
  }

  /// A video's first frame, length and size - made on the phone, so others see a preview before downloading anything.
  Future<void> _describeVideo(_Outgoing o) async {
    try {
      final t = await VideoThumbnail.thumbnailData(video: o.path!, imageFormat: ImageFormat.JPEG, maxWidth: 640, quality: 70);
      if (mounted) setState(() => o.thumb = t);
    } catch (_) {/* no preview: the video still goes */}
    final c = VideoPlayerController.file(File(o.path!));
    try {
      await c.initialize();
      final sz = c.value.size;
      if (sz.width > 0) { o.width = sz.width.round(); o.height = sz.height.round(); }
      final ms = c.value.duration.inMilliseconds;
      if (ms > 0) o.durationMs ??= ms;
    } catch (_) {} finally {
      await c.dispose();
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Future<void> _attach() async {
    final l = AppLocalizations.of(context);
    final choice = await showAppSheet<String>(
      context: context,
      scrollable: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(key: const Key('attachPhoto'), leading: const Icon(Icons.photo_library_rounded), title: Text(l.chatPhoto), onTap: () => Navigator.pop(ctx, 'photo')),
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(l.chatCamera), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.video_library_rounded), title: Text(l.chatVideo), onTap: () => Navigator.pop(ctx, 'video')),
          ListTile(leading: const Icon(Icons.videocam_rounded), title: Text(l.chatRecordVideo), onTap: () => Navigator.pop(ctx, 'recordVideo')),
          ListTile(key: const Key('attachVideoNote'), leading: const Icon(Icons.radio_button_checked_rounded), title: Text(l.chatVideoNote), onTap: () => Navigator.pop(ctx, 'videoNote')),
          ListTile(key: const Key('attachFile'), leading: const Icon(Icons.attach_file_rounded), title: Text(l.chatFile), onTap: () => Navigator.pop(ctx, 'file')),
          const Divider(height: 8),
          ListTile(key: const Key('attachPoll'), leading: const Icon(Icons.poll_rounded), title: Text(l.chatPoll), onTap: () => Navigator.pop(ctx, 'poll')),
          ListTile(key: const Key('attachLocation'), leading: const Icon(Icons.location_on_rounded), title: Text(l.chatLocation), onTap: () => Navigator.pop(ctx, 'location')),
          ListTile(key: const Key('attachContact'), leading: const Icon(Icons.person_rounded), title: Text(l.chatContact), onTap: () => Navigator.pop(ctx, 'contact')),
          if (ref.read(authControllerProvider).value?.isStaff ?? false) ...[
            ListTile(key: const Key('attachCard'), leading: const Icon(Icons.assignment_rounded), title: Text(l.chatCardAttach), onTap: () => Navigator.pop(ctx, 'card')),
            ListTile(key: const Key('attachQuick'), leading: const Icon(Icons.bolt_rounded), title: Text(l.quickReplies), onTap: () => Navigator.pop(ctx, 'quick')),
          ],
        ]),
      ),
    );
    if (choice == null) return;
    if (!mounted) return;
    switch (choice) {
      case 'poll':
        final r = await showPollSheet(context);
        if (r != null) await _sendSpecial((id) => _repo.sendPoll(widget.roomId, question: r.question, options: r.options, multiple: r.multiple, clientId: id));
        return;
      case 'location':
        await _sendMyLocation();
        return;
      case 'contact':
        final r = await showContactSheet(context);
        if (r != null) await _sendSpecial((id) => _repo.sendContact(widget.roomId, name: r.name, phone: r.phone, clientId: id));
        return;
      case 'card':
        final r = await showCardPicker(context, ref);
        if (r != null) await _sendSpecial((id) => _repo.sendCard(widget.roomId, type: r.type, id: r.id, clientId: id));
        return;
      case 'quick':
        final t = await showQuickReplies(context, ref);
        if (t != null) setState(() => _text.text = t);
        return;
      case 'videoNote':
        final path = await VideoNoteRecorder.open(context);
        if (path != null) await _sendPath(path, 'note.mp4', 'VIDEO_NOTE');
        return;
    }
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
    _amps.clear();
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((a) => _amps.add(((a.current + 50) / 50).clamp(0.0, 1.0)));
    setState(() { _recording = true; _recStarted = DateTime.now(); });
    _sendTyping('voice');
    var ticks = 0;
    // 10 times a second: the time and the button breathing with the voice; «записывает голосовое» to the others now and then
    _recTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
      if (++ticks % 25 == 0) _sendTyping('voice');
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    if (!_recording) return;
    _recTick?.cancel();
    await _ampSub?.cancel();
    final started = _recStarted;
    final path = await _recorder.stop();
    setState(() { _recording = false; _recLocked = false; });
    final ms = started == null ? 0 : DateTime.now().difference(started).inMilliseconds;
    if (!send || path == null || ms < 700) return; // a tap, not a recording
    await _sendPath(path, 'voice.m4a', 'VOICE', durationMs: ms, waveform: toBars(_amps)); // the bars others see
  }

  // ---- message actions ------------------------------------------------------------------------------------------------------
  Future<void> _messageMenu(ChatMessage m, bool mine) async {
    final l = AppLocalizations.of(context);
    final me = ref.read(authControllerProvider).value;
    final canDelete = mine || me?.role == 'SUPER_ADMIN' || me?.role == 'ADMIN';
    final canEdit = mine && (m.text ?? '').isNotEmpty && m.forwardedFrom == null && DateTime.now().difference(m.createdAt) < const Duration(hours: 48);
    final isPinned = _room?.pinnedMessage?.id == m.id;
    final watching = _room?.watching ?? false;
    if (m.deleted) return;
    final choice = await showAppSheet<String>(
      context: context,
      scrollable: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          // one tap = a reaction (not while only looking in)
          if (!watching) Padding(
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
          if (!watching) const Divider(),
          if (!watching) ListTile(key: const Key('msgReply'), leading: const Icon(Icons.reply_rounded), title: Text(l.chatReply), onTap: () => Navigator.pop(ctx, 'reply')),
          if ((m.text ?? '').isNotEmpty && !(_room?.protectContent ?? false)) ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l.chatCopy), onTap: () => Navigator.pop(ctx, 'copy')),
          if ((m.text ?? '').isNotEmpty) ListTile(key: const Key('msgTranslate'), leading: const Icon(Icons.translate_rounded), title: Text(l.chatTranslate), onTap: () => Navigator.pop(ctx, 'translate')),
          if (canEdit) ListTile(key: const Key('msgEdit'), leading: const Icon(Icons.edit_rounded), title: Text(l.chatEdit), onTap: () => Navigator.pop(ctx, 'edit')),
          if (!(_room?.protectContent ?? false)) ListTile(key: const Key('msgForward'), leading: const Icon(Icons.forward_rounded), title: Text(l.chatForward), onTap: () => Navigator.pop(ctx, 'forward')),
          if (!(_room?.protectContent ?? false) && _room?.kind != 'SAVED') ListTile(key: const Key('msgSave'), leading: const Icon(Icons.bookmark_add_rounded), title: Text(l.chatSaveToSaved), onTap: () => Navigator.pop(ctx, 'save')),
          if (ref.read(authControllerProvider).value?.isStaff ?? false) ListTile(key: const Key('msgRemind'), leading: const Icon(Icons.alarm_add_rounded), title: Text(l.reminderAdd), onTap: () => Navigator.pop(ctx, 'remind')),
          if (_room?.canPin ?? false)
            ListTile(key: const Key('msgPin'), leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded), title: Text(isPinned ? l.chatUnpin : l.chatPin), onTap: () => Navigator.pop(ctx, 'pin')),
          if (canDelete)
            ListTile(
              key: const Key('deleteMessage'),
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
              title: Text(l.chatDeleteMessage, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          if (mine) _ReadInfo(message: m, direct: _room?.kind == 'DIRECT'),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    void fail(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e)))); }
    if (choice.startsWith('react:')) {
      await _react(m, choice.substring(6));
    } else if (choice == 'save') {
      try {
        final saved = await _repo.saved();
        await _repo.forward(m.id, [saved.id]);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatSavedDone)));
      } catch (e) {
        fail(e);
      }
    } else if (choice == 'translate') {
      await showTranslation(context, ref, m);
    } else if (choice == 'remind') {
      await showReminderSheet(context, text: chatPreview(l, m));
    } else if (choice == 'reply') {
      setState(() { _replyTo = m; _editing = null; });
    } else if (choice == 'edit') {
      setState(() { _editing = m; _replyTo = null; _text.text = m.text ?? ''; });
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text ?? ''));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatCopied)));
    } else if (choice == 'forward') {
      final to = await showAppSheet<String>(
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

  /// Scroll to a message (search result, a quoted message) and flash it.
  void _jumpTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).chatOlderMessage)));
      return;
    }
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.5);
    setState(() => _flash = id);
    Future<void>.delayed(const Duration(milliseconds: 1500), () { if (mounted) setState(() => _flash = null); });
  }

  Future<void> _roomAction(String a) async {
    final l = AppLocalizations.of(context);
    final room = _room;
    if (room == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (a == 'scheduled') return _showScheduled();
    try {
      switch (a) {
        case 'mute':
          await _repo.prefs(widget.roomId, muted: !room.muted);
          final r2 = await _repo.room(widget.roomId);
          if (mounted) setState(() => _room = r2);
        case 'info':
          await _groupInfo();
        case 'protect':
          final r2 = await _repo.protect(widget.roomId, !room.protectContent);
          if (mounted) setState(() => _room = r2);
        case 'export':
          final text = await _repo.exportHistory(widget.roomId);
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/diamoraa-chat-${DateTime.now().millisecondsSinceEpoch}.txt');
          await f.writeAsString(text);
          await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: chatTitle(l, kind: room.kind, title: room.title)));
        case 'clear':
          if (!mounted || !await confirmDelete(context, title: l.chatClearHistory, body: l.chatClearHistoryBody)) return;
          await _repo.clearHistory(widget.roomId);
          if (mounted) setState(() => _messages.clear());
          ref.invalidate(chatRoomsProvider);
        case 'delete':
          if (!mounted || !await confirmDelete(context, title: l.chatDeleteChat, body: l.chatDeleteChatBody)) return;
          await _repo.deleteChat(widget.roomId);
          ref.invalidate(chatRoomsProvider);
          if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Future<void> _groupInfo() async {
    final room = _room;
    if (room == null) return;
    await showAppSheet<void>(
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
      ...albumRows(_messages), // photos / videos sent together -> one grid
    ];
    final groupChat = room != null && room.kind != 'DIRECT' && room.kind != 'CHANNEL';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: room == null ? null : _groupInfo,
          child: Row(children: [
            if (room != null) ChatAvatar(kind: room.kind, name: title, online: room.peer?.online ?? false, radius: 18, photo: room.photoThumb ?? room.peer?.avatar),
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
        actions: [
          if (room != null) IconButton(key: const Key('chatSearchIn'), tooltip: l.chatSearchInChat, icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded), onPressed: () => setState(() { _searching = !_searching; _searchCtrl.clear(); _found = null; })),
          if (room != null) IconButton(key: const Key('groupInfo'), tooltip: l.chatInfo, icon: const Icon(Icons.info_outline_rounded), onPressed: _groupInfo),
          if (room != null)
            PopupMenuButton<String>(
              key: const Key('chatMore'),
              onSelected: _roomAction,
              itemBuilder: (_) => [
                if (!room.watching) chatMenuItem(context, 'mute', room.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, room.muted ? l.chatUnmute : l.chatMute),
                if (!room.watching) chatMenuItem(context, 'scheduled', Icons.schedule_send_outlined, l.chatScheduled),
                chatMenuItem(context, 'info', room.kind == 'DIRECT' ? Icons.person_outline_rounded : Icons.info_outline_rounded, room.kind == 'DIRECT' ? l.chatShowProfile : l.chatInfo),
                if (room.canProtect) chatMenuItem(context, 'protect', room.protectContent ? Icons.lock_open_outlined : Icons.lock_outline_rounded, room.protectContent ? l.chatProtectOff : l.chatProtectOn),
                if (!room.protectContent || room.canProtect) chatMenuItem(context, 'export', Icons.file_download_outlined, l.chatExport),
                if (!room.watching) chatMenuItem(context, 'clear', Icons.cleaning_services_outlined, l.chatClearHistory),
                if (room.kind == 'DIRECT' && !room.watching) chatMenuItem(context, 'delete', Icons.delete_outline_rounded, l.chatDeleteChat, danger: true),
              ],
            ),
        ],
      ),
      body: Column(children: [
        const ChatAudioBar(),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              key: const Key('chatSearchInField'),
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.chatSearchInChat, isDense: true),
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
                  if (v.trim().length < 2) { if (mounted) setState(() => _found = null); return; }
                  final found = await _repo.searchIn(widget.roomId, v.trim()).catchError((_) => <ChatMessage>[]);
                  if (mounted) setState(() => _found = found);
                });
              },
            ),
          ),
        if (_searching && _found != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: Material(
              elevation: 2,
              child: _found!.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(l.chatNothingFound))
                  : ListView(shrinkWrap: true, children: [
                      for (final m in _found!)
                        ListTile(
                          key: Key('found-in-${m.id}'),
                          dense: true,
                          title: Text(m.sender?.fullName ?? '', maxLines: 1),
                          subtitle: Text(m.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Text(chatWhen(l, m.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          onTap: () { setState(() { _searching = false; _found = null; }); _jumpTo(m.id); },
                        ),
                    ]),
            ),
          ),
        if (room != null && room.protectContent)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('🔒 ${l.chatProtected}', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ),
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
                            DateTime atOf(Object x) => x is ChatMessage ? x.createdAt : x is List<ChatMessage> ? x.last.createdAt : (x as _Outgoing).createdAt;
                            final at = atOf(row);
                            final older = i + 1 < rows.length ? rows[i + 1] : null;
                            final olderAt = older == null ? null : atOf(older);
                            if (row is List<ChatMessage>) {
                              final first = row.last; // newest-first list: the oldest is last
                              final mineA = first.sender?.id == me?.id;
                              return Column(key: _keys.putIfAbsent(row.first.id, GlobalKey.new), children: [
                                if (!DateUtils.isSameDay(at, olderAt ?? DateTime(1970))) _DayLine(at: at),
                                _AlbumBubble(items: row.reversed.toList(), mine: mineA, onOpen: (m) => ChatGalleryScreen.open(context, _messages.reversed.toList(), m), onLongPress: () => _messageMenu(row.first, mineA)),
                              ]);
                            }
                            final newDay = olderAt == null || !DateUtils.isSameDay(at, olderAt);
                            final bubble = row is ChatMessage
                                ? _Bubble(
                                    message: row,
                                    mine: row.sender?.id == me?.id,
                                    showSender: showSender && row.sender?.id != me?.id,
                                    read: peerRead != null && !peerRead.isBefore(row.createdAt),
                                    onLongPress: () => _messageMenu(row, row.sender?.id == me?.id),
                                    onReact: (e) => _react(row, e),
                                    onOpenMedia: () => ChatGalleryScreen.open(context, _messages.reversed.toList(), row),
                                    onSwipeReply: () => setState(() { _replyTo = row; _editing = null; }),
                                    onUpdated: (m) { if (mounted) setState(() => _merge([m])); },
                                    fresh: _fresh.remove(row.id),
                                  )
                                : _OutgoingBubble(o: row as _Outgoing, onRetry: () => _sendOutgoing(row), onCancel: () => _cancelOutgoing(row));
                            final other = row is ChatMessage && groupChat && row.sender?.id != me?.id;
                            final newer = i > 0 ? rows[i - 1] : null;
                            final newerSender = newer is ChatMessage ? newer.sender?.id : newer is List<ChatMessage> ? newer.first.sender?.id : null;
                            final lastOfRun = row is ChatMessage && newerSender != row.sender?.id;
                            final withAvatar = other
                                ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    if (lastOfRun) PersonPhoto(name: row.sender?.fullName ?? '', url: row.sender?.avatar, radius: 15) else const SizedBox(width: 30),
                                    const SizedBox(width: 6),
                                    Expanded(child: bubble),
                                  ])
                                : bubble;
                            final flashing = row is ChatMessage && _flash == row.id;
                            return AnimatedContainer(
                              key: row is ChatMessage ? _keys.putIfAbsent(row.id, GlobalKey.new) : null,
                              duration: const Duration(milliseconds: 300),
                              color: flashing ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18) : Colors.transparent,
                              child: Column(children: [if (newDay) _DayLine(at: at), withAvatar]),
                            );
                          },
                        ),
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
              child: Text(room.watching ? l.chatWatchingNotice : room.kind == 'CHANNEL' ? l.chatChannelReadOnly : l.chatGroupReadOnly, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ),
          )
        else
        _Composer(
          controller: _text,
          onSend: _sendText,
          onSendLong: _sendOptions,
          onAttach: _attach,
          onRecordStart: _startRecording,
          onRecordEnd: () => _stopRecording(),
          onRecordCancel: () => _stopRecording(send: false),
          recording: _recording,
          elapsed: DateTime.now().difference(_recStarted ?? DateTime.now()),
          level: _amps.isEmpty ? 0 : _amps.last,
          locked: _recLocked,
          onLock: () => setState(() => _recLocked = true),
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
  const _Bubble({required this.message, required this.mine, required this.showSender, required this.read, required this.onLongPress, this.onReact, this.onSwipeReply, this.onOpenMedia, this.onUpdated, this.fresh = false});
  final VoidCallback? onOpenMedia;
  /// a poll answered: the message as the server has it now
  final ValueChanged<ChatMessage>? onUpdated;
  /// arrived while the chat is open: pops in
  final bool fresh;
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
            onTap: onOpenMedia ?? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatImageScreen(url: f.url, caption: m.text))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: (f.width ?? 4) / (f.height ?? 3),
                  child: Hero(
                    tag: 'chat-media-${m.id}',
                    child: CachedNetworkImage(imageUrl: f.thumbUrl ?? f.url, cacheKey: fileCacheKey(f.thumbUrl ?? f.url), fit: BoxFit.cover, placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
                  ),
                ),
              ),
            ),
          ),
        'VIDEO' when f != null => GestureDetector(
            key: Key('video-${m.id}'),
            onTap: onOpenMedia ?? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatVideoScreen(message: m))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: (f.width ?? 16) / (f.height ?? 9),
                  child: Stack(fit: StackFit.expand, children: [
                    if (f.thumbUrl != null)
                      Hero(tag: 'chat-media-${m.id}', child: CachedNetworkImage(imageUrl: f.thumbUrl!, cacheKey: fileCacheKey(f.thumbUrl!), fit: BoxFit.cover))
                    else
                      const ColoredBox(color: Colors.black87),
                    const Center(child: CircleAvatar(radius: 26, backgroundColor: Colors.black45, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34))),
                    Positioned(
                      left: 6, bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text('${f.durationMs != null ? '${formatDuration(Duration(milliseconds: f.durationMs!))} · ' : ''}${formatBytes(f.size)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        'VOICE' || 'AUDIO' when f != null => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.kind == 'AUDIO' && f.name != null) Text(f.name!, style: TextStyle(color: fg, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ChatAudioBubble(message: m, color: fg),
            if (m.kind == 'VOICE') TranscribeButton(message: m, fg: fg),
          ]),
        'POLL' => PollBubble(message: m, fg: fg, onChanged: onUpdated ?? (_) {}),
        'LOCATION' when m.data != null => LocationBubble(data: m.data!, fg: fg),
        'CONTACT' when m.data != null => ContactBubble(data: m.data!, fg: fg),
        'CARD' when m.data != null => CardBubble(data: m.data!, fg: fg),
        'VIDEO_NOTE' when f != null => GestureDetector(
            key: Key('videonote-${m.id}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatVideoScreen(message: m))),
            child: SizedBox(
              width: 200, height: 200,
              child: ClipOval(
                child: Stack(fit: StackFit.expand, children: [
                  if (f.thumbUrl != null) CachedNetworkImage(imageUrl: f.thumbUrl!, cacheKey: fileCacheKey(f.thumbUrl!), fit: BoxFit.cover) else const ColoredBox(color: Colors.black87),
                  const Center(child: CircleAvatar(radius: 24, backgroundColor: Colors.black45, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))),
                ]),
              ),
            ),
          ),
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
        if (m.linkPreview != null) LinkPreviewCard(preview: m.linkPreview!, fg: fg),
      ]);
    }

    return PopIn(
      animate: fresh,
      fromRight: mine,
      child: SwipeToReply(
      enabled: onSwipeReply != null && !m.deleted,
      onReply: () => onSwipeReply?.call(),
      child: Align(
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
              if (m.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final r in m.reactions)
                      ReactionPop(count: r.count, child: InkWell(
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
                      )),
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
    ),
    ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({required this.o, required this.onRetry, this.onCancel});
  final _Outgoing o;
  final VoidCallback onRetry;
  final VoidCallback? onCancel;
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
    final visual = o.kind == 'IMAGE' && o.path != null
        ? Image.file(File(o.path!), fit: BoxFit.cover, cacheWidth: 600)
        : o.kind == 'VIDEO' && o.thumb != null
            ? Image.memory(o.thumb!, fit: BoxFit.cover)
            : o.kind == 'VIDEO'
                ? const ColoredBox(color: Colors.black87)
                : null;
    if (visual != null) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          key: Key('outgoing-${o.clientId}'),
          onTap: o.failed ? onRetry : null,
          child: Container(
            margin: const EdgeInsets.only(top: 3, bottom: 3, left: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: (o.width ?? 4) / (o.height ?? 3),
                  child: Stack(fit: StackFit.expand, children: [
                    visual,
                    Center(
                      child: GestureDetector(
                        key: Key('cancel-${o.clientId}'),
                        onTap: o.failed ? onRetry : onCancel, // ✕ stops it, like Telegram
                        child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.black54,
                        child: o.failed
                            ? const Icon(Icons.refresh_rounded, color: Colors.white)
                            : Stack(alignment: Alignment.center, children: [
                                SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: o.progress > 0 ? o.progress : null, color: Colors.white, strokeWidth: 3)),
                                Icon(Icons.close_rounded, color: Colors.white, semanticLabel: l.chatCancelUpload),
                              ]),
                      ),
                      ),
                    ),
                    if (o.failed)
                      Positioned(left: 0, right: 0, bottom: 0, child: Container(color: Colors.black54, padding: const EdgeInsets.all(4), child: Text(l.chatSendFailed, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }
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

/// Text field + attach; the right button is «send» while there is text, otherwise the microphone - like Telegram: touch
/// it and the recording starts at once (a red dot and the time), the button grows and breathes with the voice; slide
/// left to cancel, slide up to lock it (hands free), let go to send. A quick tap only says «hold to record».
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller, required this.onSend, required this.onAttach, required this.onRecordStart, required this.onRecordEnd,
    required this.onRecordCancel, this.recording = false, this.elapsed = Duration.zero, this.level = 0, this.locked = false, required this.onLock, this.onSendLong,
  });
  /// a long press on «send»: without sound / later
  final VoidCallback? onSendLong;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;
  final bool recording;
  final Duration elapsed;
  /// 0..1, the voice right now
  final double level;
  final bool locked;
  final VoidCallback onLock;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Offset? _down;
  DateTime? _downAt;
  Offset _drag = Offset.zero;
  bool _gestureDone = false;
  static const _cancelAt = 110.0;
  static const _lockAt = 80.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _Composer old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_blink.isAnimating) _blink.repeat(reverse: true);
    if (!widget.recording && _blink.isAnimating) _blink.stop();
  }

  @override
  void dispose() {
    _blink.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  static const _emojis = ['😀', '😂', '😊', '😍', '🥰', '😘', '😉', '😎', '🤔', '😅', '😢', '😭', '😡', '😱', '🙈', '👍', '👎', '👌', '🙏', '👏',
    '💪', '🤝', '❤️', '💔', '🔥', '✨', '🎉', '🌸', '🌹', '💎', '✅', '❌', '⏰', '📦', '🧵', '✂️', '📍', '🚗', '☕', '🍰'];

  Future<void> _pickEmoji(BuildContext context) async {
    final e = await showAppSheet<String>(
      context: context,
      scrollable: true,
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

  // ---- the microphone gesture ------------------------------------------------------------------------------------------
  void _micDown(PointerDownEvent e) {
    _down = e.position;
    _downAt = DateTime.now();
    _drag = Offset.zero;
    _gestureDone = false;
    widget.onRecordStart();
  }

  void _micMove(PointerMoveEvent e) {
    if (_down == null || _gestureDone || widget.locked) return;
    setState(() => _drag = e.position - _down!);
    if (_drag.dx < -_cancelAt) {
      _gestureDone = true;
      HapticFeedback.lightImpact();
      widget.onRecordCancel();
    } else if (_drag.dy < -_lockAt) {
      _gestureDone = true;
      HapticFeedback.mediumImpact();
      widget.onLock();
    }
    if (_gestureDone) setState(() => _drag = Offset.zero);
  }

  void _micUp(PointerUpEvent e) {
    final quick = _downAt != null && DateTime.now().difference(_downAt!) < const Duration(milliseconds: 350);
    final wasDone = _gestureDone;
    _down = null;
    setState(() => _drag = Offset.zero);
    if (wasDone || widget.locked) return;
    if (quick) {
      widget.onRecordCancel();
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.chatHoldToRecord)));
      return;
    }
    widget.onRecordEnd();
  }

  void _micCancel(PointerCancelEvent e) {
    _down = null;
    setState(() => _drag = Offset.zero);
    if (!_gestureDone && !widget.locked) widget.onRecordCancel();
  }

  String _time(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final rec = widget.recording;
    final dx = _drag.dx.clamp(-_cancelAt, 0.0);
    final dy = _drag.dy.clamp(-_lockAt, 0.0);

    final mic = Listener(
      key: const Key('chatMic'),
      onPointerDown: _micDown,
      onPointerMove: _micMove,
      onPointerUp: _micUp,
      onPointerCancel: _micCancel,
      child: Transform.translate(
        offset: rec && !widget.locked ? Offset(dx * 0.5, dy * 0.5) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: rec ? 64 + widget.level * 22 : 48,
          height: rec ? 64 + widget.level * 22 : 48,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            boxShadow: rec ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10 + widget.level * 30, spreadRadius: 2 + widget.level * 12)] : null,
          ),
          child: Icon(Icons.mic_rounded, color: scheme.onPrimary, size: rec ? 30 : 24),
        ),
      ),
    );

    final Widget field;
    if (rec) {
      field = Container(
        key: const Key('recordingBar'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          FadeTransition(opacity: _blink, child: Icon(Icons.fiber_manual_record_rounded, color: scheme.error, size: 16)),
          const SizedBox(width: 8),
          Text(_time(widget.elapsed), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: widget.locked
                ? Center(child: TextButton(key: const Key('recordCancel'), onPressed: widget.onRecordCancel, child: Text(l.cancel.toUpperCase())))
                : Opacity(
                    opacity: (1 + dx / _cancelAt).clamp(0.2, 1.0),
                    child: Transform.translate(
                      offset: Offset(dx * 0.6, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.chevron_left_rounded, color: scheme.outline),
                        Flexible(child: Text(l.chatSlideToCancel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.outline))),
                      ]),
                    ),
                  ),
          ),
        ]),
      );
    } else {
      field = TextField(
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
      );
    }

    return Material(
      color: scheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Stack(clipBehavior: Clip.none, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              rec ? const SizedBox.shrink() : IconButton(key: const Key('chatAttach'), tooltip: l.chatAttach, icon: const Icon(Icons.attach_file_rounded), onPressed: widget.onAttach),
              rec ? const SizedBox.shrink() : IconButton(key: const Key('chatEmoji'), tooltip: l.chatEmoji, icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () => _pickEmoji(context)),
              Expanded(child: field),
              const SizedBox(width: 6),
              if (hasText && !rec)
                GestureDetector(onLongPress: widget.onSendLong, child: IconButton.filled(key: const Key('chatSend'), tooltip: l.chatSend, icon: const Icon(Icons.send_rounded), onPressed: widget.onSend))
              else if (widget.locked)
                IconButton.filled(key: const Key('recordSend'), tooltip: l.chatSend, iconSize: 26, icon: const Icon(Icons.send_rounded), onPressed: widget.onRecordEnd)
              else
                SizedBox(width: 52, height: 48, child: OverflowBox(maxWidth: 100, maxHeight: 100, child: mic)),
            ]),
          ),
          // the lock: slide the finger up onto it and the recording goes on by itself
          if (rec && !widget.locked)
            Positioned(
              right: 14,
              bottom: 72 - dy * 0.4,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: 1,
                child: Material(
                  elevation: 3,
                  color: scheme.surface,
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(dy < -_lockAt * 0.6 ? Icons.lock_rounded : Icons.lock_open_rounded, size: 20, color: scheme.primary),
                      Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: scheme.outline),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
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
    final ids = await showAppSheet<List<String>>(
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
        // a direct chat: the person's card (photo, status, phone, @username, «о себе», counts)
        if (_room.kind == 'DIRECT' && _room.peer != null)
          PersonProfileView(userId: _room.peer!.id, onOpenTab: _select)
        else
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
                        if (_room.canEditAdmins) chatMenuItem(context, m.isAdmin ? 'unadmin' : 'admin', m.isAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined, m.isAdmin ? l.chatRemoveAdmin : l.chatMakeAdmin),
                        if (_room.canManage && !_audienceChannel) chatMenuItem(context, 'remove', Icons.person_remove_outlined, l.chatRemoveMember, danger: true),
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
                              ? CachedNetworkImage(imageUrl: m.file!.thumbUrl ?? m.file!.url, cacheKey: fileCacheKey(m.file!.thumbUrl ?? m.file!.url), fit: BoxFit.cover)
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

/// Newest-first messages with photos / videos of one sender sent together (within 2 min, no caption) grouped.
List<Object> albumRows(List<ChatMessage> newestFirst) {
  final out = <Object>[];
  var cur = <ChatMessage>[];
  bool media(ChatMessage m) => !m.deleted && m.file != null && (m.kind == 'IMAGE' || m.kind == 'VIDEO');
  void flush() {
    if (cur.length > 1) { out.add(List<ChatMessage>.of(cur)); } else if (cur.length == 1) { out.add(cur.first); }
    cur = [];
  }
  for (final m in newestFirst) {
    final prev = cur.isEmpty ? null : cur.last;
    final joins = prev != null && media(m) && (m.text ?? '').isEmpty && (prev.text ?? '').isEmpty && prev.sender?.id == m.sender?.id &&
        prev.createdAt.difference(m.createdAt).inSeconds.abs() < 120 && cur.length < 10;
    if (joins) { cur.add(m); continue; }
    flush();
    if (media(m)) { cur = [m]; } else { out.add(m); }
  }
  flush();
  return out;
}

/// Photos / videos sent together: one grid, like Telegram's albums.
class _AlbumBubble extends StatelessWidget {
  const _AlbumBubble({required this.items, required this.mine, required this.onOpen, required this.onLongPress});
  final List<ChatMessage> items;
  final bool mine;
  final ValueChanged<ChatMessage> onOpen;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    final cols = items.length == 2 || items.length == 4 ? 2 : 3;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          width: 270,
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final m in items)
                  GestureDetector(
                    key: Key('album-${m.id}'),
                    onTap: () => onOpen(m),
                    child: Stack(fit: StackFit.expand, children: [
                      if (m.file?.thumbUrl != null || m.kind == 'IMAGE')
                        CachedNetworkImage(imageUrl: m.file!.thumbUrl ?? m.file!.url, cacheKey: fileCacheKey(m.file!.thumbUrl ?? m.file!.url), fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Colors.black87),
                      if (m.kind == 'VIDEO') const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «прочитано когда?» in the message menu (my own messages).
class _ReadInfo extends ConsumerWidget {
  const _ReadInfo({required this.message, required this.direct});
  final ChatMessage message;
  final bool direct;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return FutureBuilder<List<ChatPerson>>(
      future: ref.read(chatRepositoryProvider).reads(message.id),
      builder: (context, snap) {
        final items = snap.data;
        final text = items == null
            ? '…'
            : direct
                ? (items.isEmpty ? l.chatNotReadYet : l.chatReadAt(hm(items.first.readAt!)))
                : items.isEmpty
                    ? '${l.chatWhoRead}: ${l.chatNobodyYet}'
                    : '${l.chatWhoRead}: ${items.map((p) => '${p.fullName.split(' ').first} ${hm(p.readAt!)}').join(', ')}';
        return ListTile(key: const Key('readInfo'), dense: true, leading: Icon(Icons.done_all_rounded, color: Theme.of(context).colorScheme.primary), title: Text(text, maxLines: 3));
      },
    );
  }
}

/// A menu line with its icon on the left, like Telegram's (red for the destructive ones).
PopupMenuItem<String> chatMenuItem(BuildContext context, String value, IconData icon, String text, {bool danger = false}) {
  final color = danger ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant;
  return PopupMenuItem<String>(
    value: value,
    child: Row(children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(width: 16),
      Expanded(child: Text(text, style: danger ? TextStyle(color: color) : null)),
    ]),
  );
}
