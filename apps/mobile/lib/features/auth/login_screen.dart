import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';

enum _Step { phone, password }

/// The single Login Screen. STAFF (SUPER_ADMIN/ADMIN/MANAGER): phone -> the server says PASSWORD, never a role
/// picked by the client. WORKER: Telegram-only, always — no phone/password/OTP field for her, ever (§ critical
/// business requirement). Both live on this one screen; picking between them is picking a login METHOD, never a
/// role — the server alone still decides who anyone actually is, on both paths.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Step _step = _Step.phone;
  bool _busy = false;
  bool _openingTelegram = false;
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
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
      if (method == 'PASSWORD') {
        setState(() => _step = _Step.password);
      } else if (mounted) {
        // A worker's own phone, typed into the staff field: she doesn't use this field at all — point her at the
        // Telegram button below. errorText()'s VALIDATION_FAILED case means something else app-wide (D-042), so
        // this bypasses showError()/errorText() and shows the SnackBar directly, same pattern as
        // create_assignment_screen.dart's INSUFFICIENT_STOCK case.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.workersUseTelegram)));
      }
    });
  }

  void _back() => setState(() {
        _step = _Step.phone;
        _password.clear();
      });

  Future<void> _signInWithTelegram() async {
    setState(() => _openingTelegram = true);
    try {
      final deepLink = await ref.read(authRepositoryProvider).telegramSession();
      final opened = await launchUrl(Uri.parse(deepLink), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showError(context, ApiException(code: 'NETWORK', message: AppLocalizations.of(context).telegramLoginFailed));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _openingTelegram = false);
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
                Text(l.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 28),
                if (_step == _Step.password) ...[
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
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.orDivider, style: Theme.of(context).textTheme.bodySmall)),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _openingTelegram ? null : _signInWithTelegram,
                    icon: _openingTelegram ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                    label: Text(_openingTelegram ? l.openingTelegram : l.signInWithTelegram),
                  ),
                ] else ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password, prefixIcon: const Icon(Icons.lock_outline)),
                    onSubmitted: (_) => _busy ? null : _run(() => auth.adminLogin(_phone.text.trim(), _password.text)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : () => _run(() => auth.adminLogin(_phone.text.trim(), _password.text)), child: Text(l.signIn)),
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
