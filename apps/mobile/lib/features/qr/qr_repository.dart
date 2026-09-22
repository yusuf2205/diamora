import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

/// Resolves an opaque QR code (M2 §10-13). The server decides what the code means and whether THIS user may see it
/// (a MANAGER scanning a stranger's worker gets a plain "not found", exactly like `GET /workers/:id`) — the client only
/// asks and displays; it never decodes or trusts anything encoded in the QR text itself beyond the opaque string.
class QrRepository {
  QrRepository(this._api);
  final ApiClient _api;
  Future<Map<String, dynamic>> resolve(String code) => _api.getJson('/qr/$code');
}

final qrRepositoryProvider = Provider<QrRepository>((ref) => QrRepository(ref.watch(apiClientProvider)));

/// Pure classification of a resolved QR response — kept separate from the scanner widget so it is unit-testable
/// without a camera. `worker`/`kit`/`assignment` never mean anything without the matching JSON key actually present.
enum QrOutcomeType { worker, kit, assignment, invalid }

QrOutcomeType classifyQr(Map<String, dynamic> json) => switch (json['type']) {
      'WORKER' when json['worker'] is Map => QrOutcomeType.worker,
      'KIT' when json['kit'] is Map => QrOutcomeType.kit,
      'ASSIGNMENT' when json['assignment'] is Map => QrOutcomeType.assignment,
      _ => QrOutcomeType.invalid,
    };

