import '../core/notifications/app_notifications.dart';
import '../core/update/app_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/location/location_gate.dart';
import '../l10n/app_localizations.dart';

/// Staff shell (SUPER_ADMIN / ADMIN / MANAGER, D-028): bottom navigation + the live link to the NAS. Every tab is reachable
/// by every staff role; what each one actually shows (or whether it says "insufficient rights") is decided by permissions.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  void initState() {
    super.initState();
    // first sync as soon as the shell is on screen (cache shows instantly, then the delta arrives)
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    try {
      await ref.read(workerRepositoryProvider).refresh();
    } catch (_) {/* offline: the cache keeps working */}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // realtime hints -> refresh the cache (the API stays the source of truth)
    ref.listen(realtimeEventsProvider, (_, next) {
      final e = next.value;
      if (e == null) return;
      if (e.type == 'worker.deleted' && e.data['workerId'] is String) ref.read(workerRepositoryProvider).removeLocal(e.data['workerId'] as String);
      if (e.type.startsWith('worker.') || e.type.startsWith('collateral.')) _sync();
      if (e.type == 'worker.created' && e.data['status'] == 'PENDING_APPROVAL') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.newRegistration('${e.data['fullName'] ?? ''}')), action: SnackBarAction(label: l.tabPending, onPressed: () => widget.shell.goBranch(1))));
      }
    });
    // after a reconnect events may have been missed (no replay): refetch
    ref.listen(realtimeConnectedProvider, (_, next) {
      if (next.value == true) _sync();
    });

    return AdaptiveShell(
      shell: widget.shell,
      body: UpdateBanner(child: NoticeDelivery(child: LocationGate(child: widget.shell))),
      destinations: [
        (Icons.dashboard_rounded, Icons.dashboard_rounded, l.dashboardTab),
        (Icons.groups_rounded, Icons.groups_rounded, l.workers),
        (Icons.map_rounded, Icons.map_rounded, l.map),
        (Icons.inventory_2_rounded, Icons.inventory_2_rounded, l.inventory),
        (Icons.more_horiz_rounded, Icons.more_horiz_rounded, l.more),
      ],
    );
  }
}

/// WORKER shell: Catalog is the default screen (§18) — everything else (progress, earnings) arrives with M3–M5.
class WorkerShell extends StatelessWidget {
  const WorkerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdaptiveShell(
      shell: shell,
      body: UpdateBanner(child: NoticeDelivery(child: LocationGate(child: shell))),
      destinations: [
        (Icons.auto_awesome_rounded, Icons.auto_awesome_rounded, l.catalog),
        (Icons.home_rounded, Icons.home_rounded, l.home),
        (Icons.person_outline_rounded, Icons.person_rounded, l.profile),
      ],
    );
  }
}

/// Phone: bottom bar (labels hidden only on very narrow screens). Tablet (>= 600 dp): a side rail with every label
/// written out, widened to icon + text in landscape (>= 1000 dp), and the content kept to a readable width.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.shell, required this.body, required this.destinations});
  final StatefulNavigationShell shell;
  final Widget body;
  final List<(IconData, IconData, String)> destinations;

  static const tabletWidth = 600.0;
  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tabletWidth;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < tabletWidth) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          labelBehavior: width < 400 ? NavigationDestinationLabelBehavior.alwaysHide : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [for (final d in destinations) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
        ),
      );
    }
    final extended = width >= 1000;
    return Scaffold(
      body: Row(children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            key: const Key('tabletRail'),
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            extended: extended,
            minExtendedWidth: 200,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            groupAlignment: -0.9,
            destinations: [for (final d in destinations) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ]),
    );
  }
}
