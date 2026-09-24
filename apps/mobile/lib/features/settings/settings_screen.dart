import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'pay_rate.dart';

/// Who may open «Настройки»: anyone who can change a company-wide setting or read the action log.
bool canOpenSettings(List<String> perms) => perms.contains('PAY_RATE_MANAGE') || perms.contains('SETTINGS_MANAGE') || perms.contains('AUDIT_VIEW');

/// «Настройки»: company-wide settings, kept apart from the personal «Профиль» (§21). Deliberately small:
/// the one pay rate, the company contacts workers see, and the action log.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    final rate = ref.watch(payRateProvider);
    Widget tile(Key key, IconData icon, String title, String? subtitle, String path) => Card(
          child: ListTile(
            key: key,
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(path),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (me?.has('PAY_RATE_MANAGE') ?? false)
          tile(const Key('payRateTile'), Icons.payments_outlined, l.payRateTitle,
              rate.maybeWhen(data: (r) => '${formatUzs(r.ratePerKit)} ${l.currency}', orElse: () => '…'), '/admin/settings/pay-rate'),
        if (me?.has('SETTINGS_MANAGE') ?? false)
          tile(const Key('companyContactTile'), Icons.contact_phone_outlined, l.settingsCompanyContact, l.settingsCompanyContactHint, '/admin/settings/company-contact'),
        if (me?.has('AUDIT_VIEW') ?? false) tile(const Key('auditTile'), Icons.receipt_long_outlined, l.audit, null, '/admin/settings/audit'),
      ]),
    );
  }
}
