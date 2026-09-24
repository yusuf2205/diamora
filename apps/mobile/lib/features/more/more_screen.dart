import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// «Ещё» (§11): everything a staff member needs less often than every day, kept out of the bottom bar so the bar stays
/// at five clear tabs. Each screen still decides for itself what the viewer's permissions let her see.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <(IconData, String, String)>[
      (Icons.qr_code_scanner, l.qrScan, '/admin/qr-scan'),
      (Icons.auto_awesome_outlined, l.catalog, '/admin/catalog'),
      (Icons.badge_outlined, l.team, '/admin/team'),
      (Icons.person_outline, l.profile, '/admin/profile'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.more)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final i in items)
            Card(
              child: ListTile(
                leading: Icon(i.$1),
                title: Text(i.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(i.$3),
              ),
            ),
        ],
      ),
    );
  }
}
