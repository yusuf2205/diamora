/// M3: the worker's current job (§8). Mirrors `AssignmentsService.dto` on the API — one source of truth, no client math
/// beyond what's needed to draw a progress bar.
class CurrentWork {
  const CurrentWork({
    required this.id, required this.code, required this.status, required this.kitCount, required this.plannedMeters,
    required this.reportedMeters, this.calculatedPayment, this.expectedPayment, this.dueAt, this.notes,
    required this.productName, this.variantLabel, required this.colorName, this.colorHex,
    required this.materials, this.handoff,
  });
  final String id;
  final String code;
  final String status;
  final int kitCount;
  final double plannedMeters;
  final double reportedMeters;
  final String? calculatedPayment;
  /// what she earns if everything is accepted (server-computed at the current global rate)
  final String? expectedPayment;
  final DateTime? dueAt;
  final String? notes;
  final String productName;
  final String? variantLabel;
  final String colorName;
  final String? colorHex;
  final List<CurrentWorkMaterial> materials;
  final HandoffInfo? handoff;

  double get percent => plannedMeters > 0 ? (reportedMeters / plannedMeters * 100).clamp(0, 100) : 0;
  double get remainingMeters => (plannedMeters - reportedMeters).clamp(0, plannedMeters);

  /// Assigned but not physically received yet: the worker sees it, but cannot work on it (Phase 5.1).
  bool get awaitingReceipt => status == 'READY_TO_DELIVER' || status == 'DRAFT';

  /// Staff has scanned the QR at her door: she can scan it too and confirm.
  bool get kitReadyToReceive => awaitingReceipt && handoff != null && handoff!.status == 'AWAITING_WORKER' && !handoff!.expired;

  factory CurrentWork.fromJson(Map<String, dynamic> j) => CurrentWork(
        id: j['id'] as String, code: j['code'] as String, status: j['status'] as String, kitCount: (j['kitCount'] as num).toInt(),
        plannedMeters: (j['plannedMeters'] as num).toDouble(), reportedMeters: (j['reportedMeters'] as num?)?.toDouble() ?? 0,
        calculatedPayment: j['calculatedPayment'] as String?, expectedPayment: j['expectedPayment'] as String?,
        dueAt: j['dueAt'] != null ? DateTime.tryParse(j['dueAt'] as String) : null, notes: j['notes'] as String?,
        productName: (j['product'] as Map?)?['name'] as String? ?? '', variantLabel: (j['variant'] as Map?)?['label'] as String?,
        colorName: (j['color'] as Map?)?['name'] as String? ?? '', colorHex: (j['color'] as Map?)?['hex'] as String?,
        materials: ((j['materials'] as List?) ?? []).map((x) => CurrentWorkMaterial.fromJson((x as Map).cast<String, dynamic>())).toList(),
        handoff: j['handoff'] is Map ? HandoffInfo.fromJson((j['handoff'] as Map).cast<String, dynamic>()) : null,
      );
}

class CurrentWorkMaterial {
  const CurrentWorkMaterial({required this.materialId, required this.quantity, this.name, this.unit});
  final String materialId;
  final double quantity;
  final String? name;
  final String? unit;
  factory CurrentWorkMaterial.fromJson(Map<String, dynamic> j) => CurrentWorkMaterial(
        materialId: j['materialId'] as String, quantity: (j['quantity'] as num).toDouble(), name: j['name'] as String?, unit: j['unit'] as String?,
      );
}

/// «Органза — 18 м», «Бисер — 80 г»: a material line in plain words.
String materialLine(String? name, double quantity, String? unit) {
  final q = quantity == quantity.truncateToDouble() ? quantity.toStringAsFixed(0) : quantity.toStringAsFixed(2);
  final u = switch (unit) { 'METER' => 'м', 'GRAM' => 'г', 'PCS' => 'шт', 'SET' => 'компл.', 'ROLL' => 'рул.', 'PACKAGE' => 'уп.', _ => unit ?? '' };
  return '${name ?? '—'} — $q $u'.trimRight();
}

/// The latest two-sided QR handoff of an assignment (Phase 5).
class HandoffInfo {
  const HandoffInfo({
    required this.id, required this.status, required this.startedAt, required this.expired, required this.staffName,
    this.workerScannedAt, this.workerAcceptedAt, this.problemReason, this.problemComment,
  });
  final String id;
  /// AWAITING_WORKER | CONFIRMED | PROBLEM | EXPIRED
  final String status;
  final DateTime startedAt;
  final bool expired;
  final String staffName;
  final DateTime? workerScannedAt;
  final DateTime? workerAcceptedAt;
  final String? problemReason;
  final String? problemComment;

  bool get waiting => status == 'AWAITING_WORKER' && !expired;

  factory HandoffInfo.fromJson(Map<String, dynamic> j) => HandoffInfo(
        id: j['id'] as String, status: j['status'] as String, startedAt: DateTime.parse(j['startedAt'] as String),
        expired: j['expired'] as bool? ?? false, staffName: (j['staff'] as Map?)?['fullName'] as String? ?? '',
        workerScannedAt: j['workerScannedAt'] != null ? DateTime.tryParse(j['workerScannedAt'] as String) : null,
        workerAcceptedAt: j['workerAcceptedAt'] != null ? DateTime.tryParse(j['workerAcceptedAt'] as String) : null,
        problemReason: j['problemReason'] as String?, problemComment: j['problemComment'] as String?,
      );
}

/// One human line of the handoff timeline: HANDOFF_STARTED | WORKER_SCANNED | WORKER_CONFIRMED | WORKER_PROBLEM.
class HandoffTimelineEntry {
  const HandoffTimelineEntry({required this.kind, required this.at, this.by, this.reason});
  final String kind;
  final DateTime at;
  final String? by;
  final String? reason;
  factory HandoffTimelineEntry.fromJson(Map<String, dynamic> j) => HandoffTimelineEntry(
        kind: j['kind'] as String, at: DateTime.parse(j['at'] as String), by: j['by'] as String?, reason: j['reason'] as String?,
      );
}

/// Result of the worker scanning a kit QR: the handoff to confirm and exactly what she is about to receive.
class HandoffScan {
  const HandoffScan({required this.handoffId, required this.state, required this.work});
  final String handoffId;
  /// AWAITING_WORKER = review and confirm; CONFIRMED = she already received it
  final String state;
  final CurrentWork work;
  factory HandoffScan.fromJson(Map<String, dynamic> j) => HandoffScan(
        handoffId: j['handoffId'] as String, state: j['state'] as String,
        work: CurrentWork.fromJson((j['assignment'] as Map).cast<String, dynamic>()),
      );
}
