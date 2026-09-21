import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_exception.dart';
import '../providers.dart';

/// Amber banner while the phone has no network.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: scheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(Icons.cloud_off, size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(child: Text(AppLocalizations.of(context).offlineBanner, style: TextStyle(color: scheme.onTertiaryContainer))),
              ]),
            ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.hint});
  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (hint != null) ...[const SizedBox(height: 6), Text(hint!, textAlign: TextAlign.center)],
          ]),
        ),
      );
}

/// Grey placeholder rows while data loads (better than a spinner on slow mobile networks).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, _) => ListTile(
        leading: CircleAvatar(backgroundColor: c),
        title: Container(height: 14, width: 160, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        subtitle: Container(height: 10, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }
}

String errorText(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  if (error is ApiException) {
    switch (error.code) {
      case 'INVALID_CREDENTIALS':
        return l.invalidCredentials;
      case 'INVALID_CODE':
        return l.invalidCode;
      case 'RATE_LIMITED':
        return l.tooManyAttempts;
      case 'NETWORK':
        return l.noConnection;
      default:
        return error.message;
    }
  }
  return l.genericError;
}

void showError(BuildContext context, Object error) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(errorText(context, error)), backgroundColor: Theme.of(context).colorScheme.error));

String formatUzs(String? amount) {
  if (amount == null || amount.isEmpty) return '—';
  final neg = amount.startsWith('-');
  final d = neg ? amount.substring(1) : amount;
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(' ');
    b.write(d[i]);
  }
  return neg ? '-$b' : b.toString();
}

String initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return p.length == 1 ? p.first[0].toUpperCase() : (p[0][0] + p[1][0]).toUpperCase();
}
