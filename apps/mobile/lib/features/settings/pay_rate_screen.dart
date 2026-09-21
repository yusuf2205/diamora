import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'pay_rate.dart';

/// ADMIN: see and change the ONE price of a 9 m kit. The change applies to every worker at once.
class PayRateScreen extends ConsumerWidget {
  const PayRateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rate = ref.watch(payRateProvider);
    final history = ref.watch(payRateHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.payRateTitle)),
      body: Column(children: [
        const ConnectionBanner(),
        Expanded(
          child: rate.when(
            loading: () => const SkeletonList(count: 3),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: errorText(context, e)),
            data: (r) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(payRateProvider);
                ref.invalidate(payRateHistoryProvider);
              },
              child: ListView(padding: AppTokens.screenPadding.copyWith(top: 8, bottom: 24), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.payRateSubtitle(r.kitMeters), style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text('${formatUzs(r.ratePerKit)} ${l.currency}', key: const Key('payRateValue'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(l.payRateAppliesToAll),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('changePayRate'),
                        onPressed: () => _edit(context, ref, r),
                        icon: const Icon(Icons.edit),
                        label: Text(l.payRateChange),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.payRateHistory, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...history.maybeWhen(
                  data: (items) => [for (final c in items) _HistoryTile(change: c)],
                  orElse: () => const <Widget>[],
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PayRate current) async {
    final l = AppLocalizations.of(context);
    final saved = await showDialog<PayRate>(context: context, builder: (_) => _EditDialog(current: current));
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.payRateSaved(formatUzs(saved.ratePerKit)))));
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.change});
  final PayRateChange change;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final when = change.createdAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    final title = change.previousRatePerKit == null ? '${formatUzs(change.ratePerKit)} ${l.currency} · ${l.payRateStart}' : '${formatUzs(change.previousRatePerKit)} → ${formatUzs(change.ratePerKit)} ${l.currency}';
    final details = [when, if (change.changedBy != null) change.changedBy!, if (change.note != null && change.note!.isNotEmpty) change.note!].join(' · ');
    return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history), title: Text(title), subtitle: Text(details));
  }
}

class _EditDialog extends ConsumerStatefulWidget {
  const _EditDialog({required this.current});
  final PayRate current;

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late final _amount = TextEditingController(text: widget.current.ratePerKit);
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < 1 || value > maxPayRate) {
      setState(() => _error = l.payRateInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(payRateRepositoryProvider).change(value, note: _note.text);
      ref.invalidate(payRateProvider);
      ref.invalidate(payRateHistoryProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.payRateChange),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const Key('payRateInput'),
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            decoration: InputDecoration(labelText: l.payRateNew(widget.current.kitMeters), suffixText: l.currency, errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLength: 500, decoration: InputDecoration(labelText: l.receivedNote)),
          const SizedBox(height: 4),
          Text(l.payRateAppliesToAll, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('savePayRate'), onPressed: _busy ? null : _save, child: Text(l.save)),
      ],
    );
  }
}

/// WORKER: read-only line on the home screen, live-updated when ADMIN changes the price.
class PayRateCard extends ConsumerWidget {
  const PayRateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rate = ref.watch(payRateProvider);
    return rate.maybeWhen(
      data: (r) => Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(l.payRatePerKit(r.kitMeters)),
          trailing: Text('${formatUzs(r.ratePerKit)} ${l.currency}', key: const Key('workerPayRate'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
