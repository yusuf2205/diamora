/// Home-screen numbers for SUPER_ADMIN/ADMIN/MANAGER (mirrors `DashboardService.get()` on the API exactly). Each
/// section is `null` when the viewer's permissions don't cover it (never a fabricated zero, never a 403 for the
/// whole screen) - the UI simply omits that card.
class StaffDashboard {
  const StaffDashboard({this.workers, this.work, this.finance});
  final DashboardWorkers? workers;
  final DashboardWork? work;
  final DashboardFinance? finance;

  factory StaffDashboard.fromJson(Map<String, dynamic> j) => StaffDashboard(
        workers: j['workers'] != null ? DashboardWorkers.fromJson((j['workers'] as Map).cast<String, dynamic>()) : null,
        work: j['work'] != null ? DashboardWork.fromJson((j['work'] as Map).cast<String, dynamic>()) : null,
        finance: j['finance'] != null ? DashboardFinance.fromJson((j['finance'] as Map).cast<String, dynamic>()) : null,
      );
}

class DashboardWorkers {
  const DashboardWorkers({required this.total, required this.active});
  final int total;
  final int active;
  factory DashboardWorkers.fromJson(Map<String, dynamic> j) => DashboardWorkers(total: j['total'] as int, active: j['active'] as int);
}

class DashboardWork {
  const DashboardWork({required this.inProgress, required this.toDeliver, required this.toPickup, required this.needsAcceptance, required this.overdue});
  final int inProgress;
  final int toDeliver;
  final int toPickup;
  final int needsAcceptance;
  final int overdue;
  factory DashboardWork.fromJson(Map<String, dynamic> j) => DashboardWork(
        inProgress: j['inProgress'] as int, toDeliver: j['toDeliver'] as int, toPickup: j['toPickup'] as int,
        needsAcceptance: j['needsAcceptance'] as int, overdue: j['overdue'] as int,
      );
}

/// Money as decimal strings (UZS, D-009) - formatted with `formatUzs()`, never parsed as double.
class DashboardFinance {
  const DashboardFinance({required this.due});
  final String due;
  factory DashboardFinance.fromJson(Map<String, dynamic> j) => DashboardFinance(due: j['due'] as String);
}
