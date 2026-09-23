import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';

enum _Step { phone, password, code }

/// The single Login Screen. The human only ever gives a phone number — never picks a role. The server (`/auth/identify`)
/// decides whether the next field is a password (staff) or a Telegram code (worker) and opens the matching UI itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Step _step = _Step.phone;
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

  bool _looksLikePhone(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 && digits.length <= 15;
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

  void _submitPhone() {
    final l = AppLocalizations.of(context);
    final phone = _phone.text.trim();
    if (phone.isEmpty) return showError(context, ApiException(code: 'VALIDATION_FAILED', message: l.phoneRequired));
    if (!_looksLikePhone(phone)) return showError(context, ApiException(code: 'VALIDATION_FAILED', message: l.invalidPhoneFormat));
    _run(() async {
      final method = await ref.read(authRepositoryProvider).identify(phone);
      if (!mounted) return;
      setState(() => _step = method == 'PASSWORD' ? _Step.password : _Step.code);
    });
  }

  void _resendCode() => _run(() => ref.read(authRepositoryProvider).identify(_phone.text.trim()));

  void _back() => setState(() {
        _step = _Step.phone;
        _password.clear();
        _code.clear();
      });

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
                Text(l.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 28),
                if (_step != _Step.phone) ...[
                  Row(children: [
                    IconButton(onPressed: _busy ? null : _back, icon: const Icon(Icons.arrow_back)),
                    Expanded(child: Text(_phone.text.trim(), style: Theme.of(context).textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (_step == _Step.phone) ...[
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(labelText: l.phone, hintText: '+998 90 123 45 67', prefixIcon: const Icon(Icons.phone_outlined)),
                    onSubmitted: (_) => _busy ? null : _submitPhone(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _submitPhone, child: Text(l.continueAction)),
                ] else if (_step == _Step.password) ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password, prefixIcon: const Icon(Icons.lock_outline)),
                    onSubmitted: (_) => _busy ? null : _run(() => auth.adminLogin(_phone.text.trim(), _password.text)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : () => _run(() => auth.adminLogin(_phone.text.trim(), _password.text)), child: Text(l.signIn)),
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
                    onSubmitted: (_) => _busy ? null : _run(() => auth.workerLogin(_phone.text.trim(), _code.text.trim())),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : () => _run(() => auth.workerLogin(_phone.text.trim(), _code.text.trim())), child: Text(l.signIn)),
                  TextButton(onPressed: _busy ? null : _resendCode, child: Text(l.resendCode)),
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
