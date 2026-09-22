import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/pay_rate.dart';
import 'assignment_admin_repository.dart';
import 'assignment_models.dart';

/// M3 §12-13 — the "провести приёмку" screen: brought/accepted/defective/rework with a live earning preview, strict
/// validation (brought = accepted + defective + rework, matching the server's own rule exactly so the error is never
/// a surprise), and a clear result instead of a raw success/failure.
class AcceptanceScreen extends ConsumerStatefulWidget {
  const AcceptanceScreen({super.key, required this.assignment});
  final AssignmentDetail assignment;
  @override
  ConsumerState<AcceptanceScreen> createState() => _AcceptanceScreenState();
}

class _AcceptanceScreenState extends ConsumerState<AcceptanceScreen> {
  late final _brought = TextEditingController(text: widget.assignment.reportedMeters > 0 ? widget.assignment.reportedMeters.toStringAsFixed(1) : widget.assignment.plannedMeters.toStringAsFixed(0));
  late final _accepted = TextEditingController(text: _brought.text);
  final _defective = TextEditingController(text: '0');
  final _rework = TextEditingController(text: '0');
  final _comment = TextEditingController();
  bool _busy = false;

  double get _broughtVal => double.tryParse(_brought.text.replaceAll(',', '.')) ?? 0;
  double get _acceptedVal => double.tryParse(_accepted.text.replaceAll(',', '.')) ?? 0;
  double get _defectiveVal => double.tryParse(_defective.text.replaceAll(',', '.')) ?? 0;
  double get _reworkVal => double.tryParse(_rework.text.replaceAll(',', '.')) ?? 0;
  bool get _isValid => (_acceptedVal + _defectiveVal + _reworkVal - _broughtVal).abs() < 0.01 && _broughtVal >= 0;

  @override
  void dispose() {
    _brought.dispose();
    _accepted.dispose();
    _defective.dispose();
    _rework.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rate = ref.watch(payRateProvider).value;
    final ratePerKit = rate != null ? int.tryParse(rate.ratePerKit) : null;
    final earning = ratePerKit != null ? (ratePerKit * _acceptedVal / 9).round() : null;

    return Scaffold(
      appBar: AppBar(title: Text(l.acceptanceTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(widget.assignment.productName, style: Theme.of(context).textTheme.titleMedium),
                Text('${widget.assignment.plannedMeters.toStringAsFixed(0)} м', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _MetersField(label: l.acceptanceBrought, controller: _brought, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _MetersField(label: l.acceptanceAccepted, controller: _accepted, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _MetersField(label: l.acceptanceDefective, controller: _defective, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _MetersField(label: l.acceptanceRework, controller: _rework, onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          TextField(controller: _comment, maxLines: 2, decoration: InputDecoration(hintText: l.commentOptional, border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          if (!_isValid)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(l.acceptanceInvalid, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
            )
          else
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l.acceptanceAccepted}: ${_acceptedVal.toStringAsFixed(1)} м'),
                  if (_defectiveVal > 0) Text('${l.acceptanceDefective}: ${_defectiveVal.toStringAsFixed(1)} м'),
                  if (_reworkVal > 0) Text('${l.acceptanceRework}: ${_reworkVal.toStringAsFixed(1)} м'),
                  const SizedBox(height: 6),
                  if (earning != null) Text('${l.acceptanceCalculated}: ${formatUzs(earning.toString())} ${l.currency}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(width: double.infinity, child: FilledButton(onPressed: _isValid ? _submit : null, child: Text(l.acceptanceSubmit))),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(assignmentAdminRepositoryProvider).accept(
            widget.assignment.id,
            broughtMeters: _broughtVal.toStringAsFixed(2), acceptedMeters: _acceptedVal.toStringAsFixed(2),
            defectiveMeters: _defectiveVal.toStringAsFixed(2), reworkMeters: _reworkVal.toStringAsFixed(2),
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.acceptanceSuccess)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MetersField extends StatelessWidget {
  const _MetersField({required this.label, required this.controller, required this.onChanged});
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, suffixText: 'м', border: const OutlineInputBorder()),
      );
}
