import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'assignment_models.dart';

const _uuid = Uuid();

/// M3 staff-side assignment actions (§4-14): create a work order, confirm delivery, confirm pickup (typically right
/// after scanning the assignment's QR — §12's "приезжает → сканирует QR → видит assignment + worker → нажимает
/// «Забрал»"), accept quality, cash payout.
class AssignmentAdminRepository {
  AssignmentAdminRepository(this._api);
  final ApiClient _api;

  Future<AssignmentDetail> create({
    required String workerId, required String productModelId, required String productVariantId, required String colorId,
    required String materialKitTemplateId, required int kitCount, DateTime? dueAt, String? notes,
  }) async =>
      AssignmentDetail.fromJson(await _api.postJson('/admin/assignments', idempotencyKey: _uuid.v4(), body: {
        'workerId': workerId, 'productModelId': productModelId, 'productVariantId': productVariantId, 'colorId': colorId,
        'materialKitTemplateId': materialKitTemplateId, 'kitCount': kitCount,
        'dueAt': ?dueAt?.toIso8601String(), 'notes': ?notes,
      }));

  Future<AssignmentDetail> get(String id) async => AssignmentDetail.fromJson(await _api.getJson('/admin/assignments/$id'));

  Future<List<AssignmentSummary>> list({String? status, String? workerId}) async =>
      ((await _api.getJson('/admin/assignments', query: {'status': ?status, 'workerId': ?workerId, 'limit': 200}))['items'] as List)
          .map((j) => AssignmentSummary.fromJson((j as Map).cast<String, dynamic>()))
          .toList();

  Future<AssignmentDetail> deliver(String id) async => AssignmentDetail.fromJson(await _api.postJson('/admin/assignments/$id/deliver', idempotencyKey: _uuid.v4()));
  Future<AssignmentDetail> pickup(String id) async => AssignmentDetail.fromJson(await _api.postJson('/admin/assignments/$id/pickup', idempotencyKey: _uuid.v4()));

  Future<AssignmentDetail> accept(String id, {required String broughtMeters, required String acceptedMeters, String? defectiveMeters, String? reworkMeters, String? comment}) async =>
      AssignmentDetail.fromJson(await _api.postJson('/admin/assignments/$id/accept', idempotencyKey: _uuid.v4(), body: {
        'broughtMeters': broughtMeters, 'acceptedMeters': acceptedMeters, 'defectiveMeters': ?defectiveMeters, 'reworkMeters': ?reworkMeters, 'comment': ?comment,
      }));

  Future<Map<String, dynamic>> ledger(String workerId) => _api.getJson('/admin/workers/$workerId/ledger');

  Future<Map<String, dynamic>> payout(String workerId, {required String amount, String? comment, bool forced = false}) =>
      _api.postJson('/admin/workers/$workerId/payout', idempotencyKey: _uuid.v4(), body: {'amount': amount, 'comment': ?comment, if (forced) 'forced': true});
}

final assignmentAdminRepositoryProvider = Provider<AssignmentAdminRepository>((ref) => AssignmentAdminRepository(ref.watch(apiClientProvider)));

final assignmentDetailProvider = FutureProvider.autoDispose.family<AssignmentDetail, String>((ref, id) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('assignment.') || t.startsWith('work.') || t.startsWith('delivery.') || t == 'quality.completed')) ref.invalidateSelf();
  });
  return ref.watch(assignmentAdminRepositoryProvider).get(id);
});

class AssignmentListFilter {
  const AssignmentListFilter({this.status, this.workerId});
  final String? status;
  final String? workerId;
  @override
  bool operator ==(Object other) => other is AssignmentListFilter && other.status == status && other.workerId == workerId;
  @override
  int get hashCode => Object.hash(status, workerId);
}

final assignmentListProvider = FutureProvider.autoDispose.family<List<AssignmentSummary>, AssignmentListFilter>((ref, f) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('assignment.') || t.startsWith('work.') || t.startsWith('delivery.'))) ref.invalidateSelf();
  });
  return ref.watch(assignmentAdminRepositoryProvider).list(status: f.status, workerId: f.workerId);
});

final workerLedgerProvider = FutureProvider.autoDispose.family<WorkerLedger, String>((ref, workerId) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t == 'earning.created' || t == 'cash_payment.created' || t == 'worker.balance_updated')) ref.invalidateSelf();
  });
  return ref.watch(assignmentAdminRepositoryProvider).ledger(workerId).then(WorkerLedger.fromJson);
});

class WorkerLedger {
  const WorkerLedger({required this.balance, required this.earned, required this.paid, required this.history});
  final String balance;
  final String earned;
  final String paid;
  final List<LedgerEntry> history;
  factory WorkerLedger.fromJson(Map<String, dynamic> j) => WorkerLedger(
        balance: j['balance'] as String, earned: j['earned'] as String, paid: j['paid'] as String,
        history: ((j['history'] as List?) ?? const []).map((x) => LedgerEntry.fromJson((x as Map).cast<String, dynamic>())).toList(),
      );
}

class LedgerEntry {
  const LedgerEntry({required this.id, required this.type, required this.amount, this.comment, required this.createdAt});
  final String id;
  final String type; // EARNING | PAYOUT_CASH | BONUS | CORRECTION
  final String amount; // signed
  final String? comment;
  final DateTime createdAt;
  factory LedgerEntry.fromJson(Map<String, dynamic> j) =>
      LedgerEntry(id: j['id'] as String, type: j['type'] as String, amount: j['amount'] as String, comment: j['comment'] as String?, createdAt: DateTime.parse(j['createdAt'] as String));
}
