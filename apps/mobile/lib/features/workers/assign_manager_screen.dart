import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../team/team_repository.dart';
import 'models.dart';
import 'workers_providers.dart';

/// «Назначить менеджера»: choose a manager, tick the workers, save — one request for all. Her whole scope (lists, map,
/// QR, notifications) moves on the server at once. Opens pre-ticked with the workers this manager already has.
class AssignManagerScreen extends ConsumerStatefulWidget {
  const AssignManagerScreen({super.key, this.managerId});
  final String? managerId;
  @override
  ConsumerState<AssignManagerScreen> createState() => _AssignManagerScreenState();
}

class _AssignManagerScreenState extends ConsumerState<AssignManagerScreen> {
  late String? _managerId = widget.managerId;
  String _query = '';
  Set<String>? _picked;
  bool _busy = false;

  static const _assignable = {'ACTIVE', 'PAUSED', 'PENDING_APPROVAL'};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final managers = ref.watch(managersProvider).value?.where((m) => m.user.isActive).toList() ?? const [];
    final all = (ref.watch(workersListProvider(WorkersFilter(query: _query))).value ?? const <Worker>[]).where((w) => _assignable.contains(w.status)).toList();
    // start from «who is already hers» once the list has loaded (it streams in from the local cache / the server)
    if (_picked == null && all.isNotEmpty) _picked = {for (final w in all) if (_managerId != null && w.managerId == _managerId) w.id};
    final picked = _picked ?? <String>{};
    final changed = all.where((w) => picked.contains(w.id) && w.managerId != _managerId).map((w) => w.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.assignManagerTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DropdownButtonFormField<String?>(
            key: const Key('assignManagerPick'),
            initialValue: _managerId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.managerLabel),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.noManager)),
              for (final m in managers) DropdownMenuItem<String?>(value: m.user.id, child: Text('${m.user.fullName} · ${m.assignedWorkers}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _managerId = v;
              _picked = null; // start from «who is already hers»
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBar(hintText: l.search, leading: const Icon(Icons.search_rounded), elevation: const WidgetStatePropertyAll(0), onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: all.isEmpty
              ? EmptyState(icon: Icons.groups_2_rounded, title: l.usersEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: all.length,
                  itemBuilder: (_, i) {
                    final w = all[i];
                    return CheckboxListTile(
                      key: Key('assign-${w.id}'),
                      value: picked.contains(w.id),
                      onChanged: (v) => setState(() => v == true ? (_picked ??= {}).add(w.id) : _picked?.remove(w.id)),
                      title: Text(w.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${w.code} · ${w.managerName ?? l.noManager}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          key: const Key('assignManagerSave'),
          onPressed: _busy || changed.isEmpty ? null : () => _save(changed),
          child: Text(changed.isEmpty ? l.assignManagerSave : '${l.assignManagerSave} (${changed.length})'),
        ),
      ),
    );
  }

  Future<void> _save(List<String> ids) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(workerRepositoryProvider).assignManagerBulk(ids, _managerId);
      ref.invalidate(managersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.assignManagerDone(ids.length))));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
