import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

const _uuid = Uuid();

/// M3 staff-side assignment actions (§9, §12): confirm delivery, confirm pickup (typically right after scanning the
/// assignment's QR — §12's "приезжает → сканирует QR → видит assignment + worker → нажимает «Забрал»"), accept quality.
class AssignmentAdminRepository {
  AssignmentAdminRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> get(String id) => _api.getJson('/admin/assignments/$id');
  Future<Map<String, dynamic>> deliver(String id) => _api.postJson('/admin/assignments/$id/deliver', idempotencyKey: _uuid.v4());
  Future<Map<String, dynamic>> pickup(String id) => _api.postJson('/admin/assignments/$id/pickup', idempotencyKey: _uuid.v4());
  Future<Map<String, dynamic>> accept(String id, {required String broughtMeters, required String acceptedMeters, String? defectiveMeters, String? reworkMeters, String? comment}) =>
      _api.postJson('/admin/assignments/$id/accept', idempotencyKey: _uuid.v4(), body: {
        'broughtMeters': broughtMeters, 'acceptedMeters': acceptedMeters, 'defectiveMeters': ?defectiveMeters, 'reworkMeters': ?reworkMeters, 'comment': ?comment,
      });
}

final assignmentAdminRepositoryProvider = Provider<AssignmentAdminRepository>((ref) => AssignmentAdminRepository(ref.watch(apiClientProvider)));
