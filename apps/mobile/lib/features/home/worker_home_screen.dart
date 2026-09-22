import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/pay_rate.dart';
import '../settings/pay_rate_screen.dart';
import '../work/assignment_admin_repository.dart' show LedgerEntry;
import '../work/current_work_card.dart';
import '../work/work_repository.dart';
import '../workers/collateral_card.dart';
import '../workers/workers_providers.dart';

/// WORKER home: understand in one look where you stand (M3 §8: current work now included).
class WorkerHomeScreen extends ConsumerWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider);
    final collateral = ref.watch(myCollateralProvider);
    final currentWork = ref.watch(currentWorkProvider);
    final earnings = ref.watch(myEarningsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.home)),
      body: Column(children: [
        const ConnectionBanner(),
        Expanded(
          child: profile.when(
            loading: () => const SkeletonList(count: 3),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
            data: (me) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myProfileProvider);
                ref.invalidate(myCollateralProvider);
                ref.invalidate(payRateProvider);
                ref.invalidate(currentWorkProvider);
                ref.invalidate(myEarningsProvider);
              },
              child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
                Text(me.fullName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me.status == 'PENDING_APPROVAL' ? l.myStatusPending : l.myStatusActive, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Text(l.balanceToReceive, style: Theme.of(context).textTheme.labelLarge),
                      Text('${formatUzs(me.balance)} ${l.currency}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                      earnings.maybeWhen(
                        data: (led) => Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(children: [
                            Expanded(child: _EarningStat(label: l.earningsEarned, value: led.earned)),
                            Expanded(child: _EarningStat(label: l.earningsPaid, value: led.paid)),
                          ]),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ]),
                  ),
                ),
                earnings.maybeWhen(
                  data: (led) => led.history.isEmpty ? const SizedBox.shrink() : _EarningsHistory(entries: led.history),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (me.status != 'PENDING_APPROVAL') ...[
                  const SizedBox(height: 20),
                  Text(l.workCurrentTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  currentWork.when(
                    loading: () => const SkeletonList(count: 1),
                    error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
                    data: (w) => w == null
                        ? EmptyState(icon: Icons.inbox_outlined, title: l.workNoCurrent, hint: l.workNoCurrentHint)
                        : CurrentWorkCard(work: w),
                  ),
                ],
                const SizedBox(height: 12),
                const PayRateCard(),
                const SizedBox(height: 20),
                Text(l.collateral, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...collateral.maybeWhen(data: (items) => [for (final c in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: CollateralCard(collateral: c))], orElse: () => const <Widget>[]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _EarningStat extends StatelessWidget {
  const _EarningStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text('${formatUzs(value)} ${l.currency}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

/// M3 §13: a plain timeline — "+ 60 000 сум / Оплата за работу", never raw ledger terminology (EARNING/PAYOUT_CASH).
class _EarningsHistory extends StatelessWidget {
  const _EarningsHistory({required this.entries});
  final List<LedgerEntry> entries;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.earningsHistory, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              for (final e in entries)
                ListTile(
                  leading: Icon(e.type == 'PAYOUT_CASH' ? Icons.payments_outlined : Icons.trending_up, color: e.type == 'PAYOUT_CASH' ? scheme.error : Colors.green),
                  title: Text(e.type == 'PAYOUT_CASH' ? l.actionPayout : l.acceptanceCalculated),
                  subtitle: Text('${e.createdAt.day.toString().padLeft(2, '0')}.${e.createdAt.month.toString().padLeft(2, '0')}.${e.createdAt.year}'),
                  trailing: Text(
                    '${e.amount.startsWith('-') ? '' : '+'}${formatUzs(e.amount)} ${l.currency}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: e.amount.startsWith('-') ? scheme.error : Colors.green),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
