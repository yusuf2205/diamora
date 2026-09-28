import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../team/team_screen.dart' show shortDate;

// ---- data ------------------------------------------------------------------------------------------------------------

final ratingProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, months) async =>
    ((await ref.watch(apiClientProvider).getJson('/admin/reports/rating', query: {'months': months}))['items'] as List).cast<Map<String, dynamic>>());

final profitProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ((await ref.watch(apiClientProvider).getJson('/admin/finance/profit', query: {'months': 6}))['items'] as List).cast<Map<String, dynamic>>());

final stockValueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(apiClientProvider).getJson('/admin/stock/value'));

final financeEntriesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, kind) async =>
    ((await ref.watch(apiClientProvider).getJson('/admin/finance/$kind', query: {'limit': 20}))['items'] as List).cast<Map<String, dynamic>>());

final systemStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(apiClientProvider).getJson('/admin/system/status'));

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
String _money(AppLocalizations l, Object? v) => '${formatUzs(v?.toString())} ${l.currency}';

// ---- «Рейтинг мастериц» ------------------------------------------------------------------------------------------------

/// Who sews the most, with the fewest defects, on time — a score out of 100, best first.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});
  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _months = 3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(ratingProvider(_months));
    return Scaffold(
      appBar: AppBar(title: Text(l.ratingTitle)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 1, label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.reportMonth))),
              ButtonSegment(value: 3, label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.ratingThreeMonths))),
              ButtonSegment(value: 6, label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.ratingHalfYear))),
            ],
            selected: {_months},
            onSelectionChanged: (s) => setState(() => _months = s.first),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(),
            error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
            data: (items) => items.isEmpty
                ? EmptyState(icon: Icons.emoji_events_rounded, title: l.reportEmpty)
                : ListView.separated(
                    padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == items.length) return Text(l.ratingHowScored, style: Theme.of(context).textTheme.bodySmall);
                      final r = items[i];
                      final w = (r['worker'] as Map).cast<String, dynamic>();
                      final score = (r['score'] as num).toInt();
                      final color = score >= 75 ? AppTokens.ok : score >= 50 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: Key('rating-${w['id']}'),
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(w['fullName'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(l.ratingLine(_n(r['acceptedMeters'] as num), _n(r['defectRate'] as num), (r['late'] as num).toInt(), (r['withDeadline'] as num).toInt()), maxLines: 2),
                          trailing: Text('$score', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
                          onTap: () => context.push('/admin/workers/${w['id']}'),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

// ---- «Прибыль» ----------------------------------------------------------------------------------------------------------

/// Sales − paid for work − materials at purchase price − expenses, per month; what the warehouse is worth; entry of
/// sales and expenses.
class ProfitScreen extends ConsumerWidget {
  const ProfitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profit = ref.watch(profitProvider);
    final stock = ref.watch(stockValueProvider);
    final sales = ref.watch(financeEntriesProvider('sales'));
    final expenses = ref.watch(financeEntriesProvider('expenses'));
    final text = Theme.of(context).textTheme;
    final months = [l.m1, l.m2, l.m3, l.m4, l.m5, l.m6, l.m7, l.m8, l.m9, l.m10, l.m11, l.m12];
    String monthName(String k) => '${months[int.parse(k.split('-')[1]) - 1]} ${k.split('-')[0]}';

    return Scaffold(
      appBar: AppBar(title: Text(l.profitTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('profitAdd'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.profitAdd),
        onPressed: () => _addEntry(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profitProvider);
          ref.invalidate(stockValueProvider);
        },
        child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 96), children: [
          ...profit.when(
            loading: () => [const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e))],
            data: (items) => [
              for (final m in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: AppTokens.cardPadding,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(monthName(m['month'] as String), style: text.titleMedium)),
                        Text(_money(l, m['profit']), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: (m['profit'] as String).startsWith('-') ? Theme.of(context).colorScheme.error : AppTokens.ok)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${l.profitSales}: ${_money(l, m['sales'])}', style: text.bodySmall),
                      Text('${l.profitLabor}: −${_money(l, m['labor'])}', style: text.bodySmall),
                      Text('${l.profitMaterials}: −${_money(l, m['materials'])}${(m['materialsWithoutPrice'] as num) > 0 ? ' *' : ''}', style: text.bodySmall),
                      Text('${l.profitExpenses}: −${_money(l, m['expenses'])}', style: text.bodySmall),
                    ]),
                  ),
                ),
              if (items.any((m) => (m['materialsWithoutPrice'] as num) > 0)) Text(l.profitNoPriceHint, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (stock.value case final s?)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: AppTokens.cardPadding,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.stockValueTitle, style: text.bodySmall),
                  Text(_money(l, s['total']), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(l.stockValueSplit(_money(l, s['warehouse']), _money(l, s['withWorkers'])), style: text.bodySmall),
                  if ((s['withoutPrice'] as List).isNotEmpty)
                    Text(l.stockValueNoPrice((s['withoutPrice'] as List).map((m) => (m as Map)['name']).join(', ')), style: text.bodySmall),
                ]),
              ),
            ),
          _EntriesCard(title: l.profitSales, kind: 'sales', async: sales),
          _EntriesCard(title: l.profitExpenses, kind: 'expenses', async: expenses),
        ]),
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    var kind = 'sales';
    var category = 'DELIVERY_FUEL';
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(l.profitAdd),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [ButtonSegment(value: 'sales', label: Text(l.profitSale)), ButtonSegment(value: 'expenses', label: Text(l.profitExpense))],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(key: const Key('profitAmount'), controller: amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: '${l.payoutAmountLabel}, ${l.currency}'), onChanged: (_) => set(() {})),
              const SizedBox(height: 8),
              if (kind == 'expenses')
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: l.profitExpense),
                  items: [
                    DropdownMenuItem(value: 'DELIVERY_FUEL', child: Text(l.expenseFuel)),
                    DropdownMenuItem(value: 'PACKAGING', child: Text(l.expensePackaging)),
                    DropdownMenuItem(value: 'OTHER', child: Text(l.expenseOther)),
                  ],
                  onChanged: (v) => category = v ?? category,
                ),
              TextField(controller: note, decoration: InputDecoration(labelText: kind == 'sales' ? l.profitCustomer : l.commentOptional)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              key: const Key('profitSave'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: (int.tryParse(amount.text) ?? 0) > 0 ? () => Navigator.pop(ctx, true) : null,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final text = note.text.trim();
    try {
      await ref.read(apiClientProvider).postJson('/admin/finance/$kind', idempotencyKey: const Uuid().v4(), body: kind == 'sales'
          ? {'total': amount.text, if (text.isNotEmpty) 'customer': text}
          : {'amount': amount.text, 'category': category, if (text.isNotEmpty) 'comment': text});
      ref.invalidate(profitProvider);
      ref.invalidate(financeEntriesProvider(kind));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _EntriesCard extends ConsumerWidget {
  const _EntriesCard({required this.title, required this.kind, required this.async});
  final String title;
  final String kind;
  final AsyncValue<List<Map<String, dynamic>>> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = async.value ?? const [];
    String label(Map<String, dynamic> e) => kind == 'sales'
        ? [e['customer'] as String?, shortDate(DateTime.parse(e['date'] as String).toLocal())].whereType<String>().join(' · ')
        : [switch (e['category']) { 'DELIVERY_FUEL' => l.expenseFuel, 'PACKAGING' => l.expensePackaging, _ => l.expenseOther }, e['comment'] as String?, shortDate(DateTime.parse(e['date'] as String).toLocal())].whereType<String>().join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: AppTokens.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (items.isEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.queueEmpty, style: Theme.of(context).textTheme.bodySmall)),
          for (final e in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_money(l, e[kind == 'sales' ? 'total' : 'amount'])),
              subtitle: Text(label(e), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: l.deleteAction,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  if (!await confirmDelete(context, title: l.deleteAction, body: l.profitDeleteConfirm) || !context.mounted) return;
                  try {
                    await ref.read(apiClientProvider).deleteJson('/admin/finance/$kind/${e['id']}');
                    ref.invalidate(profitProvider);
                    ref.invalidate(financeEntriesProvider(kind));
                  } catch (err) {
                    if (context.mounted) showError(context, err);
                  }
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ---- «Состояние системы» -----------------------------------------------------------------------------------------------

/// Is everything up, and when did each backup last succeed. Refreshes on pull.
class SystemStatusScreen extends ConsumerWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(systemStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.systemTitle)),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (s) {
          final db = (s['database'] as Map).cast<String, dynamic>();
          final redis = (s['redis'] as Map).cast<String, dynamic>();
          final backups = (s['backups'] as List).cast<Map<String, dynamic>>();
          final jobs = {'pg_dump': l.backupDaily, 'pg_basebackup': l.backupWeekly, 'minio_mirror': l.backupFiles, 'config': l.backupConfig, 'verify': l.backupVerify, 'restore': l.backupRestore};
          Widget row(String title, bool ok, String detail, {String? okText}) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? AppTokens.ok : Theme.of(context).colorScheme.error),
                title: Text(title),
                subtitle: detail.isEmpty ? null : Text(detail),
                trailing: Text(okText ?? (ok ? l.systemOk : l.systemDown), style: TextStyle(color: ok ? AppTokens.ok : Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
              );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(systemStatusProvider),
            child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    row(l.systemServer, true, [if (s['version'] != null) '${s['version']}', l.systemUptime(((s['uptimeSeconds'] as num) / 3600).floor())].join(' · ')),
                    row(l.systemDatabase, db['ok'] == true, [if (db['size'] != null) '${db['size']}', if (db['ms'] != null) '${db['ms']} ms'].join(' · ')),
                    row('Redis', redis['ok'] == true, redis['ms'] != null ? '${redis['ms']} ms' : ''),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text(l.systemBackups, style: Theme.of(context).textTheme.titleSmall),
              if (s['backupsVisible'] != true) Text(l.systemBackupsHidden, style: Theme.of(context).textTheme.bodySmall),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    for (final b in backups)
                      () {
                        final at = b['at'] == null ? null : DateTime.parse(b['at'] as String).toLocal();
                        final hours = at == null ? 1e9 : DateTime.now().difference(at).inMinutes / 60;
                        final limit = b['job'] == 'pg_basebackup' ? 8 * 24 : b['job'] == 'restore' ? 1e9 : 26;
                        final ok = b['ok'] == true && hours <= limit;
                        final when = at == null ? '—' : '${shortDate(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                        return row(jobs[b['job']] ?? b['job'] as String, ok, when, okText: b['ok'] != true ? l.systemBackupFailed : ok ? l.systemOk : l.systemBackupLate);
                      }(),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
