import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'models.dart';
import '../profile/locale_controller.dart';

enum _Step { phone, password }

/// The single Login Screen. Everyone signs in through Telegram (owner, 2026-10-11): the bot knows a returning
/// worker or staff member at once and sends them straight back; a new Telegram account is asked for its phone first.
/// STAFF keep phone + password as a fallback behind «Войти по паролю» (the server says PASSWORD, never a role picked
/// by the client). WORKER: no phone/password/OTP field for her, ever — the server alone decides who anyone is.
/// While Telegram is open the screen keeps asking the server whether the bot let this login in, so coming back to the
/// app is enough; the bot's «Открыть Diamoraa» button does the same.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with WidgetsBindingObserver {
  _Step _step = _Step.phone;
  bool _busy = false;
  bool _openingTelegram = false;
  bool _withPassword = false;
  final _phone = TextEditingController();
  final _password = TextEditingController();
  // the Telegram login in progress: its session token, asked about every 2 s (and at once on coming back to the app)
  String? _waitingToken;
  DateTime _waitUntil = DateTime.now();
  Timer? _poll;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _askServer();
  }

  void _waitFor(String deepLink) {
    final token = Uri.tryParse(deepLink)?.queryParameters['start'];
    if (token == null || token.isEmpty) return;
    setState(() => _waitingToken = token);
    _waitUntil = DateTime.now().add(const Duration(minutes: 15));
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _askServer());
  }

  void _stopWaiting() {
    _poll?.cancel();
    _poll = null;
    if (mounted) setState(() => _waitingToken = null);
  }

  Future<void> _askServer() async {
    final token = _waitingToken;
    if (token == null || _asking) return;
    if (DateTime.now().isAfter(_waitUntil)) return _stopWaiting();
    _asking = true;
    try {
      final outcome = await ref.read(authControllerProvider.notifier).telegramPoll(token);
      if (outcome == null || !mounted) return;
      _stopWaiting();
      // signed in: the session change alone moves the router on; not ready yet (pending / rejected / paused): say so
      if (outcome is TelegramNotReady) {
        context.go(Uri(path: '/telegram-pending', queryParameters: {'status': outcome.status, if (outcome.reason != null) 'reason': outcome.reason!}).toString());
      }
    } on ApiException catch (e) {
      if (!e.isOffline) _stopWaiting(); // the session ended (used by the bot's button, or expired): nothing to wait for
    } catch (_) {
      _stopWaiting();
    } finally {
      _asking = false;
    }
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
      // Straight into the Telegram app (tg://): a https://t.me link may open in the browser instead, and t.me itself is
      // unreachable on some mobile networks here while the Telegram app works fine. The web link is only the fallback.
      final app = telegramAppUri(deepLink);
      var opened = app != null && await launchUrl(app, mode: LaunchMode.externalNonBrowserApplication).catchError((_) => false);
      if (!opened) opened = await launchUrl(Uri.parse(deepLink), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showError(context, ApiException(code: 'NETWORK', message: AppLocalizations.of(context).telegramLoginFailed));
      } else if (opened) {
        _waitFor(deepLink);
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
                const LanguagePicker(),
                const SizedBox(height: 20),
                Icon(Icons.diamond_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(l.appTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                Text(l.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 28),
                if (_step == _Step.password) ...[
                  Row(children: [
                    IconButton(onPressed: _busy ? null : _back, icon: const Icon(Icons.arrow_back_rounded)),
                    Expanded(child: Text(_phone.text.trim(), style: Theme.of(context).textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (_step == _Step.phone) ...[
                  // workers are the majority and never have a password: Telegram is THE button, big and first
                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _openingTelegram ? null : _signInWithTelegram,
                      icon: _openingTelegram ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 24),
                      label: Text(_openingTelegram ? l.openingTelegram : l.signInWithTelegram, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.telegramLoginHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (_waitingToken != null) ...[
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.schedule_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Flexible(child: Text(l.waitingForTelegram, textAlign: TextAlign.center)),
                    ]),
                  ],
                  const SizedBox(height: 32),
                  // staff only, a fallback when Telegram is not at hand: small, out of the way
                  if (!_withPassword)
                    Center(child: TextButton(onPressed: () => setState(() => _withPassword = true), child: Text(l.signInWithPassword))),
                  if (_withPassword) ...[
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.staffSignIn, style: Theme.of(context).textTheme.bodySmall)),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(labelText: l.phone, hintText: '+998 90 123 45 67', prefixIcon: const Icon(Icons.phone_rounded)),
                    onSubmitted: (_) => _busy ? null : _submitPhone(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _busy ? null : _submitPhone, child: Text(l.continueAction)),
                  ],
                ] else ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(labelText: l.password, prefixIcon: const Icon(Icons.lock_outline_rounded)),
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

/// `https://t.me/<bot>?start=<token>` -> `tg://resolve?domain=<bot>&start=<token>` (opens the Telegram app itself).
/// Null for anything that is not a t.me bot link.
Uri? telegramAppUri(String deepLink) {
  final u = Uri.tryParse(deepLink);
  if (u == null || u.host != 't.me' || u.pathSegments.length != 1) return null;
  return Uri(scheme: 'tg', host: 'resolve', queryParameters: {'domain': u.pathSegments.first, ...u.queryParameters});
}
