import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/widgets.dart';
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
  const AssignmentQueueScreen({super.key, required this.title, required this.statuses, this.overdueOnly = false});
  final String title;
  final List<String> statuses;
  final bool overdueOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final results = [for (final s in statuses) ref.watch(assignmentListProvider(AssignmentListFilter(status: s)))];

    Widget body;
    if (results.any((r) => r.isLoading && !r.hasValue)) {
      body = const SkeletonList(count: 4);
    } else if (results.any((r) => r.hasError)) {
      final failed = results.firstWhere((r) => r.hasError);
      body = EmptyState(icon: Icons.error_outline, title: errorText(context, failed.error!));
    } else {
      final now = DateTime.now();
      final items = [for (final r in results) ...r.value ?? const <AssignmentSummary>[]]
        ..retainWhere((a) => !overdueOnly || (a.dueAt != null && a.dueAt!.isBefore(now)))
        ..sort((a, b) {
          if (a.dueAt == null && b.dueAt == null) return 0;
          if (a.dueAt == null) return 1;
          if (b.dueAt == null) return -1;
          return a.dueAt!.compareTo(b.dueAt!);
        });
      body = items.isEmpty
          ? EmptyState(icon: Icons.inbox_outlined, title: l.queueEmpty)
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

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.a, required this.overdue});
  final AssignmentSummary a;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: overdue ? scheme.errorContainer : scheme.primaryContainer,
          child: Text(a.workerName.isNotEmpty ? a.workerName[0] : '?'),
        ),
        title: Text(a.workerName),
        subtitle: Text('${a.productName} · ${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м'
            '${a.dueAt != null ? ' · ${l.dueBy}${_date(a.dueAt!)}' : ''}'),
        subtitleTextStyle: overdue ? TextStyle(color: scheme.error) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))),
      ),
    );
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}
