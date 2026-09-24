import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'models.dart';
import 'team_repository.dart';

/// Human name of a permission code. Codes are an implementation detail - the owner only ever sees these words.
String permissionLabel(AppLocalizations l, String p) => switch (p) {
      'USER_VIEW_ALL' => l.permUserViewAll,
      'USER_CREATE' => l.permUserCreate,
      'USER_UPDATE' => l.permUserUpdate,
      'USER_DEACTIVATE' => l.permUserDeactivate,
      'PASSWORD_SET' => l.permPasswordSet,
      'ROLE_ASSIGN' => l.permRoleAssign,
      'PERMISSION_MANAGE' => l.permPermissionManage,
      'WORKER_VIEW_ALL' => l.permWorkerViewAll,
      'WORKER_VIEW_ASSIGNED' => l.permWorkerViewAssigned,
      'WORKER_APPROVE' => l.permWorkerApprove,
      'WORKER_UPDATE' => l.permWorkerUpdate,
      'WORKER_ASSIGN_MANAGER' => l.permWorkerAssignManager,
      'COLLATERAL_VIEW' => l.permCollateralView,
      'COLLATERAL_MANAGE' => l.permCollateralManage,
      'ASSIGNMENT_VIEW_ALL' => l.permAssignmentViewAll,
      'ASSIGNMENT_VIEW_ASSIGNED' => l.permAssignmentViewAssigned,
      'ASSIGNMENT_CREATE' => l.permAssignmentCreate,
      'ASSIGNMENT_ACCEPT' => l.permAssignmentAccept,
      'FINANCE_VIEW_ALL' => l.permFinanceViewAll,
      'FINANCE_VIEW_ASSIGNED' => l.permFinanceViewAssigned,
      'CASH_PAYOUT' => l.permCashPayout,
      'PROFIT_VIEW' => l.permProfitView,
      'CATALOG_VIEW' => l.permCatalogView,
      'CATALOG_MANAGE' => l.permCatalogManage,
      'INVENTORY_VIEW' => l.permInventoryView,
      'INVENTORY_MANAGE' => l.permInventoryManage,
      'MAP_VIEW_ALL' => l.permMapViewAll,
      'MAP_VIEW_ASSIGNED' => l.permMapViewAssigned,
      'LIVE_LOCATION_VIEW_ALL' => l.permLiveLocationViewAll,
      'LIVE_LOCATION_VIEW_ASSIGNED' => l.permLiveLocationViewAssigned,
      'PAY_RATE_MANAGE' => l.permPayRateManage,
      'SETTINGS_MANAGE' => l.permSettingsManage,
      'AUDIT_VIEW' => l.permAuditView,
      _ => p,
    };

/// Groups in the order an owner thinks about the business, each with an icon.
List<(String, IconData, List<String>)> _groups(AppLocalizations l) => [
      (l.permGroupUsers, Icons.manage_accounts_outlined, ['USER_VIEW_ALL', 'USER_CREATE', 'USER_UPDATE', 'USER_DEACTIVATE', 'PASSWORD_SET', 'ROLE_ASSIGN', 'PERMISSION_MANAGE']),
      (l.permGroupWorkers, Icons.groups_2_outlined, ['WORKER_VIEW_ALL', 'WORKER_VIEW_ASSIGNED', 'WORKER_APPROVE', 'WORKER_UPDATE', 'WORKER_ASSIGN_MANAGER']),
      (l.permGroupCollateral, Icons.lock_outline, ['COLLATERAL_VIEW', 'COLLATERAL_MANAGE']),
      (l.permGroupAssignments, Icons.assignment_outlined, ['ASSIGNMENT_VIEW_ALL', 'ASSIGNMENT_VIEW_ASSIGNED', 'ASSIGNMENT_CREATE', 'ASSIGNMENT_ACCEPT']),
      (l.permGroupFinance, Icons.payments_outlined, ['FINANCE_VIEW_ALL', 'FINANCE_VIEW_ASSIGNED', 'CASH_PAYOUT', 'PROFIT_VIEW']),
      (l.permGroupCatalog, Icons.auto_awesome_outlined, ['CATALOG_VIEW', 'CATALOG_MANAGE']),
      (l.permGroupInventory, Icons.inventory_2_outlined, ['INVENTORY_VIEW', 'INVENTORY_MANAGE']),
      (l.permGroupMap, Icons.map_outlined, ['MAP_VIEW_ALL', 'MAP_VIEW_ASSIGNED', 'LIVE_LOCATION_VIEW_ALL', 'LIVE_LOCATION_VIEW_ASSIGNED']),
      (l.permGroupSettings, Icons.tune, ['PAY_RATE_MANAGE', 'SETTINGS_MANAGE']),
      (l.permGroupAudit, Icons.receipt_long_outlined, ['AUDIT_VIEW']),
    ];

/// «Права доступа» of one ADMIN / MANAGER: switches in plain words, grouped. Only what the role can have is shown;
/// saving sends the full picture and the server re-validates it (a MANAGER can never be given *_ALL, etc.).
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key, required this.userId, required this.editable});
  final String userId;
  final bool editable;
  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  Set<String>? _on; // local edits; null = not touched yet
  var _busy = false;

  Future<void> _save(UserDetail d) async {
    final l = AppLocalizations.of(context);
    final on = _on!;
    final defaults = d.defaults.toSet();
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).setPermissions(
            widget.userId,
            grant: on.where((p) => !defaults.contains(p)).toList(),
            revoke: defaults.where((p) => !on.contains(p)).toList(),
          );
      ref.invalidate(userDetailProvider(widget.userId));
      if (!mounted) return;
      setState(() => _on = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.permissionsSaved)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final detail = ref.watch(userDetailProvider(widget.userId));
    final catalog = ref.watch(permissionCatalogProvider);
    final d = detail.value;
    final c = catalog.value;
    final error = detail.error ?? catalog.error;

    Widget body;
    if (d != null && d.user.role == 'SUPER_ADMIN') {
      body = EmptyState(icon: Icons.verified_user, title: l.permissionsAllSuper);
    } else if (d != null && c != null) {
      final editable = c.editableFor(d.user.role).toSet();
      final on = _on ?? d.effective.toSet();
      final defaults = d.defaults.toSet();
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
        for (final (title, icon, perms) in _groups(l))
          if (perms.any(editable.contains)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Row(children: [Icon(icon, size: 20, color: scheme.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium)]),
            ),
            Card(
              child: Column(children: [
                for (final p in perms.where(editable.contains))
                  SwitchListTile(
                    title: Text(permissionLabel(l, p)),
                    subtitle: defaults.contains(p) ? Text(l.permissionsDefault, style: TextStyle(color: scheme.outline, fontSize: 12)) : null,
                    value: on.contains(p),
                    onChanged: !widget.editable || _busy ? null : (v) => setState(() => _on = {...on}..removeWhere((x) => x == p)..addAll(v ? [p] : [])),
                  ),
              ]),
            ),
          ],
      ]);
    } else if (error != null) {
      body = EmptyState(icon: Icons.error_outline, title: errorText(context, error));
    } else {
      body = const SkeletonList(count: 6);
    }

    final dirty = _on != null && d != null && !(_on!.length == d.effective.length && _on!.containsAll(d.effective));
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? l.permissionsTitle : '${l.permissionsTitle} · ${d.user.fullName}')),
      body: body,
      bottomNavigationBar: widget.editable && dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: AppTokens.buttonHeight,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(d),
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
