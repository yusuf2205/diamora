import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';

/// ADMIN shell: bottom navigation + the live link to the NAS. New tabs (map, QR, warehouse, finance) are added per milestone.
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
      if (e.type.startsWith('worker.') || e.type.startsWith('collateral.')) _sync();
      if (e.type == 'worker.created') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.newRegistration('${e.data['fullName'] ?? ''}')), action: SnackBarAction(label: l.tabPending, onPressed: () => widget.shell.goBranch(0))));
      }
    });
    // after a reconnect events may have been missed (no replay): refetch
    ref.listen(realtimeConnectedProvider, (_, next) {
      if (next.value == true) _sync();
    });

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: l.workers),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.profile),
        ],
      ),
    );
  }
}

/// WORKER shell: deliberately minimal. Home / Work / Earnings / New work / Profile arrive with M3–M5.
class WorkerShell extends StatelessWidget {
  const WorkerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l.home),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.profile),
        ],
      ),
    );
  }
}
