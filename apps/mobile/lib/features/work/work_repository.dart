import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'models.dart';

const _uuid = Uuid();

/// M3 §8/§10-11: the worker's own current job. Self-only on the API side (JWT workerId, never a client-supplied id).
class WorkRepository {
  WorkRepository(this._api);
  final ApiClient _api;

  Future<CurrentWork?> current() async {
    final j = await _api.getJson('/work/current');
    if (j.isEmpty) return null;
    return CurrentWork.fromJson(j);
  }

  Future<CurrentWork> reportProgress(String assignmentId, {required String reportedMeters, String? comment}) async {
    final j = await _api.postJson('/work/$assignmentId/progress', idempotencyKey: _uuid.v4(), body: {'reportedMeters': reportedMeters, 'comment': ?comment, 'clientId': _uuid.v4()});
    return CurrentWork.fromJson(j);
  }

  Future<void> markReady(String assignmentId, {required String readyMeters, String? comment}) =>
      _api.postJson('/work/$assignmentId/ready', idempotencyKey: _uuid.v4(), body: {'readyMeters': readyMeters, 'comment': ?comment});
}

final workRepositoryProvider = Provider<WorkRepository>((ref) => WorkRepository(ref.watch(apiClientProvider)));

final currentWorkProvider = FutureProvider.autoDispose<CurrentWork?>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('assignment.') || t.startsWith('work.') || t.startsWith('delivery.'))) ref.invalidateSelf();
  });
  return ref.watch(workRepositoryProvider).current();
});
