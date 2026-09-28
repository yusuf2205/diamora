import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../catalog/models.dart';
import 'create_assignment_screen.dart';
import 'receive_work_screens.dart';

const _uuid = Uuid();

/// «Заказать эту работу» (mirrors JobRequestsService.dto on the API).
class JobRequest {
  const JobRequest({
    required this.id, required this.status, required this.kitCount, required this.meters, required this.workerId, required this.workerName,
    this.workerPhone, this.productId, this.productName, this.variantId, this.colorName, this.colorHex, this.note, this.decisionNote, required this.createdAt,
  });
  final String id;
  /// PENDING | FULFILLED | REJECTED | CANCELLED
  final String status;
  final int kitCount;
  final int meters;
  final String workerId;
  final String workerName;
  final String? workerPhone;
  final String? productId;
  final String? productName;
  final String? variantId;
  final String? colorName;
  final String? colorHex;
  final String? note;
  final String? decisionNote;
  final DateTime createdAt;

  String get title => [productName, colorName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory JobRequest.fromJson(Map<String, dynamic> j) {
    final w = (j['worker'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (j['product'] as Map?)?.cast<String, dynamic>();
    final v = (j['variant'] as Map?)?.cast<String, dynamic>();
    final c = (j['color'] as Map?)?.cast<String, dynamic>();
    return JobRequest(
      id: j['id'] as String, status: j['status'] as String, kitCount: (j['kitCount'] as num).toInt(), meters: (j['meters'] as num).toInt(),
      workerId: w['id'] as String? ?? '', workerName: w['fullName'] as String? ?? '', workerPhone: w['phone'] as String?,
      productId: p?['id'] as String?, productName: p?['name'] as String?, variantId: v?['id'] as String?,
      colorName: c?['name'] as String?, colorHex: c?['hex'] as String?, note: j['note'] as String?, decisionNote: j['decisionNote'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

bool _touches(String? t) => t != null && (t.startsWith('job_request.') || t == 'assignment.created');

/// The worker's own requests, newest first.
final myJobRequestsProvider = FutureProvider.autoDispose<List<JobRequest>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) { if (_touches(next.value?.type)) ref.invalidateSelf(); });
  final j = await ref.watch(apiClientProvider).getJson('/work/requests');
  return ((j['items'] as List?) ?? const []).map((x) => JobRequest.fromJson((x as Map).cast<String, dynamic>())).toList();
});

/// Staff: open requests of the workers in the caller's scope (server-side), oldest first.
final staffJobRequestsProvider = FutureProvider.autoDispose<List<JobRequest>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) { if (_touches(next.value?.type)) ref.invalidateSelf(); });
  final j = await ref.watch(apiClientProvider).getJson('/admin/job-requests');
  return ((j['items'] as List?) ?? const []).map((x) => JobRequest.fromJson((x as Map).cast<String, dynamic>())).toList();
});

// ---- worker ------------------------------------------------------------------------------------------------------------------

/// Two big buttons at the top of her home screen — always there: pick new work, scan a kit QR.
class WorkerQuickActions extends StatelessWidget {
  const WorkerQuickActions({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(child: _Tile(icon: Icons.auto_awesome_rounded, label: l.chooseWork, color: scheme.primary, onColor: scheme.onPrimary,
          onTap: () => context.go('/worker/catalog'))),
      const SizedBox(width: 10),
      Expanded(child: _Tile(icon: Icons.qr_code_scanner_rounded, label: l.workScanQr, color: scheme.secondaryContainer, onColor: scheme.onSecondaryContainer,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReceiveScanScreen())))),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.color, required this.onColor, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 96,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 30, color: onColor),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 15, height: 1.15)),
              ),
            ]),
          ),
        ),
      );
}

/// Her latest request, if it still matters: waiting (with «Отменить заявку») or just declined (with the reason).
class MyJobRequestCard extends ConsumerWidget {
  const MyJobRequestCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final latest = ref.watch(myJobRequestsProvider).value?.firstOrNull;
    if (latest == null) return const SizedBox.shrink();
    final recentlyRejected = latest.status == 'REJECTED' && DateTime.now().difference(latest.createdAt).inDays < 3;
    if (latest.status != 'PENDING' && !recentlyRejected) return const SizedBox.shrink();
    final pending = latest.status == 'PENDING';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: pending ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.errorContainer.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(pending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded, color: pending ? scheme.primary : scheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(pending ? l.myRequestPending : l.myRequestRejected, style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 4),
            Text('${latest.title} · ${latest.meters} м'),
            Text(pending ? l.myRequestPendingHint : (latest.decisionNote ?? ''), style: Theme.of(context).textTheme.bodySmall),
            if (pending)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).postJson('/work/requests/${latest.id}/cancel', idempotencyKey: _uuid.v4());
                      ref.invalidate(myJobRequestsProvider);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  child: Text(l.myRequestCancel),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// «Заказать эту работу»: colour (her choice among the variants), 9/18/27 m, an optional wish. One tap to send.
class OrderWorkSheet extends ConsumerStatefulWidget {
  const OrderWorkSheet({super.key, required this.item});
  final CatalogItem item;
  @override
  ConsumerState<OrderWorkSheet> createState() => _OrderWorkSheetState();
}

class _OrderWorkSheetState extends ConsumerState<OrderWorkSheet> {
  late final List<CatalogVariant> _variants = widget.item.variants.where((v) => v.active && v.color != null).toList();
  late String? _variantId = _variants.length == 1 ? _variants.first.id : null;
  int _kitCount = 1;
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_variantId == null || _busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final note = _note.text.trim();
      await ref.read(apiClientProvider).postJson('/work/requests', idempotencyKey: _uuid.v4(), body: {'productVariantId': _variantId, 'kitCount': _kitCount, 'note': ?(note.isEmpty ? null : note)});
      ref.invalidate(myJobRequestsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e is ApiException && e.code == 'CONFLICT') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.orderAlreadyPending)));
      } else {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.item.name, style: text.titleLarge),
          const SizedBox(height: 16),
          Text(l.orderColor, style: text.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in _variants)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: hexColor(v.color!.hex) ?? Colors.grey, radius: 9),
                label: Text(v.label?.isNotEmpty == true ? '${v.color!.name} · ${v.label}' : v.color!.name),
                selected: _variantId == v.id,
                onSelected: _busy ? null : (_) => setState(() => _variantId = v.id),
              ),
          ]),
          const SizedBox(height: 16),
          Text(l.orderVolume, style: text.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: Text(l.workMeters9)),
              ButtonSegment(value: 2, label: Text(l.workMeters18)),
              ButtonSegment(value: 3, label: Text(l.workMeters27)),
            ],
            selected: {_kitCount},
            onSelectionChanged: _busy ? null : (s) => setState(() => _kitCount = s.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: _note, maxLength: 500, decoration: InputDecoration(labelText: l.orderNote)),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _variantId == null || _busy ? null : _send,
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(l.orderSend, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---- staff -------------------------------------------------------------------------------------------------------------------

/// On the staff overview: «Заявки на работу: N» — one tap to the list. Hidden when there are none.
class JobRequestsBanner extends ConsumerWidget {
  const JobRequestsBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(staffJobRequestsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: scheme.primaryContainer,
        child: ListTile(
          leading: Icon(Icons.shopping_bag_rounded, color: scheme.onPrimaryContainer),
          title: Text(l.jobRequestsCount(items.length), style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
          subtitle: Text(items.take(2).map((r) => r.workerName).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JobRequestsScreen())),
        ),
      ),
    );
  }
}

/// «Заявки на работу»: who wants what; «Подготовить работу» opens the usual wizard already filled in, or «Отклонить».
class JobRequestsScreen extends ConsumerWidget {
  const JobRequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(staffJobRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.jobRequestsTitle)),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.inbox_rounded, title: l.jobRequestsEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(staffJobRequestsProvider),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  for (final r in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.workerName, style: Theme.of(context).textTheme.titleMedium),
                          if (r.workerPhone != null) Text(r.workerPhone!, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Row(children: [
                            CircleAvatar(radius: 7, backgroundColor: hexColor(r.colorHex) ?? Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${r.title} · ${r.meters} м', style: const TextStyle(fontWeight: FontWeight.w600))),
                          ]),
                          if (r.note?.isNotEmpty == true) ...[const SizedBox(height: 4), Text('«${r.note}»', style: Theme.of(context).textTheme.bodyMedium)],
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: FitButton(
                                kind: FitKind.filled,
                                height: AppTokens.buttonHeight,
                                icon: Icons.add_task_rounded,
                                label: l.actionAssign,
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CreateAssignmentScreen(request: r))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(onPressed: () => _reject(context, ref, r), child: Text(l.reject)),
                          ]),
                        ]),
                      ),
                    ),
                ]),
              ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, JobRequest r) async {
    final l = AppLocalizations.of(context);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reject),
        content: TextField(controller: reason, autofocus: true, maxLength: 500, decoration: InputDecoration(labelText: l.jobRequestRejectReason)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.reject)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final note = reason.text.trim();
      await ref.read(apiClientProvider).postJson('/admin/job-requests/${r.id}/reject', idempotencyKey: _uuid.v4(), body: {'note': ?(note.isEmpty ? null : note)});
      ref.invalidate(staffJobRequestsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
