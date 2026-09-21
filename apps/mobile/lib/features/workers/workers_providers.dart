import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'models.dart';

class WorkersFilter {
  const WorkersFilter({this.status, this.query = ''});
  final String? status;
  final String query;
  @override
  bool operator ==(Object other) => other is WorkersFilter && other.status == status && other.query == query;
  @override
  int get hashCode => Object.hash(status, query);
}

/// Cache-backed list (works offline); kept fresh by the sync in the ADMIN shell and by realtime events.
final workersListProvider = StreamProvider.autoDispose.family<List<Worker>, WorkersFilter>(
  (ref, f) => ref.watch(workerRepositoryProvider).watch(status: f.status, query: f.query),
);

/// Full record from the NAS. Re-fetched automatically when a realtime event mentions this worker.
final workerDetailProvider = FutureProvider.autoDispose.family<Worker, String>((ref, id) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final e = next.value;
    if (e != null && e.data['workerId'] == id) ref.invalidateSelf();
  });
  return ref.watch(workerRepositoryProvider).fetchDetail(id);
});

/// The worker's own profile (WORKER role).
final myProfileProvider = FutureProvider.autoDispose<Worker>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value != null) ref.invalidateSelf();
  });
  return ref.watch(myProfileRepositoryProvider).me();
});

final myCollateralProvider = FutureProvider.autoDispose<List<Collateral>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value != null) ref.invalidateSelf();
  });
  return ref.watch(myProfileRepositoryProvider).myCollateral();
});
