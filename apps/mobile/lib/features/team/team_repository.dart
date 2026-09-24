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

  /// Filtered and searched on the server (role / status / name-or-phone), so the list stays correct past one page.
  Future<List<TeamUser>> users([UsersFilter f = const UsersFilter()]) async => ((await _api.getJson('/users', query: {
        'limit': 100,
        if (f.role != null) 'role': f.role,
        if (f.status != null) 'status': f.status,
        if (f.query.trim().isNotEmpty) 'q': f.query.trim(),
      }))['items'] as List)
          .map((j) => TeamUser.fromJson((j as Map).cast<String, dynamic>()))
          .toList();

  Future<UserDetail> user(String id) async => UserDetail.fromJson(await _api.getJson('/users/$id'));

  Future<PermissionCatalog> permissionCatalog() async => PermissionCatalog.fromJson(await _api.getJson('/permissions'));

  /// Full replacement: `grant` = switched on beyond the role defaults, `revoke` = defaults switched off.
  Future<UserDetail> setPermissions(String userId, {required List<String> grant, required List<String> revoke}) async =>
      UserDetail.fromJson(await _api.putJson('/users/$userId/permissions', body: {'grant': grant, 'revoke': revoke}));

  Future<String> resetPassword(String userId) async =>
      (await _api.postJson('/users/$userId/reset-password', idempotencyKey: _uuid.v4()))['temporaryPassword'] as String;

  Future<List<AuditEntry>> userAudit(String userId) async =>
      ((await _api.getJson('/audit', query: {'entityId': userId, 'limit': 100}))['items'] as List).map((j) => AuditEntry.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<Map<String, Object?>> createUser({required String phone, required String fullName, required String role}) =>
      _api.postJson('/users', idempotencyKey: _uuid.v4(), body: {'phone': phone, 'fullName': fullName, 'role': role});

  Future<void> setStatus(String userId, bool active) => _api.postJson('/users/$userId/status', idempotencyKey: _uuid.v4(), body: {'status': active ? 'ACTIVE' : 'SUSPENDED'});

  Future<TeamUser> updateUser(String userId, {required String fullName, required String phone}) async =>
      TeamUser.fromJson(await _api.patchJson('/users/$userId', body: {'fullName': fullName, 'phone': phone}));

  Future<TeamUser> changeRole(String userId, String role) async => TeamUser.fromJson(await _api.putJson('/users/$userId/role', body: {'role': role}));

  Future<List<ManagerSummary>> managers() async => ((await _api.getJson('/managers'))['items'] as List).map((j) => ManagerSummary.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<List<AuditEntry>> audit() async => ((await _api.getJson('/audit', query: {'limit': 100}))['items'] as List).map((j) => AuditEntry.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<List<LiveLocationRow>> locations() async => ((await _api.getJson('/locations'))['items'] as List)
      .where((j) => (j as Map)['latitude'] != null)
      .map((j) => LiveLocationRow.fromJson((j as Map).cast<String, dynamic>()))
      .toList();
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) => TeamRepository(ref.watch(apiClientProvider)));

class UsersFilter {
  const UsersFilter({this.role, this.status, this.query = ''});
  final String? role;
  final String? status;
  final String query;
  @override
  bool operator ==(Object other) => other is UsersFilter && other.role == role && other.status == status && other.query == query;
  @override
  int get hashCode => Object.hash(role, status, query);
}

bool _touchesUsers(String? t) => t != null && (t.startsWith('user.') || t.startsWith('worker.'));

final teamUsersProvider = FutureProvider.autoDispose.family<List<TeamUser>, UsersFilter>((ref, f) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (_touchesUsers(next.value?.type)) ref.invalidateSelf();
  });
  return ref.watch(teamRepositoryProvider).users(f);
});

final userDetailProvider = FutureProvider.autoDispose.family<UserDetail, String>((ref, id) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final e = next.value;
    if (e != null && e.type.startsWith('user.') && (e.data['userId'] == null || e.data['userId'] == id)) ref.invalidateSelf();
  });
  return ref.watch(teamRepositoryProvider).user(id);
});

final permissionCatalogProvider = FutureProvider.autoDispose<PermissionCatalog>((ref) => ref.watch(teamRepositoryProvider).permissionCatalog());

final userAuditProvider = FutureProvider.autoDispose.family<List<AuditEntry>, String>((ref, id) => ref.watch(teamRepositoryProvider).userAudit(id));

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
