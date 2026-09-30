import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../core/update/app_updater.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/models.dart';
import '../team/team_screen.dart' show teamRoleLabel;
import 'locale_controller.dart';
import '../chat/chat_profile.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) => ref.watch(authRepositoryProvider).sessions());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(authControllerProvider).value;
    final sessions = ref.watch(_sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            key: const Key('myProfileCard'),
            leading: PersonPhoto(name: me?.fullName ?? '', url: ref.watch(myProfileProvider).value?.avatar, radius: 24),
            title: Text(me?.fullName ?? ''),
            subtitle: Text([me?.phone ?? '', if (me != null) teamRoleLabel(l, me.role), if (ref.watch(myProfileProvider).value?.username != null) '@${ref.watch(myProfileProvider).value!.username}'].join(' · ')),
            trailing: const Icon(Icons.chevron_right_rounded),
            // photo, «о себе», @username - like Telegram's «Информация»
            onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true, builder: (_) => const MyProfileSheet()),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const Key('editName'),
            leading: const Icon(Icons.edit_rounded),
            title: Text(l.editName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showFormSheet<void>(context, showDragHandle: true, useSafeArea: false, builder: (_) => EditNameSheet(fullName: me?.fullName ?? '')),
          ),
        ),
        if (me?.isStaff ?? false) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_rounded),
              title: Text(l.changePassword),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showFormSheet<void>(context, showDragHandle: true, useSafeArea: false, builder: (_) => const ChangePasswordSheet()),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const UpdateTile(),
        const SizedBox(height: 16),
        Text(l.language, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        const LanguagePicker(),
        const SizedBox(height: 20),
        Text(l.devices, style: Theme.of(context).textTheme.titleSmall),
        ...sessions.maybeWhen(
          data: (items) => [
            for (final s in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.device.platform == 'IOS' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded),
                title: Text(s.device.name ?? s.device.platform),
                subtitle: Text(s.current ? l.thisDevice : s.lastUsedAt.substring(0, 16).replaceFirst('T', ' ')),
                trailing: s.current ? null : IconButton(tooltip: l.revoke, icon: const Icon(Icons.logout_rounded), onPressed: () async { await ref.read(authRepositoryProvider).revokeSession(s.id); ref.invalidate(_sessionsProvider); }),
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

/// First name + surname on editing (split on the first space), one fullName on the server.
(String, String) splitFullName(String fullName) {
  final s = fullName.trim();
  final i = s.indexOf(' ');
  return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 1).trim());
}

/// «Изменить имя»: anyone changes their OWN first name and surname.
class EditNameSheet extends ConsumerStatefulWidget {
  const EditNameSheet({super.key, required this.fullName});
  final String fullName;
  @override
  ConsumerState<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<EditNameSheet> {
  late final _first = TextEditingController(text: splitFullName(widget.fullName).$1);
  late final _last = TextEditingController(text: splitFullName(widget.fullName).$2);
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_first.text.trim().length < 2) return setState(() => _error = l.nameTooShort);
    final fullName = '${_first.text.trim()} ${_last.text.trim()}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authControllerProvider.notifier).rename(fullName);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.nameSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.editName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(key: const Key('firstName'), controller: _first, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.givenName], decoration: InputDecoration(labelText: l.firstName)),
        const SizedBox(height: 12),
        TextField(key: const Key('lastName'), controller: _last, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.familyName], decoration: InputDecoration(labelText: l.lastName)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton(key: const Key('saveName'), onPressed: _busy ? null : _save, child: Text(l.save)),
      ]),
    );
  }
}
