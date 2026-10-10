import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../learn/learn_screen.dart' show TutorialPlayer;

/// GET /work/progress (apps/api/src/progress/progress.service.ts): her month, all time, records, the quality bonus and
/// every check of her work with the defect photos and the inspector's words.
final myProgressProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t == 'earning.created' || t == 'quality.completed' || t == 'worker.balance_updated') ref.invalidateSelf();
  });
  return (await ref.watch(apiClientProvider).getJson('/work/progress')).cast<String, dynamic>();
});

num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
String _m(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// «Мой прогресс» (owner, 2026-10-11): motivating, never comparing her with anyone by name.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(myProgressProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.progressTitle)),
      body: p.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(myProgressProvider.future),
          child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 32), children: [
            _MonthCard(d: d),
            if ((d['bonus'] as Map?)?['enabled'] == true) _BonusCard(bonus: (d['bonus'] as Map).cast<String, dynamic>(), month: (d['thisMonth'] as Map).cast<String, dynamic>()),
            _Calculator(ratePerKit: _n(d['ratePerKit']), kitMeters: _n(d['kitMeters']), bonus: (d['bonus'] as Map?)?.cast<String, dynamic>()),
            _AllTimeCard(all: (d['allTime'] as Map).cast<String, dynamic>()),
            const SizedBox(height: 20),
            Text(l.progressChecks, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if ((d['checks'] as List).isEmpty)
              EmptyState(icon: Icons.fact_check_outlined, title: l.progressNoChecks)
            else
              for (final c in (d['checks'] as List).cast<Map>()) _CheckCard(c: c.cast<String, dynamic>()),
          ]),
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.d});
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final m = (d['thisMonth'] as Map).cast<String, dynamic>();
    final best = (d['best'] as Map?)?.cast<String, dynamic>();
    final names = [l.m1, l.m2, l.m3, l.m4, l.m5, l.m6, l.m7, l.m8, l.m9, l.m10, l.m11, l.m12];
    final q = m['qualityPercent'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.progressThisMonth, style: text.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Stat(label: l.progressAccepted, value: '${_m(_n(m['acceptedMeters']))} м')),
            Expanded(child: _Stat(label: l.progressQuality, value: q == null ? '—' : '${_m(_n(q))}%')),
            Expanded(child: _Stat(label: l.progressEarned, value: formatUzs('${m['earned']}'))),
          ]),
          if (d['record'] == true) ...[
            const SizedBox(height: 12),
            Text(l.progressRecord, style: text.titleSmall?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.w800)),
          ] else if (best != null) ...[
            const SizedBox(height: 12),
            Text(l.progressBest(names[int.parse((best['month'] as String).substring(5)) - 1], _m(_n(best['meters']))), style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ]);
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.bonus, required this.month});
  final Map<String, dynamic> bonus;
  final Map<String, dynamic> month;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final yes = bonus['qualifies'] == true;
    final defect = _n(bonus['defectPercent']);
    final short = _n(bonus['minMeters']) - _n(month['acceptedMeters']);
    final status = yes
        ? l.bonusYes(formatUzs('${bonus['expected']}'))
        : defect > _n(bonus['maxDefectPercent'])
            ? l.bonusTooManyDefects(_m(defect))
            : l.bonusNeedMeters(_m(short > 0 ? short : 0));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: yes ? Colors.green.withValues(alpha: 0.10) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.emoji_events_rounded, color: yes ? Colors.amber.shade700 : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l.bonusQuality, style: text.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text(l.bonusRule('${bonus['percent']}', '${bonus['maxDefectPercent']}', '${bonus['minMeters']}'), style: text.bodySmall),
            const SizedBox(height: 10),
            Text(status, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: yes ? Colors.green.shade800 : null)),
            const SizedBox(height: 6),
            Text(l.bonusPaidOn1st, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// «Калькулятор заработка»: metres -> sum at the current rate (the server settles the real amount at acceptance).
class _Calculator extends StatefulWidget {
  const _Calculator({required this.ratePerKit, required this.kitMeters, this.bonus});
  final num ratePerKit;
  final num kitMeters;
  final Map<String, dynamic>? bonus;
  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  final _c = TextEditingController(text: '9');
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final meters = num.tryParse(_c.text.replaceAll(',', '.')) ?? 0;
    final sum = widget.kitMeters > 0 ? (widget.ratePerKit * meters / widget.kitMeters).floor() : 0;
    final b = widget.bonus;
    final bonus = b != null && b['enabled'] == true ? (sum * _n(b['percent']) / 100).floor() : 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.calculate_rounded), const SizedBox(width: 8), Text(l.calcTitle, style: text.titleMedium)]),
            const SizedBox(height: 12),
            TextField(
              key: const Key('calcMeters'),
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(labelText: l.calcHint, suffixText: 'м', border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final v in [9, 18, 27, 54, 90]) ActionChip(label: Text('$v м'), onPressed: () => setState(() => _c.text = '$v')),
            ]),
            const SizedBox(height: 12),
            Text(l.calcResult(formatUzs('$sum')), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (bonus > 0) Text(l.calcWithBonus(formatUzs('$bonus')), style: text.bodyMedium?.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.calcRate(formatUzs('${widget.ratePerKit}')), style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard({required this.all});
  final Map<String, dynamic> all;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = all['qualityPercent'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.progressAllTime, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat(label: l.progressAccepted, value: '${_m(_n(all['acceptedMeters']))} м')),
              Expanded(child: _Stat(label: l.progressQuality, value: q == null ? '—' : '${_m(_n(q))}%')),
            ]),
            const SizedBox(height: 8),
            Text(l.progressChecksCount('${all['checks']}'), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

/// One check of her work: what was accepted, the defects, the inspector's words and photos (tap to enlarge).
class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.c});
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final at = DateTime.tryParse('${c['at']}')?.toLocal();
    final defect = _n(c['defectiveMeters']), rework = _n(c['reworkMeters']);
    final bad = defect > 0 || rework > 0;
    final photos = ((c['photos'] as List?) ?? const []).cast<Map>();
    String two(int v) => v.toString().padLeft(2, '0');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(bad ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: bad ? scheme.error : Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('${c['product']} · ${c['color']}', style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (at != null) Text('${two(at.day)}.${two(at.month)}', style: text.bodySmall),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('${l.checkAccepted}: ${_m(_n(c['acceptedMeters']))} м', style: text.bodyMedium),
            if (defect > 0) Text('${l.checkDefective}: ${_m(defect)} м', style: text.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w700)),
            if (rework > 0) Text('${l.checkRework}: ${_m(rework)} м', style: text.bodyMedium?.copyWith(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
          ]),
          if ((c['comment'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: Text('«${c['comment']}»', style: text.bodyMedium),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _open(context, '${photos[i]['url']}'),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network('${photos[i]['thumbUrl']}', width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: scheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined)))),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _open(BuildContext context, String url) => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Center(child: InteractiveViewer(maxScale: 5, child: Image.network(url))),
            SafeArea(child: IconButton(color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx))),
          ]),
        ),
      );
}

/// «Мой прогресс» on her home screen: one tap away.
class ProgressEntryCard extends StatelessWidget {
  const ProgressEntryCard({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        key: const Key('openProgress'),
        leading: const Icon(Icons.insights_rounded),
        title: Text(l.progressTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(l.progressOpenHint),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/worker/progress'),
      ),
    );
  }
}

/// «Как шить»: the model's instruction video (asked for when tapped: the signed link is fresh).
Future<void> openHowToSew(BuildContext context, WidgetRef ref, String modelId, String title) async {
  try {
    final j = await ref.read(apiClientProvider).getJson('/work/models/$modelId/instruction');
    final url = (j['video'] as Map?)?['url'] as String?;
    if (url == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TutorialPlayer(title: title, url: url)));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
