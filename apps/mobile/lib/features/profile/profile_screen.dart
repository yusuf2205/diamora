import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/models.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'locale_controller.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) => ref.watch(authRepositoryProvider).sessions());

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
        if (me?.isStaff ?? false) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(l.changePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const ChangePasswordSheet()),
            ),
          ),
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

/// «Сменить пароль»: current + new twice. A wrong current password is said plainly and never signs anyone out.
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});
  @override
  ConsumerState<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_next.text.length < 8) return setState(() => _error = l.passwordTooShort);
    if (_next.text != _repeat.text) return setState(() => _error = l.passwordsDontMatch);
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).changePassword(_current.text, _next.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.passwordChanged)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == 'WRONG_PASSWORD' ? l.wrongCurrentPassword : errorText(context, e));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget field(TextEditingController c, String label, List<String> hints) =>
        TextField(controller: c, obscureText: true, enabled: !_busy, autofillHints: hints, decoration: InputDecoration(labelText: label));
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.changePassword, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          field(_current, l.currentPassword, const [AutofillHints.password]),
          const SizedBox(height: 12),
          field(_next, l.newPassword, const [AutofillHints.newPassword]),
          const SizedBox(height: 12),
          field(_repeat, l.repeatPassword, const [AutofillHints.newPassword]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.changePassword)),
        ]),
      ),
    );
  }
}
