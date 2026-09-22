import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/catalog/admin_catalog_screen.dart';
import '../features/catalog/worker_catalog_screen.dart';
import '../features/home/worker_home_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/qr/qr_scanner_screen.dart';
import '../features/settings/company_contact_screen.dart';
import '../features/settings/pay_rate_screen.dart';
import '../features/team/audit_screen.dart';
import '../features/team/locations_screen.dart';
import '../features/team/team_screen.dart';
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
  String home(bool staff) => staff ? '/admin/workers' : '/worker/catalog';

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final s = auth.value;
      if (s == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return home(s.isStaff);
      if (s.isStaff && loc.startsWith('/worker/')) return home(true);
      if (s.isWorker && loc.startsWith('/admin/')) return home(false);
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/admin/qr-scan', builder: (_, _) => const QrScannerScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdminShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/workers',
              builder: (_, _) => const AdminWorkersScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => WorkerDetailScreen(workerId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/catalog',
              builder: (_, _) => const AdminCatalogScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => AdminCatalogDetailScreen(itemId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/inventory', builder: (_, _) => const InventoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/team', builder: (_, _) => const TeamScreen())]),
          StatefulShellBranch(routes: [
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
          ]),
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
});
