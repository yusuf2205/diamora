import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/models.dart';
import '../settings/pay_rate.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'locale_controller.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) => ref.watch(authRepositoryProvider).sessions());

/// ADMIN: entry to the ONE price of a 9 m kit, always showing the current value.
class _PayRateTile extends ConsumerWidget {
  const _PayRateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rate = ref.watch(payRateProvider);
    return Card(
      child: ListTile(
        key: const Key('payRateTile'),
        leading: const Icon(Icons.payments_outlined),
        title: Text(l.payRateTitle),
        subtitle: Text(rate.maybeWhen(data: (r) => '${formatUzs(r.ratePerKit)} ${l.currency}', orElse: () => '…')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/profile/pay-rate'),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    final sessions = ref.watch(_sessionsProvider);
    final locale = ref.watch(localeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: CircleAvatar(child: Text(initials(me?.fullName ?? ''))), title: Text(me?.fullName ?? ''), subtitle: Text('${me?.phone ?? ''} · ${me == null ? '' : teamRoleLabel(l, me.role)}'))),
        if (me?.isStaff == true) ...[
          const SizedBox(height: 8),
          const _PayRateTile(),
          if (me!.has('LIVE_LOCATION_VIEW_ALL') || me.has('LIVE_LOCATION_VIEW_ASSIGNED')) ...[
            const SizedBox(height: 8),
            Card(child: ListTile(leading: const Icon(Icons.place_outlined), title: Text(l.locations), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/admin/profile/locations'))),
          ],
          if (me.has('SETTINGS_MANAGE')) ...[
            const SizedBox(height: 8),
            Card(child: ListTile(leading: const Icon(Icons.contact_phone_outlined), title: Text(l.settingsCompanyContact), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/admin/profile/company-contact'))),
          ],
          if (me.has('AUDIT_VIEW')) ...[
            const SizedBox(height: 8),
            Card(child: ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(l.audit), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/admin/profile/audit'))),
          ],
        ],
        const SizedBox(height: 16),
        Text(l.language, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'ru', label: Text('Русский')), ButtonSegment(value: 'uz', label: Text("O'zbekcha"))],
          selected: {locale.languageCode},
          onSelectionChanged: (s) => ref.read(localeControllerProvider.notifier).set(s.first),
        ),
        const SizedBox(height: 20),
        Text(l.devices, style: Theme.of(context).textTheme.titleSmall),
        ...sessions.maybeWhen(
          data: (items) => [
            for (final s in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.device.platform == 'IOS' ? Icons.phone_iphone : Icons.phone_android),
                title: Text(s.device.name ?? s.device.platform),
                subtitle: Text(s.current ? l.thisDevice : s.lastUsedAt.substring(0, 16).replaceFirst('T', ' ')),
                trailing: s.current ? null : TextButton(onPressed: () async { await ref.read(authRepositoryProvider).revokeSession(s.id); ref.invalidate(_sessionsProvider); }, child: Text(l.revoke)),
              ),
          ],
          orElse: () => const <Widget>[],
        ),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(everywhere: true), child: Text(l.logoutAll)),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(l.signOut)),
      ]),
    );
  }
}
