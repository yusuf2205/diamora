import '../auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui/color_swatch.dart';
import '../../core/ui/qr_print.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'acceptance_screen.dart';
import 'assignment_admin_repository.dart';
import 'assignment_models.dart';
import 'models.dart';
import '../../core/providers.dart';

/// M3 §5: the assignment as the main operational screen for staff — status-dependent quick actions instead of a
/// generic "edit" form, human status labels instead of the raw enum, a visible history timeline.
class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(assignmentDetailProvider(assignmentId));
    final canControl = ref.watch(authControllerProvider).value?.has('ASSIGNMENT_CREATE') ?? false;
    // Phase 5.9: the moment she confirms in her app, the staff member standing next to her sees it here
    ref.listen(realtimeEventsProvider, (_, next) {
      final e = next.value;
      if (e == null || e.data['assignmentId'] != assignmentId) return;
      final name = async.value?.workerName ?? '';
      final msg = switch (e.type) { 'handoff.confirmed' => l.handoffReceived(name), 'handoff.problem' => l.handoffProblemTitle, _ => null };
      if (msg == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: e.type == 'handoff.confirmed' ? Colors.green.shade700 : Theme.of(context).colorScheme.error));
    });
    return Scaffold(
      appBar: AppBar(title: Text(l.assignmentDetailTitle), actions: [
        if (async.value != null && canControl && !const ['COMPLETED', 'CANCELLED', 'ACCEPTED'].contains(async.value!.status))
          PopupMenuButton<String>(
            onSelected: (v) => v == 'due' ? _changeDue(context, ref, async.value!) : _cancel(context, ref, async.value!),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'due', child: ListTile(leading: const Icon(Icons.event_rounded), title: Text(l.assignChangeDue), contentPadding: EdgeInsets.zero)),
              if (const ['DRAFT', 'READY_TO_DELIVER', 'DELIVERED', 'IN_PROGRESS', 'READY_FOR_PICKUP'].contains(async.value!.status))
                PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.cancel_rounded, color: Theme.of(context).colorScheme.error), title: Text(l.assignCancel), contentPadding: EdgeInsets.zero)),
            ],
          ),
      ]),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (a) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(assignmentDetailProvider(assignmentId)),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _Header(a: a),
            const SizedBox(height: 16),
            _StatusChip(status: a.status),
            const SizedBox(height: 16),
            if (a.status == 'READY_TO_DELIVER' && a.handoff != null) ...[_HandoffBlock(a: a), const SizedBox(height: 16)],
            _ProgressBlock(a: a),
            const SizedBox(height: 20),
            if (a.qrCode != null) _QrBlock(a: a),
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

Future<void> _changeDue(BuildContext context, WidgetRef ref, AssignmentDetail a) async {
  final now = DateTime.now();
  final picked = await showDatePicker(context: context, initialDate: a.dueAt?.toLocal() ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
  if (picked == null || !context.mounted) return;
  try {
    await ref.read(assignmentAdminRepositoryProvider).setDue(a.id, DateTime(picked.year, picked.month, picked.day, 18));
    ref.invalidate(assignmentDetailProvider(a.id));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> _cancel(BuildContext context, WidgetRef ref, AssignmentDetail a) async {
  final l = AppLocalizations.of(context);
  final reason = TextEditingController();
  var returned = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(l.assignCancel),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: reason, autofocus: true, maxLength: 500, decoration: InputDecoration(labelText: l.assignCancelReason)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: returned, onChanged: (v) => set(() => returned = v), title: Text(l.assignCancelReturned)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), onPressed: () => Navigator.pop(ctx, reason.text.trim().length >= 2), child: Text(l.assignCancel)),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(assignmentAdminRepositoryProvider).cancel(a.id, reason: reason.text.trim(), materialsReturned: returned);
    ref.invalidate(assignmentDetailProvider(a.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.assignCancelled)));
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = swatchColor(a.colorHex, a.colorName) ?? scheme.primary;
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
            Icon(Icons.person_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text('${a.workerName} · ${a.workerPhone}')),
          ]),
          if (a.dueAt != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.event_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('${a.dueAt!.day.toString().padLeft(2, '0')}.${a.dueAt!.month.toString().padLeft(2, '0')}.${a.dueAt!.year}'),
            ]),
          ],
          if (a.notes?.isNotEmpty == true) ...[const SizedBox(height: 6), Text(a.notes!, style: Theme.of(context).textTheme.bodySmall)],
        ]),
      ),
    );
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
      // before the check: what she will get for the planned metres; after it: what was really accrued
      if ((a.acceptedMeters > 0 ? a.calculatedPayment : a.expectedPayment ?? a.calculatedPayment) case final pay?) ...[
        const SizedBox(height: 12),
        Text('${l.assignSummaryPayment}: ${formatUzs(pay)} ${l.currency}', style: Theme.of(context).textTheme.titleSmall),
      ],
    ]);
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.a});
  final AssignmentDetail a;
  String get code => a.qrCode!;
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
          const SizedBox(height: 12),
          // the label goes on the kit: staff and worker both scan THIS code at the handoff
          PrintQrButton(code: code, title: '${a.productName} · ${a.colorName}', lines: [a.workerName, '${a.plannedMeters.toStringAsFixed(0)} м · ${a.code}']),
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
      Text(a.status == 'READY_TO_DELIVER' || a.status == 'DRAFT' ? l.materialsPrepared : l.materialsAtWorker, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final m in a.materials)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Align(alignment: Alignment.centerLeft, child: Text(materialLine(m.name, m.quantity, m.unit))),
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
      if (a.handoffTimeline.isNotEmpty) ...[
        Text(l.handoffTimelineTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final e in a.handoffTimeline.reversed) _TimelineRow(text: handoffTimelineText(l, e), at: e.at, problem: e.kind == 'WORKER_PROBLEM'),
        const SizedBox(height: 16),
      ],
      Text(l.assignmentHistory, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final h in a.statusHistory.reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle_rounded, size: 8, color: Theme.of(context).colorScheme.primary),
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
        // while she is confirming there is nothing for staff to press; after a problem / timeout: start again
        final h = a.handoff;
        button = h != null && h.waiting
            ? null
            : FilledButton.icon(
                onPressed: _busy ? null : () => _confirmDeliver(context),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text(h == null ? l.handoffStart : l.handoffRestart),
              );
      case 'READY_FOR_PICKUP':
        button = FilledButton.icon(onPressed: _busy ? null : () => _pickup(context), icon: const Icon(Icons.check_circle_outline_rounded), label: Text(l.workPickedUp));
      case 'UNDER_REVIEW':
        button = FilledButton.icon(
          onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AcceptanceScreen(assignment: a))),
          icon: const Icon(Icons.fact_check_rounded),
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
            Text(l.handoffStartTitle, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.handoffStartBody, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.handoffStart))),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(assignmentAdminRepositoryProvider).startHandoff(widget.a.id));
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

/// Phase 5.2/5.9: what the staff member at the door sees after «Начать передачу»: waiting -> she scanned -> received,
/// or her problem in plain words.
class _HandoffBlock extends StatelessWidget {
  const _HandoffBlock({required this.a});
  final AssignmentDetail a;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = a.handoff!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (IconData icon, Color color, String title, String? hint) = switch (h.status) {
      'AWAITING_WORKER' when h.expired => (Icons.timer_off_rounded, scheme.error, l.handoffExpiredLabel, null),
      'AWAITING_WORKER' when h.workerScannedAt != null => (Icons.phone_android_rounded, scheme.primary, l.handoffWorkerScanned, null),
      'AWAITING_WORKER' => (Icons.hourglass_top_rounded, scheme.primary, l.handoffWaiting, l.handoffWaitingHint),
      'PROBLEM' => (Icons.report_problem_rounded, scheme.error, l.handoffProblemTitle,
          [problemReasonText(l, h.problemReason), if (h.problemComment?.isNotEmpty == true) h.problemComment!].join(' · ')),
      _ => (Icons.check_circle_rounded, Colors.green, l.handoffReceived(a.workerName), null),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(children: [
        if (h.waiting) SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: color)) else Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (hint != null) ...[const SizedBox(height: 2), Text(hint, style: text.bodyMedium)],
          ]),
        ),
      ]),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.text, required this.at, this.problem = false});
  final String text;
  final DateTime at;
  final bool problem;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = at.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(problem ? Icons.error_rounded : Icons.check_circle_rounded, size: 16, color: problem ? scheme.error : scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text),
            Text('${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

String handoffTimelineText(AppLocalizations l, HandoffTimelineEntry e) => switch (e.kind) {
      'HANDOFF_STARTED' => l.timelineStarted(e.by ?? ''),
      'WORKER_SCANNED' => l.timelineScanned,
      'WORKER_CONFIRMED' => l.timelineConfirmed,
      'WORKER_PROBLEM' => '${l.timelineProblem}: ${problemReasonText(l, e.reason)}',
      _ => e.kind,
    };

String problemReasonText(AppLocalizations l, String? r) => switch (r) {
      'SHORTAGE' => l.problemShortage,
      'WRONG_COLOR' => l.problemWrongColor,
      'WRONG_MODEL' => l.problemWrongModel,
      'WRONG_METERS' => l.problemWrongMeters,
      'DAMAGED' => l.problemDamaged,
      _ => l.problemOther,
    };
