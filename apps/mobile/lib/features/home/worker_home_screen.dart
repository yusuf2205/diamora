import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/pay_rate.dart';
import '../settings/pay_rate_screen.dart';
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
                    ]),
                  ),
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
