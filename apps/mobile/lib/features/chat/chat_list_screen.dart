import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'chat_models.dart';
import 'chat_repository.dart';

/// Short time for a list row: 14:05 today, «Вчера», otherwise 28.09.
String chatWhen(AppLocalizations l, DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  String two(int v) => v.toString().padLeft(2, '0');
  if (day == today) return '${two(t.hour)}:${two(t.minute)}';
  if (day == today.subtract(const Duration(days: 1))) return l.chatYesterday;
  return '${two(t.day)}.${two(t.month)}';
}

/// One line of what the last message was: text, or «📷 Фото» etc.
String chatPreview(AppLocalizations l, ChatMessage m) {
  if (m.deleted) return l.chatMessageDeleted;
  final label = switch (m.kind) {
    'IMAGE' => '📷 ${l.chatPhoto}',
    'VIDEO' => '🎬 ${l.chatVideo}',
    'VOICE' => '🎤 ${l.chatVoice}',
    'AUDIO' => '🎵 ${l.chatAudio}',
    'FILE' => '📎 ${m.file?.name ?? l.chatFile}',
    _ => null,
  };
  final text = (m.text ?? '').trim();
  if (label == null) return text;
  return text.isEmpty ? label : '$label · $text';
}

String chatTitle(AppLocalizations l, {required String kind, String? title}) => kind == 'COMPANY' ? l.chatCompany : (title ?? '');

/// «Чат»: my pinned chats, the company chat, then every conversation (newest first) with unread counts; search on top.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _searching = false;
  final _q = TextEditingController();
  Timer? _debounce;
  Future<ChatSearchResult>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _closeSearch() => setState(() { _searching = false; _q.clear(); _results = null; });

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next = v.trim().length < 2 ? null : ref.read(chatRepositoryProvider).search(v.trim());
      setState(() { _results = next; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rooms = ref.watch(chatRoomsProvider);
    final me = ref.watch(authControllerProvider).value;
    if (_searching) return _searchScaffold(context, l);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chat),
        actions: [IconButton(key: const Key('chatSearch'), tooltip: l.chatSearch, icon: const Icon(Icons.search_rounded), onPressed: () => setState(() => _searching = true))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('chatNew'),
        onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true, builder: (_) => const NewChatSheet()),
        icon: const Icon(Icons.edit_rounded),
        label: Text(l.chatNew),
      ),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.forum_rounded, title: l.chatNoChats)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(chatRoomsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, i) => _RoomTile(room: items[i], meId: me?.id, onLongPress: () => _roomMenu(items[i])),
                ),
              ),
      ),
    );
  }
}

extension on _ChatListScreenState {
  Future<void> _roomMenu(ChatRoomSummary room) async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(key: const Key('roomPin'), leading: Icon(room.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded), title: Text(room.pinned ? l.chatUnpinChat : l.chatPinChat), onTap: () => Navigator.pop(ctx, 'pin')),
          ListTile(key: const Key('roomMute'), leading: Icon(room.muted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded), title: Text(room.muted ? l.chatUnmute : l.chatMute), onTap: () => Navigator.pop(ctx, 'mute')),
        ]),
      ),
    );
    if (choice == null) return;
    try {
      await ref.read(chatRepositoryProvider).prefs(room.id, pinned: choice == 'pin' ? !room.pinned : null, muted: choice == 'mute' ? !room.muted : null);
      ref.invalidate(chatRoomsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Widget _searchScaffold(BuildContext context, AppLocalizations l) {
    final header = Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _closeSearch),
        title: TextField(key: const Key('chatSearchField'), controller: _q, autofocus: true, decoration: InputDecoration(hintText: l.chatSearchHint, border: InputBorder.none, filled: false), onChanged: _onQuery),
      ),
      body: _results == null
          ? const SizedBox.shrink()
          : FutureBuilder<ChatSearchResult>(
              future: _results,
              builder: (context, snap) {
                if (snap.hasError) return EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, snap.error!));
                final r = snap.data;
                if (r == null) return const Center(child: CircularProgressIndicator());
                if (r.rooms.isEmpty && r.people.isEmpty && r.messages.isEmpty) return EmptyState(icon: Icons.search_off_rounded, title: l.chatNothingFound);
                return ListView(children: [
                  if (r.rooms.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(l.chatSectionChats, style: header)),
                  for (final room in r.rooms)
                    ListTile(
                      leading: ChatAvatar(kind: room.kind, name: chatTitle(l, kind: room.kind, title: room.title), radius: 20),
                      title: Text(chatTitle(l, kind: room.kind, title: room.title)),
                      onTap: () => context.push('/chat/${room.id}'),
                    ),
                  if (r.people.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(l.chatSectionPeople, style: header)),
                  for (final p in r.people)
                    ListTile(
                      key: Key('found-person-${p.id}'),
                      leading: ChatAvatar(kind: 'DIRECT', name: p.fullName, online: p.online, radius: 20),
                      title: Text(p.fullName),
                      subtitle: Text(teamRoleLabel(l, p.role)),
                      onTap: () async {
                        final router = GoRouter.of(context);
                        final room = await ref.read(chatRepositoryProvider).direct(p.id);
                        router.push('/chat/${room.id}');
                      },
                    ),
                  if (r.messages.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(l.chatSectionMessages, style: header)),
                  for (final h in r.messages)
                    ListTile(
                      key: Key('found-msg-${h.message.id}'),
                      leading: ChatAvatar(kind: h.roomKind, name: chatTitle(l, kind: h.roomKind, title: h.roomTitle), radius: 20),
                      title: Text(chatTitle(l, kind: h.roomKind, title: h.roomTitle), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${h.message.sender?.fullName.split(' ').first ?? ''}: ${chatPreview(l, h.message)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(chatWhen(l, h.message.createdAt), style: Theme.of(context).textTheme.bodySmall),
                      onTap: () => context.push('/chat/${h.roomId}'),
                    ),
                ]);
              },
            ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.meId, this.onLongPress});
  final ChatRoomSummary room;
  final String? meId;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = chatTitle(l, kind: room.kind, title: room.title);
    final last = room.lastMessage;
    final who = last == null || room.kind == 'DIRECT' ? '' : last.sender?.id == meId ? '${l.chatYou}: ' : last.sender == null ? '' : '${last.sender!.fullName.split(' ').first}: ';
    final subtitle = last == null ? (room.kind == 'COMPANY' ? l.chatCompanyHint : l.chatMembers(room.memberCount)) : '$who${chatPreview(l, last)}';
    return ListTile(
      key: Key('room-${room.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ChatAvatar(kind: room.kind, name: title, online: room.peer?.online ?? false),
      title: Row(children: [
        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: room.unread > 0 ? FontWeight.w700 : FontWeight.w600))),
        if (room.muted) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.notifications_off_rounded, size: 15, color: scheme.outline)),
      ]),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (last != null) Text(chatWhen(l, last.createdAt), style: TextStyle(fontSize: 12, color: room.unread > 0 ? scheme.primary : scheme.outline)),
        const SizedBox(height: 4),
        if (room.unread == 0 && room.pinned) Icon(Icons.push_pin_rounded, size: 16, color: scheme.outline),
        if (room.unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: room.muted ? scheme.outline : scheme.primary, borderRadius: BorderRadius.circular(10)),
            child: Text('${room.unread}', style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
      onTap: () => context.push('/chat/${room.id}'),
      onLongPress: onLongPress,
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.kind, required this.name, this.online = false, this.radius = 24});
  final String kind;
  final String name;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: kind == 'COMPANY' ? scheme.primary : kind == 'GROUP' ? scheme.tertiaryContainer : scheme.primaryContainer,
      foregroundColor: kind == 'COMPANY' ? scheme.onPrimary : kind == 'GROUP' ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
      child: kind == 'COMPANY'
          ? Icon(Icons.diamond_rounded, size: radius)
          : kind == 'GROUP'
              ? Icon(Icons.groups_rounded, size: radius)
              : Text(initials(name), style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.6)),
    );
    if (!online) return avatar;
    return Stack(children: [
      avatar,
      Positioned(right: 0, bottom: 0, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: const Color(0xFF16A34A), shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)))),
    ]);
  }
}

/// «Новый чат»: pick one person (a direct chat opens at once) or build a group.
class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key, this.pickOnly = false, this.exclude = const {}});
  /// «Добавить участников» of an existing group: only returns the ticked people.
  final bool pickOnly;
  final Set<String> exclude;
  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  final _q = TextEditingController();
  final _title = TextEditingController();
  late bool _group = widget.pickOnly;
  final _picked = <String>{};
  List<ChatPerson>? _people;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(chatRepositoryProvider).contacts(_q.text);
      if (mounted) setState(() => _people = p.where((x) => !widget.exclude.contains(x.id)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    }
  }

  Future<void> _openDirect(ChatPerson p) async {
    setState(() => _busy = true);
    try {
      final room = await ref.read(chatRepositoryProvider).direct(p.id);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/chat/${room.id}');
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = errorText(context, e); });
    }
  }

  Future<void> _createGroup() async {
    if (_title.text.trim().isEmpty || _picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final room = await ref.read(chatRepositoryProvider).createGroup(_title.text.trim(), _picked.toList());
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/chat/${room.id}');
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = errorText(context, e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = _people;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: Text(widget.pickOnly ? l.chatAddMembers : _group ? l.chatNewGroup : l.chatNew, style: Theme.of(context).textTheme.titleLarge)),
              if (!widget.pickOnly)
                TextButton.icon(
                  key: const Key('chatToggleGroup'),
                  onPressed: () => setState(() { _group = !_group; _picked.clear(); }),
                  icon: Icon(_group ? Icons.person_rounded : Icons.group_add_rounded),
                  label: Text(_group ? l.chatNew : l.chatNewGroup),
                ),
            ]),
          ),
          if (_group && !widget.pickOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(key: const Key('chatGroupName'), controller: _title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l.chatGroupName), onChanged: (_) => setState(() {})),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _q,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.chatSearchPeople),
              onChanged: (_) => _load(),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(
            child: people == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final p = people[i];
                      final avatar = ChatAvatar(kind: 'DIRECT', name: p.fullName, online: p.online, radius: 20);
                      final role = Text(teamRoleLabel(l, p.role));
                      if (!_group) {
                        return ListTile(key: Key('contact-${p.id}'), leading: avatar, title: Text(p.fullName), subtitle: role, enabled: !_busy, onTap: () => _openDirect(p));
                      }
                      return CheckboxListTile(
                        key: Key('contact-${p.id}'),
                        secondary: avatar,
                        title: Text(p.fullName),
                        subtitle: role,
                        value: _picked.contains(p.id),
                        onChanged: (v) => setState(() => v == true ? _picked.add(p.id) : _picked.remove(p.id)),
                      );
                    },
                  ),
          ),
          if (_group)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: const Key('chatCreateGroup'),
                  onPressed: _busy || _picked.isEmpty || (!widget.pickOnly && _title.text.trim().isEmpty)
                      ? null
                      : widget.pickOnly
                          ? () => Navigator.of(context).pop(_picked.toList())
                          : _createGroup,
                  child: Text(widget.pickOnly ? '${l.chatAddMembers} (${_picked.length})' : '${l.chatCreate} (${_picked.length})'),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
