import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'chat_list_screen.dart' show chatTitle;
import 'chat_models.dart';

/// «Папки» like Telegram (owner, 2026-10-11): tabs over the chat list - «Все», then folders the person makes from her
/// chats (kept on this phone). A long press on a folder edits or deletes it.
class ChatFolder {
  ChatFolder({required this.id, required this.name, required this.roomIds});
  final String id;
  String name;
  Set<String> roomIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'roomIds': roomIds.toList()};
  factory ChatFolder.fromJson(Map<String, dynamic> j) => ChatFolder(id: j['id'] as String, name: j['name'] as String, roomIds: ((j['roomIds'] as List?) ?? const []).cast<String>().toSet());
}

class ChatFoldersController extends Notifier<List<ChatFolder>> {
  static const _key = 'chat_folders';
  @override
  List<ChatFolder> build() {
    try {
      final raw = ref.read(sharedPrefsProvider).getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map>().map((x) => ChatFolder.fromJson(x.cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<ChatFolder> next) async {
    state = next;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(next.map((f) => f.toJson()).toList()));
  }

  Future<void> put(ChatFolder f) => _save([...state.where((x) => x.id != f.id), f]..sort((a, b) => state.indexWhere((x) => x.id == a.id).compareTo(state.indexWhere((x) => x.id == b.id))));
  Future<void> remove(String id) => _save(state.where((x) => x.id != id).toList());
}

final chatFoldersProvider = NotifierProvider<ChatFoldersController, List<ChatFolder>>(ChatFoldersController.new);

/// The tabs: «Все» · folders · «+»
class ChatFolderBar extends ConsumerWidget {
  const ChatFolderBar({super.key, required this.selected, required this.onSelect, required this.rooms});
  final String? selected;
  final ValueChanged<String?> onSelect;
  final List<ChatRoomSummary> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final folders = ref.watch(chatFoldersProvider);
    if (folders.isEmpty) return const SizedBox.shrink(); // no tabs until there is a folder (a small screen keeps its room)
    int unreadIn(Set<String> ids) => rooms.where((r) => ids.contains(r.id)).fold(0, (n, r) => n + r.unread);
    Widget chip(String? id, String label, int unread, {VoidCallback? onLong}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onLongPress: onLong,
            child: ChoiceChip(
              key: Key('folder-${id ?? 'all'}'),
              label: Text(unread > 0 ? '$label  $unread' : label),
              selected: selected == id,
              showCheckmark: false,
              onSelected: (_) => onSelect(id),
            ),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
        chip(null, l.chatFolderAll, 0),
        for (final f in folders) chip(f.id, f.name, unreadIn(f.roomIds), onLong: () => showFolderEditor(context, ref, rooms, folder: f)),
        ActionChip(key: const Key('folderAdd'), avatar: const Icon(Icons.add_rounded, size: 18), label: Text(l.chatFolderNew), onPressed: () => showFolderEditor(context, ref, rooms)),
      ]),
    );
  }
}

/// a new folder, or one to rename / change / delete
Future<void> showFolderEditor(BuildContext context, WidgetRef ref, List<ChatRoomSummary> rooms, {ChatFolder? folder, String? withRoom}) {
  final l = AppLocalizations.of(context);
  final name = TextEditingController(text: folder?.name ?? '');
  final picked = {...?folder?.roomIds, ?withRoom};
  return showAppSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 12),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.7,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(folder == null ? l.chatFolderNew : l.chatFolderEdit, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(key: const Key('folderName'), controller: name, autofocus: folder == null, maxLength: 24, decoration: InputDecoration(labelText: l.chatFolderName, hintText: l.chatFolderNameHint)),
              Text(l.chatFolderChats, style: Theme.of(ctx).textTheme.labelLarge),
              Expanded(
                child: ListView(children: [
                  for (final r in rooms)
                    CheckboxListTile(
                      key: Key('folderRoom-${r.id}'),
                      dense: true,
                      value: picked.contains(r.id),
                      onChanged: (v) => set(() => v == true ? picked.add(r.id) : picked.remove(r.id)),
                      title: Text(chatTitle(l, kind: r.kind, title: r.title), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
              Row(children: [
                if (folder != null)
                  TextButton(
                    onPressed: () async { await ref.read(chatFoldersProvider.notifier).remove(folder.id); if (ctx.mounted) Navigator.pop(ctx); },
                    child: Text(l.deleteAction, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('folderSave'),
                  style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                  onPressed: () async {
                    if (name.text.trim().isEmpty || picked.isEmpty) return;
                    await ref.read(chatFoldersProvider.notifier).put(ChatFolder(id: folder?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), roomIds: picked));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(l.save),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}
