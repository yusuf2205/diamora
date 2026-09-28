import 'package:flutter/material.dart';
import '../work/job_requests.dart';
import '../../core/notifications/app_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/models.dart';
import '../work/assignment_queue_screen.dart';
import '../work/create_assignment_screen.dart';
import '../work/deliveries_screen.dart';
import '../workers/workers_due_screen.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

const _active = ['DELIVERED', 'IN_PROGRESS', 'READY_TO_DELIVER', 'READY_FOR_PICKUP', 'REWORK_REQUIRED'];

/// «Обзор» — the staff home screen (§2, §5-9). Everything on it is a real number from `GET /dashboard` (MANAGER: her
/// own workers only, enforced by the server); a section the viewer may not see is simply absent, never a zero. Every
/// number opens the list behind it, and the screen refreshes itself on realtime events (see `staffDashboardProvider`).
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffDashboardProvider);
    final session = ref.watch(authControllerProvider).value;
    final d = async.value;
    // Last known numbers stay on screen while a realtime refresh runs (no skeleton flash); an error with nothing to show
    // is reported at once - Riverpod keeps retrying in the background, but the owner must not stare at a skeleton.
    final Widget body;
    if (d != null) {
      body = RefreshIndicator(
        onRefresh: () async => ref.invalidate(staffDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(session: session),
            _QuickActions(session: session),
            if (session?.has('ASSIGNMENT_VIEW_ALL') == true || session?.has('ASSIGNMENT_VIEW_ASSIGNED') == true) const JobRequestsBanner(),
            _Attention(d: d),
            _Counters(d: d),
            if (d.today != null) _Today(t: d.today!),
          ],
        ),
      );
    } else if (async.hasError) {
      body = ListView(children: [
        _Header(session: session),
        SizedBox(height: 320, child: EmptyState(icon: Icons.cloud_off_rounded, title: errorText(context, async.error!))),
        Center(child: OutlinedButton(onPressed: () => ref.invalidate(staffDashboardProvider), child: Text(AppLocalizations.of(context).retry))),
      ]);
    } else {
      body = ListView(children: [_Header(session: session), const SizedBox(height: 360, child: SkeletonList(count: 4))]);
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

void _queue(BuildContext context, String title, List<String> statuses, {bool overdueOnly = false, bool dueTodayOnly = false}) =>
    _push(context, AssignmentQueueScreen(title: title, statuses: statuses, overdueOnly: overdueOnly, dueTodayOnly: dueTodayOnly));

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final Session? session;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final h = DateTime.now().hour;
    final greeting = h < 12 ? l.greetingMorning : (h < 18 ? l.greetingDay : l.greetingEvening);
    final s = session;
    final role = switch (s?.role) { 'SUPER_ADMIN' => l.roleSuperAdmin, 'ADMIN' => l.roleAdmin, 'MANAGER' => l.roleManager, _ => '' };
    final name = s == null ? '' : s.fullName.trim().split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? greeting : '$greeting, $name', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (role.isNotEmpty) Text(role, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ]),
        ),
        const NoticeBell(),
      ]),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.d});
  final StaffDashboard d;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final w = d.work, f = d.finance;
    final items = <_AttnItem>[
      if (w != null && w.overdue > 0)
        _AttnItem(Icons.warning_amber_rounded, scheme.error, l.attnOverdue(w.overdue), () => _queue(context, l.dashOverdue, const ['DELIVERED', 'IN_PROGRESS'], overdueOnly: true)),
      if (w != null && w.reworkRequired > 0)
        _AttnItem(Icons.report_problem_rounded, scheme.error, l.attnRework(w.reworkRequired), () => _queue(context, l.dashProblems, const ['REWORK_REQUIRED'])),
      if (w != null && w.toDeliver > 0)
        _AttnItem(Icons.local_shipping_rounded, Colors.orange, l.attnToDeliver(w.toDeliver), () => _push(context, const DeliveriesScreen())),
      if (w != null && w.toPickup > 0)
        _AttnItem(Icons.move_to_inbox_rounded, Colors.purple, l.attnToPickup(w.toPickup), () => _push(context, const DeliveriesScreen(initialTab: 1))),
      if (w != null && w.needsAcceptance > 0)
        _AttnItem(Icons.fact_check_rounded, scheme.tertiary, l.attnAcceptance(w.needsAcceptance), () => _queue(context, l.dashNeedsAcceptance, const ['UNDER_REVIEW'])),
      if (f != null && f.workersDue > 0)
        _AttnItem(Icons.payments_rounded, Colors.green, l.attnWorkersDue(f.workersDue), () => _push(context, const WorkersDueScreen())),
    ];
    if (w == null && f == null) return const SizedBox.shrink();
    // compact chips, not a tall list: the counters below already hold the numbers, these only say what to do FIRST
    return _Section(
      title: l.dashAttention,
      child: items.isEmpty
          ? Row(children: [const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20), const SizedBox(width: 8), Text(l.dashAllClear)])
          : Wrap(spacing: 6, runSpacing: 6, children: [
              for (final it in items)
                ActionChip(
                  avatar: Icon(it.icon, color: it.color, size: 18),
                  label: Text(it.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  visualDensity: VisualDensity.compact,
                  onPressed: it.onTap,
                ),
            ]),
    );
  }
}

class _AttnItem {
  const _AttnItem(this.icon, this.color, this.text, this.onTap);
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.session});
  final Session? session;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final perms = session?.permissions ?? const <String>[];
    // short one-word labels (the full name is the tooltip): five in one tidy row on any phone
    final actions = <(IconData, String, String, VoidCallback)>[
      if (perms.contains('ASSIGNMENT_CREATE')) (Icons.add_task_rounded, l.qaAssign, l.actionAssign, () => _push(context, const CreateAssignmentScreen())),
      (Icons.qr_code_scanner_rounded, l.qaScan, l.actionScanQr, () => context.push('/admin/qr-scan')),
      (Icons.map_rounded, l.qaMap, l.actionMap, () => context.go('/admin/map')),
      (Icons.inventory_2_rounded, l.qaStock, l.actionStock, () => context.go('/admin/inventory')),
      if (perms.contains('CASH_PAYOUT')) (Icons.payments_rounded, l.qaPay, l.actionPayout, () => _push(context, const WorkersDueScreen())),
    ];
    return _Section(
      title: l.dashQuickActions,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final a in actions)
          Expanded(
            child: Tooltip(
              message: a.$3,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: a.$4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 22, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(a.$1, size: 22)),
                    const SizedBox(height: 4),
                    WordSafeText(a.$2, textAlign: TextAlign.center, maxLines: 1, style: Theme.of(context).textTheme.labelMedium),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.d});
  final StaffDashboard d;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = d.work;
    final cards = <Widget>[
      if (d.workers != null) _StatCard(icon: Icons.groups_rounded, value: '${d.workers!.active}', label: l.dashActiveWorkers, onTap: () => context.go('/admin/workers?tab=active')),
      if (w != null) ...[
        _StatCard(icon: Icons.autorenew_rounded, value: '${w.inProgress}', label: l.dashInProgress, onTap: () => _queue(context, l.dashInProgress, const ['IN_PROGRESS'])),
        _StatCard(icon: Icons.local_shipping_rounded, value: '${w.toDeliver}', label: l.deliveryNeeded, onTap: () => _push(context, const DeliveriesScreen())),
        _StatCard(icon: Icons.move_to_inbox_rounded, value: '${w.toPickup}', label: l.pickupNeeded, onTap: () => _push(context, const DeliveriesScreen(initialTab: 1))),
        _StatCard(icon: Icons.fact_check_rounded, value: '${w.needsAcceptance}', label: l.dashNeedsAcceptance, onTap: () => _queue(context, l.dashNeedsAcceptance, const ['UNDER_REVIEW'])),
      ],
      if (d.finance != null)
        _StatCard(icon: Icons.payments_rounded, value: '${formatUzs(d.finance!.due)} ${l.currency}', label: l.payoutDue, onTap: () => _push(context, const WorkersDueScreen())),
      if (w != null) ...[
        _StatCard(icon: Icons.warning_amber_rounded, value: '${w.overdue}', label: l.dashOverdue, danger: w.overdue > 0,
            onTap: () => _queue(context, l.dashOverdue, const ['DELIVERED', 'IN_PROGRESS'], overdueOnly: true)),
        _StatCard(icon: Icons.report_problem_rounded, value: '${w.reworkRequired}', label: l.dashProblems, danger: w.reworkRequired > 0,
            onTap: () => _queue(context, l.dashProblems, const ['REWORK_REQUIRED'])),
      ],
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 6 : c.maxWidth >= 560 ? 4 : 3;
        final width = (c.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final card in cards) SizedBox(width: width, child: card)]);
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: danger ? color : null)),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            SizedBox(height: 30, child: Align(alignment: Alignment.topLeft, child: WordSafeText(label, maxLines: 2, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, height: 1.15)))),
          ]),
        ),
      ),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.t});
  final DashboardToday t;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = <(IconData, String, String, VoidCallback?)>[
      if (t.dueToday != null) (Icons.event_rounded, l.dashDueToday, '${t.dueToday}', () => _queue(context, l.dashDueToday, _active, dueTodayOnly: true)),
      if (t.deliveredToday != null) (Icons.local_shipping_rounded, l.dashDeliveredToday, '${t.deliveredToday}', null),
      if (t.pickedUpToday != null) (Icons.move_to_inbox_rounded, l.dashPickedUpToday, '${t.pickedUpToday}', null),
      if (t.paidToday != null) (Icons.payments_rounded, l.dashPaidToday, '${formatUzs(t.paidToday)} ${l.currency}', null),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: l.dashToday,
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(rows[i].$1),
              title: Text(rows[i].$2),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(rows[i].$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (rows[i].$4 != null) const Icon(Icons.chevron_right_rounded),
              ]),
              onTap: rows[i].$4,
            ),
          ],
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          child,
        ]),
      );
}
