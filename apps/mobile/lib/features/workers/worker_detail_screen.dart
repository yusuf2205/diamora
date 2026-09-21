import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'collateral_card.dart';
import 'models.dart';
import 'workers_providers.dart';

/// ADMIN: full card of a worker. Approve/reject are server-confirmed operations (transaction -> COMMIT -> realtime).
class WorkerDetailScreen extends ConsumerWidget {
  const WorkerDetailScreen({super.key, required this.workerId});
  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(workerDetailProvider(workerId));
    return Scaffold(
      appBar: AppBar(title: Text(async.value?.fullName ?? l.workers)),
      body: Column(children: [
        const ConnectionBanner(),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(count: 4),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
            data: (w) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(workerDetailProvider(workerId)),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _Header(worker: w),
                const SizedBox(height: 12),
                _Contacts(worker: w),
                const SizedBox(height: 16),
                Text(l.collateral, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in w.collaterals) ...[
                  CollateralCard(
                    collateral: c,
                    actions: c.status == 'PENDING' && !w.isPending
                        ? [FilledButton.tonal(onPressed: () => _receive(context, ref, c), child: Text(l.receiveCollateral))]
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (w.notes != null && w.notes!.isNotEmpty) ...[Text(l.notes, style: Theme.of(context).textTheme.titleSmall), Text(w.notes!)],
                if (w.isPending) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(icon: const Icon(Icons.check), onPressed: () => _approve(context, ref, w), label: Text(l.approve)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(icon: const Icon(Icons.close), onPressed: () => _reject(context, ref, w), label: Text(l.reject)),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, Worker w) async {
    final l = AppLocalizations.of(context);
    var received = w.collaterals.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(l.approveTitle),
          content: CheckboxListTile(contentPadding: EdgeInsets.zero, value: received, onChanged: (v) => set(() => received = v ?? false), title: Text(l.collateralReceivedCheck)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm))],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(workerRepositoryProvider).approve(w.id, collateralReceived: received);
      ref.invalidate(workerDetailProvider(w.id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.approvedDone)));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, Worker w) async {
    final l = AppLocalizations.of(context);
    final reason = await _askText(context, l.rejectTitle, l.rejectReason);
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(workerRepositoryProvider).reject(w.id, reason);
      ref.invalidate(workerDetailProvider(w.id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.rejectedDone)));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _receive(BuildContext context, WidgetRef ref, Collateral c) async {
    final l = AppLocalizations.of(context);
    final loc = await _askText(context, l.receiveCollateral, l.storageLocation, required: false);
    if (loc == null || !context.mounted) return;
    try {
      await ref.read(workerRepositoryProvider).receiveCollateral(c.id, storageLocation: loc);
      ref.invalidate(workerDetailProvider(workerId));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<String?> _askText(BuildContext context, String title, String label, {bool required = true}) {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (required && v.length < 3) return;
              Navigator.pop(ctx, v);
            },
            child: Text(l.confirm),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = switch (worker.status) { 'PENDING_APPROVAL' => l.statusPending, 'ACTIVE' => l.statusActive, 'PAUSED' => l.statusPaused, 'REJECTED' => l.statusRejected, _ => l.statusArchived };
    return Row(children: [
      CircleAvatar(radius: 32, backgroundColor: scheme.primaryContainer, child: Text(initials(worker.fullName), style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(worker.fullName, style: Theme.of(context).textTheme.titleLarge),
          Text('${worker.code} · $status', style: TextStyle(color: worker.isPending ? AppTokens.warn : scheme.outline)),
          if (worker.rejectedReason != null) Text(worker.rejectedReason!, style: TextStyle(color: scheme.error)),
        ]),
      ),
    ]);
  }
}

class _Contacts extends StatelessWidget {
  const _Contacts({required this.worker});
  final Worker worker;

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: AppTokens.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(worker.phone), subtitle: worker.secondaryPhone == null ? null : Text('${l.secondaryPhone}: ${worker.secondaryPhone}')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(worker.hasLocation ? '${worker.latitude!.toStringAsFixed(5)}, ${worker.longitude!.toStringAsFixed(5)}' : l.noLocation),
            subtitle: Text(l.location),
          ),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.call), onPressed: () => _open(Uri.parse('tel:${worker.phone}')), label: Text(l.call))),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.directions),
                // Yandex Maps deep link (no API key needed); falls back to the web page
                onPressed: worker.hasLocation
                    ? () => _open(Uri.parse('https://yandex.uz/maps/?rtext=~${worker.latitude},${worker.longitude}&rtt=auto'))
                    : null,
                label: Text(l.route),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
