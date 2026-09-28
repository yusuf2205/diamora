import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';

/// One row of «Залоги»: who, what, where it is kept.
class CollateralListItem {
  const CollateralListItem({required this.id, required this.type, required this.status, this.amount, this.description, this.storageLocation, required this.workerId, required this.workerName, required this.workerCode});
  final String id, type, status, workerId, workerName, workerCode;
  final String? amount, description, storageLocation;
  factory CollateralListItem.fromJson(Map<String, dynamic> j) {
    final w = (j['worker'] as Map).cast<String, dynamic>();
    return CollateralListItem(
      id: j['id'] as String, type: j['type'] as String, status: j['status'] as String, amount: j['amount'] as String?,
      description: j['description'] as String?, storageLocation: j['storageLocation'] as String?,
      workerId: w['id'] as String, workerName: w['fullName'] as String, workerCode: w['code'] as String,
    );
  }
}

class CollateralsPage {
  const CollateralsPage({required this.items, required this.moneyTotal, required this.moneyCount, required this.itemCount});
  final List<CollateralListItem> items;
  final String moneyTotal;
  final int moneyCount, itemCount;
}

final collateralsProvider = FutureProvider.autoDispose.family<CollateralsPage, String>((ref, status) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type == 'collateral.updated') ref.invalidateSelf();
  });
  final j = await ref.watch(apiClientProvider).getJson('/collaterals', query: {'status': status, 'limit': 100});
  final held = (j['held'] as Map?)?.cast<String, dynamic>() ?? const {};
  return CollateralsPage(
    items: (j['items'] as List).map((x) => CollateralListItem.fromJson((x as Map).cast<String, dynamic>())).toList(),
    moneyTotal: held['moneyTotal'] as String? ?? '0', moneyCount: held['moneyCount'] as int? ?? 0, itemCount: held['itemCount'] as int? ?? 0,
  );
});

/// «Деньги: 1 500 000 сум» or the item's description.
String collateralWhatText(AppLocalizations l, {required String type, String? amount, String? description}) =>
    type == 'MONEY' ? '${l.collateralMoney}: ${formatUzs(amount)} ${l.currency}' : (description ?? l.collateralItem);

/// «Вернуть залог»: a note + her confirmation that she got it back, then HELD -> RETURNED on the server. true when done.
Future<bool> returnCollateralFlow(BuildContext context, WidgetRef ref, {required String collateralId, required String what}) async {
  final l = AppLocalizations.of(context);
  final note = TextEditingController();
  var confirmed = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(l.collateralReturnTitle),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(what),
            const SizedBox(height: 12),
            TextField(key: const Key('collateralReturnNote'), controller: note, decoration: InputDecoration(labelText: l.collateralReturnNote), onChanged: (_) => set(() {})),
            CheckboxListTile(
              key: const Key('collateralReturnConfirm'),
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (v) => set(() => confirmed = v ?? false),
              title: Text(l.collateralReturnConfirm),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('collateralReturnSave'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: confirmed && note.text.trim().length >= 2 ? () => Navigator.pop(ctx, true) : null,
            child: Text(l.collateralReturnTitle),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(apiClientProvider).postJson('/collaterals/$collateralId/return', idempotencyKey: const Uuid().v4(), body: {'note': note.text.trim(), 'workerConfirmed': true});
    if (context.mounted) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.collateralReturnedToast)));
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// «Залоги»: who left what, what is in our hands right now, and «Вернуть» when she leaves.
class CollateralsScreen extends ConsumerStatefulWidget {
  const CollateralsScreen({super.key});
  @override
  ConsumerState<CollateralsScreen> createState() => _CollateralsScreenState();
}

class _CollateralsScreenState extends ConsumerState<CollateralsScreen> {
  String _status = 'HELD';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    if (me == null || !me.has('COLLATERAL_VIEW')) {
      return Scaffold(appBar: AppBar(title: Text(l.collateralsTitle)), body: EmptyState(icon: Icons.lock_outline_rounded, title: l.teamNoAccess));
    }
    final canManage = me.has('COLLATERAL_MANAGE');
    final async = ref.watch(collateralsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: Text(l.collateralsTitle)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (async.value case final page?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: Padding(
                padding: AppTokens.cardPadding,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.collateralsWithUs, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('${formatUzs(page.moneyTotal)} ${l.currency} · ${l.collateralsItems(page.itemCount)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'HELD', label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.collateralsTabHeld, maxLines: 1))),
              ButtonSegment(value: 'PENDING', label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.collateralsTabPending, maxLines: 1))),
              ButtonSegment(value: 'RETURNED', label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.collateralsTabReturned, maxLines: 1))),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(),
            error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
            data: (page) => page.items.isEmpty
                ? EmptyState(icon: Icons.lock_open_rounded, title: l.collateralsEmpty)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(collateralsProvider(_status)),
                    child: ListView.separated(
                      padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = page.items[i];
                        final what = collateralWhatText(l, type: c.type, amount: c.amount, description: c.description);
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(c.type == 'MONEY' ? Icons.payments_rounded : Icons.diamond_rounded),
                            title: Text(c.workerName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text([what, if (c.storageLocation != null) c.storageLocation!].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: canManage && c.status == 'HELD'
                                ? IconButton.filledTonal(
                                    key: Key('return-${c.id}'),
                                    tooltip: l.collateralReturnTitle,
                                    icon: const Icon(Icons.assignment_return_rounded),
                                    onPressed: () async {
                                      if (await returnCollateralFlow(context, ref, collateralId: c.id, what: '${c.workerName} — $what')) ref.invalidate(collateralsProvider(_status));
                                    },
                                  )
                                : null,
                            onTap: () => context.push('/admin/workers/${c.workerId}'),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
