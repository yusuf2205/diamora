import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../work/assignment_admin_repository.dart';
import '../work/assignment_detail_screen.dart';
import '../work/assignment_models.dart';
import '../work/cash_payout_sheet.dart';
import '../work/create_assignment_screen.dart';
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
      appBar: AppBar(
        title: Text(async.value?.fullName ?? l.workers),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner_outlined), tooltip: l.actionScanQr, onPressed: () => context.push('/admin/qr-scan')),
          if (async.value?.qrCode != null)
            IconButton(icon: const Icon(Icons.qr_code_2), tooltip: l.showQr, onPressed: () => _showQr(context, l, async.value!.qrCode!)),
        ],
      ),
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
                if (!w.isPending) ...[
                  const SizedBox(height: 16),
                  _CurrentWorkSection(worker: w),
                  const SizedBox(height: 16),
                  _EarningsSection(worker: w),
                ],
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

  /// The worker's opaque, personal QR (M2 §13): rendered locally from the code text, nothing downloaded or printed
  /// server-side. Scanning it later resolves through the exact same scope check as this very screen (`GET /qr/:code`).
  Future<void> _showQr(BuildContext context, AppLocalizations l, String code) => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.workerQrTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              QrImageView(data: code, size: 220),
              const SizedBox(height: 8),
              SelectableText(code, style: Theme.of(ctx).textTheme.bodySmall),
            ]),
          ),
        ),
      );

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

/// M3 §3: "Выдать работу" + her currently open assignments, right on the card that's already the main operational
/// screen for a worker — no separate dashboard needed to reach the most common action.
class _CurrentWorkSection extends ConsumerWidget {
  const _CurrentWorkSection({required this.worker});
  final Worker worker;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final assignments = ref.watch(assignmentListProvider(AssignmentListFilter(workerId: worker.id)));
    final active = assignments.value?.where((a) => a.status != 'COMPLETED' && a.status != 'CANCELLED').toList() ?? const <AssignmentSummary>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.workCurrentTitle, style: Theme.of(context).textTheme.titleMedium),
        if (active.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CreateAssignmentScreen(workerId: worker.id))),
            label: Text(l.actionAssign),
          ),
      ]),
      const SizedBox(height: 8),
      if (active.isEmpty)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.workNoCurrent)))
      else
        for (final a in active)
          Card(
            child: ListTile(
              title: Text('${a.productName} · ${a.colorName}'),
              subtitle: Text(statusLabel(l, a.status)),
              trailing: Text('${a.plannedMeters.toStringAsFixed(0)} м'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: a.id))),
            ),
          ),
    ]);
  }
}

class _EarningsSection extends ConsumerWidget {
  const _EarningsSection({required this.worker});
  final Worker worker;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ledger = ref.watch(workerLedgerProvider(worker.id));
    return ledger.when(
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (led) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _MoneyStat(label: l.earningsEarned, value: led.earned)),
              Expanded(child: _MoneyStat(label: l.earningsPaid, value: led.paid)),
              Expanded(child: _MoneyStat(label: l.balanceToReceive, value: led.balance, emphasize: true)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.payments_outlined),
                onPressed: () => showCashPayoutSheet(context, workerId: worker.id, balance: led.balance),
                label: Text(l.actionPayout),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      Text('${formatUzs(value)} ${l.currency}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: emphasize ? scheme.primary : null)),
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
