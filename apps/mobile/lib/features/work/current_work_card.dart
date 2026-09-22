import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/company_contact.dart';
import '../settings/pay_rate.dart';
import 'models.dart';
import 'work_repository.dart';

/// M3 §8: "understand your current job in one look" — photo-less for now (product photos are catalog media, a nice-to-have
/// wiring left for a follow-up), but everything else the brief asks for: product, colour, planned/done metres, progress
/// bar, deadline, expected earning, and the three actions a worker actually needs, each 1 tap away.
class CurrentWorkCard extends ConsumerWidget {
  const CurrentWorkCard({super.key, required this.work});
  final CurrentWork work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rate = ref.watch(payRateProvider).value;
    final ratePerKit = rate != null ? int.tryParse(rate.ratePerKit) : null;
    final expected = ratePerKit != null ? (ratePerKit * work.plannedMeters / 9).round() : null;
    final inProgress = work.status == 'IN_PROGRESS';
    final color = _hexColor(work.colorHex) ?? scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(work.variantLabel?.isNotEmpty == true ? '${work.productName} · ${work.variantLabel}' : work.productName, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text('${work.colorName} · ${work.kitCount == 1 ? l.workMeters9 : work.kitCount == 2 ? l.workMeters18 : l.workMeters27}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _StatusChip(status: work.status),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(l.workDoneOf(work.reportedMeters.toStringAsFixed(1), work.plannedMeters.toStringAsFixed(0)), style: Theme.of(context).textTheme.bodyMedium),
            Text('${work.percent.round()}%', style: Theme.of(context).textTheme.labelLarge),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: work.percent / 100, minHeight: 8)),
          const SizedBox(height: 16),
          if (work.dueAt != null) _InfoRow(icon: Icons.event_outlined, label: l.workDueDate, value: _formatDate(work.dueAt!)),
          if (expected != null) _InfoRow(icon: Icons.payments_outlined, label: l.workExpectedEarning, value: '${formatUzs(expected.toString())} ${l.currency}'),
          if (work.materials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.workMaterials, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(work.materials.map((m) => m.quantity.toStringAsFixed(m.quantity.truncateToDouble() == m.quantity ? 0 : 2)).join(' · '), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          if (inProgress) ...[
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _reportProgress(context, ref), icon: const Icon(Icons.trending_up), label: Text(l.workUpdateProgress))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _markReady(context, ref), icon: const Icon(Icons.check_circle_outline), label: Text(l.workReady))),
            const SizedBox(height: 10),
          ],
          SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => _reportProblem(context, ref), icon: const Icon(Icons.report_problem_outlined), label: Text(l.workProblem))),
        ]),
      ),
    );
  }

  Future<void> _reportProgress(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: work.reportedMeters > 0 ? work.reportedMeters.toStringAsFixed(1) : '');
    final value = await showModalBottomSheet<double>(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.workUpdateProgress, style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l.workDoneOf('0', work.plannedMeters.toStringAsFixed(0)), style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.workMetersDone, suffixText: 'м', border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: () { final v = double.tryParse(controller.text.replaceAll(',', '.')); if (v != null && v >= 0 && v <= work.plannedMeters) Navigator.pop(ctx, v); }, child: Text(l.save)),
        ]),
      ),
    );
    if (value == null) return;
    await ref.read(workRepositoryProvider).reportProgress(work.id, reportedMeters: value.toStringAsFixed(2));
    ref.invalidate(currentWorkProvider);
  }

  Future<void> _markReady(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.workReady),
        content: Text(l.workReadyConfirm(work.plannedMeters.toStringAsFixed(0))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.workReady)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workRepositoryProvider).markReady(work.id, readyMeters: work.plannedMeters.toStringAsFixed(2));
    ref.invalidate(currentWorkProvider);
  }

  Future<void> _reportProblem(BuildContext context, WidgetRef ref) async {
    final contact = await ref.read(companyContactProvider.future);
    if (!context.mounted) return;
    if ((contact.telegramUrl ?? '').isEmpty && (contact.phone ?? '').isEmpty) return;
    if ((contact.telegramUrl ?? '').isNotEmpty) {
      final appUri = Uri.parse(contact.telegramUrl!.replaceFirst('https://t.me/', 'tg://resolve?domain='));
      if (await canLaunchUrl(appUri)) { await launchUrl(appUri); return; }
      await launchUrl(Uri.parse(contact.telegramUrl!), mode: LaunchMode.externalApplication);
    } else if ((contact.phone ?? '').isNotEmpty) {
      await launchUrl(Uri.parse('tel:${contact.phone}'));
    }
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'READY_TO_DELIVER' => (l.workStatusReadyToDeliver, scheme.tertiary),
      'DELIVERED' => (l.workStatusDelivered, scheme.tertiary),
      'IN_PROGRESS' => (l.workStatusInProgress, scheme.primary),
      'READY_FOR_PICKUP' => (l.workStatusReadyForPickup, scheme.secondary),
      'PICKED_UP' => (l.workStatusPickedUp, scheme.secondary),
      'UNDER_REVIEW' => (l.workStatusUnderReview, scheme.secondary),
      _ => (status, scheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      );
}
