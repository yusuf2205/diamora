import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'models.dart';
import 'work_repository.dart';

/// Worker-side error text for the handoff: plain words, never a code. `null` = use the generic [errorText].
String? handoffErrorText(AppLocalizations l, Object e) {
  if (e is! ApiException) return null;
  return switch (e.code) {
    'FOREIGN_KIT' => l.receiveForeign,
    'HANDOFF_NOT_STARTED' => l.receiveNotStarted,
    'HANDOFF_EXPIRED' => l.receiveExpired,
    'NOT_FOUND' => l.qrInvalid,
    _ => null,
  };
}

/// Phase 5.3: the worker scans the kit QR the staff member brought. Her scanner can do exactly ONE thing: open the
/// receipt of HER OWN work. Anything else is a clear sentence, never another worker's data.
class ReceiveScanScreen extends ConsumerStatefulWidget {
  const ReceiveScanScreen({super.key, this.scannerBuilder});
  /// tests replace the camera
  final Widget Function(void Function(String code) onCode)? scannerBuilder;
  @override
  ConsumerState<ReceiveScanScreen> createState() => _ReceiveScanScreenState();
}

class _ReceiveScanScreenState extends ConsumerState<ReceiveScanScreen> {
  MobileScannerController? _controller;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.scannerBuilder == null) _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> onCode(String code) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() { _busy = true; _error = null; });
    final l = AppLocalizations.of(context);
    try {
      final scan = await ref.read(workRepositoryProvider).scanHandoff(code);
      if (!mounted) return;
      if (scan.state == 'CONFIRMED') {
        setState(() => _error = l.receiveAlready);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptReviewScreen(scan: scan)));
    } catch (e) {
      if (mounted) setState(() => _error = handoffErrorText(l, e) ?? errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.workScanQr)),
      body: Stack(children: [
        Positioned.fill(
          child: widget.scannerBuilder?.call(onCode) ??
              MobileScanner(controller: _controller, onDetect: (c) {
                final raw = c.barcodes.isEmpty ? null : c.barcodes.first.rawValue;
                if (raw != null) onCode(raw);
              }),
        ),
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: Card(
            color: _error != null ? scheme.errorContainer : scheme.surface.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(_error != null ? Icons.error_outline_rounded : Icons.qr_code_scanner_rounded, color: _error != null ? scheme.onErrorContainer : scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_error ?? l.receiveScanHint,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _error != null ? scheme.onErrorContainer : null, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Card(
                  color: Colors.green.shade700,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Text(AppLocalizations.of(context).qrRecognized, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Phase 5.4: «Получение работы» — exactly what she gets, then SHE decides. No success is shown before the server commits.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key, required this.scan});
  final HandoffScan scan;
  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  var _busy = false;

  Future<void> _confirm() async {
    if (_busy) return; // a double-tap is one request; the server is replay-safe on top of that
    setState(() => _busy = true);
    try {
      // the location is a nice extra fact of receipt, never a gate: at most 4 s, and only if already permitted
      double? lat, lng, acc;
      try {
        final pos = await ref.read(geoProvider).current().timeout(const Duration(seconds: 4));
        lat = pos.latitude; lng = pos.longitude; acc = pos.accuracy;
      } catch (_) {}
      await ref.read(workRepositoryProvider).confirmHandoff(widget.scan.handoffId, latitude: lat, longitude: lng, accuracyM: acc);
      ref.invalidate(currentWorkProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const ReceiveDoneScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(handoffErrorText(l, e) ?? errorText(context, e)), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _problem() async {
    final sent = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => HandoffProblemSheet(handoffId: widget.scan.handoffId),
    );
    if (sent == true && mounted) {
      ref.invalidate(currentWorkProvider);
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.problemSent)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = widget.scan.work;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.receiveTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        WorkHeroCard(work: w),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.inventory_2_rounded, color: scheme.primary), const SizedBox(width: 8), Text(l.workMaterials, style: text.titleMedium)]),
              const SizedBox(height: 8),
              for (final m in w.materials)
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(materialLine(m.name, m.quantity, m.unit), style: text.bodyLarge)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(Icons.fact_check_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(l.receiveCheckHint, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _busy ? null : _confirm,
                icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
                label: Text(l.receiveConfirm, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _busy ? null : _problem, icon: const Icon(Icons.report_problem_rounded), label: Text(l.receiveProblem)),
          ]),
        ),
      ),
    );
  }
}

/// The big, friendly summary of one piece of work: colour, name, metres, kits, deadline, pay. Used on the receipt and home.
class WorkHeroCard extends StatelessWidget {
  const WorkHeroCard({super.key, required this.work});
  final CurrentWork work;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = hexColor(work.colorHex) ?? scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 88,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.55)])),
          alignment: Alignment.center,
          child: const Icon(Icons.diamond_rounded, size: 44, color: Colors.white),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(work.variantLabel?.isNotEmpty == true ? '${work.productName} · ${work.variantLabel}' : work.productName, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(work.colorName, style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Pill(icon: Icons.straighten_rounded, text: '${work.plannedMeters.toStringAsFixed(0)} м'),
              _Pill(icon: Icons.layers_rounded, text: l.receiveKits(work.kitCount)),
              if (work.dueAt != null) _Pill(icon: Icons.event_rounded, text: formatDay(work.dueAt!)),
            ]),
            if (work.expectedPayment != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.payments_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text('${l.workExpectedEarning}: ', style: text.bodyMedium),
                Flexible(child: Text('${formatUzs(work.expectedPayment)} ${l.currency}', style: text.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800))),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}

/// Phase 5.7: «Есть проблема» — a reason in plain words + optional comment. Nothing is transferred.
class HandoffProblemSheet extends ConsumerStatefulWidget {
  const HandoffProblemSheet({super.key, required this.handoffId});
  final String handoffId;
  @override
  ConsumerState<HandoffProblemSheet> createState() => _HandoffProblemSheetState();
}

class _HandoffProblemSheetState extends ConsumerState<HandoffProblemSheet> {
  String? _reason;
  final _comment = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null || _busy) return;
    setState(() => _busy = true);
    try {
      final c = _comment.text.trim();
      await ref.read(workRepositoryProvider).reportHandoffProblem(widget.handoffId, reason: _reason!, comment: c.isEmpty ? null : c);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reasons = {
      'SHORTAGE': l.problemShortage, 'WRONG_COLOR': l.problemWrongColor, 'WRONG_MODEL': l.problemWrongModel,
      'WRONG_METERS': l.problemWrongMeters, 'DAMAGED': l.problemDamaged, 'OTHER': l.problemOther,
    };
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.problemTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in reasons.entries)
              ChoiceChip(label: Text(e.value), selected: _reason == e.key, onSelected: _busy ? null : (_) => setState(() => _reason = e.key)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _comment, maxLines: 3, maxLength: 500, decoration: InputDecoration(labelText: l.problemComment)),
          const SizedBox(height: 8),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(
              onPressed: _reason == null || _busy ? null : _send,
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.problemSend),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Shown ONLY after the server committed the receipt.
class ReceiveDoneScreen extends StatelessWidget {
  const ReceiveDoneScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
              ),
            ),
            const SizedBox(height: 24),
            Text(l.receiveDone, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l.receiveDoneHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            SizedBox(height: 56, child: FilledButton(onPressed: () => context.go('/worker/home'), child: Text(l.receiveGoHome))),
          ]),
        ),
      ),
    );
  }
}

Color? hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

String formatDay(DateTime d) {
  final t = d.toLocal();
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}
