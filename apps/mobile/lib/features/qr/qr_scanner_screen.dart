import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_exception.dart';
import '../../l10n/app_localizations.dart';
import '../work/assignment_admin_repository.dart';
import '../work/models.dart';
import 'qr_repository.dart';

/// Full QR scanner (M2 §12-13). After a scan: a WORKER code opens Worker Detail (scope-checked server-side — a MANAGER
/// scanning a stranger's worker gets the same "not found" `GET /workers/:id` would give, never her data); a KIT code
/// shows the assembled batch's composition. An invalid/unknown/revoked code is a clear, honest error — never a fake
/// success. Never used for money or catalog scanning (there is nothing else to scan in this codebase, by design).
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    // instant, unmistakable feedback that the camera READ the code: a buzz, a click, a green «QR распознан»
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    try {
      final res = await ref.read(qrRepositoryProvider).resolve(raw);
      if (!mounted) return;
      switch (classifyQr(res)) {
        case QrOutcomeType.worker:
          final workerId = (res['worker'] as Map)['id'] as String;
          _ok('${l.qrWorkerFound}: ${(res['worker'] as Map)['fullName'] ?? ''}');
          context.pop();
          context.push('/admin/workers/$workerId');
          return; // screen is gone; no need to reset _busy
        case QrOutcomeType.kit:
          await _showKit(l, (res['kit'] as Map).cast<String, dynamic>());
        case QrOutcomeType.assignment:
          await _showAssignment(l, (res['assignment'] as Map).cast<String, dynamic>());
        case QrOutcomeType.invalid:
          _snack(l.qrInvalid);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.status == 404 ? l.qrInvalid : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: Theme.of(context).colorScheme.error));

  /// success is green, never the red of an error
  void _ok(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(text))]), backgroundColor: Colors.green.shade700));

  Future<void> _showKit(AppLocalizations l, Map<String, dynamic> kit) {
    final items = (kit['items'] as List).cast<Map<String, dynamic>>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.qrKitFound, style: Theme.of(ctx).textTheme.titleSmall?.copyWith(color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 4),
            Text('${kit['kitTemplateName']} × ${kit['count']}', style: Theme.of(ctx).textTheme.titleMedium),
            Text('${kit['totalMeters']} м'),
            const Divider(height: 24),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(it['name'] as String)),
                  Text('${it['requiredQuantity']} ${it['unit']}'),
                ]),
              ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.confirm))),
          ]),
        ),
      ),
    );
  }

  /// M3 §12 pickup: scan an assignment QR -> see who/what -> one tap "Забрал" when it's actually ready. Any other
  /// status just shows the card (nothing to do yet, e.g. it's still being worked on).
  Future<void> _showAssignment(AppLocalizations l, Map<String, dynamic> a) async {
    final worker = (a['worker'] as Map).cast<String, dynamic>();
    final product = (a['product'] as Map?)?.cast<String, dynamic>();
    final color = (a['color'] as Map?)?.cast<String, dynamic>();
    final status = a['status'] as String;
    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(worker['fullName'] as String? ?? '', style: Theme.of(ctx).textTheme.titleMedium),
              Text(worker['phone'] as String? ?? '', style: Theme.of(ctx).textTheme.bodySmall),
              const Divider(height: 24),
              Text('${product?['name'] ?? ''} · ${color?['name'] ?? ''}', style: Theme.of(ctx).textTheme.bodyLarge),
              if (status == 'READY_TO_DELIVER') ...[
                // Phase 5.2: everything to check before handing the kit over
                Text('${a['plannedMeters']} м · ${l.receiveKits((a['kitCount'] as num).toInt())}'),
                if (a['dueAt'] != null) Text('${l.workDueDate}: ${_day(a['dueAt'] as String)}'),
                const SizedBox(height: 8),
                for (final m in ((a['materials'] as List?) ?? const []).cast<Map>())
                  Text(materialLine(m['name'] as String?, (m['quantity'] as num).toDouble(), m['unit'] as String?), style: Theme.of(ctx).textTheme.bodyMedium),
                if ((a['notes'] as String?)?.isNotEmpty == true) ...[const SizedBox(height: 6), Text(a['notes'] as String, style: Theme.of(ctx).textTheme.bodySmall)],
              ] else
                Text('${a['reportedMeters']} / ${a['plannedMeters']} м'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: status == 'READY_TO_DELIVER'
                    ? FilledButton.icon(
                        onPressed: busy ? null : () async {
                          setSheetState(() => busy = true);
                          try {
                            await ref.read(assignmentAdminRepositoryProvider).startHandoff(a['id'] as String);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (!mounted) return;
                            // the waiting screen: she scans the same QR, this screen turns green when she confirms
                            _ok(l.handoffStartedToast);
                            context.pop();
                            context.push('/admin/assignments/${a['id']}');
                          } on ApiException catch (e) {
                            setSheetState(() => busy = false);
                            if (ctx.mounted) _snack(e.message);
                          }
                        },
                        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_2_rounded),
                        label: Text(l.handoffStart),
                      )
                    : status == 'READY_FOR_PICKUP'
                    ? FilledButton.icon(
                        onPressed: busy ? null : () async {
                          setSheetState(() => busy = true);
                          try {
                            await ref.read(assignmentAdminRepositoryProvider).pickup(a['id'] as String);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) _ok(l.workPickedUp);
                          } on ApiException catch (e) {
                            setSheetState(() => busy = false);
                            if (ctx.mounted) _snack(e.message);
                          }
                        },
                        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(l.workPickedUp),
                      )
                    : OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.confirm)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _day(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.qrScan)),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Positioned(
          bottom: 32, left: 24, right: 24,
          child: Card(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            child: Padding(padding: const EdgeInsets.all(12), child: Text(l.qrScanHint, textAlign: TextAlign.center)),
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
                      Text(l.qrRecognized, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(width: 12),
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
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
