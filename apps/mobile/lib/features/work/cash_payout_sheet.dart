import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'assignment_admin_repository.dart';

/// M3 §14 — "Выплатить наличными": presets (вся сумма / половина) or a manual amount, one confirmation, one result.
Future<void> showCashPayoutSheet(BuildContext context, {required String workerId, required String balance}) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _CashPayoutSheet(workerId: workerId, balance: balance));
}

class _CashPayoutSheet extends ConsumerStatefulWidget {
  const _CashPayoutSheet({required this.workerId, required this.balance});
  final String workerId;
  final String balance;
  @override
  ConsumerState<_CashPayoutSheet> createState() => _CashPayoutSheetState();
}

class _CashPayoutSheetState extends ConsumerState<_CashPayoutSheet> {
  late final _amount = TextEditingController(text: widget.balance);
  bool _busy = false;

  int get _balanceInt => int.tryParse(widget.balance) ?? 0;
  int get _amountInt => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.payoutTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${l.payoutDue}: ${formatUzs(widget.balance)} ${l.currency}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_balanceInt <= 0)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(l.payoutNothingDue, textAlign: TextAlign.center))
          else ...[
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _amount.text = widget.balance), child: Text(l.payoutFull))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _amount.text = (_balanceInt ~/ 2).toString()), child: Text(l.payoutHalf))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _amount, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l.payoutAmountLabel, suffixText: l.currency, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(onPressed: _amountInt > 0 ? _confirm : null, child: Text(l.payoutSubmit)),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.payoutConfirmTitle),
        content: Text(l.payoutConfirmBody('${formatUzs(_amountInt.toString())} ${l.currency}')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.payoutSubmit)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(assignmentAdminRepositoryProvider).payout(widget.workerId, amount: _amountInt.toString());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.payoutSuccess)));
    } catch (e) {
      // the server's INVARIANT_VIOLATION here always means "amount > balance" (the only invariant this endpoint has) -
      // a plain, specific message beats the generic mapping, which would otherwise show the raw server sentence (§34)
      if (mounted) {
        if (e is ApiException && e.code == 'INVARIANT_VIOLATION') {
          showError(context, ApiException(code: e.code, message: l.payoutExceedsBalance));
        } else {
          showError(context, e);
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }
}
