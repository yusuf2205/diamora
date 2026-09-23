import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Shown after a Telegram handoff that did NOT produce a session (§14: never the Worker UI for an unapproved
/// mastеritsa) — status is one of PENDING_APPROVAL / REJECTED / PAUSED / ERROR (apps/api's TelegramExchangeResult).
class TelegramPendingScreen extends StatelessWidget {
  const TelegramPendingScreen({super.key, required this.status, this.reason});
  final String status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, title, body) = switch (status) {
      'PENDING_APPROVAL' => (Icons.hourglass_top, l.pendingApprovalTitle, l.pendingApprovalBody),
      'REJECTED' => (Icons.block, l.rejectedTitle, reason ?? l.pendingApprovalBody),
      'PAUSED' => (Icons.pause_circle_outline, l.workerPausedTitle, l.workerPausedBody),
      _ => (Icons.error_outline, l.genericError, l.telegramLoginFailed),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.go('/login'), child: Text(l.backToLogin)),
            ]),
          ),
        ),
      ),
    );
  }
}
