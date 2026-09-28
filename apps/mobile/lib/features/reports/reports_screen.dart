import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';

typedef ReportKey = ({String period, int offset});

final reportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ReportKey>((ref, k) {
  return ref.watch(apiClientProvider).getJson('/admin/reports', query: {'period': k.period, 'offset': k.offset});
});

/// «Отчёт»: day / week / month — issued, accepted, earned, paid, overdue, per worker, and what is running low.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, this.period = 'week', this.offset = 0});
  final String period;
  final int offset;
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late String _period = widget.period;
  late int _offset = widget.offset;

  String _range(Map<String, dynamic> r) {
    String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    final from = DateTime.parse(r['from'] as String).add(const Duration(hours: 5));
    final to = DateTime.parse(r['to'] as String).add(const Duration(hours: 5)).subtract(const Duration(days: 1));
    return _period == 'day' ? d(from) : '${d(from)} — ${d(to)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(reportProvider((period: _period, offset: _offset)));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.reportsTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'day', label: Text(l.reportDay)),
            ButtonSegment(value: 'week', label: Text(l.reportWeek)),
            ButtonSegment(value: 'month', label: Text(l.reportMonth)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() { _period = s.first; _offset = 0; }),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(tooltip: l.back, icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _offset--)),
          Expanded(child: Center(child: Text(async.hasValue ? _range(async.value!) : '…', style: text.titleMedium))),
          IconButton(tooltip: l.next, icon: const Icon(Icons.chevron_right_rounded), onPressed: _offset >= 0 ? null : () => setState(() => _offset++)),
        ]),
        const SizedBox(height: 8),
        ...async.when(
          loading: () => [const SizedBox(height: 320, child: SkeletonList(count: 3))],
          error: (e, _) => [EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e))],
          data: (r) {
            final t = (r['total'] as Map).cast<String, dynamic>();
            final rows = ((r['rows'] as List?) ?? const []).cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
            final low = (r['lowStock'] as List?)?.cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
            String m(num v) => v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
            Widget stat(String label, String value, {Color? color}) => Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: text.bodySmall),
                      const SizedBox(height: 4),
                      Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
                    ]),
                  ),
                );
            return [
              // two per row, height follows the text (a fixed aspect ratio cut big sums on small phones)
              LayoutBuilder(builder: (context, c) => Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  stat(l.reportIssued, '${t['issuedCount']} · ${m(t['issuedMeters'] as num)} м'),
                  stat(l.reportAccepted, '${m(t['acceptedMeters'] as num)} м'),
                  stat(l.earningsEarned, '${formatUzs(t['earned'] as String)} ${l.currency}'),
                  stat(l.earningsPaid, '${formatUzs(t['paid'] as String)} ${l.currency}'),
                  if ((t['overdue'] as num) > 0) stat(l.reportOverdue, '${t['overdue']}', color: scheme.error),
                  if ((t['defectiveMeters'] as num) > 0) stat(l.reportDefective, '${m(t['defectiveMeters'] as num)} м', color: scheme.error),
                ].map((w) => SizedBox(width: (c.maxWidth - 8) / 2, child: w)).toList(),
              )),
              const SizedBox(height: 16),
              Text(l.reportByWorker, style: text.titleMedium),
              const SizedBox(height: 8),
              if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l.reportEmpty, style: text.bodyMedium)),
              for (final x in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((x['worker'] as Map)['fullName'] as String, style: text.titleSmall),
                      const SizedBox(height: 4),
                      Text('${l.reportAccepted}: ${m(x['acceptedMeters'] as num)} м · ${l.reportIssued}: ${m(x['issuedMeters'] as num)} м', style: text.bodyMedium),
                      Text('${l.earningsEarned}: ${formatUzs(x['earned'] as String)} · ${l.earningsPaid}: ${formatUzs(x['paid'] as String)}', style: text.bodyMedium),
                      if ((x['overdue'] as num) > 0) Text('${l.reportOverdue}: ${x['overdue']}', style: text.bodyMedium?.copyWith(color: scheme.error)),
                    ]),
                  ),
                ),
              if (low != null && low.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l.reportLowStock, style: text.titleMedium),
                const SizedBox(height: 8),
                for (final s in low)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
                      title: Text(s['name'] as String),
                      subtitle: Text('${m(s['quantity'] as num)} / ${m(s['minStock'] as num)}'),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(l.reportExcelHint, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ];
          },
        ),
      ]),
    );
  }
}

/// «Мои заработки по месяцам» on the worker's home (self only).
final myMonthsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t == 'earning.created' || t == 'cash_payment.created') ref.invalidateSelf();
  });
  final j = await ref.watch(apiClientProvider).getJson('/work/earnings/monthly');
  return ((j['items'] as List?) ?? const []).cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
});

class MyMonthsCard extends ConsumerWidget {
  const MyMonthsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final months = ref.watch(myMonthsProvider).value;
    if (months == null || months.every((m) => (m['acceptedMeters'] as num) == 0 && m['earned'] == '0' && m['paid'] == '0')) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final names = [l.m1, l.m2, l.m3, l.m4, l.m5, l.m6, l.m7, l.m8, l.m9, l.m10, l.m11, l.m12];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.myMonthsTitle, style: text.titleMedium),
            const SizedBox(height: 8),
            for (final m in months)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 72, child: Text(names[int.parse((m['month'] as String).substring(5)) - 1], style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                  Expanded(child: Text('${(m['acceptedMeters'] as num).toStringAsFixed(0)} м', style: text.bodyMedium)),
                  Text('${formatUzs(m['earned'] as String)} ${l.currency}', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
