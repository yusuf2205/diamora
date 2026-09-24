import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../work/assignment_admin_repository.dart';
import '../work/assignment_detail_screen.dart';
import '../work/assignment_models.dart';
import '../work/cash_payout_sheet.dart';
import '../work/create_assignment_screen.dart';
import '../map/map_screen.dart' show freshnessLabel;
import '../team/models.dart';
import '../team/team_repository.dart';
import 'collateral_card.dart';
import 'models.dart';
import 'worker_history_screen.dart';
import 'workers_providers.dart';

/// Her live position/presence from `GET /locations` (same scoped source as the map) - null when none is known.
LiveLocationRow? _liveFor(WidgetRef ref, String workerId) =>
    ref.watch(liveLocationsProvider).value?.where((r) => r.workerId == workerId).firstOrNull;

/// ADMIN: full card of a worker. Approve/reject are server-confirmed operations (transaction -> COMMIT -> realtime).
class WorkerDetailScreen extends ConsumerWidget {
  const WorkerDetailScreen({super.key, required this.workerId});
  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(workerDetailProvider(workerId));
    final canArchive = ref.watch(authControllerProvider).value?.has('WORKER_UPDATE') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.fullName ?? l.workers),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner_outlined), tooltip: l.actionScanQr, onPressed: () => context.push('/admin/qr-scan')),
          if (async.value?.qrCode != null)
            IconButton(icon: const Icon(Icons.qr_code_2), tooltip: l.showQr, onPressed: () => _showQr(context, l, async.value!.qrCode!)),
          if (async.value != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: l.history,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorkerHistoryScreen(workerId: workerId, name: async.value!.fullName))),
            ),
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
                if (canArchive && (w.status == 'ACTIVE' || w.status == 'PAUSED')) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, minimumSize: const Size.fromHeight(AppTokens.buttonHeight)),
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => _setStatus(context, ref, w, 'ARCHIVED'),
                    label: Text(l.archiveWorker),
                  ),
                ],
                if (canArchive && w.status == 'ARCHIVED') ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppTokens.buttonHeight)),
                    icon: const Icon(Icons.unarchive_outlined),
                    onPressed: () => _setStatus(context, ref, w, 'ACTIVE'),
                    label: Text(l.restoreWorker),
                  ),
                ],
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

  Future<void> _setStatus(BuildContext context, WidgetRef ref, Worker w, String status) async {
    final l = AppLocalizations.of(context);
    if (status == 'ARCHIVED') {
      final scheme = Theme.of(context).colorScheme;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.archiveWorker),
          content: Text(l.archiveConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError), onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    try {
      await ref.read(workerRepositoryProvider).setStatus(w.id, status);
      ref.invalidate(workerDetailProvider(w.id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'ARCHIVED' ? l.workerArchived : l.workerRestored)));
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

class _Header extends ConsumerWidget {
  const _Header({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = switch (worker.status) { 'PENDING_APPROVAL' => l.statusPending, 'ACTIVE' => l.statusActive, 'PAUSED' => l.statusPaused, 'REJECTED' => l.statusRejected, _ => l.statusArchived };
    final online = _liveFor(ref, worker.id)?.online ?? false;
    final canChangeManager = ref.watch(authControllerProvider).value?.has('WORKER_ASSIGN_MANAGER') ?? false;
    return Row(children: [
      Stack(children: [
        CircleAvatar(radius: 32, backgroundColor: scheme.primaryContainer, child: Text(initials(worker.fullName), style: Theme.of(context).textTheme.titleLarge)),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: online ? AppTokens.ok : scheme.outline, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)),
          ),
        ),
      ]),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(worker.fullName, style: Theme.of(context).textTheme.titleLarge),
          Text('${worker.code} · $status · ${online ? l.onlineNow : l.offlineNow}', style: TextStyle(color: worker.isPending ? AppTokens.warn : scheme.outline)),
          Text('${l.managerLabel}: ${worker.managerName ?? l.noManager}', style: TextStyle(color: scheme.outline)),
          if (canChangeManager && !worker.isPending)
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              icon: const Icon(Icons.swap_horiz, size: 18),
              onPressed: () => showChangeManagerSheet(context, worker),
              label: Text(l.changeManager),
            ),
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
    void open(String id) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssignmentDetailScreen(assignmentId: id)));
    String m(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(l.workCurrentTitle, style: Theme.of(context).textTheme.titleMedium)),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => open(a.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${a.productName} · ${a.colorName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${m(a.plannedMeters)} м'),
                  ]),
                  const SizedBox(height: 4),
                  Text(statusLabel(l, a.status), style: TextStyle(color: statusColor(Theme.of(context).colorScheme, a.status))),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: a.plannedMeters > 0 ? (a.reportedMeters / a.plannedMeters).clamp(0, 1) : 0, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 6),
                  Text([
                    l.workDoneOf(m(a.reportedMeters), m(a.plannedMeters)),
                    if (a.dueAt != null) '${l.workDueDate}: ${a.dueAt!.toLocal().day.toString().padLeft(2, '0')}.${a.dueAt!.toLocal().month.toString().padLeft(2, '0')}',
                  ].join(' · ')),
                  // the one thing to do right now for this assignment, one tap away (the action itself runs on its screen)
                  if (a.status == 'READY_TO_DELIVER' || a.status == 'READY_FOR_PICKUP' || a.status == 'UNDER_REVIEW') ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => open(a.id),
                      icon: Icon(switch (a.status) { 'READY_TO_DELIVER' => Icons.local_shipping_outlined, 'READY_FOR_PICKUP' => Icons.move_to_inbox_outlined, _ => Icons.fact_check_outlined }),
                      label: Text(switch (a.status) { 'READY_TO_DELIVER' => l.deliveryDone, 'READY_FOR_PICKUP' => l.workPickedUp, _ => l.actionAccept }),
                    ),
                  ],
                ]),
              ),
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

class _Contacts extends ConsumerWidget {
  const _Contacts({required this.worker});
  final Worker worker;

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // prefer her live position (with its age) over the one she shared at registration
    final live = _liveFor(ref, worker.id);
    final lat = live?.latitude ?? worker.latitude, lng = live?.longitude ?? worker.longitude;
    final hasLocation = lat != null && lng != null;
    return Card(
      child: Padding(
        padding: AppTokens.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(worker.phone), subtitle: worker.secondaryPhone == null ? null : Text('${l.secondaryPhone}: ${worker.secondaryPhone}')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(hasLocation ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : l.noLocation),
            subtitle: Text(live != null ? freshnessLabel(l, live) : l.location),
          ),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.call), onPressed: () => _open(Uri.parse('tel:${worker.phone}')), label: Text(l.call))),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.directions),
                // Yandex Maps deep link (no API key needed); falls back to the web page
                onPressed: hasLocation ? () => _open(Uri.parse('https://yandex.uz/maps/?rtext=~$lat,$lng&rtt=auto')) : null,
                label: Text(l.route),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// «Сменить менеджера»: pick one of the active managers (or none). The server moves her whole scope - the old manager's
/// lists, map and QR lose her at once, the new one's gain her - and tells both over realtime.
Future<void> showChangeManagerSheet(BuildContext context, Worker worker) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ChangeManagerSheet(worker: worker),
    );

class _ChangeManagerSheet extends ConsumerStatefulWidget {
  const _ChangeManagerSheet({required this.worker});
  final Worker worker;
  @override
  ConsumerState<_ChangeManagerSheet> createState() => _ChangeManagerSheetState();
}

class _ChangeManagerSheetState extends ConsumerState<_ChangeManagerSheet> {
  late String? _picked = widget.worker.managerId;
  var _busy = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(workerRepositoryProvider).assignManager(widget.worker.id, _picked);
      ref.invalidate(workerDetailProvider(widget.worker.id));
      ref.invalidate(managersProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.managerChanged)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final managers = ref.watch(managersProvider);
    final active = managers.value?.where((m) => m.user.isActive).toList();
    Widget option(String? id, String title, String? subtitle) => ListTile(
          enabled: !_busy,
          onTap: () => setState(() => _picked = id),
          leading: Icon(_picked == id ? Icons.radio_button_checked : Icons.radio_button_off, color: _picked == id ? Theme.of(context).colorScheme.primary : null),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.changeManager, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 8),
          if (active == null)
            managers.hasError
                ? Padding(padding: const EdgeInsets.all(16), child: Text(errorText(context, managers.error!)))
                : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final m in active) option(m.user.id, m.user.fullName, l.teamAssignedWorkers(m.assignedWorkers)),
                option(null, l.noManager, null),
              ]),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: AppTokens.buttonHeight,
              child: FilledButton(
                onPressed: _busy || _picked == widget.worker.managerId ? null : _save,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
