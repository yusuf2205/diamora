import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// «Цель месяца» (no money - the owner's decision): the goal in metres, how far she is, her place this month, badges.
class MonthGoal {
  const MonthGoal({required this.goalMeters, required this.personal, required this.doneMeters, this.leftMeters, this.percent, required this.daysLeft, this.place, required this.of, required this.badges});
  final int goalMeters;
  final bool personal;
  final double doneMeters;
  final double? leftMeters;
  final int? percent;
  final int daysLeft;
  final int? place;
  final int of;
  final List<GoalBadge> badges;
  factory MonthGoal.fromJson(Map<String, dynamic> j) => MonthGoal(
        goalMeters: (j['goalMeters'] as num).toInt(),
        personal: j['personal'] as bool? ?? false,
        doneMeters: (j['doneMeters'] as num).toDouble(),
        leftMeters: (j['leftMeters'] as num?)?.toDouble(),
        percent: (j['percent'] as num?)?.toInt(),
        daysLeft: (j['daysLeft'] as num?)?.toInt() ?? 0,
        place: (j['place'] as num?)?.toInt(),
        of: (j['of'] as num?)?.toInt() ?? 0,
        badges: ((j['badges'] as List?) ?? const []).map((b) => GoalBadge.fromJson((b as Map).cast<String, dynamic>())).toList(),
      );
}

class GoalBadge {
  const GoalBadge({required this.code, required this.title, required this.hint, required this.earned});
  final String code;
  final String title;
  final String hint;
  final bool earned;
  factory GoalBadge.fromJson(Map<String, dynamic> j) =>
      GoalBadge(code: j['code'] as String, title: j['title'] as String, hint: j['hint'] as String? ?? '', earned: j['earned'] as bool? ?? false);
}

final myGoalProvider = FutureProvider.autoDispose<MonthGoal>((ref) async => MonthGoal.fromJson(await ref.watch(apiClientProvider).getJson('/work/goal')));

String _m(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

const _badgeIcons = <String, IconData>{
  'first_kit': Icons.flag_rounded,
  'm100': Icons.military_tech_rounded,
  'm500': Icons.emoji_events_rounded,
  'goal': Icons.track_changes_rounded,
  'no_defects': Icons.verified_rounded,
  'on_time': Icons.schedule_rounded,
};

class GoalCard extends ConsumerWidget {
  const GoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ref.watch(myGoalProvider).maybeWhen(
          data: (g) {
            final done = g.goalMeters > 0 && (g.leftMeters ?? 1) <= 0;
            return Card(
              key: const Key('goalCard'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(done ? Icons.celebration_rounded : Icons.track_changes_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.goalTitle, style: text.titleMedium)),
                    if (g.place != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text(l.goalPlace(g.place!, g.of), style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  if (g.goalMeters > 0) ...[
                    Text(l.goalProgress(_m(g.doneMeters), g.goalMeters), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(key: const Key('goalBar'), value: (g.percent ?? 0) / 100, minHeight: 12, backgroundColor: scheme.surfaceContainerHighest),
                    ),
                    const SizedBox(height: 8),
                    Text(done ? l.goalDone : l.goalLeft(_m(g.leftMeters ?? 0), g.daysLeft), style: text.bodyMedium?.copyWith(color: done ? scheme.primary : scheme.onSurfaceVariant, fontWeight: done ? FontWeight.w700 : null)),
                  ] else
                    Text(l.goalNoGoal(_m(g.doneMeters)), style: text.titleMedium),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final b in g.badges)
                      Tooltip(
                        message: b.hint,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Container(
                          key: Key('badge-${b.code}'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: b.earned ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_badgeIcons[b.code] ?? Icons.star_rounded, size: 18, color: b.earned ? scheme.primary : scheme.outline),
                            const SizedBox(width: 6),
                            Text(b.title, style: TextStyle(fontWeight: FontWeight.w600, color: b.earned ? scheme.onPrimaryContainer : scheme.outline)),
                          ]),
                        ),
                      ),
                  ]),
                ]),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
