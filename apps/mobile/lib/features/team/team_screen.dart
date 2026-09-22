import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
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
