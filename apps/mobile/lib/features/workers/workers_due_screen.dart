import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../work/assignment_admin_repository.dart';
import 'models.dart';
import '../../core/providers.dart';
import 'workers_providers.dart';

/// Staff Dashboard's "К выплате" card (§2): every ACTIVE worker with money owed, biggest balance first. Reuses the
/// same offline cache the Workers tab uses (`Worker.balance` is already on every list row) - no new endpoint.
class WorkersDueScreen extends ConsumerStatefulWidget {
  const WorkersDueScreen({super.key});
  @override
  ConsumerState<WorkersDueScreen> createState() => _WorkersDueScreenState();
}

/// «Выплатить сразу нескольким» (owner, 2026-10-11): tick the workers (all by default), one button pays each her whole
/// balance in cash - one payout per worker, exactly as if paid one by one (each is its own audited ledger entry).
class _WorkersDueScreenState extends ConsumerState<WorkersDueScreen> {
  Set<String>? _picked; // null = all of them
  bool _paying = false;

  Future<void> _payAll(List<Worker> chosen) async {
    final l = AppLocalizations.of(context);
    if (chosen.isEmpty) return;
    final total = chosen.fold<int>(0, (s, w) => s + (int.tryParse(w.balance) ?? 0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.payManyTitle),
        content: Text(l.payManyConfirm('${chosen.length}', formatUzs('$total'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(key: const Key('payManyConfirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.actionPayout)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _paying = true);
    var paid = 0;
    final failed = <String>[];
    for (final w in chosen) {
      try {
        await ref.read(assignmentAdminRepositoryProvider).payout(w.id, amount: w.balance, comment: l.payManyComment);
        paid++;
      } catch (_) {
        failed.add(w.fullName);
      }
    }
    try {
      await ref.read(workerRepositoryProvider).refresh();
    } catch (_) {/* the list refreshes itself on the next realtime event */}
    if (!mounted) return;
    setState(() {
      _paying = false;
      _picked = null;
    });
    final done = l.payManyDone('$paid');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed.isEmpty ? done : '$done · ${l.payManyFailed(failed.join(', '))}'),
      backgroundColor: failed.isEmpty ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canPay = ref.watch(authControllerProvider).value?.has('CASH_PAYOUT') ?? false;
    final async = ref.watch(workersListProvider(const WorkersFilter(status: 'ACTIVE')));
    final due = (async.value ?? const <Worker>[]).where((w) => (int.tryParse(w.balance) ?? 0) > 0).toList()
      ..sort((a, b) => (int.tryParse(b.balance) ?? 0).compareTo(int.tryParse(a.balance) ?? 0));
    final chosen = due.where((w) => _picked == null || _picked!.contains(w.id)).toList();
    final total = chosen.fold<int>(0, (s, w) => s + (int.tryParse(w.balance) ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(l.payoutDue)),
      bottomNavigationBar: !canPay || due.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const Key('payMany'),
                  onPressed: _paying || chosen.isEmpty ? null : () => _payAll(chosen),
                  icon: _paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payments_rounded),
                  label: Text(l.payManyButton('${chosen.length}', formatUzs('$total'))),
                ),
              ),
            ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (_) {
          if (due.isEmpty) return EmptyState(icon: Icons.payments_rounded, title: l.workersDueEmpty);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: due.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DueTile(
              worker: due[i],
              picked: canPay ? chosen.contains(due[i]) : null,
              onPick: (v) => setState(() {
                final s = _picked ?? due.map((w) => w.id).toSet();
                v ? s.add(due[i].id) : s.remove(due[i].id);
                _picked = s;
              }),
            ),
          );
        },
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.worker, this.picked, required this.onPick});
  final Worker worker;
  /// null: this staff member cannot pay (no tick box)
  final bool? picked;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/workers/${worker.id}'),
        leading: picked == null
            ? CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(initials(worker.fullName)))
            : Checkbox(key: Key('payPick-${worker.id}'), value: picked, onChanged: (v) => onPick(v ?? false)),
        title: Text(worker.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(worker.code),
        trailing: Text('${formatUzs(worker.balance)} ${l.currency}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
