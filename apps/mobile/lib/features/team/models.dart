class TeamUser {
  const TeamUser({
    required this.id, required this.phone, required this.fullName, required this.role, required this.status,
    this.online = false, this.permissions = const [], this.lastSeenAt, this.lastLoginAt, this.createdAt, this.workerId, this.managerName,
    this.locationHidden = false,
  });
  final String id;
  final String phone;
  final String fullName;
  final String role; // SUPER_ADMIN | ADMIN | MANAGER | WORKER
  final String status; // ACTIVE | SUSPENDED
  final bool online;
  final List<String> permissions;
  final DateTime? lastSeenAt;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final String? workerId; // set for WORKER accounts: her card lives at /admin/workers/:workerId
  final String? managerName;
  final bool locationHidden;
  bool get isActive => status == 'ACTIVE';
  bool get isWorker => role == 'WORKER';
  /// The best "last seen" we know: presence heartbeat, else the last sign-in.
  DateTime? get seenAt => lastSeenAt ?? lastLoginAt;

  factory TeamUser.fromJson(Map<String, dynamic> j) => TeamUser(
        id: j['id'] as String, phone: j['phone'] as String, fullName: j['fullName'] as String, role: j['role'] as String,
        status: j['status'] as String, online: j['online'] as bool? ?? false,
        permissions: ((j['permissions'] as List?) ?? const []).cast<String>(),
        lastSeenAt: DateTime.tryParse(j['lastSeenAt'] as String? ?? ''), lastLoginAt: DateTime.tryParse(j['lastLoginAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''), workerId: j['workerId'] as String?, managerName: j['managerName'] as String?,
        locationHidden: j['locationHidden'] as bool? ?? false,
      );
}

/// One user's card: the user plus how their permissions are made up (role defaults vs. per-user overrides).
class UserDetail {
  const UserDetail({required this.user, required this.defaults, required this.effective});
  final TeamUser user;
  final List<String> defaults;
  final List<String> effective;
  factory UserDetail.fromJson(Map<String, dynamic> j) {
    final pd = (j['permissionDetail'] as Map?) ?? const {};
    return UserDetail(
      user: TeamUser.fromJson(j),
      defaults: ((pd['defaults'] as List?) ?? const []).cast<String>(),
      effective: ((pd['effective'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// What may be granted to each adjustable role (`GET /permissions`) - the server re-checks every save anyway.
class PermissionCatalog {
  const PermissionCatalog({required this.all, required this.grantable, required this.roleDefaults});
  final List<String> all;
  final Map<String, List<String>> grantable;
  final Map<String, List<String>> roleDefaults;
  /// Everything that makes sense to show as a switch for this role: its defaults plus what can be added.
  List<String> editableFor(String role) {
    final set = {...?roleDefaults[role], ...?grantable[role]};
    return all.where(set.contains).toList();
  }

  factory PermissionCatalog.fromJson(Map<String, dynamic> j) {
    Map<String, List<String>> m(Object? v) => ((v as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as List).cast<String>()));
    return PermissionCatalog(all: (j['permissions'] as List).cast<String>(), grantable: m(j['grantable']), roleDefaults: m(j['roleDefaults']));
  }
}

class ManagerSummary {
  const ManagerSummary({required this.user, required this.assignedWorkers});
  final TeamUser user;
  final int assignedWorkers;
  factory ManagerSummary.fromJson(Map<String, dynamic> j) => ManagerSummary(
        user: TeamUser.fromJson(j),
        assignedWorkers: (j['stats'] as Map?)?['workers'] as int? ?? 0,
      );
}

class AuditEntry {
  const AuditEntry({required this.id, required this.action, required this.entity, this.entityId, this.actorId, this.actorRole, required this.createdAt});
  final String id;
  final String action;
  final String entity;
  final String? entityId;
  final String? actorId;
  final String? actorRole;
  final String createdAt;
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String, action: j['action'] as String, entity: j['entity'] as String, entityId: j['entityId'] as String?,
        actorId: j['actorId'] as String?, actorRole: j['actorRole'] as String?, createdAt: j['createdAt'] as String,
      );
}

/// LIVE (< 2 min) / RECENT (2-10 min) / STALE (past that) — mirrors `locationFreshness()` in packages/shared (M2 §17).
/// Never presented to the user as if a RECENT/STALE point were happening right now.
enum LocationFreshness { live, recent, stale }

LocationFreshness _freshnessOf(String? raw, bool stale) => switch (raw) {
      'LIVE' => LocationFreshness.live,
      'RECENT' => LocationFreshness.recent,
      'STALE' => LocationFreshness.stale,
      _ => stale ? LocationFreshness.stale : LocationFreshness.live,
    };

class LiveLocationRow {
  const LiveLocationRow({
    required this.userId, required this.role, required this.fullName, this.workerId, this.workerCode, this.phone,
    this.managerId, required this.latitude, required this.longitude, required this.ageSeconds, required this.stale,
    this.freshness = LocationFreshness.stale, this.online = false,
  });
  final String userId;
  final String role;
  final String fullName;
  final String? workerId;
  final String? workerCode;
  final String? phone;
  final String? managerId;
  final double latitude;
  final double longitude;
  final int ageSeconds;
  final bool stale;
  final LocationFreshness freshness;
  final bool online;
  factory LiveLocationRow.fromJson(Map<String, dynamic> j) => LiveLocationRow(
        userId: j['userId'] as String, role: j['role'] as String, fullName: j['fullName'] as String,
        workerId: (j['worker'] as Map?)?['id'] as String?, workerCode: (j['worker'] as Map?)?['code'] as String?,
        phone: j['phone'] as String?, managerId: (j['worker'] as Map?)?['managerId'] as String?,
        latitude: (j['latitude'] as num).toDouble(), longitude: (j['longitude'] as num).toDouble(),
        ageSeconds: (j['ageSeconds'] as num).toInt(), stale: j['stale'] as bool? ?? false,
        freshness: _freshnessOf(j['freshness'] as String?, j['stale'] as bool? ?? false), online: j['online'] as bool? ?? false,
      );
}
