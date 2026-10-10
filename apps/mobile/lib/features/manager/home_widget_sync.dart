import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../l10n/app_localizations.dart';
import '../dashboard/dashboard_models.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// The home-screen widget (Android, ManagerWidgetProvider.kt): «Сегодня · отвезти N · забрать M · просрочено K», written
/// in the app's language every time «Обзор» refreshes. Never breaks anything: no widget placed / no plugin -> nothing.
Future<void> syncHomeWidget(AppLocalizations l, StaffDashboard d) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final w = d.work;
  if (w == null) return;
  final now = DateTime.now();
  try {
    await HomeWidget.saveWidgetData<String>('w_title', '💎 Diamoraa · ${l.widgetToday}');
    await HomeWidget.saveWidgetData<String>('w_line1', l.widgetDeliver('${w.toDeliver}'));
    await HomeWidget.saveWidgetData<String>('w_line2', l.widgetPickup('${w.toPickup}'));
    await HomeWidget.saveWidgetData<String>('w_line3', w.overdue > 0 ? l.widgetOverdue('${w.overdue}') : null);
    await HomeWidget.saveWidgetData<String>('w_updated', '${_two(now.hour)}:${_two(now.minute)}');
    await HomeWidget.updateWidget(androidName: 'ManagerWidgetProvider');
  } catch (_) {
    /* the widget is a nicety: a missing plugin or storage hiccup never touches the app */
  }
}
