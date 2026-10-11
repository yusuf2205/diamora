import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'chat_list_screen.dart' show chatPreview, chatWhen;
import 'chat_models.dart';

/// One conversation in «Все переписки».
class WatchRoom {
  WatchRoom({required this.id, required this.kind, this.title, required this.memberCount, required this.messageCount, this.lastMessage, required this.lastMessageAt});
  final String id;
  final String kind;
  final String? title;
  final int memberCount;
  final int messageCount;
  final ChatMessage? lastMessage;
  final DateTime lastMessageAt;
  factory WatchRoom.fromJson(Map<String, dynamic> j) => WatchRoom(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String?,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        messageCount: (j['messageCount'] as num?)?.toInt() ?? 0,
        lastMessage: j['lastMessage'] == null ? null : ChatMessage.fromJson((j['lastMessage'] as Map).cast<String, dynamic>()),
        lastMessageAt: DateTime.parse(j['lastMessageAt'] as String).toLocal(),
      );
}

/// Every conversation of the company, newest first; refreshed live (her socket hears every chat).
final watchRoomsProvider = FutureProvider.autoDispose.family<List<WatchRoom>, String>((ref, q) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t == 'chat.message' || t == 'chat.message_deleted' || t == 'chat.room') ref.invalidateSelf();
  });
  final j = await ref.watch(apiClientProvider).getJson('/chat/watch/rooms', query: q.isEmpty ? null : {'q': q});
  return ((j['items'] as List?) ?? const []).map((x) => WatchRoom.fromJson((x as Map).cast<String, dynamic>())).toList();
});

/// «Все переписки» (SUPER_ADMIN, owner 2026-10-11): who writes what to whom. Opening one reads it without joining - the
/// people there see nothing (no «прочитано», no member); she can delete a message, not write.
class ChatWatchScreen extends ConsumerStatefulWidget {
  const ChatWatchScreen({super.key});
  @override
  ConsumerState<ChatWatchScreen> createState() => _ChatWatchScreenState();
}

class _ChatWatchScreenState extends ConsumerState<ChatWatchScreen> {
  String _q = '';
  String _kind = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rooms = ref.watch(watchRoomsProvider(_q));
    final scheme = Theme.of(context).colorScheme;
    String kindLabel(String k) => switch (k) { 'DIRECT' => l.chatWatchDirect, 'GROUP' => l.chatWatchGroup, 'CHANNEL' => l.chatWatchChannel, _ => l.chatCompany };
    return Scaffold(
      appBar: AppBar(title: Text(l.chatWatchTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            key: const Key('watchSearch'),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.chatWatchSearch, isDense: true),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () { if (mounted && _q != v.trim()) setState(() => _q = v.trim()); });
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
            for (final (k, label) in [('', l.chatFolderAll), ('DIRECT', l.chatWatchDirect), ('GROUP', l.chatWatchGroups)])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(label), selected: _kind == k, showCheckmark: false, onSelected: (_) => setState(() => _kind = k)),
              ),
          ]),
        ),
        Expanded(
          child: rooms.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorText(context, e), textAlign: TextAlign.center))),
            data: (all) {
              final items = all.where((r) => _kind.isEmpty || r.kind == _kind || (_kind == 'GROUP' && r.kind != 'DIRECT')).toList();
              if (items.isEmpty) return Center(child: Text(l.chatWatchEmpty, style: TextStyle(color: scheme.outline)));
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(watchRoomsProvider(_q)),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final r = items[i];
                    final title = r.kind == 'COMPANY' ? l.chatCompany : (r.title ?? '—');
                    final last = r.lastMessage;
                    return ListTile(
                      key: Key('watch-${r.id}'),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(switch (r.kind) { 'DIRECT' => Icons.people_alt_rounded, 'CHANNEL' => Icons.campaign_rounded, 'COMPANY' => Icons.apartment_rounded, _ => Icons.groups_rounded }, color: scheme.onPrimaryContainer),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Text(chatWhen(l, r.lastMessageAt), style: TextStyle(fontSize: 12, color: scheme.outline)),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(last == null ? '—' : '${last.sender?.fullName.split(' ').first ?? ''}${last.sender == null ? '' : ': '}${chatPreview(l, last)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${kindLabel(r.kind)} · ${l.chatWatchMessages(r.messageCount)}', style: TextStyle(fontSize: 11, color: scheme.outline)),
                      ]),
                      onTap: () => context.push('/chat/${r.id}'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
