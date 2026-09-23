import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/models.dart';
import 'models.dart';
import 'team_repository.dart';

const _staffRoles = ['SUPER_ADMIN', 'ADMIN', 'MANAGER'];

/// SUPER_ADMIN / ADMIN "Команда" (§4-6, §34): users, roles, managers. Every action is server-confirmed and audited.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    if (me == null || !me.has('USER_VIEW_ALL')) {
      return Scaffold(appBar: AppBar(title: Text(l.team)), body: EmptyState(icon: Icons.lock_outline, title: l.teamNoAccess));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.team), bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.teamUsers), Tab(text: l.teamManagers)])),
      floatingActionButton: me.has('USER_CREATE') ? FloatingActionButton.extended(onPressed: () => _createUser(context), icon: const Icon(Icons.person_add_alt), label: Text(l.teamAddUser)) : null,
      body: TabBarView(controller: _tabs, children: const [_UsersTab(), _ManagersTab()]),
    );
  }

  Future<void> _createUser(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final phone = TextEditingController();
    final name = TextEditingController();
    var role = 'MANAGER';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) => AlertDialog(
          title: Text(l.teamAddUser),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: l.teamFullName)),
            const SizedBox(height: 8),
            TextField(controller: phone, decoration: InputDecoration(labelText: l.phone), keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: InputDecoration(labelText: l.teamRole),
              items: [for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(teamRoleLabel(l, r)))],
              onChanged: (v) => setState(() => role = v ?? role),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final res = await ref.read(teamRepositoryProvider).createUser(phone: phone.text.trim(), fullName: name.text.trim(), role: role);
      ref.invalidate(teamUsersProvider);
      ref.invalidate(managersProvider);
      final pwd = res['temporaryPassword'] as String?;
      if (pwd != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l.teamCreated),
            content: SelectableText(pwd, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.confirm))],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

String teamRoleLabel(AppLocalizations l, String role) => switch (role) {
      'SUPER_ADMIN' => l.roleSuperAdmin,
      'ADMIN' => l.roleAdmin,
      'MANAGER' => l.roleManager,
      _ => l.roleWorker,
    };

class _UsersTab extends ConsumerWidget {
  const _UsersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final users = ref.watch(teamUsersProvider);
    final me = ref.watch(authControllerProvider).value;
    return users.when(
      loading: () => const SkeletonList(count: 6),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(teamUsersProvider),
        child: ListView.separated(
          padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final u = list[i];
            final canDeactivate = (me?.has('USER_DEACTIVATE') ?? false) && u.id != me?.id;
            return Card(
              child: ListTile(
                onTap: () => _editUser(context, ref, u, me),
                leading: CircleAvatar(child: Text(initials(u.fullName))),
                title: Text(u.fullName),
                subtitle: Text('${u.phone} · ${teamRoleLabel(l, u.role)}${u.online ? ' · ${l.onlineNow}' : ''}'),
                trailing: canDeactivate
                    ? Switch(
                        value: u.isActive,
                        onChanged: (v) async {
                          try {
                            await ref.read(teamRepositoryProvider).setStatus(u.id, v);
                            ref.invalidate(teamUsersProvider);
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                      )
                    : Text(u.isActive ? l.teamStatusActive : l.teamStatusSuspended),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Open a user: edit name/phone, change role (with a confirm dialog), or flip status — all server-confirmed, all
/// respecting the SAME rank rules the API enforces regardless of what this sheet chooses to show (§29-30, §33).
Future<void> _editUser(BuildContext context, WidgetRef ref, TeamUser u, Session? me) async {
  final canEdit = me?.has('USER_UPDATE') ?? false;
  final canAssignRole = (me?.has('ROLE_ASSIGN') ?? false) && u.id != me?.id;
  final canDeactivate = (me?.has('USER_DEACTIVATE') ?? false) && u.id != me?.id;
  if (!canEdit && !canAssignRole && !canDeactivate) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _EditUserSheet(user: u, canEdit: canEdit, canAssignRole: canAssignRole, canDeactivate: canDeactivate),
  );
}

class _EditUserSheet extends ConsumerStatefulWidget {
  const _EditUserSheet({required this.user, required this.canEdit, required this.canAssignRole, required this.canDeactivate});
  final TeamUser user;
  final bool canEdit;
  final bool canAssignRole;
  final bool canDeactivate;
  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  late String _role = widget.user.role;
  late bool _active = widget.user.isActive;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).updateUser(widget.user.id, fullName: _name.text.trim(), phone: _phone.text.trim());
      ref.invalidate(teamUsersProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.teamSaved)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'CONFLICT') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.teamPhoneTaken), backgroundColor: Theme.of(context).colorScheme.error));
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(String newRole) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.teamConfirmRoleChange(teamRoleLabel(l, widget.user.role), teamRoleLabel(l, newRole))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).changeRole(widget.user.id, newRole);
      ref.invalidate(teamUsersProvider);
      if (!mounted) return;
      setState(() => _role = newRole);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.teamRoleChanged)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleStatus(bool active) async {
    try {
      await ref.read(teamRepositoryProvider).setStatus(widget.user.id, active);
      ref.invalidate(teamUsersProvider);
      if (mounted) setState(() => _active = active);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.teamEditUser, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _name, enabled: widget.canEdit && !_busy, decoration: InputDecoration(labelText: l.teamFullName)),
          const SizedBox(height: 12),
          TextField(controller: _phone, enabled: widget.canEdit && !_busy, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.phone)),
          const SizedBox(height: 12),
          if (widget.canAssignRole)
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: InputDecoration(labelText: l.teamRole),
              items: [for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(teamRoleLabel(l, r)))],
              onChanged: _busy ? null : (v) { if (v != null && v != _role) _changeRole(v); },
            )
          else
            ListTile(contentPadding: EdgeInsets.zero, title: Text(l.teamRole), trailing: Text(teamRoleLabel(l, _role))),
          if (widget.canDeactivate) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_active ? l.teamStatusActive : l.teamStatusSuspended),
              value: _active,
              onChanged: _busy ? null : _toggleStatus,
            ),
          ],
          const SizedBox(height: 20),
          if (widget.canEdit)
            SizedBox(
              width: double.infinity,
              child: _busy ? const Center(child: CircularProgressIndicator()) : FilledButton(onPressed: _save, child: Text(l.teamSaveChanges)),
            ),
        ]),
      ),
    );
  }
}

class _ManagersTab extends ConsumerWidget {
  const _ManagersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final managers = ref.watch(managersProvider);
    return managers.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (list) => list.isEmpty
          ? EmptyState(icon: Icons.groups_2_outlined, title: l.emptyWorkers)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(managersProvider),
              child: ListView.separated(
                padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(initials(m.user.fullName))),
                      title: Text(m.user.fullName),
                      subtitle: Text('${m.user.phone}${m.user.online ? ' · ${l.onlineNow}' : ''}'),
                      trailing: Text(l.teamAssignedWorkers(m.assignedWorkers)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
