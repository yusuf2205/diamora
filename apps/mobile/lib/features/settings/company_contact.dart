import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';

/// Company phone + Telegram shown to the WORKER ("Позвонить" / "Написать в Telegram", D-029). Never hard-coded in Flutter.
class CompanyContact {
  const CompanyContact({this.phone, this.telegramUsername, this.telegramUrl});
  final String? phone;
  final String? telegramUsername;
  final String? telegramUrl;
  factory CompanyContact.fromJson(Map<String, dynamic> j) =>
      CompanyContact(phone: j['phone'] as String?, telegramUsername: j['telegramUsername'] as String?, telegramUrl: j['telegramUrl'] as String?);
}

class CompanyContactRepository {
  CompanyContactRepository(this._api);
  final ApiClient _api;
  Future<CompanyContact> get() async => CompanyContact.fromJson(await _api.getJson('/settings/company-contact'));
  Future<CompanyContact> update({String? phone, String? telegramUsername}) async =>
      CompanyContact.fromJson(await _api.putJson('/settings/company-contact', body: {'phone': phone, 'telegramUsername': telegramUsername}));
}

final companyContactRepositoryProvider = Provider<CompanyContactRepository>((ref) => CompanyContactRepository(ref.watch(apiClientProvider)));

final companyContactProvider = FutureProvider.autoDispose<CompanyContact>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type == 'company_contact.changed') ref.invalidateSelf();
  });
  return ref.watch(companyContactRepositoryProvider).get();
});
