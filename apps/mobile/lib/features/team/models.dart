class TeamUser {
  const TeamUser({
    required this.id, required this.phone, required this.fullName, required this.role, required this.status,
    this.online = false, this.permissions = const [],
  });
  final String id;
  final String phone;
  final String fullName;
  final String role; // SUPER_ADMIN | ADMIN | MANAGER
  final String status; // ACTIVE | SUSPENDED
  final bool online;
  final List<String> permissions;
  bool get isActive => status == 'ACTIVE';

  factory TeamUser.fromJson(Map<String, dynamic> j) => TeamUser(
        id: j['id'] as String, phone: j['phone'] as String, fullName: j['fullName'] as String, role: j['role'] as String,
        status: j['status'] as String, online: j['online'] as bool? ?? false,
        permissions: ((j['permissions'] as List?) ?? const []).cast<String>(),
      );
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
