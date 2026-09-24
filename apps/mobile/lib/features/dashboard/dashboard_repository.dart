import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<StaffDashboard> get() async => StaffDashboard.fromJson(await _api.getJson('/dashboard'));
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(apiClientProvider)));

/// Refetched whenever anything that moves a dashboard number happens elsewhere in the app - cheap (small home
/// business), so no attempt to patch individual counters client-side.
final staffDashboardProvider = FutureProvider.autoDispose<StaffDashboard>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null &&
        (t.startsWith('worker.') || t.startsWith('assignment.') || t.startsWith('work.') || t.startsWith('delivery.') ||
            t.startsWith('collateral.') || t == 'quality.completed' || t == 'earning.created' || t == 'cash_payment.created')) {
      ref.invalidateSelf();
    }
  });
  return ref.watch(dashboardRepositoryProvider).get();
});
