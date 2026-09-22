import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
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
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.location_searching, title: l.locationsEmpty)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(liveLocationsProvider),
                child: ListView.separated(
                  padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(row: list[i]),
                ),
              ),
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
    final minutes = row.ageSeconds ~/ 60;
    final age = switch (row.freshness) {
      LocationFreshness.live => l.locationJustNow,
      LocationFreshness.recent => l.locationRecentMinutes(minutes),
      LocationFreshness.stale => l.locationStaleMinutes(minutes),
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: row.stale ? Theme.of(context).colorScheme.surfaceContainerHighest : AppTokens.ok.withValues(alpha: 0.15),
          child: Icon(Icons.place_outlined, color: row.stale ? null : AppTokens.ok),
        ),
        title: Text(row.fullName),
        subtitle: Text('${teamRoleLabel(l, row.role)}${row.workerCode != null ? ' · ${row.workerCode}' : ''}${row.online ? ' · ${l.onlineNow}' : ''} · ${row.latitude.toStringAsFixed(4)}, ${row.longitude.toStringAsFixed(4)}'),
        trailing: Text(age, style: TextStyle(color: row.stale ? Theme.of(context).colorScheme.error : null)),
      ),
    );
  }
}
