import '../../core/ui/navigate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../map/map_screen.dart' show positionAgeLabel;
import 'models.dart';
import 'team_repository.dart';
import 'team_screen.dart' show teamRoleLabel;

/// Live locations (D-030, §23-26). A real map (Yandex MapKit) is planned for M4; this list already carries every field
/// a map marker would need (role, code, coordinates, staleness) and is scoped server-side exactly like the future map.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rows = ref.watch(liveLocationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.locations)),
      body: rows.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: errorText(context, e)),
        data: (all) {
          // live positions only: workers shown at home (no live position) belong on the map, not in this list
          final list = all.where((r) => !r.isHome).toList();
          return list.isEmpty
            ? EmptyState(icon: Icons.location_searching_rounded, title: l.locationsEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(liveLocationsProvider),
                child: ListView.separated(
                  padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(row: list[i]),
                ),
              );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final LiveLocationRow row;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // LIVE / RECENT / STALE (M2 §17): a RECENT or STALE point is never worded as if it were happening right now.
    final age = positionAgeLabel(l, row.freshness, row.ageSeconds, compact: true);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dot = switch (row.freshness) { LocationFreshness.live => AppTokens.ok, LocationFreshness.recent => Colors.orange, _ => scheme.outline };
    // no ListTile: its fixed leading/trailing columns squeezed long names into broken words on 320 dp phones
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.fullName, style: text.titleMedium),
              const SizedBox(height: 2),
              Text([teamRoleLabel(l, row.role), if (row.workerCode != null) row.workerCode!].join(' · '), style: text.bodySmall),
              const SizedBox(height: 2),
              Text(age, style: text.bodyMedium?.copyWith(color: row.stale ? scheme.error : null, fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(
            tooltip: l.route,
            icon: const Icon(Icons.directions_rounded),
            onPressed: () => openRoute(row.latitude, row.longitude),
          ),
        ]),
      ),
    );
  }
}
