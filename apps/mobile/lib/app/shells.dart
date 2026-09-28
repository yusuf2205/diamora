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

    return Scaffold(
      body: UpdateBanner(child: LocationGate(child: widget.shell)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_rounded), selectedIcon: const Icon(Icons.dashboard_rounded), label: l.dashboardTab),
          NavigationDestination(icon: const Icon(Icons.groups_rounded), selectedIcon: const Icon(Icons.groups_rounded), label: l.workers),
          NavigationDestination(icon: const Icon(Icons.map_rounded), selectedIcon: const Icon(Icons.map_rounded), label: l.map),
          NavigationDestination(icon: const Icon(Icons.inventory_2_rounded), selectedIcon: const Icon(Icons.inventory_2_rounded), label: l.inventory),
          NavigationDestination(icon: const Icon(Icons.more_horiz_rounded), selectedIcon: const Icon(Icons.more_horiz_rounded), label: l.more),
        ],
      ),
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
    return Scaffold(
      body: UpdateBanner(child: LocationGate(child: shell)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.auto_awesome_rounded), selectedIcon: const Icon(Icons.auto_awesome_rounded), label: l.catalog),
          NavigationDestination(icon: const Icon(Icons.home_rounded), selectedIcon: const Icon(Icons.home_rounded), label: l.home),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: l.profile),
        ],
      ),
    );
  }
}
