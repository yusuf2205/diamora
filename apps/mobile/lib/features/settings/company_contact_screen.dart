import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'company_contact.dart';

/// SETTINGS_MANAGE (§13): the phone/Telegram the WORKER catalog shows on "Позвонить" / "Написать в Telegram".
class CompanyContactScreen extends ConsumerStatefulWidget {
  const CompanyContactScreen({super.key});
  @override
  ConsumerState<CompanyContactScreen> createState() => _CompanyContactScreenState();
}

class _CompanyContactScreenState extends ConsumerState<CompanyContactScreen> {
  final _phone = TextEditingController();
  final _telegram = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final contact = ref.watch(companyContactProvider);
    contact.whenData((c) {
      if (!_loaded) {
        _phone.text = c.phone ?? '';
        _telegram.text = c.telegramUsername ?? '';
        _loaded = true;
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsCompanyContact)),
      body: contact.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
        data: (_) => ListView(padding: AppTokens.screenPadding.copyWith(top: 16, bottom: 24), children: [
          Text(l.settingsCompanyContactHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.settingsPhone)),
          const SizedBox(height: 12),
          TextField(controller: _telegram, decoration: InputDecoration(labelText: l.settingsTelegram, prefixText: '@')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(companyContactRepositoryProvider).update(
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            telegramUsername: _telegram.text.trim().isEmpty ? null : _telegram.text.trim(),
          );
      ref.invalidate(companyContactProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).catalogSaved)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
