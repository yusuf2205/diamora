import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

const _uuid = Uuid();

/// Keep in step with MAX_PAY_RATE_UZS in packages/shared (the server validates again).
const maxPayRate = 10000000;

/// The ONE global price of a 9 m kit (D-027). Money is a decimal string — never a float.
class PayRate {
  const PayRate({required this.ratePerKit, required this.kitMeters, required this.updatedAt});
  final String ratePerKit;
  final int kitMeters;
  final DateTime updatedAt;

  factory PayRate.fromJson(Map<String, dynamic> j) => PayRate(
        ratePerKit: j['ratePerKit'] as String,
        kitMeters: (j['kitMeters'] as num?)?.toInt() ?? 9,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class PayRateChange {
  const PayRateChange({required this.id, required this.ratePerKit, this.previousRatePerKit, this.changedBy, this.note, required this.createdAt});
  final String id;
  final String ratePerKit;
  final String? previousRatePerKit;
  final String? changedBy;
  final String? note;
  final DateTime createdAt;

  factory PayRateChange.fromJson(Map<String, dynamic> j) => PayRateChange(
        id: j['id'] as String,
        ratePerKit: j['ratePerKit'] as String,
        previousRatePerKit: j['previousRatePerKit'] as String?,
        changedBy: j['changedBy'] as String?,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Reads are for everybody (ADMIN and WORKER); [change] is ADMIN only and ALWAYS goes to the server (money setting, D-022).
class PayRateRepository {
  PayRateRepository(this._api);
  final ApiClient _api;

  Future<PayRate> current() async => PayRate.fromJson(await _api.getJson('/settings/pay-rate'));

  Future<PayRate> change(int ratePerKit, {String? note}) async => PayRate.fromJson(await _api.putJson(
        '/settings/pay-rate',
        idempotencyKey: _uuid.v4(),
        body: {'ratePerKit': ratePerKit.toString(), if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      ));

  Future<List<PayRateChange>> history() async =>
      ((await _api.getJson('/settings/pay-rate/history'))['items'] as List).map((j) => PayRateChange.fromJson((j as Map).cast<String, dynamic>())).toList();
}

final payRateRepositoryProvider = Provider<PayRateRepository>((ref) => PayRateRepository(ref.watch(apiClientProvider)));

/// Re-fetched whenever the server announces `pay_rate.changed`: an ADMIN edit shows up on every open screen at once.
final payRateProvider = FutureProvider.autoDispose<PayRate>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type == 'pay_rate.changed') ref.invalidateSelf();
  });
  return ref.watch(payRateRepositoryProvider).current();
});

final payRateHistoryProvider = FutureProvider.autoDispose<List<PayRateChange>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type == 'pay_rate.changed') ref.invalidateSelf();
  });
  return ref.watch(payRateRepositoryProvider).history();
});
