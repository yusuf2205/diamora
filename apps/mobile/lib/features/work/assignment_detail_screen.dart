import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'acceptance_screen.dart';
import 'assignment_admin_repository.dart';
import 'assignment_models.dart';

/// M3 §5: the assignment as the main operational screen for staff — status-dependent quick actions instead of a
/// generic "edit" form, human status labels instead of the raw enum, a visible history timeline.
class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(assignmentDetailProvider(assignmentId));
    return Scaffold(
      appBar: AppBar(title: Text(l.assignmentDetailTitle)),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (a) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(assignmentDetailProvider(assignmentId)),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _Header(a: a),
            const SizedBox(height: 16),
            _StatusChip(status: a.status),
            const SizedBox(height: 16),
            _ProgressBlock(a: a),
            const SizedBox(height: 20),
            if (a.qrCode != null) _QrBlock(code: a.qrCode!),
            const SizedBox(height: 20),
            if (a.materials.isNotEmpty) _MaterialsBlock(a: a),
            const SizedBox(height: 20),
            _HistoryBlock(a: a),
            const SizedBox(height: 100),
          ]),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(data: (a) => _ActionBar(a: a), orElse: () => null),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _hexColor(a.colorHex) ?? scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(a.variantLabel?.isNotEmpty == true ? '${a.productName} · ${a.variantLabel}' : a.productName, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 4),
          Text('${a.colorName} · ${a.plannedMeters.toStringAsFixed(0)} м', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const Divider(height: 24),
          Row(children: [
            Icon(Icons.person_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text('${a.workerName} · ${a.workerPhone}')),
          ]),
          if (a.dueAt != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.event_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('${a.dueAt!.day.toString().padLeft(2, '0')}.${a.dueAt!.month.toString().padLeft(2, '0')}.${a.dueAt!.year}'),
            ]),
          ],
          if (a.notes?.isNotEmpty == true) ...[const SizedBox(height: 6), Text(a.notes!, style: Theme.of(context).textTheme.bodySmall)],
        ]),
      ),
    );
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.workDoneOf(a.reportedMeters.toStringAsFixed(1), a.plannedMeters.toStringAsFixed(0))),
        Text('${a.percent.round()}%'),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: a.percent / 100, minHeight: 8)),
      if (a.calculatedPayment != null) ...[
        const SizedBox(height: 12),
        Text('${l.assignSummaryPayment}: ${formatUzs(a.calculatedPayment)} ${l.currency}', style: Theme.of(context).textTheme.titleSmall),
      ],
    ]);
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(l.assignmentQr, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          QrImageView(data: code, size: 180),
        ]),
      ),
    );
  }
}

class _MaterialsBlock extends StatelessWidget {
  const _MaterialsBlock({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.assignmentMaterialsIssued, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final m in a.materials)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(m.materialId.substring(0, 8)), Text(m.quantity.toStringAsFixed(2))]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _HistoryBlock extends StatelessWidget {
  const _HistoryBlock({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.assignmentHistory, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final h in a.statusHistory.reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(statusLabel(l, h.to)),
                Text('${h.changedAt.day.toString().padLeft(2, '0')}.${h.changedAt.month.toString().padLeft(2, '0')} ${h.changedAt.hour.toString().padLeft(2, '0')}:${h.changedAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(scheme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(statusLabel(l, status), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Human status label — never the raw enum on screen (§1).
String statusLabel(AppLocalizations l, String status) => switch (status) {
      'DRAFT' => l.workStatusReadyToDeliver,
      'READY_TO_DELIVER' => l.workStatusReadyToDeliver,
      'DELIVERED' => l.workStatusDelivered,
      'IN_PROGRESS' => l.workStatusInProgress,
      'READY_FOR_PICKUP' => l.workStatusReadyForPickup,
      'PICKED_UP' => l.workStatusPickedUp,
      'UNDER_REVIEW' => l.workStatusUnderReview,
      'PARTIALLY_ACCEPTED' => l.statusPartiallyAccepted,
      'ACCEPTED' => l.statusAccepted,
      'REWORK_REQUIRED' => l.statusReworkRequired,
      'COMPLETED' => l.statusCompleted,
      'CANCELLED' => l.statusCancelled,
      _ => status,
    };

Color statusColor(ColorScheme scheme, String status) => switch (status) {
      'READY_TO_DELIVER' || 'DELIVERED' => scheme.tertiary,
      'IN_PROGRESS' => scheme.primary,
      'READY_FOR_PICKUP' || 'PICKED_UP' || 'UNDER_REVIEW' => scheme.secondary,
      'COMPLETED' || 'ACCEPTED' => Colors.green,
      'REWORK_REQUIRED' || 'CANCELLED' => scheme.error,
      _ => scheme.outline,
    };

class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.a});
  final AssignmentDetail a;
  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = widget.a;
    Widget? button;
    switch (a.status) {
      case 'READY_TO_DELIVER':
        button = FilledButton.icon(onPressed: _busy ? null : () => _confirmDeliver(context), icon: const Icon(Icons.local_shipping_outlined), label: Text(l.deliveryDone));
      case 'READY_FOR_PICKUP':
        button = FilledButton.icon(onPressed: _busy ? null : () => _pickup(context), icon: const Icon(Icons.check_circle_outline), label: Text(l.workPickedUp));
      case 'UNDER_REVIEW':
        button = FilledButton.icon(
          onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AcceptanceScreen(assignment: a))),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l.actionAccept),
        );
      default:
        button = null;
    }
    if (button == null && !_busy) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _busy ? const Center(child: CircularProgressIndicator()) : SizedBox(width: double.infinity, child: button),
      ),
    );
  }

  Future<void> _confirmDeliver(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.deliveryConfirmTitle, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.deliveryConfirmBody, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.deliveryDone))),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(assignmentAdminRepositoryProvider).deliver(widget.a.id));
  }

  Future<void> _pickup(BuildContext context) => _run(() => ref.read(assignmentAdminRepositoryProvider).pickup(widget.a.id));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(assignmentDetailProvider(widget.a.id));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
