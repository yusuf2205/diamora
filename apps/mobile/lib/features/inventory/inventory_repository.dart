import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'models.dart';

const _uuid = Uuid();

/// Materials / Stock / 9 m Kit templates (M2 §5-9). Every write is server-confirmed and idempotent — nothing here is
/// ever queued offline (stock correctness matters more than a nice offline UX for a warehouse action).
class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  Future<List<MaterialCategoryRef>> categories() async =>
      (await _api.getList('/admin/materials/categories')).map((j) => MaterialCategoryRef.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<List<MaterialItem>> materials() async =>
      ((await _api.getJson('/admin/materials', query: {'limit': 200}))['items'] as List).map((j) => MaterialItem.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<void> createMaterial({required String name, String? categoryId, required String unit, String? minStock}) => _api.postJson(
        '/admin/materials', idempotencyKey: _uuid.v4(),
        body: {'name': name, 'categoryId': ?categoryId, 'unit': unit, 'minStock': ?minStock},
      );

  Future<void> receipt({required String materialId, required String quantity, String? comment}) =>
      _api.postJson('/admin/stock/receipt', idempotencyKey: _uuid.v4(), body: {'materialId': materialId, 'quantity': quantity, 'comment': ?comment});

  Future<List<KitTemplate>> kits() async => ((await _api.getJson('/admin/kits'))['items'] as List).map((j) => KitTemplate.fromJson((j as Map).cast<String, dynamic>())).toList();

  Future<void> createKit({required String name, double ribbonMeters = 9, required List<Map<String, String>> items}) =>
      _api.postJson('/admin/kits', idempotencyKey: _uuid.v4(), body: {'name': name, 'ribbonMeters': ribbonMeters, 'items': items});

  Future<KitAssembled> assembleKit(String kitTemplateId, int count) async =>
      KitAssembled.fromJson(await _api.postJson('/admin/kits/$kitTemplateId/assemble', idempotencyKey: _uuid.v4(), body: {'count': count}));
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => InventoryRepository(ref.watch(apiClientProvider)));

final materialCategoriesProvider = FutureProvider.autoDispose<List<MaterialCategoryRef>>((ref) => ref.watch(inventoryRepositoryProvider).categories());

final materialsProvider = FutureProvider.autoDispose<List<MaterialItem>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && (t.startsWith('material.') || t.startsWith('stock.'))) ref.invalidateSelf();
  });
  return ref.watch(inventoryRepositoryProvider).materials();
});

final kitTemplatesProvider = FutureProvider.autoDispose<List<KitTemplate>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final t = next.value?.type;
    if (t != null && t.startsWith('kit.')) ref.invalidateSelf();
  });
  return ref.watch(inventoryRepositoryProvider).kits();
});
