class CatalogFile {
  const CatalogFile({required this.id, required this.url, this.thumbUrl});
  final String id;
  final String url;
  final String? thumbUrl;
  factory CatalogFile.fromJson(Map<String, dynamic> j) => CatalogFile(id: j['id'] as String, url: j['url'] as String, thumbUrl: j['thumbUrl'] as String?);
}

class CatalogMedia {
  const CatalogMedia({required this.id, required this.kind, required this.isMain, this.caption, this.variantId, this.file});
  final String id;
  final String kind; // PHOTO | VIDEO
  final bool isMain;
  final String? caption;
  final String? variantId;
  final CatalogFile? file;
  bool get isVideo => kind == 'VIDEO';
  factory CatalogMedia.fromJson(Map<String, dynamic> j) => CatalogMedia(
        id: j['id'] as String, kind: j['kind'] as String, isMain: j['isMain'] as bool? ?? false, caption: j['caption'] as String?,
        variantId: j['variantId'] as String?, file: j['file'] == null ? null : CatalogFile.fromJson((j['file'] as Map).cast<String, dynamic>()),
      );
}

class CatalogColor {
  const CatalogColor({required this.id, required this.name, this.hex});
  final String id;
  final String name;
  final String? hex;
  factory CatalogColor.fromJson(Map<String, dynamic> j) => CatalogColor(id: j['id'] as String, name: j['name'] as String, hex: j['hex'] as String?);
}

class CatalogVariant {
  const CatalogVariant({required this.id, this.label, this.active = true, this.color});
  final String id;
  final String? label;
  final bool active;
  final CatalogColor? color;
  factory CatalogVariant.fromJson(Map<String, dynamic> j) => CatalogVariant(
        id: j['id'] as String, label: j['label'] as String?, active: j['active'] as bool? ?? true,
        color: j['color'] == null ? null : CatalogColor.fromJson((j['color'] as Map).cast<String, dynamic>()),
      );
}

/// One catalog card / detail. Covers both the WORKER payload (no status/code) and the staff payload (everything) - a field
/// missing from a WORKER response is simply null here. NEVER a price field: the server payload has none either (D-029).
class CatalogItem {
  const CatalogItem({
    required this.id, required this.name, this.code, this.description, this.status, this.availability = 'AVAILABLE',
    this.isNew = false, this.sortOrder = 0, this.coverPhoto, this.media = const [], this.variants = const [], this.colors = const [],
  });
  final String id;
  final String name;
  final String? code;
  final String? description;
  final String? status; // DRAFT | PUBLISHED | HIDDEN (staff only)
  final String availability; // AVAILABLE | ON_REQUEST | UNAVAILABLE
  final bool isNew;
  final int sortOrder;
  final CatalogFile? coverPhoto;
  final List<CatalogMedia> media;
  final List<CatalogVariant> variants;
  final List<CatalogColor> colors;

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String?,
        description: j['description'] as String?,
        status: j['status'] as String?,
        availability: j['availability'] as String? ?? 'AVAILABLE',
        isNew: j['isNew'] as bool? ?? false,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        coverPhoto: j['coverPhoto'] == null ? null : CatalogFile.fromJson((j['coverPhoto'] as Map).cast<String, dynamic>()),
        media: ((j['media'] as List?) ?? const []).map((m) => CatalogMedia.fromJson((m as Map).cast<String, dynamic>())).toList(),
        variants: ((j['variants'] as List?) ?? const []).map((v) => CatalogVariant.fromJson((v as Map).cast<String, dynamic>())).toList(),
        colors: ((j['colors'] as List?) ?? const [])
            .map((c) => CatalogColor.fromJson({'id': (c as Map)['id'], 'name': c['name'] ?? ''}))
            .toList(),
      );

  CatalogFile? get mainPhoto {
    if (coverPhoto != null) return coverPhoto;
    for (final m in media) {
      if (!m.isVideo) return m.file;
    }
    return null;
  }
}
