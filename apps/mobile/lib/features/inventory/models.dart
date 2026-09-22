class MaterialCategoryRef {
  const MaterialCategoryRef({required this.id, this.code, required this.name});
  final String id;
  final String? code;
  final String name;
  factory MaterialCategoryRef.fromJson(Map<String, dynamic> j) => MaterialCategoryRef(id: j['id'] as String, code: j['code'] as String?, name: j['name'] as String);
}

/// A material's card (M2 §5-7). `balance`/`low` come straight from the server's `StockBalance` — never a client-side guess.
class MaterialItem {
  const MaterialItem({
    required this.id, required this.name, this.article, required this.unit, required this.isActive,
    this.categoryName, required this.minStock, required this.balance, required this.low,
  });
  final String id;
  final String name;
  final String? article;
  final String unit;
  final bool isActive;
  final String? categoryName;
  final double minStock;
  final double balance;
  final bool low;
  factory MaterialItem.fromJson(Map<String, dynamic> j) => MaterialItem(
        id: j['id'] as String, name: j['name'] as String, article: j['article'] as String?, unit: j['unit'] as String,
        isActive: j['isActive'] as bool? ?? true, categoryName: (j['category'] as Map?)?['name'] as String?,
        minStock: (j['minStock'] as num).toDouble(), balance: (j['balance'] as num).toDouble(), low: j['low'] as bool? ?? false,
      );
}

class KitTemplateItem {
  const KitTemplateItem({required this.materialId, required this.materialName, required this.unit, required this.requiredQuantity});
  final String materialId;
  final String materialName;
  final String unit;
  final double requiredQuantity;
  factory KitTemplateItem.fromJson(Map<String, dynamic> j) => KitTemplateItem(
        materialId: j['materialId'] as String, materialName: j['materialName'] as String, unit: j['unit'] as String,
        requiredQuantity: (j['requiredQuantity'] as num).toDouble(),
      );
}

/// The 9 m recipe (M2 §8-9). `baseMeters` is always 9; assembling with `count` = 2/3 gives 18/27 m — never a separate template.
class KitTemplate {
  const KitTemplate({required this.id, required this.name, this.variantId, required this.ribbonMeters, required this.baseMeters, required this.active, required this.items});
  final String id;
  final String name;
  final String? variantId;
  final double ribbonMeters;
  final int baseMeters;
  final bool active;
  final List<KitTemplateItem> items;
  factory KitTemplate.fromJson(Map<String, dynamic> j) => KitTemplate(
        id: j['id'] as String, name: j['name'] as String, variantId: j['variantId'] as String?, ribbonMeters: (j['ribbonMeters'] as num).toDouble(),
        baseMeters: (j['baseMeters'] as num).toInt(), active: j['active'] as bool? ?? true,
        items: (j['items'] as List).map((x) => KitTemplateItem.fromJson((x as Map).cast<String, dynamic>())).toList(),
      );
}

/// Result of a physical assembly (M2 §11): one opaque QR for the whole batch.
class KitAssembled {
  const KitAssembled({required this.qrCode, required this.kitTemplateName, required this.count, required this.totalMeters});
  final String qrCode;
  final String kitTemplateName;
  final int count;
  final double totalMeters;
  factory KitAssembled.fromJson(Map<String, dynamic> j) => KitAssembled(
        qrCode: j['qrCode'] as String, kitTemplateName: j['kitTemplateName'] as String,
        count: (j['count'] as num).toInt(), totalMeters: (j['totalMeters'] as num).toDouble(),
      );
}
