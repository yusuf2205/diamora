import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_screen.dart' show canOpenSettings;

/// «Ещё» (§11): everything a staff member needs less often than every day, kept out of the bottom bar so the bar stays
/// at five clear tabs. Each screen still decides for itself what the viewer's permissions let her see.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final perms = ref.watch(authControllerProvider).value?.permissions ?? const <String>[];
    final items = <(IconData, String, String)>[
      (Icons.qr_code_scanner_rounded, l.qrScan, '/admin/qr-scan'),
      (Icons.auto_awesome_rounded, l.catalog, '/admin/catalog'),
      (Icons.badge_rounded, l.team, '/admin/team'),
      if (perms.contains('COLLATERAL_VIEW')) (Icons.lock_rounded, l.collateralsTitle, '/admin/collaterals'),
      if (perms.contains('FINANCE_VIEW_ALL') || perms.contains('FINANCE_VIEW_ASSIGNED') || perms.contains('PROFIT_VIEW')) (Icons.bar_chart_rounded, l.reportsTitle, '/admin/reports'),
      if (canOpenSettings(perms)) (Icons.settings_rounded, l.settingsTitle, '/admin/settings'),
      (Icons.person_outline_rounded, l.profile, '/admin/profile'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.more)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final i in items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(i.$1),
                title: Text(i.$2),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(i.$3),
              ),
            ),
        ],
      ),
    );
  }
}
