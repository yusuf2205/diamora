/// Home-screen numbers for SUPER_ADMIN/ADMIN/MANAGER (mirrors `DashboardService.get()` on the API exactly). Each
/// section is `null` when the viewer's permissions don't cover it (never a fabricated zero, never a 403 for the
/// whole screen) - the UI simply omits that card.
class StaffDashboard {
  const StaffDashboard({this.workers, this.work, this.finance, this.today});
  final DashboardWorkers? workers;
  final DashboardWork? work;
  final DashboardFinance? finance;
  final DashboardToday? today;

  factory StaffDashboard.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(String k) => j[k] == null ? null : (j[k] as Map).cast<String, dynamic>();
    return StaffDashboard(
      workers: m('workers') == null ? null : DashboardWorkers.fromJson(m('workers')!),
      work: m('work') == null ? null : DashboardWork.fromJson(m('work')!),
      finance: m('finance') == null ? null : DashboardFinance.fromJson(m('finance')!),
      today: m('today') == null ? null : DashboardToday.fromJson(m('today')!),
    );
  }
}

class DashboardWorkers {
  const DashboardWorkers({required this.total, required this.active});
  final int total;
  final int active;
  factory DashboardWorkers.fromJson(Map<String, dynamic> j) => DashboardWorkers(total: j['total'] as int, active: j['active'] as int);
}

class DashboardWork {
  const DashboardWork({
    required this.inProgress, required this.toDeliver, required this.toPickup, required this.needsAcceptance, required this.overdue,
    this.reworkRequired = 0,
  });
  final int inProgress;
  final int toDeliver;
  final int toPickup;
  final int needsAcceptance;
  final int overdue;
  final int reworkRequired;
  factory DashboardWork.fromJson(Map<String, dynamic> j) => DashboardWork(
        inProgress: j['inProgress'] as int, toDeliver: j['toDeliver'] as int, toPickup: j['toPickup'] as int,
        needsAcceptance: j['needsAcceptance'] as int, overdue: j['overdue'] as int, reworkRequired: (j['reworkRequired'] as int?) ?? 0,
      );
}

/// Money as decimal strings (UZS, D-009) - formatted with `formatUzs()`, never parsed as double.
class DashboardFinance {
  const DashboardFinance({required this.due, this.workersDue = 0});
  final String due;
  final int workersDue;
  factory DashboardFinance.fromJson(Map<String, dynamic> j) => DashboardFinance(due: j['due'] as String, workersDue: (j['workersDue'] as int?) ?? 0);
}

/// Today in the business's own time zone; each figure is `null` when the viewer may not see that kind of data.
class DashboardToday {
  const DashboardToday({this.dueToday, this.deliveredToday, this.pickedUpToday, this.paidToday});
  final int? dueToday;
  final int? deliveredToday;
  final int? pickedUpToday;
  final String? paidToday;
  factory DashboardToday.fromJson(Map<String, dynamic> j) => DashboardToday(
        dueToday: j['dueToday'] as int?, deliveredToday: j['deliveredToday'] as int?,
        pickedUpToday: j['pickedUpToday'] as int?, paidToday: j['paidToday'] as String?,
      );
}
