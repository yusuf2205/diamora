import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'work_repository.dart';

/// Sends what was saved without internet as soon as it can: when the phone gets a network, when the live link to the
/// server comes back, when the app is opened again, and every 45 s while something waits. Wraps the worker's app.
class OfflineSync extends ConsumerStatefulWidget {
  const OfflineSync({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<OfflineSync> createState() => _OfflineSyncState();
}

class _OfflineSyncState extends ConsumerState<OfflineSync> {
  Timer? _tick;
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _flush);
    _tick = Timer.periodic(const Duration(seconds: 45), (_) => _flush());
    WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _life?.dispose();
    super.dispose();
  }

  Future<void> _flush() async {
    if (!mounted) return;
    final sent = await ref.read(offlineQueueProvider).flush().catchError((_) => 0);
    if (sent > 0 && mounted) {
      ref.invalidate(currentWorkProvider);
      ref.invalidate(myEarningsProvider);
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.offlineSent(sent))));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (_, next) { if (next.value == true) _flush(); });
    ref.listen(realtimeConnectedProvider, (_, next) { if (next.value == true) _flush(); });
    return widget.child;
  }
}

/// «Не отправлено: 2 — отправится само»; what the server refused is listed with a way to dismiss it.
class PendingActionsBanner extends ConsumerWidget {
  const PendingActionsBanner({super.key});

  String _what(AppLocalizations l, String kind) => switch (kind) {
        'progress' => l.offlineKindProgress,
        'ready' => l.offlineKindReady,
        'receive' => l.offlineKindReceive,
        _ => kind,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rows = ref.watch(pendingActionsProvider).value ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final waiting = rows.where((r) => r.lastError == null).toList();
    final refused = rows.where((r) => r.lastError != null).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        if (waiting.isNotEmpty)
          Card(
            key: const Key('pendingBanner'),
            color: scheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.cloud_upload_rounded, color: scheme.onTertiaryContainer),
              title: Text(l.offlineWaiting(waiting.length), style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w700)),
              subtitle: Text('${waiting.map((r) => _what(l, r.kind)).toSet().join(', ')} · ${l.offlineWillSend}', style: TextStyle(color: scheme.onTertiaryContainer)),
              trailing: IconButton(
                tooltip: l.offlineSendNow,
                icon: Icon(Icons.refresh_rounded, color: scheme.onTertiaryContainer),
                onPressed: () => ref.read(offlineQueueProvider).flush().then((n) {
                  if (n > 0) {
                    ref.invalidate(currentWorkProvider);
                    ref.invalidate(myEarningsProvider);
                  }
                }).catchError((_) {}),
              ),
            ),
          ),
        for (final r in refused)
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              title: Text(l.offlineRefused(_what(l, r.kind)), style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
              subtitle: Text(l.offlineRefusedHint, style: TextStyle(color: scheme.onErrorContainer)),
              trailing: IconButton(tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: Icon(Icons.close_rounded, color: scheme.onErrorContainer), onPressed: () => ref.read(offlineQueueProvider).dismiss(r.id)),
            ),
          ),
      ]),
    );
  }
}
