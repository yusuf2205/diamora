import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../work/assignment_queue_screen.dart';
import '../work/create_assignment_screen.dart';
import '../work/deliveries_screen.dart';
import '../workers/workers_due_screen.dart';
import 'dashboard_repository.dart';

/// The staff home screen (§2): the numbers a SUPER_ADMIN/ADMIN/MANAGER actually works from, each one a door into
/// the matching queue - never a dead end. Everything here is real data from `GET /dashboard`; a section the viewer
/// lacks permission for is simply absent (never a fabricated zero), matching the backend's own honesty rule.
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(staffDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.dashboardTab)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateAssignmentScreen())),
        icon: const Icon(Icons.add),
        label: Text(l.actionAssign),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              if (d.workers != null) _Card(
                icon: Icons.groups_outlined, label: l.dashActiveWorkers, value: '${d.workers!.active}',
                onTap: () => context.go('/admin/workers?tab=active'),
              ),
              if (d.work != null) ...[
                _Card(icon: Icons.autorenew, label: l.dashInProgress, value: '${d.work!.inProgress}',
                    onTap: () => _openQueue(context, l.dashInProgress, const ['IN_PROGRESS'])),
                _Card(icon: Icons.local_shipping_outlined, label: l.deliveryNeeded, value: '${d.work!.toDeliver}',
                    onTap: () => _openDeliveries(context, 0)),
                _Card(icon: Icons.move_to_inbox_outlined, label: l.pickupNeeded, value: '${d.work!.toPickup}',
                    onTap: () => _openDeliveries(context, 1)),
                _Card(icon: Icons.fact_check_outlined, label: l.dashNeedsAcceptance, value: '${d.work!.needsAcceptance}',
                    onTap: () => _openQueue(context, l.dashNeedsAcceptance, const ['UNDER_REVIEW'])),
                _Card(icon: Icons.warning_amber_outlined, label: l.dashOverdue, value: '${d.work!.overdue}', danger: d.work!.overdue > 0,
                    onTap: () => _openQueue(context, l.dashOverdue, const ['DELIVERED', 'IN_PROGRESS'], overdueOnly: true)),
              ],
              if (d.finance != null) _Card(
                icon: Icons.payments_outlined, label: l.payoutDue, value: '${formatUzs(d.finance!.due)} ${l.currency}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkersDueScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueue(BuildContext context, String title, List<String> statuses, {bool overdueOnly = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentQueueScreen(title: title, statuses: statuses, overdueOnly: overdueOnly)));

  void _openDeliveries(BuildContext context, int initialTab) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeliveriesScreen(initialTab: initialTab)));
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.label, required this.value, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: danger ? color : null)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.outline),
          ]),
        ),
      ),
    );
  }
}
