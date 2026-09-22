import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';

/// ADMIN: phone + password. WORKER: phone -> one-time code that the Telegram bot sends to her chat.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _admin = false;
  bool _codeSent = false;
  bool _busy = false;
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = ref.read(authControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.diamond_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(l.appTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: [ButtonSegment(value: false, label: Text(l.iAmWorker)), ButtonSegment(value: true, label: Text(l.iAmAdmin))],
                  selected: {_admin},
                  onSelectionChanged: (s) => setState(() {
                    _admin = s.first;
                    _codeSent = false;
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(labelText: l.phone, hintText: '+998 90 123 45 67', prefixIcon: const Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                if (_admin) ...[
                  TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: l.password, prefixIcon: const Icon(Icons.lock_outline))),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : () => _run(() => auth.adminLogin(_phone.text, _password.text)), child: Text(l.signIn)),
                ] else if (!_codeSent) ...[
                  Text(l.workerLoginHint, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    onPressed: _busy
                        ? null
                        : () {
                            if (_phone.text.trim().isEmpty) return showError(context, ApiException(code: 'VALIDATION_FAILED', message: l.phoneRequired));
                            _run(() async {
                              await ref.read(authRepositoryProvider).requestWorkerCode(_phone.text);
                              if (mounted) setState(() => _codeSent = true);
                            });
                          },
                    label: Text(l.getCode),
                  ),
                ] else ...[
                  Text(l.codeSent, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(labelText: l.codeHint, counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : () => _run(() => auth.workerLogin(_phone.text, _code.text.trim())), child: Text(l.signIn)),
                  TextButton(onPressed: () => setState(() => _codeSent = false), child: Text(l.retry)),
                ],
                if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
