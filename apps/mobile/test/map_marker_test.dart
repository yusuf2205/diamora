import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusmus_mobile/core/theme/app_theme.dart';
import 'package:yusmus_mobile/features/map/map_screen.dart';
import 'package:yusmus_mobile/features/team/models.dart';
import 'package:yusmus_mobile/l10n/app_localizations_ru.dart';

LiveLocationRow row({required String role, required LocationFreshness freshness, int ageSeconds = 0}) => LiveLocationRow(
      userId: 'u1', role: role, fullName: 'Тест', latitude: 41.3, longitude: 69.2, ageSeconds: ageSeconds,
      stale: freshness == LocationFreshness.stale, freshness: freshness,
    );

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  final l = AppLocalizationsRu();

  group('markerColor (M2 §14-17): role first, freshness second — a STALE point is never coloured as live', () {
    test('a STALE point is always the neutral "outline" colour, whatever the role', () {
      for (final role in ['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'WORKER']) {
        expect(markerColor(row(role: role, freshness: LocationFreshness.stale), scheme), scheme.outline, reason: role);
      }
    });

    test('SUPER_ADMIN/ADMIN share the primary colour; MANAGER gets tertiary; a LIVE worker gets the "ok" green', () {
      expect(markerColor(row(role: 'SUPER_ADMIN', freshness: LocationFreshness.live), scheme), scheme.primary);
      expect(markerColor(row(role: 'ADMIN', freshness: LocationFreshness.recent), scheme), scheme.primary);
      expect(markerColor(row(role: 'MANAGER', freshness: LocationFreshness.live), scheme), scheme.tertiary);
      expect(markerColor(row(role: 'WORKER', freshness: LocationFreshness.live), scheme), AppTokens.ok);
      expect(markerColor(row(role: 'WORKER', freshness: LocationFreshness.recent), scheme), scheme.secondary);
    });
  });

  group('freshnessLabel: never words a RECENT/STALE point as if it were happening right now', () {
    test('LIVE says "now"; RECENT/STALE carry the actual age in minutes', () {
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.live, ageSeconds: 30)), l.locationJustNow);
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.recent, ageSeconds: 300)), l.locationRecentMinutes(5));
      expect(freshnessLabel(l, row(role: 'WORKER', freshness: LocationFreshness.stale, ageSeconds: 1200)), l.locationStaleMinutes(20));
    });
  });
}
