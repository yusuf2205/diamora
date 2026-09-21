import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/workers/worker_repository.dart';
import 'db/app_database.dart';
import 'network/api_client.dart';
import 'realtime/realtime_client.dart';
import 'storage/token_store.dart';

/// Overridden in main() once SharedPreferences is loaded.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      tokens: ref.watch(tokenStoreProvider),
      // a failed refresh = the session was revoked/expired -> back to the login screen
      onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
    ));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
final workerRepositoryProvider = Provider<WorkerRepository>((ref) => WorkerRepository(ref.watch(apiClientProvider), ref.watch(appDatabaseProvider), ref.watch(sharedPrefsProvider)));
final myProfileRepositoryProvider = Provider<MyProfileRepository>((ref) => MyProfileRepository(ref.watch(apiClientProvider)));

/// true = the phone has some network. Reachability of OUR server is discovered by the requests themselves.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => !r.contains(ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

// ---- realtime -------------------------------------------------------------------------------------------------------
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final c = RealtimeClient(ref.watch(tokenStoreProvider));
  ref.onDispose(() => c.disconnect());
  return c;
});

/// Every server event (docs/REALTIME.md). Screens listen and refetch; they never treat the payload as truth.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) => ref.watch(realtimeClientProvider).events);
final realtimeConnectedProvider = StreamProvider<bool>((ref) => ref.watch(realtimeClientProvider).connection);
