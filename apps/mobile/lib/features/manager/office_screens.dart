import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';

// ---- «Общий поиск» ----------------------------------------------------------------------------------------------------
/// One line that finds workers, works, customer orders, materials, models and staff (GET /admin/search; each kind only
/// if the viewer may see it - the server decides).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  Future<Map<String, dynamic>>? _result;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = v.trim();
      setState(() => _result = q.length < 2 ? null : ref.read(apiClientProvider).getJson('/admin/search', query: {'q': q}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('globalSearch'),
          controller: _q,
          autofocus: true,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l.searchHint, border: InputBorder.none, filled: false),
        ),
        actions: [if (_q.text.isNotEmpty) IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _q.clear(); _changed(''); })],
      ),
      body: _result == null
          ? EmptyState(icon: Icons.search_rounded, title: l.searchHint, hint: l.searchExplain)
          : FutureBuilder<Map<String, dynamic>>(
              future: _result,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
                if (snap.hasError) return EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, snap.error!));
                final r = snap.data!;
                List<Map<String, dynamic>> list(String k) => ((r[k] as List?) ?? const []).cast<Map>().map((x) => x.cast<String, dynamic>()).toList();
                final sections = <Widget>[
                  ..._section(context, l.workers, Icons.people_alt_rounded, list('workers'), (x) => ('${x['fullName']}', '${x['code']} · ${x['phone']}'), (x) => '/admin/workers/${x['id']}'),
                  ..._section(context, l.searchWorks, Icons.content_cut_rounded, list('works'), (x) => ('${x['worker']} · ${x['product']}', '${x['code']} · ${x['plannedMeters']} м'), (x) => '/admin/assignments/${x['id']}'),
                  ..._section(context, l.ordersTitle, Icons.shopping_bag_rounded, list('orders'), (x) => ('${x['name']}', '${x['code']} · ${x['phone']}'), (_) => '/admin/orders'),
                  ..._section(context, l.searchMaterials, Icons.inventory_2_rounded, list('materials'), (x) => ('${x['name']}', ''), (_) => '/admin/inventory'),
                  ..._section(context, l.catalog, Icons.auto_awesome_rounded, list('models'), (x) => ('${x['name']}', '${x['code']}'), (x) => '/admin/catalog/${x['id']}'),
                  ..._section(context, l.team, Icons.badge_rounded, list('staff'), (x) => ('${x['fullName']}', '${x['phone']}'), (x) => '/admin/team/${x['id']}'),
                ];
                if (sections.isEmpty) return EmptyState(icon: Icons.search_off_rounded, title: l.searchNothing);
                return ListView(padding: AppTokens.screenPadding.copyWith(top: 4, bottom: 24), children: sections);
              },
            ),
    );
  }

  List<Widget> _section(BuildContext context, String title, IconData icon, List<Map<String, dynamic>> rows, (String, String) Function(Map<String, dynamic>) text, String Function(Map<String, dynamic>) link) {
    if (rows.isEmpty) return const [];
    return [
      Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 4), child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary))),
      for (final x in rows)
        Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(text(x).$1, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: text(x).$2.isEmpty ? null : Text(text(x).$2, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => context.push(link(x)),
          ),
        ),
    ];
  }
}

// ---- «Деньги» ----------------------------------------------------------------------------------------------------------
final moneyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type ?? '';
    if (t == 'earning.created' || t == 'cash_payment.created' || t == 'worker.balance_updated') ref.invalidateSelf();
  });
  return ref.watch(apiClientProvider).getJson('/admin/money');
});

/// Owed to workers, this month and the last: earned (with bonuses), paid, sales, materials, expenses, profit - one screen.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final m = ref.watch(moneyProvider);
    final names = [l.m1, l.m2, l.m3, l.m4, l.m5, l.m6, l.m7, l.m8, l.m9, l.m10, l.m11, l.m12];
    String sum(Object? v) => '${formatUzs('${v ?? 0}')} ${l.currency}';
    Widget row(String label, Object? v, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text(sum(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
          ]),
        );
    Widget month(Map<String, dynamic> x, bool profit) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(names[int.parse((x['month'] as String).substring(5)) - 1], style: text.titleMedium),
              const SizedBox(height: 6),
              row(l.moneyEarned, x['earned']),
              if ((int.tryParse('${x['bonus']}') ?? 0) > 0) row(l.bonusQuality, x['bonus']),
              row(l.moneyPaid, x['paid']),
              if (profit) ...[
                const Divider(),
                row(l.moneySales, x['sales']),
                row(l.moneyMaterials, x['materials']),
                row(l.moneyExpenses, x['expenses']),
                row(l.moneyProfit, x['profit'], bold: true, color: (int.tryParse('${x['profit']}') ?? 0) < 0 ? Theme.of(context).colorScheme.error : Colors.green.shade800),
              ],
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.moneyTitle)),
      body: m.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (d) {
          final owed = (d['owed'] as Map).cast<String, dynamic>();
          final profit = d['profitVisible'] == true;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(moneyProvider.future),
            child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.moneyOwed, style: text.titleMedium),
                    Text(sum(owed['total']), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(l.moneyOwedWorkers('${owed['workers']}'), style: text.bodySmall),
                    for (final w in ((owed['top'] as List?) ?? const []).cast<Map>())
                      InkWell(
                        onTap: () => context.push('/admin/workers/${w['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [Expanded(child: Text('${w['fullName']}', maxLines: 1, overflow: TextOverflow.ellipsis)), Text(sum(w['balance']))]),
                        ),
                      ),
                  ]),
                ),
              ),
              month((d['thisMonth'] as Map).cast<String, dynamic>(), profit),
              month((d['lastMonth'] as Map).cast<String, dynamic>(), profit),
            ]),
          );
        },
      ),
    );
  }
}
