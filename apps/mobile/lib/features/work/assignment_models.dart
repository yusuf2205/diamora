/// Staff-side assignment detail (§4-7, §12-14) — mirrors `AssignmentsService.dto` on the API exactly.
class AssignmentDetail {
  const AssignmentDetail({
    required this.id, required this.code, required this.status, required this.kitCount, required this.plannedMeters,
    required this.reportedMeters, required this.deliveredMeters, required this.acceptedMeters, required this.defectiveMeters,
    this.calculatedPayment, this.dueAt, this.notes, this.qrCode,
    required this.workerId, required this.workerName, required this.workerPhone,
    required this.productName, this.variantLabel, required this.colorName, this.colorHex,
    required this.materials, required this.statusHistory, required this.deliveries,
  });
  final String id;
  final String code;
  final String status;
  final int kitCount;
  final double plannedMeters;
  final double reportedMeters;
  final double deliveredMeters;
  final double acceptedMeters;
  final double defectiveMeters;
  final String? calculatedPayment;
  final DateTime? dueAt;
  final String? notes;
  final String? qrCode;
  final String workerId;
  final String workerName;
  final String workerPhone;
  final String productName;
  final String? variantLabel;
  final String colorName;
  final String? colorHex;
  final List<AssignmentMaterialLine> materials;
  final List<AssignmentStatusEvent> statusHistory;
  final List<AssignmentDelivery> deliveries;

  double get percent => plannedMeters > 0 ? (reportedMeters / plannedMeters * 100).clamp(0, 100) : 0;

  factory AssignmentDetail.fromJson(Map<String, dynamic> j) {
    final worker = (j['worker'] as Map?)?.cast<String, dynamic>() ?? const {};
    final product = (j['product'] as Map?)?.cast<String, dynamic>();
    final variant = (j['variant'] as Map?)?.cast<String, dynamic>();
    final color = (j['color'] as Map?)?.cast<String, dynamic>();
    return AssignmentDetail(
      id: j['id'] as String, code: j['code'] as String, status: j['status'] as String, kitCount: (j['kitCount'] as num).toInt(),
      plannedMeters: (j['plannedMeters'] as num).toDouble(), reportedMeters: (j['reportedMeters'] as num?)?.toDouble() ?? 0,
      deliveredMeters: (j['deliveredMeters'] as num?)?.toDouble() ?? 0, acceptedMeters: (j['acceptedMeters'] as num?)?.toDouble() ?? 0,
      defectiveMeters: (j['defectiveMeters'] as num?)?.toDouble() ?? 0, calculatedPayment: j['calculatedPayment'] as String?,
      dueAt: j['dueAt'] != null ? DateTime.tryParse(j['dueAt'] as String) : null, notes: j['notes'] as String?, qrCode: j['qrCode'] as String?,
      workerId: worker['id'] as String? ?? '', workerName: worker['fullName'] as String? ?? '', workerPhone: worker['phone'] as String? ?? '',
      productName: product?['name'] as String? ?? '', variantLabel: variant?['label'] as String?,
      colorName: color?['name'] as String? ?? '', colorHex: color?['hex'] as String?,
      materials: ((j['materials'] as List?) ?? const []).map((x) => AssignmentMaterialLine.fromJson((x as Map).cast<String, dynamic>())).toList(),
      statusHistory: ((j['statusHistory'] as List?) ?? const []).map((x) => AssignmentStatusEvent.fromJson((x as Map).cast<String, dynamic>())).toList(),
      deliveries: ((j['deliveries'] as List?) ?? const []).map((x) => AssignmentDelivery.fromJson((x as Map).cast<String, dynamic>())).toList(),
    );
  }
}

class AssignmentMaterialLine {
  const AssignmentMaterialLine({required this.materialId, required this.quantity});
  final String materialId;
  final double quantity;
  factory AssignmentMaterialLine.fromJson(Map<String, dynamic> j) => AssignmentMaterialLine(materialId: j['materialId'] as String, quantity: (j['quantity'] as num).toDouble());
}

class AssignmentStatusEvent {
  const AssignmentStatusEvent({this.from, required this.to, required this.actor, this.comment, required this.changedAt});
  final String? from;
  final String to;
  final String actor;
  final String? comment;
  final DateTime changedAt;
  factory AssignmentStatusEvent.fromJson(Map<String, dynamic> j) => AssignmentStatusEvent(
        from: j['from'] as String?, to: j['to'] as String, actor: j['actor'] as String, comment: j['comment'] as String?,
        changedAt: DateTime.parse(j['changedAt'] as String),
      );
}

class AssignmentDelivery {
  const AssignmentDelivery({required this.id, required this.code, required this.type, required this.status, this.completedAt});
  final String id;
  final String code;
  final String type; // DELIVERY_TO_WORKER | PICKUP_FROM_WORKER
  final String status; // PENDING | COMPLETED | CANCELLED
  final DateTime? completedAt;
  factory AssignmentDelivery.fromJson(Map<String, dynamic> j) => AssignmentDelivery(
        id: j['id'] as String, code: j['code'] as String, type: j['type'] as String, status: j['status'] as String,
        completedAt: j['completedAt'] != null ? DateTime.tryParse(j['completedAt'] as String) : null,
      );
}

/// A row in the "Нужно доставить"/"Есть что забрать" lists — the same lightweight shape either way.
class AssignmentSummary {
  const AssignmentSummary({
    required this.id, required this.status, required this.plannedMeters, required this.reportedMeters,
    this.dueAt, required this.workerName, required this.productName, required this.colorName,
  });
  final String id;
  final String status;
  final double plannedMeters;
  final double reportedMeters;
  final DateTime? dueAt;
  final String workerName;
  final String productName;
  final String colorName;
  factory AssignmentSummary.fromJson(Map<String, dynamic> j) {
    final worker = (j['worker'] as Map?)?.cast<String, dynamic>() ?? const {};
    final product = (j['product'] as Map?)?.cast<String, dynamic>();
    final color = (j['color'] as Map?)?.cast<String, dynamic>();
    return AssignmentSummary(
      id: j['id'] as String, status: j['status'] as String, plannedMeters: (j['plannedMeters'] as num).toDouble(),
      reportedMeters: (j['reportedMeters'] as num?)?.toDouble() ?? 0,
      dueAt: j['dueAt'] != null ? DateTime.tryParse(j['dueAt'] as String) : null,
      workerName: worker['fullName'] as String? ?? '', productName: product?['name'] as String? ?? '', colorName: color?['name'] as String? ?? '',
    );
  }
}
