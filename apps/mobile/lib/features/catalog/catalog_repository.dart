import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'models.dart';

const _uuid = Uuid();

/// "Наши работы" (D-029). Reads are cheap enough to always go to the server (small home-business catalog, kept live by
/// realtime); writes always go to the server (media/publishing are ADMIN-critical, D-022 applies the same way as collateral).
class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  // ---- WORKER: published only, never a price --------------------------------------------------------------------------
  Future<List<CatalogItem>> published() async =>
      ((await _api.getJson('/catalog'))['items'] as List).map((j) => CatalogItem.fromJson((j as Map).cast<String, dynamic>())).toList();
  Future<CatalogItem> publishedDetail(String id) async => CatalogItem.fromJson(await _api.getJson('/catalog/$id'));

  // ---- staff: manage everything -----------------------------------------------------------------------------------------
  Future<List<CatalogItem>> staffList({String? status}) async =>
      ((await _api.getJson('/admin/catalog', query: {'status': ?status, 'limit': 100}))['items'] as List)
          .map((j) => CatalogItem.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
  Future<CatalogItem> staffGet(String id) async => CatalogItem.fromJson(await _api.getJson('/admin/catalog/$id'));

  Future<CatalogItem> create(String name, {String? description}) async =>
      CatalogItem.fromJson(await _api.postJson('/admin/catalog', body: {'name': name, if (description != null && description.trim().isNotEmpty) 'description': description.trim()}));

  Future<CatalogItem> update(String id, {String? name, String? description, bool? isNew, String? availability}) async =>
      CatalogItem.fromJson(await _api.patchJson('/admin/catalog/$id', body: {
        'name': ?name,
        'description': ?description,
        'isNew': ?isNew,
        'availability': ?availability,
      }));

  Future<CatalogItem> publish(String id) async => CatalogItem.fromJson(await _api.postJson('/admin/catalog/$id/publish'));
  Future<CatalogItem> hide(String id) async => CatalogItem.fromJson(await _api.postJson('/admin/catalog/$id/hide'));
  Future<void> remove(String id) => _api.deleteJson('/admin/catalog/$id');

  Future<CatalogItem> addVariant(String modelId, String colorId, {String? label}) async =>
      CatalogItem.fromJson(await _api.postJson('/admin/catalog/$modelId/variants', body: {'colorId': colorId, if (label != null && label.trim().isNotEmpty) 'label': label.trim()}));

  Future<CatalogItem> addMedia(String modelId, List<int> bytes, String filename, {String kind = 'PHOTO', String? caption}) async =>
      CatalogItem.fromJson(await _api.uploadFile('/admin/catalog/$modelId/media', bytes: bytes, filename: filename, fields: {'kind': kind, 'caption': ?caption}));

  Future<CatalogItem> setMainMedia(String modelId, String mediaId) async {
    await _api.postJson('/admin/catalog/media/$mediaId/main');
    return staffGet(modelId);
  }

  Future<CatalogItem> removeMedia(String modelId, String mediaId) async {
    await _api.deleteJson('/admin/catalog/media/$mediaId');
    return staffGet(modelId);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(apiClientProvider)));

/// The public catalog, refreshed live whenever ADMIN changes it.
final publishedCatalogProvider = FutureProvider.autoDispose<List<CatalogItem>>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('catalog.') ?? false) ref.invalidateSelf();
  });
  return ref.watch(catalogRepositoryProvider).published();
});

final publishedItemProvider = FutureProvider.autoDispose.family<CatalogItem, String>((ref, id) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('catalog.') ?? false) ref.invalidateSelf();
  });
  return ref.watch(catalogRepositoryProvider).publishedDetail(id);
});

class StaffCatalogFilter {
  const StaffCatalogFilter({this.status});
  final String? status;
  @override
  bool operator ==(Object other) => other is StaffCatalogFilter && other.status == status;
  @override
  int get hashCode => status.hashCode;
}

final staffCatalogProvider = FutureProvider.autoDispose.family<List<CatalogItem>, StaffCatalogFilter>((ref, f) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('catalog.') ?? false) ref.invalidateSelf();
  });
  return ref.watch(catalogRepositoryProvider).staffList(status: f.status);
});

final staffCatalogItemProvider = FutureProvider.autoDispose.family<CatalogItem, String>((ref, id) {
  ref.listen(realtimeEventsProvider, (_, next) {
    if (next.value?.type.startsWith('catalog.') ?? false) ref.invalidateSelf();
  });
  return ref.watch(catalogRepositoryProvider).staffGet(id);
});

String newIdempotencyKey() => _uuid.v4();
