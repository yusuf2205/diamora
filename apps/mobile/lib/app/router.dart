import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/home/worker_home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/pay_rate_screen.dart';
import '../features/workers/admin_workers_screen.dart';
import '../features/workers/worker_detail_screen.dart';
import 'shells.dart';

/// Route table. Redirects are UX only — the server rejects anything the role may not do.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String home(bool admin) => admin ? '/admin/workers' : '/worker/home';

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final s = auth.value;
      if (s == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return home(s.isAdmin);
      if (s.isAdmin && loc.startsWith('/worker/')) return home(true);
      if (s.isWorker && loc.startsWith('/admin/')) return home(false);
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
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
              path: '/admin/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [GoRoute(path: 'pay-rate', builder: (_, _) => const PayRateScreen())],
            ),
          ]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => WorkerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/worker/home', builder: (_, _) => const WorkerHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/worker/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});
