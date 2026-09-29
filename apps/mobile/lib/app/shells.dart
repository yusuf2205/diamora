import '../core/notifications/app_notifications.dart';
import '../core/update/app_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/chat/chat_repository.dart';
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
      fullWidthBranches: const {2}, // the map uses the whole screen
      body: UpdateBanner(child: NoticeDelivery(child: LocationGate(child: widget.shell))),
      destinations: [
        (Icons.dashboard_rounded, Icons.dashboard_rounded, l.dashboardTab),
        (Icons.groups_rounded, Icons.groups_rounded, l.workers),
        (Icons.map_rounded, Icons.map_rounded, l.map),
        (Icons.inventory_2_rounded, Icons.inventory_2_rounded, l.inventory),
        (Icons.forum_outlined, Icons.forum_rounded, l.chat),
        (Icons.more_horiz_rounded, Icons.more_horiz_rounded, l.more),
      ],
      badges: {4: ref.watch(chatUnreadProvider).value ?? 0},
    );
  }
}

/// WORKER shell: Catalog is the default screen (§18) — everything else (progress, earnings) arrives with M3–M5.
class WorkerShell extends ConsumerWidget {
  const WorkerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return AdaptiveShell(
      shell: shell,
      body: UpdateBanner(child: NoticeDelivery(child: LocationGate(child: shell))),
      destinations: [
        (Icons.auto_awesome_rounded, Icons.auto_awesome_rounded, l.catalog),
        (Icons.home_rounded, Icons.home_rounded, l.home),
        (Icons.forum_outlined, Icons.forum_rounded, l.chat),
        (Icons.person_outline_rounded, Icons.person_rounded, l.profile),
      ],
      badges: {2: ref.watch(chatUnreadProvider).value ?? 0},
    );
  }
}

/// Phone: bottom bar (labels hidden only on very narrow screens). Tablet (>= 600 dp): a side rail with large icons and
/// every label written out (icon + text side by side in landscape, >= 1000 dp); the screens get roomier spacing, a bit
/// larger text, and are kept to a readable width in the middle (except [fullWidthBranches], e.g. the map).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.shell, required this.body, required this.destinations, this.fullWidthBranches = const {}, this.badges = const {}});
  final StatefulNavigationShell shell;
  final Widget body;
  final List<(IconData, IconData, String)> destinations;
  final Set<int> fullWidthBranches;
  /// a number on a tab's icon (unread chat messages); 0 = no badge
  final Map<int, int> badges;

  Widget _icon(int i, IconData icon) {
    final n = badges[i] ?? 0;
    return n > 0 ? Badge(key: Key('tabBadge-$i'), label: Text(n > 99 ? '99+' : '$n'), child: Icon(icon)) : Icon(icon);
  }

  static const contentMaxWidth = 960.0;

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
          destinations: [for (final (i, d) in destinations.indexed) NavigationDestination(icon: _icon(i, d.$1), selectedIcon: _icon(i, d.$2), label: d.$3)],
        ),
      );
    }
    final extended = width >= 1000;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(fontSize: 15);
    final full = fullWidthBranches.contains(shell.currentIndex);
    return Scaffold(
      body: Row(children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            key: const Key('tabletRail'),
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            extended: extended,
            minWidth: 96,
            minExtendedWidth: 232,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            groupAlignment: -0.85,
            selectedIconTheme: IconThemeData(size: 30, color: theme.colorScheme.onSecondaryContainer),
            unselectedIconTheme: IconThemeData(size: 30, color: theme.colorScheme.onSurfaceVariant),
            selectedLabelTextStyle: labelStyle?.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelTextStyle: labelStyle,
            destinations: [
              for (final (i, d) in destinations.indexed)
                NavigationRailDestination(
                  icon: _icon(i, d.$1),
                  selectedIcon: _icon(i, d.$2),
                  label: Text(d.$3),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Theme(
            data: tabletTheme(theme),
            child: MediaQuery(
              // a tablet is held further away: slightly larger text everywhere
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1) * 1.12)),
              child: full
                  ? body
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: contentMaxWidth), child: body),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Roomier spacing on a tablet: cards and list rows breathe, buttons and fields are taller.
ThemeData tabletTheme(ThemeData t) => t.copyWith(
      cardTheme: t.cardTheme.copyWith(margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4)),
      listTileTheme: t.listTileTheme.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), minVerticalPadding: 12),
      appBarTheme: t.appBarTheme.copyWith(titleSpacing: 24, toolbarHeight: 64),
      inputDecorationTheme: t.inputDecorationTheme.copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18)),
      iconTheme: t.iconTheme.copyWith(size: 26),
    );
