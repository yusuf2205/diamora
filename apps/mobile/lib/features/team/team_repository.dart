import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'models.dart';

const _uuid = Uuid();

/// Users, roles, managers, live locations, audit (D-028/D-030). Every write is a critical, server-confirmed action -
/// nothing here is ever queued offline.
class TeamRepository {
  TeamRepository(this._api);
  final ApiClient _api;

  Future<List<TeamUser>> users() async => ((await _api.getJson('/users', query: {'limit': 200}))['items'] as List).map((j) => TeamUser.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<Map<String, Object?>> createUser({required String phone, required String fullName, required String role}) =>
      _api.postJson('/users', idempotencyKey: _uuid.v4(), body: {'phone': phone, 'fullName': fullName, 'role': role});

  Future<void> setStatus(String userId, bool active) => _api.postJson('/users/$userId/status', idempotencyKey: _uuid.v4(), body: {'status': active ? 'ACTIVE' : 'SUSPENDED'});

  Future<List<ManagerSummary>> managers() async => ((await _api.getJson('/managers'))['items'] as List).map((j) => ManagerSummary.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<List<AuditEntry>> audit() async => ((await _api.getJson('/audit', query: {'limit': 100}))['items'] as List).map((j) => AuditEntry.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<List<LiveLocationRow>> locations() async => ((await _api.getJson('/locations'))['items'] as List)
      .where((j) => (j as Map)['latitude'] != null)
      .map((j) => LiveLocationRow.fromJson((j as Map).cast<String, dynamic>()))
      .toList();
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) => TeamRepository(ref.watch(apiClientProvider)));

final teamUsersProvider = FutureProvider.autoDispose<List<TeamUser>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('user.') ?? false) ref.invalidateSelf();
  });
  return ref.watch(teamRepositoryProvider).users();
});

final managersProvider = FutureProvider.autoDispose<List<ManagerSummary>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('user.') || t == 'worker.manager_changed')) ref.invalidateSelf();
  });
  return ref.watch(teamRepositoryProvider).managers();
});

final auditProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) => ref.watch(teamRepositoryProvider).audit());

final liveLocationsProvider = FutureProvider.autoDispose<List<LiveLocationRow>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t == 'user.location.updated' || t == 'worker.location.updated' || t == 'user.presence_changed') ref.invalidateSelf();
  });
  return ref.watch(teamRepositoryProvider).locations();
});
