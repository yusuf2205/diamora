import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'models.dart';
import 'permissions_screen.dart';
import 'team_repository.dart';
import 'team_screen.dart';

/// Card of one STAFF user: who they are, whether they are around, what they may do - and the few actions on them.
/// Every button is only a request: rank rules, "never yourself" and "one SUPER_ADMIN always stays" live on the server.
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(userDetailProvider(userId));
    return Scaffold(
      appBar: AppBar(title: Text(async.value?.user.fullName ?? l.teamEditUser)),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(userDetailProvider(userId)),
            child: _Body(detail: value),
          ),
        AsyncValue(:final error?) => EmptyState(
            icon: Icons.error_outline,
            title: errorText(context, error),
            action: FilledButton.tonal(onPressed: () => ref.invalidate(userDetailProvider(userId)), child: Text(l.retry)),
          ),
        _ => const SkeletonList(count: 4),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final UserDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(authControllerProvider).value;
    final u = detail.user;
    final isMe = me?.id == u.id;
    final canRole = (me?.has('ROLE_ASSIGN') ?? false) && !isMe;
    final canPerms = (me?.has('PERMISSION_MANAGE') ?? false) && !isMe && (u.role == 'ADMIN' || u.role == 'MANAGER');
    final canStatus = (me?.has('USER_DEACTIVATE') ?? false) && !isMe;
    final canEdit = me?.has('USER_UPDATE') ?? false;
    final canHistory = me?.has('AUDIT_VIEW') ?? false;
    final isSuper = me?.isSuperAdmin ?? false;
    final managerWorkers = u.role == 'MANAGER' ? ref.watch(managersProvider).value?.where((m) => m.user.id == u.id).firstOrNull?.assignedWorkers : null;

    Widget info(IconData icon, String label, String value, {VoidCallback? onTap}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: scheme.onSurfaceVariant),
          title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          onTap: onTap,
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        OnlineAvatar(name: u.fullName, online: u.online, radius: 34),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.fullName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              RoleBadge(role: u.role),
              Text(u.isActive ? l.teamStatusActive : l.teamStatusSuspended, style: TextStyle(color: u.isActive ? AppTokens.ok : scheme.error, fontWeight: FontWeight.w600)),
              Text(u.online ? l.onlineNow : l.offlineNow, style: TextStyle(color: scheme.outline)),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            info(Icons.phone_outlined, l.phone, u.phone, onTap: () => launchUrl(Uri.parse('tel:${u.phone}'))),
            info(Icons.schedule, l.lastSeenLabel, u.online ? l.onlineNow : seenLabel(l, u.seenAt)),
            if (u.createdAt != null) info(Icons.event_outlined, l.createdLabel, shortDate(u.createdAt!)),
            if (managerWorkers != null) info(Icons.groups_2_outlined, l.workersOfManager, '$managerWorkers'),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(children: [
          if (canRole)
            _ActionTile(icon: Icons.badge_outlined, title: l.changeRole, subtitle: teamRoleLabel(l, u.role), onTap: () => _changeRole(context, ref, u)),
          _ActionTile(
            icon: Icons.verified_user_outlined,
            title: l.permissionsTitle,
            subtitle: u.role == 'SUPER_ADMIN' ? l.permissionsAllSuper : l.permissionsCount(detail.effective.length, _editableCount(ref, u.role, detail)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PermissionsScreen(userId: u.id, editable: canPerms))),
          ),
          if (canEdit) _ActionTile(icon: Icons.edit_outlined, title: l.editDetails, onTap: () => _edit(context, ref, u)),
          if (isSuper && !isMe) _ActionTile(icon: Icons.password, title: l.setPassword, onTap: () => _setPassword(context, ref, u)),
          if (canEdit && !isMe) _ActionTile(icon: Icons.key_outlined, title: l.resetPassword, onTap: () => _resetPassword(context, ref, u)),
          if (isSuper)
            SwitchListTile(
              secondary: const Icon(Icons.location_on_outlined),
              title: Text(l.showOnMap),
              subtitle: Text(u.locationHidden ? l.hiddenOnMapHint : l.showOnMapHint),
              value: !u.locationHidden,
              onChanged: (v) => _run(context, ref, u, () => ref.read(teamRepositoryProvider).setLocationHidden(u.id, !v), l.teamSaved),
            ),
          if (canHistory) _ActionTile(icon: Icons.history, title: l.history, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _UserHistoryScreen(user: u)))),
        ]),
      ),
      if (canStatus) ...[
        const SizedBox(height: 16),
        u.isActive
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size.fromHeight(AppTokens.buttonHeight)),
                icon: const Icon(Icons.block),
                onPressed: () => _setActive(context, ref, u, false),
                label: Text(l.deactivateUser),
              )
            : FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppTokens.buttonHeight)),
                icon: const Icon(Icons.restore),
                onPressed: () => _setActive(context, ref, u, true),
                label: Text(l.restoreUser),
              ),
      ],
    ]);
  }

  int _editableCount(WidgetRef ref, String role, UserDetail d) =>
      ref.watch(permissionCatalogProvider).value?.editableFor(role).length ?? {...d.defaults, ...d.effective}.length;

  Future<void> _changeRole(BuildContext context, WidgetRef ref, TeamUser u) async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        var role = u.role;
        return StatefulBuilder(
          builder: (ctx, set) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.changeRole, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l.changeRoleHint, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                for (final r in const ['SUPER_ADMIN', 'ADMIN', 'MANAGER']) RoleOption(role: r, selected: role == r, onTap: () => set(() => role = r)),
                const SizedBox(height: 8),
                SizedBox(
                  height: AppTokens.buttonHeight,
                  child: FilledButton(onPressed: role == u.role ? null : () => Navigator.pop(ctx, role), child: Text(l.save)),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final ok = await _confirm(context, l.teamConfirmRoleChange(teamRoleLabel(l, u.role), teamRoleLabel(l, picked)), l.changeRoleHint);
    if (!ok || !context.mounted) return;
    await _run(context, ref, u, () => ref.read(teamRepositoryProvider).changeRole(u.id, picked), l.teamRoleChanged);
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, TeamUser u, bool active) async {
    final l = AppLocalizations.of(context);
    if (!active && !await _confirm(context, l.deactivateUser, l.deactivateConfirm(u.fullName), danger: true)) return;
    if (!context.mounted) return;
    await _run(context, ref, u, () => ref.read(teamRepositoryProvider).setStatus(u.id, active), active ? l.userRestored : l.userDeactivated);
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, TeamUser u) async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(context, l.resetPassword, l.resetPasswordConfirm)) return;
    try {
      final pwd = await ref.read(teamRepositoryProvider).resetPassword(u.id);
      if (context.mounted) await showTemporaryPassword(context, pwd);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _setPassword(BuildContext context, WidgetRef ref, TeamUser u) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.setPassword),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.setPasswordHint),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: l.newPassword, helperText: l.passwordTooShort)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () { if (ctrl.text.length >= 8) Navigator.pop(ctx, ctrl.text); }, child: Text(l.save)),
        ],
      ),
    );
    if (pwd == null || !context.mounted) return;
    await _run(context, ref, u, () => ref.read(teamRepositoryProvider).setPassword(u.id, pwd), l.passwordSet);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, TeamUser u) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _EditDetailsSheet(user: u),
      );

  Future<void> _run(BuildContext context, WidgetRef ref, TeamUser u, Future<Object?> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(userDetailProvider(u.id));
      ref.invalidate(teamUsersProvider);
      ref.invalidate(managersProvider);
      if (context.mounted) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

Future<bool> _confirm(BuildContext context, String title, String body, {bool danger = false}) async {
  final l = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.confirm),
            ),
          ],
        ),
      ) ??
      false;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

class _EditDetailsSheet extends ConsumerStatefulWidget {
  const _EditDetailsSheet({required this.user});
  final TeamUser user;
  @override
  ConsumerState<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends ConsumerState<_EditDetailsSheet> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  var _busy = false;

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
      ref.invalidate(userDetailProvider(widget.user.id));
      ref.invalidate(teamUsersProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.teamSaved)));
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.editDetails, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _name, enabled: !_busy, decoration: InputDecoration(labelText: l.teamFullName)),
          const SizedBox(height: 12),
          TextField(controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.phone)),
          const SizedBox(height: 20),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.teamSaveChanges)),
          ),
        ]),
      ),
    );
  }
}

String auditActionLabel(AppLocalizations l, String action) => switch (action) {
      'user.create' => l.auditUserCreate,
      'user.update' => l.auditUserUpdate,
      'user.deactivate' => l.auditUserDeactivate,
      'user.reactivate' => l.auditUserReactivate,
      'user.role_change' => l.auditUserRoleChange,
      'user.permission_change' => l.auditUserPermissionChange,
      'user.password_reset' => l.auditUserPasswordReset,
      _ => action,
    };

class _UserHistoryScreen extends ConsumerWidget {
  const _UserHistoryScreen({required this.user});
  final TeamUser user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(userAuditProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text('${l.history} · ${user.fullName}')),
      body: switch (async) {
        AsyncValue(:final value?) => value.isEmpty
            ? EmptyState(icon: Icons.history, title: l.historyEmpty)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = value[i];
                  final at = DateTime.tryParse(e.createdAt)?.toLocal();
                  return ListTile(
                    leading: const Icon(Icons.circle, size: 10),
                    title: Text(auditActionLabel(l, e.action)),
                    subtitle: Text([
                      if (at != null) '${shortDate(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                      if (e.actorRole != null) teamRoleLabel(l, e.actorRole!),
                    ].join(' · ')),
                  );
                },
              ),
        AsyncValue(:final error?) => EmptyState(icon: Icons.error_outline, title: errorText(context, error)),
        _ => const SkeletonList(count: 5),
      },
    );
  }
}
