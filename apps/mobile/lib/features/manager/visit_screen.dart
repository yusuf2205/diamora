import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../work/assignment_admin_repository.dart';
import '../work/assignment_models.dart';
import '../work/cash_payout_sheet.dart';
import '../workers/workers_providers.dart';

/// Everything still open at one worker's place.
final visitWorksProvider = FutureProvider.autoDispose.family<List<AssignmentSummary>, String>((ref, workerId) async {
  final all = await ref.watch(assignmentAdminRepositoryProvider).list(workerId: workerId);
  return all.where((a) => !const ['COMPLETED', 'CANCELLED', 'ACCEPTED', 'PARTIALLY_ACCEPTED'].contains(a.status)).toList();
});

/// «Визит» (owner, 2026-10-11): a manager at a worker's door scans HER QR and gets everything for this visit on one screen
/// - pick up all finished work with one button, start handing over each new kit, pay her - instead of one scan per work.
class VisitScreen extends ConsumerStatefulWidget {
  const VisitScreen({super.key, required this.workerId});
  final String workerId;
  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  final _busy = <String>{};

  Future<void> _do(String key, Future<void> Function() f, {String? done}) async {
    setState(() => _busy.add(key));
    try {
      await f();
      ref.invalidate(visitWorksProvider(widget.workerId));
      ref.invalidate(workerDetailProvider(widget.workerId));
      if (done != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done), backgroundColor: Colors.green.shade700));
      }
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final me = ref.watch(authControllerProvider).value;
    final worker = ref.watch(workerDetailProvider(widget.workerId)).value;
    final works = ref.watch(visitWorksProvider(widget.workerId));
    final repo = ref.read(assignmentAdminRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.visitTitle)),
      body: works.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (items) {
          final pickup = items.where((a) => a.status == 'READY_FOR_PICKUP').toList();
          final deliver = items.where((a) => a.status == 'READY_TO_DELIVER').toList();
          final other = items.where((a) => a.status != 'READY_FOR_PICKUP' && a.status != 'READY_TO_DELIVER').toList();
          final balance = int.tryParse(worker?.balance ?? '0') ?? 0;
          String what(AssignmentSummary a) => '${a.productName} · ${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м';
          return RefreshIndicator(
            onRefresh: () => ref.refresh(visitWorksProvider(widget.workerId).future),
            child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
              Card(
                child: ListTile(
                  title: Text(worker?.fullName ?? '', style: text.titleMedium),
                  subtitle: Text(worker?.phone ?? ''),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (worker != null) IconButton.filledTonal(tooltip: l.call, icon: const Icon(Icons.call_rounded), onPressed: () => launchUrl(Uri.parse('tel:${worker.phone}'))),
                    IconButton(tooltip: l.visitOpenCard, icon: const Icon(Icons.badge_outlined), onPressed: () => context.push('/admin/workers/${widget.workerId}')),
                  ]),
                ),
              ),
              if (items.isEmpty && balance <= 0) Padding(padding: const EdgeInsets.all(24), child: Text(l.visitNothing, textAlign: TextAlign.center)),
              if (pickup.isNotEmpty) ...[
                _Title(l.visitPickup(pickup.length.toString())),
                for (final a in pickup)
                  Card(child: ListTile(
                    title: Text(what(a)),
                    trailing: FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: _busy.contains(a.id) ? null : () => _do(a.id, () => repo.pickup(a.id), done: l.workPickedUp),
                      child: Text(l.workPickedUp),
                    ),
                  )),
                if (pickup.length > 1)
                  FilledButton.icon(
                    key: const Key('visitPickupAll'),
                    onPressed: _busy.contains('all') ? null : () => _do('all', () async { for (final a in pickup) { await repo.pickup(a.id); } }, done: l.visitPickedAll(pickup.length.toString())),
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(l.visitPickupAll(pickup.length.toString())),
                  ),
              ],
              if (deliver.isNotEmpty) ...[
                _Title(l.visitDeliver(deliver.length.toString())),
                for (final a in deliver)
                  Card(child: ListTile(
                    title: Text(what(a)),
                    subtitle: Text(l.visitDeliverHint),
                    trailing: FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: _busy.contains(a.id) ? null : () => _do(a.id, () async {
                        await repo.startHandoff(a.id);
                        // the waiting screen: it turns green when she confirms on her phone
                        if (mounted) this.context.push('/admin/assignments/${a.id}');
                      }),
                      child: Text(l.handoffStart),
                    ),
                  )),
              ],
              if (other.isNotEmpty) ...[
                _Title(l.visitInProgress),
                for (final a in other)
                  Card(child: ListTile(
                    title: Text(what(a)),
                    subtitle: Text('${a.reportedMeters.toStringAsFixed(0)} / ${a.plannedMeters.toStringAsFixed(0)} м'),
                    onTap: () => context.push('/admin/assignments/${a.id}'),
                  )),
              ],
              if (balance > 0 && (me?.has('CASH_PAYOUT') ?? false)) ...[
                _Title(l.visitPay),
                OutlinedButton.icon(
                  key: const Key('visitPay'),
                  onPressed: () => showCashPayoutSheet(context, workerId: widget.workerId, balance: worker?.balance ?? '0'),
                  icon: const Icon(Icons.payments_rounded),
                  label: Text('${l.actionPayout}: ${formatUzs(worker?.balance ?? '0')} ${l.currency}'),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(text, style: Theme.of(context).textTheme.titleMedium));
}
