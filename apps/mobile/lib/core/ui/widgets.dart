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
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final content = Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (hint != null) ...[const SizedBox(height: 6), Text(hint!, textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]);
        // on its own (a whole screen) it scrolls, so on a short phone the action button is never hidden under the
        // bottom bar; inside a list it is just a block (a list already scrolls)
        return box.hasBoundedHeight
            ? Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: content))
            : Padding(padding: const EdgeInsets.all(24), child: content);
      });
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
      case 'QR_NOT_YOURS':
        return l.qrNotYours;
      case 'QR_REVOKED':
        return l.qrRevoked;
      case 'OPEN_WORK':
        return l.errOpenWork;
      case 'IN_USE':
        final kits = (error.details is Map ? (error.details as Map)['kits'] : null) as List?;
        return kits != null && kits.isNotEmpty ? l.errInUseKits(kits.join(', ')) : l.errInUse;
      default:
        return error.message;
    }
  }
  return l.genericError;
}

/// The one «Удалить?» dialog: a plain sentence of what will happen and a red button. true only on an explicit confirm.
Future<bool> confirmDelete(BuildContext context, {required String title, required String body}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          key: const Key('confirmDelete'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.deleteAction),
        ),
      ],
    ),
  );
  return ok == true;
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

/// Text that never breaks a word in the middle: it wraps only between words, and if a single word is wider than the
/// space (a narrow phone, a big system font) the whole text is scaled down just enough to fit.
class WordSafeText extends StatelessWidget {
  const WordSafeText(this.text, {super.key, this.style, this.maxLines = 2, this.textAlign});
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final effective = DefaultTextStyle.of(context).style.merge(style);
      final scaler = MediaQuery.textScalerOf(context);
      var widest = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        final tp = TextPainter(text: TextSpan(text: word, style: effective), textDirection: Directionality.of(context), textScaler: scaler, maxLines: 1)..layout();
        if (tp.width > widest) widest = tp.width;
      }
      final factor = c.hasBoundedWidth && widest > c.maxWidth && widest > 0 ? (c.maxWidth / widest) * 0.98 : 1.0;
      final size = (effective.fontSize ?? 14) * factor;
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: effective.copyWith(fontSize: size));
    });
  }
}

/// A form (fields to type in). Phone: a bottom sheet. Tablet (>= 600 dp): a window in the middle that moves above the
/// keyboard - a tablet keyboard covers about half the screen and left a bottom sheet's fields hidden under it.
Future<T?> showFormSheet<T>(BuildContext context, {required WidgetBuilder builder, bool showDragHandle = false, bool useSafeArea = true}) {
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        key: const Key('formDialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // the window itself stays above the keyboard; the form must not add the keyboard's height a second time
          child: MediaQuery.removeViewInsets(
            context: ctx,
            removeBottom: true,
            child: SingleChildScrollView(padding: const EdgeInsets.only(top: 8), child: Builder(builder: builder)),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: useSafeArea, showDragHandle: showDragHandle, builder: builder);
}
