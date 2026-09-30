import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/providers.dart';
import 'assignment_admin_repository.dart' show WorkerLedger;
import 'models.dart';

const _uuid = Uuid();

/// M3 §8/§10-11: the worker's own current job. Self-only on the API side (JWT workerId, never a client-supplied id).
class WorkRepository {
  WorkRepository(this._api, [this._cache]);
  final ApiClient _api;
  /// the last good answers, shown without internet (null in tests that do not care)
  final ResponseCache? _cache;

  Future<CurrentWork?> current() async {
    Future<Object> fetch() => _api.getJson('/work/current');
    CurrentWork? parse(Object j) => (j as Map).isEmpty ? null : CurrentWork.fromJson(j.cast<String, dynamic>());
    final c = _cache;
    return c == null ? parse(await fetch()) : c.get('work/current', fetch, parse);
  }

  Future<CurrentWork> reportProgress(String assignmentId, {required String reportedMeters, String? comment, String? idempotencyKey}) async {
    final j = await _api.postJson('/work/$assignmentId/progress', idempotencyKey: idempotencyKey ?? _uuid.v4(), body: {'reportedMeters': reportedMeters, 'comment': ?comment, 'clientId': idempotencyKey ?? _uuid.v4()});
    return CurrentWork.fromJson(j);
  }

  Future<void> markReady(String assignmentId, {required String readyMeters, String? comment, String? idempotencyKey}) =>
      _api.postJson('/work/$assignmentId/ready', idempotencyKey: idempotencyKey ?? _uuid.v4(), body: {'readyMeters': readyMeters, 'comment': ?comment});

  /// OfflineQueue: sends one action saved without internet, with the key it got when she did it.
  Future<void> sendQueued(String kind, Map<String, dynamic> p, String key) async {
    switch (kind) {
      case 'progress':
        await reportProgress(p['assignmentId'] as String, reportedMeters: p['reportedMeters'] as String, idempotencyKey: key);
      case 'ready':
        await markReady(p['assignmentId'] as String, readyMeters: p['readyMeters'] as String, idempotencyKey: key);
      case 'receive':
        // scanned without internet: look the kit up now, then confirm it (a foreign / already-received kit is refused)
        final scan = await scanHandoff(p['code'] as String);
        if (scan.state != 'CONFIRMED') {
          await _api.postJson('/work/handoff/${scan.handoffId}/confirm', idempotencyKey: key, body: {'latitude': ?p['latitude'], 'longitude': ?p['longitude']});
        }
      default:
        throw ApiException(code: 'UNKNOWN_ACTION', message: kind);
    }
  }

  /// Phase 5: she scanned a kit QR with her own camera. A foreign kit is refused server-side (FOREIGN_KIT) with no data.
  Future<HandoffScan> scanHandoff(String code) async => HandoffScan.fromJson(await _api.postJson('/work/handoff/scan', body: {'code': code}));

  /// «Подтвердить получение»: the server moves material custody to her in one transaction; replay-safe.
  Future<CurrentWork> confirmHandoff(String handoffId, {double? latitude, double? longitude, double? accuracyM}) async => CurrentWork.fromJson(
        await _api.postJson('/work/handoff/$handoffId/confirm', idempotencyKey: _uuid.v4(), body: {'latitude': ?latitude, 'longitude': ?longitude, 'accuracyM': ?accuracyM}),
      );

  /// «Есть проблема»: nothing is transferred, staff is told in realtime.
  Future<void> reportHandoffProblem(String handoffId, {required String reason, String? comment}) =>
      _api.postJson('/work/handoff/$handoffId/problem', idempotencyKey: _uuid.v4(), body: {'reason': reason, 'comment': ?comment});

  /// M3 §13: "К получению / Заработано / Выплачено" — self-only, the same numbers a staff member would see about her.
  Future<WorkerLedger> myEarnings() async {
    Future<Object> fetch() => _api.getJson('/work/earnings');
    WorkerLedger parse(Object j) => WorkerLedger.fromJson((j as Map).cast<String, dynamic>());
    final c = _cache;
    return c == null ? parse(await fetch()) : c.get('work/earnings', fetch, parse);
  }
}

final responseCacheProvider = Provider<ResponseCache>((ref) => ResponseCache(ref.watch(appDatabaseProvider)));
final workRepositoryProvider = Provider<WorkRepository>((ref) => WorkRepository(ref.watch(apiClientProvider), ref.watch(responseCacheProvider)));

/// «Не отправлено»: what is waiting on the phone; sent by itself when the internet is back.
final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue(ref.watch(appDatabaseProvider), (k, p, key) => ref.read(workRepositoryProvider).sendQueued(k, p, key)));
final pendingActionsProvider = StreamProvider.autoDispose<List<PendingAction>>((ref) => ref.watch(offlineQueueProvider).watch());

final currentWorkProvider = FutureProvider.autoDispose<CurrentWork?>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('assignment.') || t.startsWith('work.') || t.startsWith('delivery.') || t.startsWith('handoff.'))) ref.invalidateSelf();
  });
  return ref.watch(workRepositoryProvider).current();
});

final myEarningsProvider = FutureProvider.autoDispose<WorkerLedger>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t == 'earning.created' || t == 'cash_payment.created' || t == 'worker.balance_updated')) ref.invalidateSelf();
  });
  return ref.watch(workRepositoryProvider).myEarnings();
});
