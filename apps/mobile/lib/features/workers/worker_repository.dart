import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/network/api_client.dart';
import 'models.dart';

const _uuid = Uuid();
const _lastSyncKey = 'workers_last_sync';

/// ADMIN side: reads come from the local cache (offline-first), writes ALWAYS go to the server (approval and collateral
/// are critical operations that need server confirmation — D-022). Every write uses an Idempotency-Key.
class WorkerRepository {
  WorkerRepository(this._api, this._db, this._prefs);
  final ApiClient _api;
  final AppDatabase _db;
  final SharedPreferences _prefs;

  // ---- reads (cache) ------------------------------------------------------------------------------------------
  Stream<List<Worker>> watch({String? status, String query = ''}) {
    final q = query.trim().toLowerCase();
    final select = _db.select(_db.cachedWorkers)..orderBy([(t) => OrderingTerm.desc(t.cachedAt)]);
    select.where((t) {
      Expression<bool> cond = const Constant(true);
      if (status != null) cond = cond & t.status.equals(status);
      if (q.isNotEmpty) cond = cond & t.search.like('%$q%');
      return cond;
    });
    return select.watch().map((rows) => rows.map((r) => Worker.fromJson(jsonDecode(r.json) as Map<String, dynamic>)).toList());
  }

  /// Delta sync: only workers changed since the last successful sync (`updatedSince`).
  Future<void> refresh({bool full = false}) async {
    final since = full ? null : _prefs.getString(_lastSyncKey);
    final startedAt = DateTime.now().toUtc();
    String? cursor;
    do {
      final page = await _api.getJson('/workers', query: {'limit': 100, 'updatedSince': ?since, 'cursor': ?cursor});
      await _upsert((page['items'] as List).cast<Map<String, dynamic>>());
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    await _prefs.setString(_lastSyncKey, startedAt.toIso8601String());
  }

  Future<void> _upsert(List<Map<String, dynamic>> items) => _db.batch((b) {
        for (final j in items) {
          final w = Worker.fromJson(j);
          b.insert(
            _db.cachedWorkers,
            CachedWorkersCompanion.insert(id: w.id, status: w.status, name: w.fullName, search: w.searchText, json: jsonEncode(j), cachedAt: DateTime.now()),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  /// Fresh full record (GPS, collaterals with photos) straight from the NAS.
  Future<Worker> fetchDetail(String id) async {
    final json = await _api.getJson('/workers/$id');
    await _upsert([json]);
    return Worker.fromJson(json);
  }

  // ---- writes (server confirmation required) ---------------------------------------------------------------------
  Future<Worker> approve(String id, {required bool collateralReceived, String? note}) async {
    final json = await _api.postJson('/workers/$id/approve', idempotencyKey: _uuid.v4(), body: {'collateralReceived': collateralReceived, if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
    await _upsert([json]);
    return Worker.fromJson(json);
  }

  Future<Worker> reject(String id, String reason) async {
    final json = await _api.postJson('/workers/$id/reject', idempotencyKey: _uuid.v4(), body: {'reason': reason.trim()});
    await _upsert([json]);
    return Worker.fromJson(json);
  }

  Future<void> receiveCollateral(String collateralId, {int? estimatedValue, String? storageLocation, String? note}) =>
      _api.postJson('/collaterals/$collateralId/receive', idempotencyKey: _uuid.v4(), body: {
        if (estimatedValue != null) 'estimatedValue': estimatedValue.toString(),
        if (storageLocation != null && storageLocation.trim().isNotEmpty) 'storageLocation': storageLocation.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  /// The cache is wiped on logout: the next user of this phone must never see the previous user's data.
  Future<void> clear() async {
    await _db.delete(_db.cachedWorkers).go();
    await _prefs.remove(_lastSyncKey);
  }
}

/// WORKER side: her own data only (the server returns nothing else).
class MyProfileRepository {
  MyProfileRepository(this._api);
  final ApiClient _api;

  Future<Worker> me() async => Worker.fromJson(await _api.getJson('/workers/me'));

  Future<List<Collateral>> myCollateral() async =>
      ((await _api.getJson('/workers/me/collateral'))['items'] as List).map((j) => Collateral.fromJson((j as Map).cast<String, dynamic>())).toList();
}
