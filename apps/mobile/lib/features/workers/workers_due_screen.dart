import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'models.dart';
import 'workers_providers.dart';

/// Staff Dashboard's "К выплате" card (§2): every ACTIVE worker with money owed, biggest balance first. Reuses the
/// same offline cache the Workers tab uses (`Worker.balance` is already on every list row) - no new endpoint.
class WorkersDueScreen extends ConsumerWidget {
  const WorkersDueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(workersListProvider(const WorkersFilter(status: 'ACTIVE')));
    return Scaffold(
      appBar: AppBar(title: Text(l.payoutDue)),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (workers) {
          final due = workers.where((w) => (int.tryParse(w.balance) ?? 0) > 0).toList()
            ..sort((a, b) => (int.tryParse(b.balance) ?? 0).compareTo(int.tryParse(a.balance) ?? 0));
          if (due.isEmpty) return EmptyState(icon: Icons.payments_outlined, title: l.workersDueEmpty);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: due.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DueTile(worker: due[i]),
          );
        },
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/workers/${worker.id}'),
        leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(initials(worker.fullName))),
        title: Text(worker.fullName),
        subtitle: Text(worker.code),
        trailing: Text('${formatUzs(worker.balance)} ${l.currency}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
