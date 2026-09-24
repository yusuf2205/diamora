import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'models.dart';
import 'team_repository.dart';

String teamRoleLabel(AppLocalizations l, String role) => switch (role) {
      'SUPER_ADMIN' => l.roleSuperAdmin,
      'ADMIN' => l.roleAdmin,
      'MANAGER' => l.roleManager,
      _ => l.roleWorker,
    };

Color roleColor(ColorScheme s, String role) => switch (role) {
      'SUPER_ADMIN' => s.primary,
      'ADMIN' => s.tertiary,
      'MANAGER' => s.secondary,
      _ => s.outline,
    };

String shortDate(DateTime d) {
  final x = d.toLocal();
  return '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
}

/// "5 мин назад" / "сегодня 14:05" / "12.09.2026" - how long ago somebody was around, in plain words.
String seenLabel(AppLocalizations l, DateTime? at) {
  if (at == null) return l.neverSeen;
  final x = at.toLocal();
  final ago = DateTime.now().difference(x);
  if (ago.inMinutes < 1) return l.locationJustNow;
  if (ago.inMinutes < 60) return l.locationRecentMinutes(ago.inMinutes);
  final now = DateTime.now();
  if (x.year == now.year && x.month == now.month && x.day == now.day) return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  return shortDate(x);
}

/// A filter chip: one role, or a status. Exactly one is active at a time - simple beats clever here.
enum _Filter { all, superAdmin, admin, manager, worker, active, disabled }

UsersFilter _toQuery(_Filter f, String q) => switch (f) {
      _Filter.all => UsersFilter(query: q),
      _Filter.superAdmin => UsersFilter(role: 'SUPER_ADMIN', query: q),
      _Filter.admin => UsersFilter(role: 'ADMIN', query: q),
      _Filter.manager => UsersFilter(role: 'MANAGER', query: q),
      _Filter.worker => UsersFilter(role: 'WORKER', query: q),
      _Filter.active => UsersFilter(status: 'ACTIVE', query: q),
      _Filter.disabled => UsersFilter(status: 'SUSPENDED', query: q),
    };

/// «Команда»: everybody with an account - staff and workers - searchable and filterable. Tapping a staff member opens their
/// card (role, rights, disable/restore, history); tapping a worker opens her worker card. Every rule is enforced by the API.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  var _filter = _Filter.all;
  var _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    if (me == null || !me.has('USER_VIEW_ALL')) {
      return Scaffold(appBar: AppBar(title: Text(l.team)), body: EmptyState(icon: Icons.lock_outline, title: l.teamNoAccess));
    }
    final q = _toQuery(_filter, _query);
    final users = ref.watch(teamUsersProvider(q));
    final labels = {
      _Filter.all: l.filterAll, _Filter.superAdmin: l.roleSuperAdmin, _Filter.admin: l.roleAdmin, _Filter.manager: l.roleManager,
      _Filter.worker: l.roleWorker, _Filter.active: l.filterActive, _Filter.disabled: l.filterDisabled,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.team)),
      floatingActionButton: me.has('USER_CREATE')
          ? FloatingActionButton.extended(onPressed: () => showAddUserSheet(context), icon: const Icon(Icons.person_add_alt), label: Text(l.teamAddUser))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBar(
            hintText: l.teamSearch,
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _query = v));
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(labels[f]!), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (users) {
            AsyncValue(:final value?) => value.isEmpty
                ? EmptyState(icon: Icons.person_search_outlined, title: l.usersEmpty)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(teamUsersProvider(q)),
                    child: ListView.separated(
                      padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 96),
                      itemCount: value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserRow(user: value[i], isMe: value[i].id == me.id),
                    ),
                  ),
            AsyncValue(:final error?) => EmptyState(
                icon: Icons.error_outline,
                title: errorText(context, error),
                action: FilledButton.tonal(onPressed: () => ref.invalidate(teamUsersProvider(q)), child: Text(l.retry)),
              ),
            _ => const SkeletonList(count: 6),
          },
        ),
      ]),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.isMe});
  final TeamUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final u = user;
    final second = [
      u.phone,
      if (u.isWorker) '${l.managerLabel}: ${u.managerName ?? l.noManager}',
      if (!u.online) seenLabel(l, u.seenAt),
    ].join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: () => u.isWorker && u.workerId != null ? context.push('/admin/workers/${u.workerId}') : context.push('/admin/team/${u.id}'),
        child: Opacity(
          opacity: u.isActive ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              OnlineAvatar(name: u.fullName, online: u.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(u.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (isMe) Text('  · ${l.youLabel}', style: TextStyle(color: scheme.outline)),
                  ]),
                  const SizedBox(height: 2),
                  Text(second, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                RoleBadge(role: u.role),
                if (!u.isActive) ...[const SizedBox(height: 4), Text(l.teamStatusSuspended, style: TextStyle(color: scheme.error, fontSize: 12))],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class OnlineAvatar extends StatelessWidget {
  const OnlineAvatar({super.key, required this.name, required this.online, this.radius = 22});
  final String name;
  final bool online;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = radius * 0.55;
    return Stack(children: [
      CircleAvatar(radius: radius, backgroundColor: scheme.primaryContainer, child: Text(initials(name), style: TextStyle(fontSize: radius * 0.7))),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: dot, height: dot,
          decoration: BoxDecoration(color: online ? AppTokens.ok : scheme.outlineVariant, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)),
        ),
      ),
    ]);
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final c = roleColor(Theme.of(context).colorScheme, role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(teamRoleLabel(AppLocalizations.of(context), role), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Shows a freshly issued one-time password with a copy button. It is never stored on the device.
Future<void> showTemporaryPassword(BuildContext context, String password) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.tempPasswordTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(password, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1)),
        const SizedBox(height: 12),
        Text(l.tempPasswordHint),
      ]),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: password));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copied)));
          },
          label: Text(l.copy),
        ),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.confirm)),
      ],
    ),
  );
}

/// «+ Добавить пользователя»: staff only (ADMIN / MANAGER). Workers register themselves through the Telegram bot.
Future<void> showAddUserSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddUserSheet(),
    );

class _AddUserSheet extends ConsumerStatefulWidget {
  const _AddUserSheet();
  @override
  ConsumerState<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends ConsumerState<_AddUserSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+998');
  var _role = 'MANAGER';
  var _active = true;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_name.text.trim().length < 2 || _phone.text.replaceAll(RegExp(r'\D'), '').length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.checkYourInput)));
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(teamRepositoryProvider);
    try {
      final res = await repo.createUser(phone: _phone.text.trim(), fullName: _name.text.trim(), role: _role);
      final id = (res['user'] as Map?)?['id'] as String?;
      if (!_active && id != null) await repo.setStatus(id, false);
      ref.invalidate(teamUsersProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      final outer = nav.context;
      nav.pop();
      final pwd = res['temporaryPassword'] as String?;
      if (pwd != null && outer.mounted) await showTemporaryPassword(outer, pwd);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'CONFLICT') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.teamPhoneTaken), backgroundColor: Theme.of(context).colorScheme.error));
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
    final me = ref.watch(authControllerProvider).value;
    // an ADMIN (with USER_CREATE) may only create lower ranks - the server enforces it, the UI just doesn't offer the rest
    final roles = [if (me?.isSuperAdmin ?? false) 'ADMIN', 'MANAGER'];
    if (!roles.contains(_role)) _role = roles.last;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.teamAddUser, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l.workersViaTelegram, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(controller: _name, enabled: !_busy, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: l.teamFullName)),
          const SizedBox(height: 12),
          TextField(controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.phone)),
          const SizedBox(height: 16),
          Text(l.teamRole, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final r in roles) RoleOption(role: r, selected: _role == r, onTap: _busy ? null : () => setState(() => _role = r)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.activeImmediately), value: _active, onChanged: _busy ? null : (v) => setState(() => _active = v)),
          const SizedBox(height: 8),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.teamAddUser)),
          ),
        ]),
      ),
    );
  }
}

/// A role as a tappable card with a one-line explanation of what it can do.
class RoleOption extends StatelessWidget {
  const RoleOption({super.key, required this.role, required this.selected, this.onTap});
  final String role;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (role) { 'SUPER_ADMIN' => l.roleSuperAdminHint, 'ADMIN' => l.roleAdminHint, _ => l.roleManagerHint };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(teamRoleLabel(l, role), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(hint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? scheme.primary : scheme.outline),
            ]),
          ),
        ),
      ),
    );
  }
}
