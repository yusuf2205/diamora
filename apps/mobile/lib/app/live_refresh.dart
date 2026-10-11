import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../core/providers.dart';
import '../features/catalog/catalog_repository.dart';
import '../features/dashboard/dashboard_repository.dart';
import '../features/goals/goal_card.dart';
import '../features/insights/insights_screens.dart';
import '../features/inventory/inventory_repository.dart';
import '../features/manager/manager_tools.dart';
import '../features/manager/office_screens.dart';
import '../features/manager/visit_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/company_contact.dart';
import '../features/settings/pay_rate.dart';
import '../features/team/team_repository.dart';
import '../features/work/assignment_admin_repository.dart';
import '../features/work/create_assignment_screen.dart';
import '../features/work/job_requests.dart';
import '../features/work/work_repository.dart';
import '../features/workers/add_worker_sheet.dart';
import '../features/workers/collaterals_screen.dart';
import '../features/workers/visit_time.dart';
import '../features/workers/workers_providers.dart' as workers;

/// «Всё в реальном времени» (owner, 2026-10-11): whatever the server says changed - a work, a payment, a goal, stock, a
/// person's role, an order - every screen's data refetches by itself, like the web panel. Events are only hints, so the
/// rule is simple: something happened -> refresh what is open (an unused provider costs nothing). Bursts are merged
/// (one refresh per 0.8 s). Chat, «печатает…» and presence keep their own, finer listeners. After a reconnect (events
/// may have been missed) everything refreshes too.
final liveRefreshProvider = Provider<void>((ref) {
  Timer? pending;
  void refresh() {
    for (final p in <ProviderOrFamily>[
      publishedCatalogProvider, publishedItemProvider, staffCatalogProvider, staffCatalogItemProvider,
      staffDashboardProvider, myGoalProvider,
      ratingProvider, profitProvider, stockValueProvider, financeEntriesProvider,
      materialsProvider, materialCategoriesProvider, kitTemplatesProvider,
      idleWorkersProvider, remindersProvider, awayProvider, moneyProvider, visitWorksProvider,
      clientOrdersProvider, myProgressProvider, reportProvider, myMonthsProvider,
      companyContactProvider, payRateProvider, payRateHistoryProvider,
      teamUsersProvider, userDetailProvider, userAuditProvider, managersProvider, auditProvider, liveLocationsProvider,
      assignmentDetailProvider, assignmentListProvider, workerLedgerProvider, workerSuggestProvider,
      myJobRequestsProvider, staffJobRequestsProvider, currentWorkProvider, myEarningsProvider,
      workerInvitesProvider, collateralsProvider, myVisitTimeProvider,
      workers.workerDetailProvider, workers.myProfileProvider, workers.myCollateralProvider,
    ]) {
      ref.invalidate(p);
    }
  }

  void soon() => pending ??= Timer(const Duration(milliseconds: 800), () {
        pending = null;
        refresh();
      });

  ref.listen(realtimeEventsProvider, (_, next) {
    final type = next.value?.type;
    if (type == null || type.startsWith('chat.') || type == 'user.presence_changed') return;
    soon();
  });
  ref.listen(realtimeConnectedProvider, (prev, next) {
    if (next.value == true && prev?.value == false) soon(); // back online: what was missed
  });
  ref.onDispose(() => pending?.cancel());
});
