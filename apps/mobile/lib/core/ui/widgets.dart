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
                Icon(Icons.cloud_off_rounded, size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(child: Text(AppLocalizations.of(context).offlineBanner, style: TextStyle(color: scheme.onTertiaryContainer))),
              ]),
            ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.action});
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (hint != null) ...[const SizedBox(height: 6), Text(hint!, textAlign: TextAlign.center)],
            if (action != null) ...[const SizedBox(height: 16), action!],
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
      case 'USER_NOT_FOUND':
        return l.userNotFound;
      case 'ACCOUNT_DISABLED':
        return l.accountDisabled;
      case 'RATE_LIMITED':
        return l.tooManyAttempts;
      case 'NETWORK':
        return l.noConnection;
      case 'VALIDATION_FAILED':
        return l.checkYourInput;
      case 'INSUFFICIENT_STOCK':
        return l.insufficientStockGeneric;
      case 'INVALID_TRANSITION':
        return l.statusChangedMeanwhile;
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

enum FitKind { filled, tonal, outlined, text }

/// A button that never breaks its label in the middle of a word: icon + label when the label fits on ONE line in the
/// space it gets, otherwise just the (self-explaining) icon with the label as tooltip / screen-reader text.
/// Use it wherever buttons share a row or sit in tight places (320 dp phones).
class FitButton extends StatelessWidget {
  const FitButton({super.key, required this.icon, required this.label, required this.onPressed, this.kind = FitKind.outlined, this.style, this.height});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final FitKind kind;
  final ButtonStyle? style;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final textStyle = Theme.of(context).textTheme.labelLarge;
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle), maxLines: 1, textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      const chrome = 18.0 + 8 + 16 + 24; // icon + gap + Material 3 start/end padding of an icon button
      final fits = !c.hasBoundedWidth || tp.width + chrome <= c.maxWidth;
      final Widget button;
      if (fits) {
        final l = Text(label, maxLines: 1, softWrap: false);
        final i = Icon(icon);
        button = switch (kind) {
          FitKind.filled => FilledButton.icon(onPressed: onPressed, style: style, icon: i, label: l),
          FitKind.tonal => FilledButton.tonalIcon(onPressed: onPressed, style: style, icon: i, label: l),
          FitKind.outlined => OutlinedButton.icon(onPressed: onPressed, style: style, icon: i, label: l),
          FitKind.text => TextButton.icon(onPressed: onPressed, style: style, icon: i, label: l),
        };
      } else {
        final i = Icon(icon, semanticLabel: label);
        final s = (style ?? const ButtonStyle()).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero));
        button = Tooltip(
          message: label,
          child: switch (kind) {
            FitKind.filled => FilledButton(onPressed: onPressed, style: s, child: i),
            FitKind.tonal => FilledButton.tonal(onPressed: onPressed, style: s, child: i),
            FitKind.outlined => OutlinedButton(onPressed: onPressed, style: s, child: i),
            FitKind.text => TextButton(onPressed: onPressed, style: s, child: i),
          },
        );
      }
      return height == null ? button : SizedBox(height: height, width: c.hasBoundedWidth ? c.maxWidth : null, child: button);
    });
  }
}
