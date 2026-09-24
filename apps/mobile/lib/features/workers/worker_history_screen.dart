import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../work/assignment_admin_repository.dart';
import '../work/assignment_detail_screen.dart';

/// «История» of one worker (§15): every assignment she ever had (with its human status) and every money movement,
/// newest first. Plain facts from the same scoped endpoints the card uses - not the technical audit log.
class WorkerHistoryScreen extends ConsumerWidget {
  const WorkerHistoryScreen({super.key, required this.workerId, required this.name});
  final String workerId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final work = ref.watch(assignmentListProvider(AssignmentListFilter(workerId: workerId)));
    final money = ref.watch(workerLedgerProvider(workerId));
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    Widget section(String title, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            Card(child: rows.isEmpty ? ListTile(title: Text(l.historyEmpty)) : Column(children: rows)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text('${l.history} · $name')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        work.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
          data: (items) => section(l.historyWork, [
            for (final a in items)
              ListTile(
                leading: Icon(Icons.circle, size: 12, color: statusColor(scheme, a.status)),
                title: Text('${a.productName} · ${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м'),
                subtitle: Text(statusLabel(l, a.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))),
              ),
          ]),
        ),
        money.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(), // e.g. a MANAGER without finance rights: simply no money section
          data: (led) => section(l.historyMoney, [
            for (final e in led.history)
              ListTile(
                leading: Icon(e.type == 'PAYOUT_CASH' ? Icons.payments_outlined : Icons.trending_up, color: e.type == 'PAYOUT_CASH' ? scheme.error : Colors.green),
                title: Text(e.type == 'PAYOUT_CASH' ? l.actionPayout : l.acceptanceCalculated),
                subtitle: Text(date(e.createdAt.toLocal())),
                trailing: Text(
                  '${e.amount.startsWith('-') ? '' : '+'}${formatUzs(e.amount)} ${l.currency}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: e.amount.startsWith('-') ? scheme.error : Colors.green),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
