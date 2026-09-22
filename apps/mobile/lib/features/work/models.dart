/// M3: the worker's current job (§8). Mirrors `AssignmentsService.dto` on the API — one source of truth, no client math
/// beyond what's needed to draw a progress bar.
class CurrentWork {
  const CurrentWork({
    required this.id, required this.code, required this.status, required this.kitCount, required this.plannedMeters,
    required this.reportedMeters, this.calculatedPayment, this.dueAt, this.notes,
    required this.productName, this.variantLabel, required this.colorName, this.colorHex,
    required this.materials,
  });
  final String id;
  final String code;
  final String status;
  final int kitCount;
  final double plannedMeters;
  final double reportedMeters;
  final String? calculatedPayment;
  final DateTime? dueAt;
  final String? notes;
  final String productName;
  final String? variantLabel;
  final String colorName;
  final String? colorHex;
  final List<CurrentWorkMaterial> materials;

  double get percent => plannedMeters > 0 ? (reportedMeters / plannedMeters * 100).clamp(0, 100) : 0;
  double get remainingMeters => (plannedMeters - reportedMeters).clamp(0, plannedMeters);

  factory CurrentWork.fromJson(Map<String, dynamic> j) => CurrentWork(
        id: j['id'] as String, code: j['code'] as String, status: j['status'] as String, kitCount: (j['kitCount'] as num).toInt(),
        plannedMeters: (j['plannedMeters'] as num).toDouble(), reportedMeters: (j['reportedMeters'] as num?)?.toDouble() ?? 0,
        calculatedPayment: j['calculatedPayment'] as String?,
        dueAt: j['dueAt'] != null ? DateTime.tryParse(j['dueAt'] as String) : null, notes: j['notes'] as String?,
        productName: (j['product'] as Map?)?['name'] as String? ?? '', variantLabel: (j['variant'] as Map?)?['label'] as String?,
        colorName: (j['color'] as Map?)?['name'] as String? ?? '', colorHex: (j['color'] as Map?)?['hex'] as String?,
        materials: ((j['materials'] as List?) ?? []).map((x) => CurrentWorkMaterial.fromJson((x as Map).cast<String, dynamic>())).toList(),
      );
}

class CurrentWorkMaterial {
  const CurrentWorkMaterial({required this.materialId, required this.quantity});
  final String materialId;
  final double quantity;
  factory CurrentWorkMaterial.fromJson(Map<String, dynamic> j) => CurrentWorkMaterial(materialId: j['materialId'] as String, quantity: (j['quantity'] as num).toDouble());
}
