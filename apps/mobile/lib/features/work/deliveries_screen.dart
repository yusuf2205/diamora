import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'assignment_admin_repository.dart';
import 'assignment_detail_screen.dart';
import 'assignment_models.dart';

/// M3 §6/§11 — exactly the two queues a staff member needs to discover without digging through every worker's card:
/// "Нужно доставить" and "Есть что забрать". Deliberately no map/distance sorting (§7): a plain, fast list.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});
  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.deliveriesTitle),
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.deliveryNeeded), Tab(text: l.pickupNeeded)]),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _AssignmentQueue(status: 'READY_TO_DELIVER'),
        _AssignmentQueue(status: 'READY_FOR_PICKUP'),
      ]),
    );
  }
}

class _AssignmentQueue extends ConsumerWidget {
  const _AssignmentQueue({required this.status});
  final String status;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(assignmentListProvider(AssignmentListFilter(status: status)));
    return list.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
      data: (items) => items.isEmpty
          ? EmptyState(icon: Icons.inbox_outlined, title: status == 'READY_TO_DELIVER' ? l.deliveryNeeded : l.pickupNeeded, hint: l.workNoCurrent)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(assignmentListProvider(AssignmentListFilter(status: status))),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _QueueCard(a: items[i]),
              ),
            ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.a});
  final AssignmentSummary a;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(a.workerName.isNotEmpty ? a.workerName[0] : '?')),
        title: Text(a.workerName),
        subtitle: Text('${a.productName} · ${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))),
      ),
    );
  }
}
