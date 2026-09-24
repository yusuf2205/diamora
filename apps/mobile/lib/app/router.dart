import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/models.dart';
import '../features/auth/telegram_pending_screen.dart';
import '../features/catalog/admin_catalog_screen.dart';
import '../features/catalog/worker_catalog_screen.dart';
import '../features/dashboard/staff_dashboard_screen.dart';
import '../features/home/worker_home_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/map/map_screen.dart';
import '../features/more/more_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/qr/qr_scanner_screen.dart';
import '../features/settings/company_contact_screen.dart';
import '../features/settings/pay_rate_screen.dart';
import '../features/team/audit_screen.dart';
import '../features/team/locations_screen.dart';
import '../features/team/team_screen.dart';
import '../features/team/user_detail_screen.dart';
import '../features/work/assignment_detail_screen.dart';
import '../features/workers/admin_workers_screen.dart';
import '../features/workers/worker_detail_screen.dart';
import 'shells.dart';

/// Route table. Redirects are UX only — the server rejects anything the role may not do.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  // SUPER_ADMIN / ADMIN / MANAGER share the staff shell (D-028: what each tab shows is then filtered by permission);
  // WORKER's default screen is the catalog (§18), not a dashboard.
  String home(bool staff) => staff ? '/admin/dashboard' : '/worker/catalog';

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final s = auth.value;
      if (s == null) return (loc == '/login' || loc == '/telegram-pending') ? null : '/login';
      if (loc == '/login' || loc == '/splash') return home(s.isStaff);
      if (s.isStaff && loc.startsWith('/worker/')) return home(true);
      if (s.isWorker && loc.startsWith('/admin/')) return home(false);
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/telegram-pending',
        builder: (_, s) => TelegramPendingScreen(status: s.uri.queryParameters['status'] ?? 'ERROR', reason: s.uri.queryParameters['reason']),
      ),
      GoRoute(path: '/admin/qr-scan', builder: (_, _) => const QrScannerScreen()),
      GoRoute(path: '/admin/assignments/:id', builder: (_, s) => AssignmentDetailScreen(assignmentId: s.pathParameters['id']!)),
      // opened from «Ещё» (full screen, back arrow) rather than taking a bottom-bar slot each (§11)
      GoRoute(
        path: '/admin/catalog',
        builder: (_, _) => const AdminCatalogScreen(),
        routes: [GoRoute(path: ':id', builder: (_, s) => AdminCatalogDetailScreen(itemId: s.pathParameters['id']!))],
      ),
      GoRoute(
        path: '/admin/team',
        builder: (_, _) => const TeamScreen(),
        routes: [GoRoute(path: ':id', builder: (_, s) => UserDetailScreen(userId: s.pathParameters['id']!))],
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(path: 'pay-rate', builder: (_, _) => const PayRateScreen()),
          GoRoute(path: 'locations', builder: (_, _) => const LocationsScreen()),
          GoRoute(path: 'company-contact', builder: (_, _) => const CompanyContactScreen()),
          GoRoute(path: 'audit', builder: (_, _) => const AuditScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdminShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/admin/dashboard', builder: (_, _) => const StaffDashboardScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/workers',
              builder: (_, s) => AdminWorkersScreen(initialTab: switch (s.uri.queryParameters['tab']) { 'active' => 1, 'all' => 2, _ => 0 }),
              routes: [GoRoute(path: ':id', builder: (_, s) => WorkerDetailScreen(workerId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/inventory', builder: (_, _) => const InventoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/more', builder: (_, _) => const MoreScreen())]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => WorkerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/worker/catalog',
              builder: (_, _) => const WorkerCatalogScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => CatalogItemDetailScreen(itemId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/worker/home', builder: (_, _) => const WorkerHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/worker/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
  );

  // WORKER Telegram-only login (§): the App Link that follows the bot's handoff button. `getInitialLink` covers a
  // cold start (Diamoraa was closed); `uriLinkStream` covers it already running (foreground or background). On a
  // cold start some app_links versions deliver the SAME uri through both — a seen-tickets set makes the one-time
  // ticket exchange idempotent on the app side too, or the loser of that race would 401 and its stray
  // /telegram-pending?status=ERROR navigation could overwrite an otherwise-successful login. Both sides also go
  // through a platform channel that doesn't exist in widget tests (or could hiccup for any other reason) — never
  // let that take the whole app down, it's just one login path among others.
  final handledTickets = <String>{};
  try {
    final links = AppLinks();
    final sub = links.uriLinkStream.listen((uri) => handleTelegramLink(ref, router, uri, handledTickets), onError: (_) {});
    ref.onDispose(sub.cancel);
    links.getInitialLink().then((uri) {
      if (uri != null) handleTelegramLink(ref, router, uri, handledTickets);
    }).catchError((_) {});
  } catch (_) {
    /* no platform channel available (tests, or a platform app_links doesn't support) - the rest of the app still works */
  }

  return router;
});

/// `t=<ticket>` from the bot's handoff URL, whatever the exact path/host the OS routed here on (custom-scheme
/// fallback vs. the verified App Link) — a URL we didn't ask for is simply ignored, never acted on.
Future<void> handleTelegramLink(Ref ref, GoRouter router, Uri uri, Set<String> handledTickets) async {
  final ticket = uri.queryParameters['t'];
  if (ticket == null || ticket.isEmpty || !handledTickets.add(ticket)) return; // already seen this exact ticket
  try {
    final outcome = await ref.read(authControllerProvider.notifier).telegramExchange(ticket);
    if (outcome is TelegramNotReady) {
      router.go(Uri(path: '/telegram-pending', queryParameters: {'status': outcome.status, if (outcome.reason != null) 'reason': outcome.reason!}).toString());
    }
    // TelegramLoggedIn: the session change alone drives the router (refreshListenable) to the WORKER shell.
  } catch (_) {
    router.go('/telegram-pending?status=ERROR');
  }
}
