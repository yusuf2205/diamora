import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/widgets.dart';
import '../auth/auth_controller.dart';
import '../settings/pay_rate.dart';
import '../../l10n/app_localizations.dart';
import 'assignment_admin_repository.dart';
import 'assignment_detail_screen.dart';
import 'assignment_models.dart';

/// A single-purpose worklist opened from a Staff Dashboard card (§2): one or more assignment statuses, merged into
/// one feed, soonest deadline first. Reuses the same per-status cache `DeliveriesScreen` uses, so nothing here
/// re-fetches data that's already in flight elsewhere. `overdueOnly` additionally drops anything without a
/// due date in the past - the statuses passed in already narrow "which kind of overdue" (e.g. delivered-but-not-
/// finished vs. in-progress-but-not-finished), matching `StatsService.forWorkers()`'s own definition exactly.
class AssignmentQueueScreen extends ConsumerWidget {
  const AssignmentQueueScreen({super.key, required this.title, required this.statuses, this.overdueOnly = false, this.dueTodayOnly = false});
  final String title;
  final List<String> statuses;
  final bool overdueOnly;
  /// Only deadlines falling on today's calendar date (the device's local day, the same day the owner lives in).
  final bool dueTodayOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final results = [for (final s in statuses) ref.watch(assignmentListProvider(AssignmentListFilter(status: s)))];

    Widget body;
    if (results.any((r) => r.isLoading && !r.hasValue)) {
      body = const SkeletonList(count: 4);
    } else if (results.any((r) => r.hasError)) {
      final failed = results.firstWhere((r) => r.hasError);
      body = EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, failed.error!));
    } else {
      final now = DateTime.now();
      final items = [for (final r in results) ...r.value ?? const <AssignmentSummary>[]]
        ..retainWhere((a) => !overdueOnly || (a.dueAt != null && a.dueAt!.isBefore(now)))
        ..retainWhere((a) {
          if (!dueTodayOnly) return true;
          final d = a.dueAt?.toLocal();
          return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
        })
        ..sort((a, b) {
          if (a.dueAt == null && b.dueAt == null) return 0;
          if (a.dueAt == null) return 1;
          if (b.dueAt == null) return -1;
          return a.dueAt!.compareTo(b.dueAt!);
        });
      body = items.isEmpty
          ? EmptyState(icon: Icons.inbox_rounded, title: l.queueEmpty)
          : RefreshIndicator(
              onRefresh: () async {
                for (final s in statuses) {
                  ref.invalidate(assignmentListProvider(AssignmentListFilter(status: s)));
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _QueueCard(a: items[i], overdue: overdueOnly),
              ),
            );
    }

    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.a, required this.overdue});
  final AssignmentSummary a;
  final bool overdue;

  /// «Принять всё» (owner, 2026-10-11): no defects - one tap and a confirmation instead of the whole form
  Future<void> _acceptAll(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final meters = a.reportedMeters > 0 ? a.reportedMeters : a.plannedMeters;
    final rate = int.tryParse(ref.read(payRateProvider).value?.ratePerKit ?? '');
    final sum = rate == null ? null : formatUzs('${(rate * meters / 9).floor()}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.acceptAllAction),
        content: Text(l.acceptAllConfirm(a.workerName, meters.toStringAsFixed(meters == meters.roundToDouble() ? 0 : 1), sum ?? '—')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(key: const Key('acceptAllConfirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.acceptAllAction)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final m = meters.toStringAsFixed(2);
      await ref.read(assignmentAdminRepositoryProvider).accept(a.id, broughtMeters: m, acceptedMeters: m, defectiveMeters: '0', reworkMeters: '0');
      ref.invalidate(assignmentListProvider(const AssignmentListFilter(status: 'UNDER_REVIEW')));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.acceptanceSuccess)));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canAccept = a.status == 'UNDER_REVIEW' && (ref.watch(authControllerProvider).value?.has('ASSIGNMENT_ACCEPT') ?? false);
    return Card(
      child: Column(children: [ListTile(
        leading: CircleAvatar(
          backgroundColor: overdue ? scheme.errorContainer : scheme.primaryContainer,
          child: Text(a.workerName.isNotEmpty ? a.workerName[0] : '?'),
        ),
        title: Text(a.workerName),
        subtitle: Text('${a.productName} · ${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м'
            '${a.dueAt != null ? ' · ${l.dueBy}${_date(a.dueAt!)}' : ''}'),
        subtitleTextStyle: overdue ? TextStyle(color: scheme.error) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))),
      ),
      if (canAccept)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(child: FilledButton.icon(key: Key('acceptAll-${a.id}'), onPressed: () => _acceptAll(context, ref), icon: const Icon(Icons.done_all_rounded), label: Text(l.acceptAllAction))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))), child: Text(l.acceptWithDefects))),
          ]),
        ),
      ]),
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}
